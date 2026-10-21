package main

import (
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/habil/revisor/internal/revisar"
)

// entorno devuelve un getenv falso a partir de un mapa.
func entorno(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func sinArchivos(string) ([]byte, error) { return nil, errors.New("no debería leer archivos") }

func TestLeerConfigPorOmision(t *testing.T) {
	cfg, err := LeerConfig(entorno(map[string]string{
		VarServicios: "uno http://a:9000/ 2s, dos http://b:9000/",
	}), sinArchivos)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Puerto != "8080" {
		t.Errorf("puerto = %q, quería 8080", cfg.Puerto)
	}
	if len(cfg.Servicios) != 2 || cfg.Servicios[0].Nombre != "uno" || cfg.Servicios[0].Timeout != 2*time.Second {
		t.Errorf("servicios = %+v", cfg.Servicios)
	}
	if cfg.Token != "" {
		t.Errorf("sin token configurado, Token debería estar vacío")
	}
}

func TestLeerConfigErrores(t *testing.T) {
	casos := map[string]map[string]string{
		"falta la lista":  {},
		"puerto inválido": {VarServicios: "uno http://a/", VarPuerto: "ochenta"},
		"url sin esquema": {VarServicios: "uno a:9000"},
	}
	for nombre, env := range casos {
		if _, err := LeerConfig(entorno(env), sinArchivos); err == nil {
			t.Errorf("%s: esperaba error", nombre)
		}
	}
}

func TestTokenPorArchivoGanaAlDeEntorno(t *testing.T) {
	ruta := filepath.Join(t.TempDir(), "token")
	os.WriteFile(ruta, []byte("de-archivo\n"), 0o600)
	cfg, err := LeerConfig(entorno(map[string]string{
		VarServicios: "uno http://a/", VarTokenArchivo: ruta, VarToken: "de-entorno",
	}), os.ReadFile)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Token != "de-archivo" || len(cfg.Avisos) != 0 {
		t.Errorf("token = %q, avisos = %v", cfg.Token, cfg.Avisos)
	}
}

func TestTokenPorEntornoAvisa(t *testing.T) {
	cfg, _ := LeerConfig(entorno(map[string]string{VarServicios: "uno http://a/", VarToken: "x"}), sinArchivos)
	if len(cfg.Avisos) != 1 {
		t.Errorf("esperaba un aviso por el token en el entorno, hay %v", cfg.Avisos)
	}
}

func servidorDePrueba(t *testing.T, cfg Config) *httptest.Server {
	t.Helper()
	falso := &revisar.Falso{Respuestas: map[string]revisar.RespuestaFalsa{
		"caido": {Codigo: 503},
	}}
	srv := httptest.NewServer(Rutas(cfg, falso, io.Discard))
	t.Cleanup(srv.Close)
	return srv
}

func TestSalud(t *testing.T) {
	srv := servidorDePrueba(t, Config{})
	resp, err := http.Get(srv.URL + "/salud")
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 200 {
		t.Errorf("código = %d", resp.StatusCode)
	}
}

func TestEstadosEnTablaMarcaLaFalla(t *testing.T) {
	cfg, _ := LeerConfig(entorno(map[string]string{VarServicios: "sano http://a/, caido http://b/"}), sinArchivos)
	srv := servidorDePrueba(t, cfg)
	resp, err := http.Get(srv.URL + "/api/estados?formato=tabla")
	if err != nil {
		t.Fatal(err)
	}
	cuerpo, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(cuerpo), "FALLA") {
		t.Errorf("la tabla debería marcar FALLA:\n%s", cuerpo)
	}
}

func TestEstadosPideToken(t *testing.T) {
	cfg, _ := LeerConfig(entorno(map[string]string{VarServicios: "sano http://a/", VarToken: "secreto"}), sinArchivos)
	srv := servidorDePrueba(t, cfg)

	resp, _ := http.Get(srv.URL + "/api/estados")
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("sin token: código = %d, quería 401", resp.StatusCode)
	}

	req, _ := http.NewRequest("GET", srv.URL+"/api/estados", nil)
	req.Header.Set("Authorization", "Bearer secreto")
	resp, _ = http.DefaultClient.Do(req)
	if resp.StatusCode != http.StatusOK {
		t.Errorf("con token: código = %d, quería 200", resp.StatusCode)
	}
}

func TestEstadosGuardaElReporte(t *testing.T) {
	ruta := filepath.Join(t.TempDir(), "reporte.json")
	cfg, _ := LeerConfig(entorno(map[string]string{VarServicios: "sano http://a/", VarReporte: ruta}), sinArchivos)
	srv := servidorDePrueba(t, cfg)
	if _, err := http.Get(srv.URL + "/api/estados"); err != nil {
		t.Fatal(err)
	}
	datos, err := os.ReadFile(ruta)
	if err != nil || !strings.Contains(string(datos), `"servicio": "sano"`) {
		t.Errorf("reporte guardado = %q, err = %v", datos, err)
	}
}

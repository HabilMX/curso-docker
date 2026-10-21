package main

import (
	"bytes"
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/habil/revisor/internal/reporte"
	"github.com/habil/revisor/internal/revisar"
)

// LimiteGeneral es el tiempo máximo para armar un reporte completo, igual que
// la bandera --limite del curso de Go.
const LimiteGeneral = 10 * time.Second

// PlazoApagado es cuánto se espera a que terminen las peticiones en curso
// cuando llega la señal de apagado. Es menor que los 10 segundos que concede
// docker stop por omisión, para que el proceso termine solo y no lo maten.
const PlazoApagado = 5 * time.Second

// servir levanta el servidor y se queda ahí hasta recibir SIGTERM o SIGINT.
func servir(cfg Config, salida, errores io.Writer) int {
	srv := &http.Server{
		Addr:              ":" + cfg.Puerto,
		Handler:           Rutas(cfg, revisar.NuevoHTTP(LimiteGeneral), salida),
		ReadHeaderTimeout: 5 * time.Second,
	}

	// La señal se pide ANTES de empezar a escuchar: si llegara entre las dos
	// cosas, el proceso moriría sin apagarse en orden.
	senales := make(chan os.Signal, 1)
	signal.Notify(senales, syscall.SIGTERM, syscall.SIGINT)

	fallo := make(chan error, 1)
	go func() { fallo <- srv.ListenAndServe() }()

	fmt.Fprintf(salida, "revisor %s escuchando en :%s (%d servicio(s))\n", version, cfg.Puerto, len(cfg.Servicios))

	select {
	case err := <-fallo:
		fmt.Fprintln(errores, "revisor:", err)
		return 1
	case s := <-senales:
		fmt.Fprintf(salida, "revisor: recibí %v, apagando\n", s)
	}

	ctx, cancelar := context.WithTimeout(context.Background(), PlazoApagado)
	defer cancelar()
	if err := srv.Shutdown(ctx); err != nil {
		fmt.Fprintln(errores, "revisor: el apagado no terminó a tiempo:", err)
		return 1
	}
	fmt.Fprintln(salida, "revisor: apagado limpio")
	return 0
}

// Rutas arma el enrutador. Recibe el Revisor como parámetro para que las
// pruebas le pasen el falso del curso de Go y no toquen la red.
func Rutas(cfg Config, r revisar.Revisor, bitacora io.Writer) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /salud", func(w http.ResponseWriter, _ *http.Request) {
		responderJSON(w, http.StatusOK, map[string]string{"estado": "vivo", "version": version})
	})

	mux.HandleFunc("GET /api/estados", func(w http.ResponseWriter, req *http.Request) {
		if cfg.Token != "" && !tokenValido(req, cfg.Token) {
			responderJSON(w, http.StatusUnauthorized, map[string]string{"error": "falta el token o no es válido"})
			return
		}

		ctx, cancelar := context.WithTimeout(req.Context(), LimiteGeneral)
		defer cancelar()
		estados := revisar.Todos(ctx, r, cfg.Servicios, 0)

		var cuerpo bytes.Buffer
		if err := reporte.JSON(&cuerpo, estados); err != nil {
			responderJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		if cfg.RutaReporte != "" {
			if err := guardar(cfg.RutaReporte, cuerpo.Bytes()); err != nil {
				responderJSON(w, http.StatusInternalServerError,
					map[string]string{"error": "no pude guardar el reporte: " + err.Error()})
				return
			}
		}

		if req.URL.Query().Get("formato") == "tabla" {
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			reporte.Tabla(w, estados)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write(cuerpo.Bytes())
	})

	return registrar(mux, bitacora)
}

// tokenValido compara en tiempo constante, para no regalar pistas por cuánto
// tarda la comparación.
func tokenValido(req *http.Request, token string) bool {
	recibido, ok := strings.CutPrefix(req.Header.Get("Authorization"), "Bearer ")
	return ok && subtle.ConstantTimeCompare([]byte(recibido), []byte(token)) == 1
}

// guardar escribe el reporte en un archivo temporal de la misma carpeta y
// luego lo renombra: quien lea el archivo ve el reporte viejo o el nuevo,
// nunca uno a medias.
func guardar(ruta string, datos []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(ruta), ".reporte-*.tmp")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name()) // si el rename funcionó, ya no existe y esto no hace nada
	if _, err := tmp.Write(datos); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), ruta)
}

func responderJSON(w http.ResponseWriter, codigo int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(codigo)
	json.NewEncoder(w).Encode(v)
}

// registrar escribe una línea por petición: método, ruta, código y tiempo.
// Va a la salida estándar porque ahí es donde docker logs la busca.
func registrar(siguiente http.Handler, bitacora io.Writer) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		inicio := time.Now()
		rec := &grabadora{ResponseWriter: w, codigo: http.StatusOK}
		siguiente.ServeHTTP(rec, req)
		fmt.Fprintf(bitacora, "revisor: %s %s %d %s\n", req.Method, req.URL.Path, rec.codigo,
			time.Since(inicio).Round(time.Millisecond))
	})
}

type grabadora struct {
	http.ResponseWriter
	codigo int
}

func (g *grabadora) WriteHeader(codigo int) {
	g.codigo = codigo
	g.ResponseWriter.WriteHeader(codigo)
}

// healthcheck consulta el /salud del propio proceso. Existe para que la imagen
// final, que no tiene shell ni curl, pueda vigilarse a sí misma.
func healthcheck(getenv func(string) string, salida, errores io.Writer) int {
	puerto := getenv(VarPuerto)
	if puerto == "" {
		puerto = PuertoPorOmision
	}
	cliente := &http.Client{Timeout: 2 * time.Second}
	resp, err := cliente.Get("http://127.0.0.1:" + puerto + "/salud")
	if err != nil {
		var urlErr interface{ Timeout() bool }
		if errors.As(err, &urlErr) && urlErr.Timeout() {
			fmt.Fprintln(errores, "no sano: /salud no contestó en 2s")
		} else {
			fmt.Fprintln(errores, "no sano:", err)
		}
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Fprintf(errores, "no sano: /salud respondió %d\n", resp.StatusCode)
		return 1
	}
	fmt.Fprintln(salida, "sano")
	return 0
}

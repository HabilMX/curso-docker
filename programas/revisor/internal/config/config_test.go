package config

import (
	"strings"
	"testing"
	"time"
)

func TestInterpretar_casosValidos(t *testing.T) {
	entrada := `
# comentario, se ignora
catalogo  https://catalogo.interno.mx

pagos     https://pagos.interno.mx      500ms
`
	servicios, err := Interpretar([]byte(entrada), "prueba.txt")
	if err != nil {
		t.Fatalf("Interpretar() devolvió error inesperado: %v", err)
	}
	if len(servicios) != 2 {
		t.Fatalf("Interpretar() devolvió %d servicios, quería 2", len(servicios))
	}
	if servicios[0].Nombre != "catalogo" || servicios[0].Timeout != 0 {
		t.Errorf("servicio 0 = %+v, no es el esperado", servicios[0])
	}
	if servicios[1].Nombre != "pagos" || servicios[1].Timeout != 500*time.Millisecond {
		t.Errorf("servicio 1 = %+v, no es el esperado", servicios[1])
	}
}

func TestInterpretar_casosDeError(t *testing.T) {
	casos := []struct {
		nombre   string
		entrada  string
		contexto string // fragmento que el mensaje de error debe contener
	}{
		{
			nombre:   "nombre repetido",
			entrada:  "catalogo https://a.mx\ncatalogo https://b.mx\n",
			contexto: "ya estaba en la linea",
		},
		{
			nombre:   "url sin esquema",
			entrada:  "catalogo catalogo.interno.mx\n",
			contexto: "debe empezar con http",
		},
		{
			nombre:   "tiempo limite invalido",
			entrada:  "catalogo https://a.mx nombas\n",
			contexto: "invalido",
		},
		{
			nombre:   "tiempo limite en cero",
			entrada:  "catalogo https://a.mx 0s\n",
			contexto: "mayor que cero",
		},
		{
			nombre:   "faltan campos",
			entrada:  "catalogo\n",
			contexto: "esperaba",
		},
		{
			nombre:   "archivo sin servicios",
			entrada:  "# solo comentarios\n\n",
			contexto: "no declara ningun servicio",
		},
	}

	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			_, err := Interpretar([]byte(c.entrada), "prueba.txt")
			if err == nil {
				t.Fatalf("Interpretar() no devolvió error, y debía contener %q", c.contexto)
			}
			if !strings.Contains(err.Error(), c.contexto) {
				t.Errorf("Interpretar() error = %q, quería que contuviera %q", err.Error(), c.contexto)
			}
		})
	}
}

func TestCargar_archivoInexistente(t *testing.T) {
	_, err := Cargar("/ruta/que/no/existe.txt")
	if err == nil {
		t.Fatal("Cargar() no devolvió error con una ruta inexistente")
	}
}

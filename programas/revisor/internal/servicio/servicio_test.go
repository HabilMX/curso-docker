package servicio

import (
	"testing"
	"time"
)

func TestEtiqueta(t *testing.T) {
	casos := []struct {
		nombre   string
		servicio Servicio
		quiere   string
	}{
		{"nombre normal", Servicio{Nombre: "catalogo"}, "catalogo"},
		{"sin nombre", Servicio{}, "(sin nombre)"},
	}

	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			if got := c.servicio.Etiqueta(); got != c.quiere {
				t.Errorf("Etiqueta() = %q, quería %q", got, c.quiere)
			}
		})
	}
}

func TestEsSeguro(t *testing.T) {
	casos := []struct {
		nombre string
		url    string
		quiere bool
	}{
		{"https minuscula", "https://api.ejemplo.mx", true},
		{"https mayuscula", "HTTPS://api.ejemplo.mx", true},
		{"http", "http://api.ejemplo.mx", false},
		{"vacio", "", false},
	}

	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			s := Servicio{URL: c.url}
			if got := s.EsSeguro(); got != c.quiere {
				t.Errorf("EsSeguro() = %v, quería %v", got, c.quiere)
			}
		})
	}
}

func TestTimeoutEfectivo(t *testing.T) {
	casos := []struct {
		nombre  string
		timeout time.Duration
		quiere  time.Duration
	}{
		{"declarado", 5 * time.Second, 5 * time.Second},
		{"cero (valor por omision)", 0, TimeoutPorOmision},
		{"negativo (dato corrupto, no debe pasar)", -1 * time.Second, TimeoutPorOmision},
	}

	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			s := Servicio{Timeout: c.timeout}
			if got := s.TimeoutEfectivo(); got != c.quiere {
				t.Errorf("TimeoutEfectivo() = %v, quería %v", got, c.quiere)
			}
		})
	}
}

func TestEstadoOK(t *testing.T) {
	casos := []struct {
		nombre string
		estado Estado
		quiere bool
	}{
		{"200 sin error", Estado{Codigo: 200}, true},
		{"299 sin error", Estado{Codigo: 299}, true},
		{"404", Estado{Codigo: 404}, false},
		{"500", Estado{Codigo: 500}, false},
		{"sin respuesta (codigo cero)", Estado{Codigo: 0}, false},
		{"con error aunque el codigo sea 200", Estado{Codigo: 200, Err: errTimeoutDePrueba}, false},
		{"199, justo debajo del rango", Estado{Codigo: 199}, false},
		{"300, justo arriba del rango", Estado{Codigo: 300}, false},
	}

	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			if got := c.estado.OK(); got != c.quiere {
				t.Errorf("OK() = %v, quería %v", got, c.quiere)
			}
		})
	}
}

func TestEstadoMotivo(t *testing.T) {
	sano := Estado{Codigo: 200}
	if got := sano.Motivo(); got != "" {
		t.Errorf("Motivo() de un estado sano = %q, quería cadena vacía", got)
	}

	sinRespuesta := Estado{Codigo: 0}
	if got := sinRespuesta.Motivo(); got != "sin respuesta" {
		t.Errorf("Motivo() = %q, quería %q", got, "sin respuesta")
	}

	conCodigo := Estado{Codigo: 500}
	if got := conCodigo.Motivo(); got != "codigo 500" {
		t.Errorf("Motivo() = %q, quería %q", got, "codigo 500")
	}
}

var errTimeoutDePrueba = &erroTexto{"se acabo el tiempo de espera"}

type erroTexto struct{ texto string }

func (e *erroTexto) Error() string { return e.texto }

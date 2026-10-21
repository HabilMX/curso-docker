package revisar

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/habil/revisor/internal/servicio"
)

func TestTodos_casoBasico(t *testing.T) {
	f := &Falso{Respuestas: map[string]RespuestaFalsa{
		"pagos": {Codigo: 500},
	}}
	servicios := []servicio.Servicio{
		{Nombre: "catalogo", URL: "https://x"},
		{Nombre: "pagos", URL: "https://x"},
		{Nombre: "inventario", URL: "https://x"},
	}

	estados := Todos(context.Background(), f, servicios, 0)

	if len(estados) != 3 {
		t.Fatalf("Todos() devolvió %d estados, quería 3", len(estados))
	}
	if f.Contador != 3 {
		t.Errorf("Falso.Contador = %d, quería 3 (una llamada por servicio)", f.Contador)
	}

	porNombre := map[string]servicio.Estado{}
	for _, e := range estados {
		porNombre[e.Servicio.Nombre] = e
	}
	if !porNombre["catalogo"].OK() {
		t.Errorf("catalogo debía estar OK, quedó %+v", porNombre["catalogo"])
	}
	if porNombre["pagos"].OK() {
		t.Errorf("pagos NO debía estar OK (500), quedó %+v", porNombre["pagos"])
	}
}

func TestTodos_respetaElTimeoutPorServicio(t *testing.T) {
	f := &Falso{Respuestas: map[string]RespuestaFalsa{
		"lento": {Colgado: true},
	}}
	servicios := []servicio.Servicio{
		{Nombre: "lento", URL: "https://x", Timeout: 30 * time.Millisecond},
	}

	inicio := time.Now()
	estados := Todos(context.Background(), f, servicios, 1)
	transcurrido := time.Since(inicio)

	if transcurrido > 200*time.Millisecond {
		t.Fatalf("Todos() tardó %v; el timeout de 30ms del servicio debió cortarlo mucho antes", transcurrido)
	}
	if estados[0].Err == nil {
		t.Fatalf("estado del servicio colgado no trae error; debía traer uno de tiempo agotado")
	}
}

func TestTodos_elParaleloLimitaCuantasCorrenALaVez(t *testing.T) {
	const totalServicios = 20
	const limite = 3

	var enVuelo int32
	var maximoObservado int32

	// Este Falso mide, con un contador atómico, cuántas llamadas a Revisar
	// están en curso AL MISMO TIEMPO. Si el semáforo de Todos funciona,
	// maximoObservado nunca debe pasar de `limite`.
	medidor := &medidorDeConcurrencia{
		enVuelo:         &enVuelo,
		maximoObservado: &maximoObservado,
		espera:          15 * time.Millisecond,
	}

	servicios := make([]servicio.Servicio, totalServicios)
	for i := range servicios {
		servicios[i] = servicio.Servicio{Nombre: "s", URL: "https://x"}
	}

	Todos(context.Background(), medidor, servicios, limite)

	max := atomic.LoadInt32(&maximoObservado)
	if max > int32(limite) {
		t.Errorf("se observaron %d consultas simultáneas; el límite era %d", max, limite)
	}
	if max == 0 {
		t.Fatal("nunca se observó ninguna consulta en vuelo; la prueba no está midiendo nada")
	}
}

// medidorDeConcurrencia es un Revisor de prueba que solo existe para contar
// cuántas llamadas a Revisar están abiertas al mismo tiempo.
type medidorDeConcurrencia struct {
	enVuelo         *int32
	maximoObservado *int32
	espera          time.Duration
}

func (m *medidorDeConcurrencia) Revisar(ctx context.Context, s servicio.Servicio) servicio.Estado {
	actual := atomic.AddInt32(m.enVuelo, 1)
	defer atomic.AddInt32(m.enVuelo, -1)

	for {
		max := atomic.LoadInt32(m.maximoObservado)
		if actual <= max || atomic.CompareAndSwapInt32(m.maximoObservado, max, actual) {
			break
		}
	}

	time.Sleep(m.espera)
	return servicio.Estado{Servicio: s, Codigo: 200}
}

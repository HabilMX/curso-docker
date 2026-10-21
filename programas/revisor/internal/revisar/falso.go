package revisar

import (
	"context"
	"sync"
	"time"

	"github.com/habil/revisor/internal/servicio"
)

// Falso es un Revisor que nunca toca la red. Existe para poder probar Todos
// —la función concurrente— con resultados exactos y predecibles, en vez de
// depender de que un servidor de verdad esté arriba y conteste rápido.
//
// Se configura con Respuestas: un mapa de nombre de servicio -> lo que Falso
// debe "contestar" cuando lo consulten, incluyendo cuánto tardar en hacerlo.
// Si un servicio no está en el mapa, Falso contesta 200 de inmediato.
//
// 🔒 Falso lleva su propio mutex porque las pruebas lo consultan desde varias
// goroutines a la vez (eso es justo lo que Todos hace) y Contador se
// incrementa en cada llamada: sin el candado, el detector de carreras (`go
// test -race`) lo señala de inmediato. Ésa es la prueba de que hace falta,
// no una suposición.
type Falso struct {
	Respuestas map[string]RespuestaFalsa

	mu       sync.Mutex
	Contador int // cuántas veces se llamó a Revisar; solo para pruebas
}

// RespuestaFalsa es lo que Falso va a devolver para un servicio en particular.
type RespuestaFalsa struct {
	Codigo  int
	Espera  time.Duration // simula latencia de red
	Err     error
	Colgado bool // si es true, Revisar no responde hasta que el context lo cancele
}

// Revisar cumple la interfaz Revisor sin tocar la red.
func (f *Falso) Revisar(ctx context.Context, s servicio.Servicio) servicio.Estado {
	f.mu.Lock()
	f.Contador++
	f.mu.Unlock()

	r, existe := f.Respuestas[s.Nombre]
	if !existe {
		return servicio.Estado{Servicio: s, Codigo: 200}
	}

	if r.Colgado {
		// Simula un servicio que acepta la conexión y nunca contesta: la única
		// forma de salir de aquí es que el context de arriba se cancele.
		<-ctx.Done()
		return servicio.Estado{Servicio: s, Err: traducir(ctx, ctx.Err())}
	}

	if r.Espera > 0 {
		temporizador := time.NewTimer(r.Espera)
		defer temporizador.Stop()
		select {
		case <-temporizador.C:
			// pasó el tiempo simulado; sigue abajo con la respuesta normal
		case <-ctx.Done():
			return servicio.Estado{Servicio: s, Err: traducir(ctx, ctx.Err())}
		}
	}

	if r.Err != nil {
		return servicio.Estado{Servicio: s, Err: r.Err}
	}
	return servicio.Estado{Servicio: s, Codigo: r.Codigo}
}

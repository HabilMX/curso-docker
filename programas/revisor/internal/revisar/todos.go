package revisar

import (
	"context"
	"sync"

	"github.com/habil/revisor/internal/servicio"
)

// ParaleloPorOmision es cuántos servicios se consultan a la vez cuando nadie
// dice otra cosa.
const ParaleloPorOmision = 5

// Todos consulta todos los servicios a la vez y devuelve sus estados.
//
// Tres cosas pasan aquí, y conviene verlas por separado:
//
//  1. Una goroutine por servicio. Lanzarlas es barato; lo que cuesta es
//     acordarse de esperarlas, y de eso se encarga el WaitGroup.
//  2. Un canal recoge los resultados. Nadie escribe en una estructura
//     compartida, así que no hace falta ningún candado.
//  3. Un semáforo limita cuántas consultas hay abiertas al mismo tiempo. Con mil
//     servicios y sin límite, el programa abriría mil conexiones de golpe y el
//     cuello de botella sería la máquina propia, no los servicios.
//
// El orden del resultado NO es el de la entrada: gana quien conteste primero.
// Ordenar es trabajo de quien imprime, no de quien mide.
func Todos(ctx context.Context, r Revisor, servicios []servicio.Servicio, paralelo int) []servicio.Estado {
	if len(servicios) == 0 {
		return nil
	}
	if paralelo <= 0 {
		paralelo = ParaleloPorOmision
	}

	resultados := make(chan servicio.Estado, len(servicios))
	semaforo := make(chan struct{}, paralelo)

	var wg sync.WaitGroup
	for _, s := range servicios {
		wg.Add(1)
		go func() {
			defer wg.Done()

			semaforo <- struct{}{}        // pide turno; se bloquea si ya hay «paralelo» corriendo
			defer func() { <-semaforo }() // devuelve el turno pase lo que pase

			// Cada servicio tiene su propio tiempo límite, hijo del general. Si
			// el de arriba se cancela, este muere con él.
			propio, cancelar := context.WithTimeout(ctx, s.TimeoutEfectivo())
			defer cancelar() // sin esto, el temporizador no se libera: es la fuga más común de Go

			resultados <- r.Revisar(propio, s)
		}()
	}

	// Quien envía cierra, nunca quien recibe. Y se cierra desde otra goroutine
	// porque Wait tiene que poder esperar mientras el bucle de abajo ya está
	// recibiendo: si cerráramos aquí mismo, con el canal lleno nos trabaríamos.
	go func() {
		wg.Wait()
		close(resultados)
	}()

	estados := make([]servicio.Estado, 0, len(servicios))
	for e := range resultados {
		estados = append(estados, e)
	}
	return estados
}

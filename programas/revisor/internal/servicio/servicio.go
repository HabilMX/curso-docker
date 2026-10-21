// Package servicio define el vocabulario del programa: qué es un servicio y qué
// es el estado en que lo encontramos.
//
// Está aparte del resto a propósito. Es el único paquete que todos los demás
// importan, y no importa a ninguno: así nunca puede haber un ciclo de
// importaciones, y leer este archivo alcanza para entender de qué habla el
// programa.
package servicio

import (
	"fmt"
	"strings"
	"time"
)

// TimeoutPorOmision es lo que se le concede a un servicio que no declara
// cuánto se le espera. Dos segundos: suficiente para una red sana, corto para
// que un servicio caído no detenga el reporte.
const TimeoutPorOmision = 2 * time.Second

// Servicio es una cosa que sabemos consultar por HTTP.
type Servicio struct {
	Nombre  string        // cómo se llama en el reporte; único en la lista
	URL     string        // dirección completa, con esquema
	Timeout time.Duration // cuánto se le espera antes de darlo por perdido
}

// Etiqueta devuelve el nombre del servicio listo para imprimir en una tabla.
func (s Servicio) Etiqueta() string {
	if s.Nombre == "" {
		return "(sin nombre)"
	}
	return s.Nombre
}

// EsSeguro dice si el servicio se consulta cifrado.
func (s Servicio) EsSeguro() bool {
	return strings.HasPrefix(strings.ToLower(s.URL), "https://")
}

// TimeoutEfectivo devuelve el tiempo límite que de verdad se va a aplicar.
//
// Existe para que el valor cero del struct sea usable: un Servicio{} recién
// creado, o uno cuya línea de configuración no traía tiempo, no se queda con un
// timeout de cero (que significaría «no esperes nada» y fallaría siempre).
func (s Servicio) TimeoutEfectivo() time.Duration {
	if s.Timeout <= 0 {
		return TimeoutPorOmision
	}
	return s.Timeout
}

// Estado es el resultado de haber consultado un servicio: una fotografía, no un
// objeto que cambia.
//
// No lleva etiquetas `json` a propósito. Lo que sale al mundo lo decide el
// paquete reporte, con su propio struct: si algún día cambia el nombre de un
// campo aquí, no se rompe el formato que otros programas ya están leyendo.
type Estado struct {
	Servicio Servicio      // a quién se consultó
	Codigo   int           // código HTTP; 0 si nunca hubo respuesta
	Duracion time.Duration // cuánto tardó la consulta
	Err      error         // por qué falló, o nil
}

// OK dice si el servicio está sano: respondió, y respondió bien.
func (e Estado) OK() bool {
	return e.Err == nil && e.Codigo >= 200 && e.Codigo <= 299
}

// Motivo explica en una línea por qué el estado no es OK, para la tabla.
// Devuelve la cadena vacía cuando el servicio está sano.
func (e Estado) Motivo() string {
	switch {
	case e.OK():
		return ""
	case e.Err != nil:
		return e.Err.Error()
	case e.Codigo == 0:
		return "sin respuesta"
	default:
		return fmt.Sprintf("codigo %d", e.Codigo)
	}
}

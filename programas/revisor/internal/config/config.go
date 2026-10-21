// Package config traduce un archivo de texto a la lista de servicios que el
// programa va a revisar.
//
// Está separado de la lectura del disco a propósito: Interpretar recibe bytes,
// así que se puede probar con cien entradas distintas sin crear un solo archivo
// temporal.
package config

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/habil/revisor/internal/servicio"
)

// Cargar lee el archivo de la ruta dada y devuelve los servicios que declara.
func Cargar(ruta string) ([]servicio.Servicio, error) {
	datos, err := os.ReadFile(ruta)
	if err != nil {
		return nil, fmt.Errorf("leyendo la configuracion: %w", err)
	}
	return Interpretar(datos, ruta)
}

// Interpretar convierte el contenido de la configuracion en servicios.
//
// El parametro origen solo se usa para los mensajes de error: es el nombre que
// el usuario va a leer cuando algo esté mal escrito.
//
// Formato, una linea por servicio:
//
//	nombre  url  [tiempo-limite]
//
// Las lineas vacias y las que empiezan con # se ignoran.
func Interpretar(datos []byte, origen string) ([]servicio.Servicio, error) {
	var servicios []servicio.Servicio
	vistos := make(map[string]int) // nombre -> numero de linea donde aparecio

	for i, linea := range strings.Split(string(datos), "\n") {
		numero := i + 1
		linea = strings.TrimSpace(linea)
		if linea == "" || strings.HasPrefix(linea, "#") {
			continue
		}

		campos := strings.Fields(linea)
		if len(campos) < 2 || len(campos) > 3 {
			return nil, fmt.Errorf("%s:%d: esperaba «nombre url [tiempo]», hay %d campo(s)",
				origen, numero, len(campos))
		}

		nombre, url := campos[0], campos[1]

		if antes, repetido := vistos[nombre]; repetido {
			return nil, fmt.Errorf("%s:%d: el nombre %q ya estaba en la linea %d",
				origen, numero, nombre, antes)
		}
		if !tieneEsquema(url) {
			return nil, fmt.Errorf("%s:%d: la URL %q debe empezar con http:// o https://",
				origen, numero, url)
		}

		timeout := time.Duration(0)
		if len(campos) == 3 {
			d, err := time.ParseDuration(campos[2])
			if err != nil {
				return nil, fmt.Errorf("%s:%d: tiempo limite %q invalido (usa 500ms, 2s, 1m): %w",
					origen, numero, campos[2], err)
			}
			if d <= 0 {
				return nil, fmt.Errorf("%s:%d: el tiempo limite %q tiene que ser mayor que cero",
					origen, numero, campos[2])
			}
			timeout = d
		}

		vistos[nombre] = numero
		servicios = append(servicios, servicio.Servicio{Nombre: nombre, URL: url, Timeout: timeout})
	}

	if len(servicios) == 0 {
		return nil, fmt.Errorf("%s: no declara ningun servicio", origen)
	}
	return servicios, nil
}

func tieneEsquema(url string) bool {
	u := strings.ToLower(url)
	return strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://")
}

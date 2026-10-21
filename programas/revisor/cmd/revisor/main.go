// El binario revisor del curso de Docker: el mismo revisor del curso de Go,
// ahora como servicio HTTP.
//
// Uso:
//
//	revisor               levanta el servidor (se configura por variables de entorno)
//	revisor healthcheck   consulta su propio /salud y sale con 0 si está sano
//	revisor version       imprime la versión con la que se compiló
//
// Los paquetes de internal/ son los del curso de Go, sin cambios. Lo único
// nuevo es este paquete main: leer la configuración del entorno, atender HTTP
// y apagarse bien cuando llega una señal.
package main

import (
	"fmt"
	"io"
	"os"
)

// version se fija al compilar con -ldflags "-X main.version=1.3.0". Si nadie
// la fija, dice "desarrollo": así una imagen construida sin versión se delata
// sola en /salud.
var version = "desarrollo"

func main() {
	os.Exit(ejecutar(os.Args[1:], os.Stdout, os.Stderr))
}

// ejecutar está separado de main por la misma razón que en el curso de Go:
// main llama a os.Exit y no se puede probar; ejecutar devuelve el código.
func ejecutar(args []string, salida, errores io.Writer) int {
	if len(args) > 0 {
		switch args[0] {
		case "healthcheck":
			return healthcheck(os.Getenv, salida, errores)
		case "version":
			fmt.Fprintln(salida, version)
			return 0
		default:
			fmt.Fprintf(errores, "revisor: subcomando desconocido %q (usa: healthcheck, version)\n", args[0])
			return 2
		}
	}

	cfg, err := LeerConfig(os.Getenv, os.ReadFile)
	if err != nil {
		fmt.Fprintln(errores, "revisor:", err)
		return 1
	}
	for _, aviso := range cfg.Avisos {
		fmt.Fprintln(errores, "revisor: aviso:", aviso)
	}
	return servir(cfg, salida, errores)
}

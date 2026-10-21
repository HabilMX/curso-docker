// Package reporte convierte los estados que ya se midieron en algo que un
// humano —tabla— o un programa —JSON— pueda leer. No sabe nada de HTTP ni de
// concurrencia: solo recibe []servicio.Estado y los formatea.
package reporte

import (
	"fmt"
	"io"
	"sort"
	"time"

	"github.com/habil/revisor/internal/servicio"
)

// Tabla escribe un reporte legible por humanos en w, ordenado por nombre —el
// orden en el que llegan los estados NO es determinista (lo explica la
// lección de concurrencia), así que ordenar aquí es obligatorio, no cosmético.
func Tabla(w io.Writer, estados []servicio.Estado) {
	ordenados := ordenarPorNombre(estados)

	anchoNombre := len("SERVICIO")
	for _, e := range ordenados {
		if n := len(e.Servicio.Etiqueta()); n > anchoNombre {
			anchoNombre = n
		}
	}

	fmt.Fprintf(w, "%-*s  %-6s  %8s  %s\n", anchoNombre, "SERVICIO", "ESTADO", "TIEMPO", "DETALLE")
	for _, e := range ordenados {
		fmt.Fprintf(w, "%-*s  %-6s  %8s  %s\n",
			anchoNombre,
			e.Servicio.Etiqueta(),
			etiquetaEstado(e),
			formatoTiempo(e),
			detalle(e),
		)
	}
}

func ordenarPorNombre(estados []servicio.Estado) []servicio.Estado {
	copia := make([]servicio.Estado, len(estados))
	copy(copia, estados)
	sort.Slice(copia, func(i, j int) bool {
		return copia[i].Servicio.Nombre < copia[j].Servicio.Nombre
	})
	return copia
}

func etiquetaEstado(e servicio.Estado) string {
	switch {
	case e.OK() && e.Duracion > time.Second:
		return "LENTO"
	case e.OK():
		return "OK"
	default:
		return "FALLA"
	}
}

func formatoTiempo(e servicio.Estado) string {
	if e.Codigo == 0 && e.Err != nil && e.Duracion == 0 {
		return "—"
	}
	return e.Duracion.Round(time.Millisecond).String()
}

func detalle(e servicio.Estado) string {
	if e.OK() {
		return fmt.Sprintf("%d", e.Codigo)
	}
	return e.Motivo()
}

package reporte

import (
	"encoding/json"
	"io"
	"time"

	"github.com/habil/revisor/internal/servicio"
)

// lineaJSON es lo que de verdad se serializa. No es servicio.Estado
// directamente, a propósito: si mañana Estado gana un campo interno, el
// formato JSON que otros programas ya leen no cambia solo porque Estado
// cambió. Desacoplar el modelo interno del formato externo es la razón de
// que este tipo exista.
type lineaJSON struct {
	Servicio string `json:"servicio"`
	OK       bool   `json:"ok"`
	Codigo   int    `json:"codigo,omitempty"`
	TiempoMs int64  `json:"tiempo_ms"`
	Detalle  string `json:"detalle,omitempty"`
}

// JSON escribe el reporte como una lista de objetos, uno por servicio,
// ordenada igual que Tabla para que los dos formatos sean comparables línea a
// línea.
func JSON(w io.Writer, estados []servicio.Estado) error {
	ordenados := ordenarPorNombre(estados)

	lineas := make([]lineaJSON, len(ordenados))
	for i, e := range ordenados {
		lineas[i] = lineaJSON{
			Servicio: e.Servicio.Etiqueta(),
			OK:       e.OK(),
			Codigo:   e.Codigo,
			TiempoMs: e.Duracion.Round(time.Millisecond).Milliseconds(),
			Detalle:  e.Motivo(),
		}
	}

	codificador := json.NewEncoder(w)
	codificador.SetIndent("", "  ")
	return codificador.Encode(lineas)
}

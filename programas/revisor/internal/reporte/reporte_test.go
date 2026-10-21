package reporte

import (
	"bytes"
	"errors"
	"testing"
	"time"

	"github.com/habil/revisor/internal/servicio"
)

func datosDePrueba() []servicio.Estado {
	return []servicio.Estado{
		{Servicio: servicio.Servicio{Nombre: "pagos"}, Codigo: 200, Duracion: 87 * time.Millisecond},
		{Servicio: servicio.Servicio{Nombre: "catalogo"}, Codigo: 200, Duracion: 142 * time.Millisecond},
		{Servicio: servicio.Servicio{Nombre: "inventario"}, Codigo: 200, Duracion: 2300 * time.Millisecond},
		{Servicio: servicio.Servicio{Nombre: "reportes"}, Err: errors.New("connection refused"), Duracion: 0},
	}
}

func TestTabla_ordenaPorNombre(t *testing.T) {
	var buf bytes.Buffer
	Tabla(&buf, datosDePrueba())
	t.Log("\n" + buf.String())

	salida := buf.String()
	posCatalogo := indexOf(salida, "catalogo")
	posInventario := indexOf(salida, "inventario")
	posPagos := indexOf(salida, "pagos")
	posReportes := indexOf(salida, "reportes")

	if !(posCatalogo < posInventario && posInventario < posPagos && posPagos < posReportes) {
		t.Errorf("la tabla no quedó ordenada alfabéticamente:\n%s", salida)
	}
}

func TestJSON_esValido(t *testing.T) {
	var buf bytes.Buffer
	if err := JSON(&buf, datosDePrueba()); err != nil {
		t.Fatalf("JSON() devolvió error: %v", err)
	}
	t.Log("\n" + buf.String())
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

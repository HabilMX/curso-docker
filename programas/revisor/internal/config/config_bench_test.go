package config

import "testing"

func BenchmarkInterpretar(b *testing.B) {
	entrada := []byte(`
catalogo   https://catalogo.interno.mx
pagos      https://pagos.interno.mx      500ms
inventario https://inventario.interno.mx 1s
reportes   https://reportes.interno.mx
`)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := Interpretar(entrada, "bench.txt"); err != nil {
			b.Fatal(err)
		}
	}
}

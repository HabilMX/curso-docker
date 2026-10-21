// servicio-prueba es el servicio que falla a propósito del curso de Docker.
//
// Tiene tres modos, y se puede cambiar de uno a otro sin reiniciarlo:
//
//	sano   GET / responde 200 de inmediato
//	lento  GET / tarda PRUEBA_RETARDO (3s por omisión) y luego responde 200
//	caido  GET / responde 503 de inmediato
//
// Uso:
//
//	servicio-prueba               levanta el servidor
//	servicio-prueba healthcheck   consulta su propio GET / y sale con 0 solo si respondió 200 en menos de 2s
//
// Variables de entorno: PRUEBA_PUERTO (9000), PRUEBA_MODO (sano), PRUEBA_RETARDO (3s).
//
// Cambiar el modo en caliente:
//
//	curl -X POST http://127.0.0.1:9000/modo/caido
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"
)

var modos = map[string]bool{"sano": true, "lento": true, "caido": true}

func main() {
	puerto := entornoO("PRUEBA_PUERTO", "9000")

	if len(os.Args) > 1 {
		if os.Args[1] == "healthcheck" {
			os.Exit(healthcheck(puerto))
		}
		fmt.Fprintf(os.Stderr, "servicio-prueba: subcomando desconocido %q (usa: healthcheck)\n", os.Args[1])
		os.Exit(2)
	}

	inicial := entornoO("PRUEBA_MODO", "sano")
	if !modos[inicial] {
		fmt.Fprintf(os.Stderr, "servicio-prueba: PRUEBA_MODO=%q no existe (usa sano, lento o caido)\n", inicial)
		os.Exit(1)
	}
	retardo, err := time.ParseDuration(entornoO("PRUEBA_RETARDO", "3s"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "servicio-prueba: PRUEBA_RETARDO inválido:", err)
		os.Exit(1)
	}

	var modo atomic.Value
	modo.Store(inicial)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		actual := modo.Load().(string)
		switch actual {
		case "lento":
			select {
			case <-time.After(retardo):
			case <-r.Context().Done():
				return
			}
			fmt.Fprintln(w, "lento")
		case "caido":
			http.Error(w, "caido", http.StatusServiceUnavailable)
		default:
			fmt.Fprintln(w, "sano")
		}
		fmt.Printf("servicio-prueba: GET / en modo %s\n", actual)
	})
	mux.HandleFunc("GET /modo", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "modo: %s\n", modo.Load())
	})
	mux.HandleFunc("POST /modo/{nuevo}", func(w http.ResponseWriter, r *http.Request) {
		nuevo := r.PathValue("nuevo")
		if !modos[nuevo] {
			http.Error(w, "modo desconocido: usa sano, lento o caido", http.StatusBadRequest)
			return
		}
		modo.Store(nuevo)
		fmt.Printf("servicio-prueba: modo cambiado a %s\n", nuevo)
		fmt.Fprintf(w, "modo: %s\n", nuevo)
	})

	srv := &http.Server{Addr: ":" + puerto, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	senales := make(chan os.Signal, 1)
	signal.Notify(senales, syscall.SIGTERM, syscall.SIGINT)
	fallo := make(chan error, 1)
	go func() { fallo <- srv.ListenAndServe() }()
	fmt.Printf("servicio-prueba escuchando en :%s en modo %s\n", puerto, inicial)

	select {
	case err := <-fallo:
		fmt.Fprintln(os.Stderr, "servicio-prueba:", err)
		os.Exit(1)
	case s := <-senales:
		fmt.Printf("servicio-prueba: recibí %v, apagando\n", s)
	}
	ctx, cancelar := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelar()
	srv.Shutdown(ctx)
}

func healthcheck(puerto string) int {
	cliente := &http.Client{Timeout: 2 * time.Second}
	resp, err := cliente.Get("http://127.0.0.1:" + puerto + "/")
	if err != nil {
		fmt.Fprintln(os.Stderr, "no sano:", err)
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Fprintf(os.Stderr, "no sano: GET / respondió %d\n", resp.StatusCode)
		return 1
	}
	fmt.Println("sano")
	return 0
}

func entornoO(clave, porOmision string) string {
	if v := os.Getenv(clave); v != "" {
		return v
	}
	return porOmision
}

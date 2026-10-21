package main

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/habil/revisor/internal/config"
	"github.com/habil/revisor/internal/servicio"
)

// Las variables de entorno que entiende el revisor. Son las únicas: una
// variable con otro nombre se ignora en silencio, como cualquier variable que
// un programa no lee.
const (
	VarPuerto        = "REVISOR_PUERTO"        // puerto donde escucha; por omisión 8080
	VarServicios     = "REVISOR_SERVICIOS"     // obligatoria: «nombre url [tiempo]», separados por comas
	VarReporte       = "REVISOR_REPORTE"       // opcional: archivo donde guarda el último reporte en JSON
	VarTokenArchivo  = "REVISOR_TOKEN_ARCHIVO" // opcional: archivo que contiene el token de acceso
	VarToken         = "REVISOR_TOKEN"         // opcional y desaconsejada: el token en el entorno
	PuertoPorOmision = "8080"
)

// Config es todo lo que el servidor necesita saber para arrancar.
type Config struct {
	Puerto      string
	Servicios   []servicio.Servicio
	RutaReporte string
	Token       string   // vacío = /api/estados no pide token
	Avisos      []string // cosas que no impiden arrancar pero conviene decir
}

// LeerConfig arma la configuración a partir del entorno. Recibe las funciones
// para leer variables y archivos en vez de llamar a os directamente, para que
// las pruebas no tengan que tocar el entorno real ni el disco.
func LeerConfig(getenv func(string) string, leerArchivo func(string) ([]byte, error)) (Config, error) {
	cfg := Config{Puerto: getenv(VarPuerto), RutaReporte: getenv(VarReporte)}

	if cfg.Puerto == "" {
		cfg.Puerto = PuertoPorOmision
	}
	if n, err := strconv.Atoi(cfg.Puerto); err != nil || n < 1 || n > 65535 {
		return Config{}, fmt.Errorf("%s=%q no es un puerto válido (1 a 65535)", VarPuerto, cfg.Puerto)
	}

	crudo := getenv(VarServicios)
	if strings.TrimSpace(crudo) == "" {
		return Config{}, fmt.Errorf("falta %s (ejemplo: %s=\"prueba http://curso-docker-prueba:9000/ 2s\")",
			VarServicios, VarServicios)
	}
	// Cada entrada separada por coma se vuelve una línea del formato del curso
	// de Go, y la interpreta el mismo paquete config, sin cambios.
	servicios, err := config.Interpretar([]byte(strings.ReplaceAll(crudo, ",", "\n")), VarServicios)
	if err != nil {
		return Config{}, err
	}
	cfg.Servicios = servicios

	if ruta := getenv(VarTokenArchivo); ruta != "" {
		datos, err := leerArchivo(ruta)
		if err != nil {
			return Config{}, fmt.Errorf("leyendo el token de %s: %w", VarTokenArchivo, err)
		}
		cfg.Token = strings.TrimSpace(string(datos))
		if cfg.Token == "" {
			return Config{}, fmt.Errorf("el archivo de %s (%s) está vacío", VarTokenArchivo, ruta)
		}
	} else if t := getenv(VarToken); t != "" {
		cfg.Token = t
		cfg.Avisos = append(cfg.Avisos, fmt.Sprintf(
			"el token llegó por %s: cualquiera con docker inspect lo puede leer; usa %s",
			VarToken, VarTokenArchivo))
	}

	return cfg, nil
}

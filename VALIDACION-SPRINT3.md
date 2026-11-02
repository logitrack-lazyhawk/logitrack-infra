# Validación de la revisión del Sprint 3

Fecha: 2 de noviembre de 2026.

## Comprobaciones sobre los archivos finales

- `mvn validate` pasó para security-service, shipment-service, courier-service,
  config-server y el Eureka incluido en este repositorio. Este objetivo valida
  el modelo Maven; no compila ni resuelve todas las dependencias de ejecución.
- Los YAML se analizaron con rechazo de claves duplicadas, también en bloques
  anidados. Los seis archivos de servicios tienen un solo management.
- `docker compose config --quiet` pasó.
- Se comprobaron la sintaxis de los scripts y `git diff --check`.

## Pruebas offline de código

Las pruebas se ejecutaron sobre copias temporales de los fuentes finales en
/tmp/logitrack-offline-check, usando la caché Maven existente. Los repositorios
conservan los POM finales con Boot 4.1.2, Cloud 2025.1.4, starter Zipkin y
feign-micrometer. Para poder ejecutar las copias sin red se omitieron allí
starter-zipkin, feign-micrometer y devtools, que no estaban en caché.
La copia de security usó Boot 4.2.0-SNAPSHOT de la caché con el verificador de
compatibilidad desactivado; la versión final 4.1.2 requiere validación con conexión.

| Comprobación | Resultado |
| --- | --- |
| Suite shipment | 60 pruebas aprobadas antes de añadir las últimas tres comprobaciones |
| Feign real + propagación de contexto | 7 pruebas aprobadas: 6 de Feign y 1 del executor |
| Suite security con versión en caché | 12 pruebas aprobadas, incluida salud pública sin token |
| Courier: contexto y repartidor inactivo | 2 pruebas aprobadas |
| Courier: diferenciación HTTP 404/400 | 1 prueba adicional aprobada después de corregir su stub |
| Config Server en backend native | 1 prueba aprobada |
| Eureka sin starter Zipkin en la copia | Fuente Java compilado; empaquetado bloqueado por plugins ausentes en caché |

Las pruebas de Feign usan su proxy real con Resilience4j, ErrorDecoder y
FallbackFactory, pero reemplazan el transporte HTTP por uno simulado. Comprueban
respuesta exitosa, 404, 400, 500, IOException, circuito abierto y exclusión de
errores de negocio de las métricas de fallo. El executor preserva y limpia el
contexto entre llamadas.

## Pendiente de ejecución con conexión

No se pudo descargar Maven Central por la restricción de red del entorno, ni
acceder al daemon Docker por permisos. Por eso no se afirma que los artefactos
finales completos, la exportación Zipkin o el descubrimiento Eureka hayan sido
probados en ejecución real.

Los comandos de SPRINT3.md ejecutan esa validación: compilación y pruebas con
dependencias finales, arranque de Compose y demostración de Feign, errores,
caída/recuperación y una traza compartida real entre shipment y courier.

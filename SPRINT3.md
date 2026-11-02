# Tu parte del Sprint 3: OpenFeign, resiliencia y Zipkin

## Arranque

Requiere Java 25, conexión para descargar dependencias/imágenes, Docker Compose
y los repositorios config-server, configserver-ms, security-service, courier-service,
shipment-service y logitrack-infra como carpetas hermanas.

Desde logitrack-infra:

```bash
bash scripts/verify-sprint3.sh
docker compose up -d --build --wait --wait-timeout 300
python3 scripts/smoke-sprint3.py --outage
```

El último comando crea datos de prueba, comprueba la asignación y los errores
404/400, encuentra una traza compartida en Zipkin y detiene temporalmente courier
para comprobar el 503 y la recuperación. Restaura courier al terminar esa prueba.
Sin `--outage`, no detiene ningún contenedor. Usar sobre el entorno local de clase.

- Eureka: http://localhost:8065
- Zipkin: http://localhost:9411
- Config Server: http://localhost:8085/shipment-service/dev
- Health de security: http://localhost:8083/actuator/health (público, sin detalles).

Compose usa el backend **native** de Config Server y monta ../configserver-ms
en modo solo lectura. De esta forma puede probarse el código antes de hacer push.
Al ejecutar Config Server fuera de Compose, sigue usando Git y su rama main.
Si los datos de MySQL ya existían, el script de inicialización no vuelve a correr;
se conservan los volúmenes al detener el entorno con `docker compose down`.

## Comportamiento

shipment consulta a courier por nombre Eureka antes de guardar la asignación.
Los errores 404 preservan recurso inexistente, los 400 indican repartidor inactivo,
y una caída, un 500 o un circuito abierto devuelven un JSON 503 sin asignar el envío.
Los errores de negocio no abren el circuito. Los tiempos y umbrales están en
configserver-ms/shipment-service-{dev,prod}.yml.

Micrometer Tracing/Brave reemplaza a Sleuth en esta versión de Spring Boot.
Feign tiene instrumentación Micrometer y se propaga el contexto al executor de
Resilience4j para mantener el traceId entre servicios incluso con TimeLimiter.
Boot 4 usa `management.tracing.export.zipkin.endpoint`.

El Eureka mínimo incluido en eureka-server permite ejecutar esta parte de manera
independiente. Si el equipo utiliza otro repositorio Eureka, se puede cambiar
el build del servicio eureka-server en Compose por ese proyecto.
El Gateway y sus reglas JWT corresponden a otra parte del equipo; este entorno
permite comprobar directamente las APIs de dominio y no implementa el Gateway.

## Publicación

Cada carpeta es un repositorio distinto. Los commits locales y comandos de push
se detallan en PUSH-SPRINT3.md. No hace falta volver a crear los commits.

## Límite de la validación realizada

El entorno de revisión no permite acceder al daemon de Docker ni resolver Maven
Central. La validación completa de los POM finales y las trazas reales requiere
ejecutar los tres comandos de arranque con conexión. Los resultados de pruebas
offline se documentan en VALIDACION-SPRINT3.md; no equivalen a una ejecución completa
con Zipkin y Docker.

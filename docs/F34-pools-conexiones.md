# F34 — Medición de pools JDBC, HTTP y RabbitMQ

## 1. Objetivo

Verificar el comportamiento de las conexiones JDBC, HTTP y RabbitMQ de LogiTrack, documentando límites, tiempos de respuesta y configuración de timeouts.

**Fecha:** 10 de noviembre de 2026.

## 2. Entorno de pruebas

- Sistema: Linux y Docker Compose.
- Microservicio analizado: `courier-service`.
- Base de datos: MySQL 8.4.
- Mensajería: RabbitMQ 4.4.
- Configuración centralizada: Spring Cloud Config Server.
- Monitorización: Spring Boot Actuator y RabbitMQ CLI.

## 3. Mediciones JDBC — HikariCP

| Métrica | Resultado |
|---|---|
| Conexiones activas | 0 |
| Conexiones inactivas | 2 |
| Conexiones totales | 2 |
| Tamaño máximo | 5 |
| Tamaño mínimo | 2 |
| Conexiones pendientes | 0 |

Configuración del entorno de desarrollo:

- `maximum-pool-size`: 5
- `minimum-idle`: 2
- `connection-timeout`: 20.000 ms
- `idle-timeout`: 30.000 ms

**Interpretación:** el pool mantiene dos conexiones disponibles y no presenta solicitudes pendientes durante la medición. No se ha realizado todavía una prueba de saturación del pool.

## 4. Mediciones HTTP

Se realizaron diez peticiones al endpoint `/actuator/health` de Courier.

- Peticiones exitosas: 10/10.
- Código de respuesta: HTTP 200.
- Tiempo promedio: 7,68 ms.
- Tiempo mínimo: 5,38 ms.
- Tiempo máximo: 9,53 ms.

En `shipment-service`, el cliente OpenFeign tiene configurados los siguientes límites:

- `connectTimeout`: 2.000 ms.
- `readTimeout`: 3.000 ms.

**Interpretación:** las respuestas observadas fueron correctas y rápidas. La prueba mide latencia HTTP normal; no comprueba todavía una expiración real del timeout de Feign.

## 5. Mediciones RabbitMQ

- Conexiones activas: 1.
- Canales abiertos: 2.
- Consumidores de la cola Courier: 1.
- Mensajes pendientes: 0.
- Mensajes sin confirmar: 0.
- Dead Letter Exchange: `logitrack.assignment.dlx`.

La configuración de Courier establece tres intentos de procesamiento para errores recuperables.

**Interpretación:** el consumidor mantiene una conexión operativa con RabbitMQ y la cola dispone de una configuración DLQ válida. Los reintentos no representan un timeout de conexión AMQP.

## 6. Conclusiones preliminares

Las mediciones muestran estabilidad durante el funcionamiento normal de Courier, sin conexiones JDBC pendientes y con respuestas HTTP satisfactorias.

Los límites configurados están documentados, pero quedan pendientes pruebas controladas de expiración de timeouts y, si corresponde, saturación de conexiones antes de considerar completamente validada F34.

## 7. Evidencia

Archivo: `docs/F34-evidencia.txt`.

Script reproducible: `scripts/f34-medir-pools.sh`.

Issue: `logitrack-lazyhawk/logitrack-infra#32`.

## 8. Prueba controlada de timeout HTTP

Se utilizó un servidor HTTP local de prueba que demora
2 segundos en responder y un cliente Python con timeout
configurado en 1 segundo.

Resultado observado:
- Tiempo hasta el timeout: 1,029 segundos.
- Resultado: PASS.

La prueba confirma que el cliente HTTP respeta su timeout
en un entorno controlado. No valida directamente el
readTimeout de OpenFeign ni los timeouts de JDBC o RabbitMQ.

La salida se conserva en docs/F34-evidencia.txt.

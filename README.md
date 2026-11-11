# 📦 LogiTrack Infraestructura & Orquestación (Sprint 4)

[![Docker](https://img.shields.io/badge/Docker-29.8-blue?logo=docker)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker_Compose-v2-blue?logo=docker)](https://docs.docker.com/compose/)
[![Java](https://img.shields.io/badge/Java-25-orange?logo=openjdk)](https://adoptium.net/)
[![Spring Boot](https://img.shields.io/badge/Spring_Boot-4.x-green?logo=springboot)](https://spring.io/projects/spring-boot)
[![Spring Cloud](https://img.shields.io/badge/Spring_Cloud-2025.1.4-green?logo=spring)](https://spring.io/projects/spring-cloud)
[![Keycloak](https://img.shields.io/badge/Keycloak-24.0.1-red?logo=keycloak)](https://www.keycloak.org/)
[![Grafana](https://img.shields.io/badge/Grafana-11.x-orange?logo=grafana)](https://grafana.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-2.x-red?logo=prometheus)](https://prometheus.io/)
[![MySQL](https://img.shields.io/badge/MySQL-8.4-blue?logo=mysql)](https://www.mysql.com/)
[![RabbitMQ](https://img.shields.io/badge/RabbitMQ-3.13-orange?logo=rabbitmq)](https://www.rabbitmq.com/)

Repositorio oficial de infraestructura y orquestación del proyecto **LogiTrack (LazyHawk)** para la cátedra de **DAAS (2026)** - Universidad Nacional de Jujuy (UNJu).

Este repositorio centraliza la orquestación con `docker-compose.yml` para desplegar el ecosistema distribuido completo del Sprint 4: **API Gateway**, **Eureka Server**, **Config Server**, **Keycloak (IAM & OIDC)**, **RabbitMQ (Mensajería Asíncrona)**, **Stack de Observabilidad Unificada (Grafana, Prometheus, Loki, Promtail, Zipkin)**, **Bases de Datos MySQL independientes**, **Frontend React** y **Microservicios de Dominio** comunicados mediante OpenFeign, mensajería asíncrona y resiliencia.

---

## 🏛️ Arquitectura del Ecosistema (Sprint 4)

### 1. Topología de Red y Contenedores Docker (16 Servicios)

<p align="center">
  <img src="docs/img/diagrama-3-topologia-red-docker.svg" alt="Diagrama de Topología de Red LogiTrack Sprint 4" width="950px" />
</p>

### 2. Seguridad Perimetral, Keycloak & Control de Acceso RBAC

<p align="center">
  <img src="docs/img/diagrama-1-seguridad-keycloak-rbac.svg" alt="Diagrama de Seguridad y RBAC con Keycloak" width="950px" />
</p>

Toda petición externa ingresa obligatoriamente por el **API Gateway** (puerto `8066`), el cual valida los tokens JWT emitidos por **Keycloak** (puerto `8082`), aplica control de acceso basado en roles (RBAC: `CLIENTE`, `VENDEDOR`, `REPARTIDOR`, `ADMIN`), gestiona políticas de CORS y enruta dinámicamente (`lb://`) apoyándose en **Eureka Server**.

### 3. Observabilidad Unificada (Métricas, Logs y Trazabilidad)

<p align="center">
  <img src="docs/img/diagrama-2-observabilidad-grafana-loki-prometheus.svg" alt="Diagrama de Observabilidad Grafana Loki Prometheus Zipkin" width="950px" />
</p>

Integración de los 3 pilares de la observabilidad mediante **Grafana**, **Prometheus**, **Loki**, **Promtail** y **Zipkin**, con correlación automática de *Log-to-Trace* vía `traceId`.

---

## 🗄️ Estado de las Bases de Datos

* **Las imágenes de MySQL no traen registros pre-cargados:** La imagen base oficial `mysql:8.4.0` se inicializa únicamente ejecutando el script [`init-dbs.sql`](init-dbs.sql), el cual crea los esquemas necesarios:
  * `shipment_db`
  * `courier_db`
  * `security_db`
  * `commerce_db`
* **Persistencia:** Los datos residen en el volumen Docker persistente `mysql_data`.
* **Para reiniciar las bases de datos totalmente limpias y sin registros:**
  ```bash
  docker compose down -v
  docker compose up -d
  ```

---

## 📋 Puertos y Endpoints del Ecosistema (16 Servicios)

| Componente | Contenedor | Puerto Host | Descripción | Endpoint de Verificación |
| :--- | :--- | :---: | :--- | :--- |
| **Frontend Web** | `logitrack-frontend` | `5173` | Aplicación SPA React + Vite con RBAC | [http://localhost:5173](http://localhost:5173) |
| **API Gateway** | `logitrack-api-gateway` | `8066` | Puerta de enlace perimetral, filtro JWT y RBAC | [http://localhost:8066/actuator/gateway/routes](http://localhost:8066/actuator/gateway/routes) |
| **Keycloak (IAM)** | `logitrack-keycloak` | `8082` | Servidor de Identidad OIDC y roles (`lazyhawk`) | [http://localhost:8082](http://localhost:8082) (admin / admin) |
| **Eureka Server** | `logitrack-eureka-server` | `8065` | Registro y descubrimiento dinámico de servicios | [http://localhost:8065](http://localhost:8065) |
| **Config Server** | `logitrack-configserver` | `8085` | Servidor de configuración centralizada | [http://localhost:8085/api-gateway/dev](http://localhost:8085/api-gateway/dev) |
| **Commerce Service** | `logitrack-commerce-service` | `8084` | Catálogo de productos y órdenes de compra | [http://localhost:8084/actuator/health](http://localhost:8084/actuator/health) |
| **Shipment Service** | `logitrack-shipment-service` | `8080` | Gestión de envíos y tarifas | [http://localhost:8080/actuator/health](http://localhost:8080/actuator/health) |
| **Courier Service** | `logitrack-courier-service` | `8081` | Gestión y asignación de repartidores | [http://localhost:8081/actuator/health](http://localhost:8081/actuator/health) |
| **Security Service** | `logitrack-security-service` | `8083` | Servicio complementario de autenticación local | [http://localhost:8083/actuator/health](http://localhost:8083/actuator/health) |
| **RabbitMQ Management** | `logitrack-rabbitmq` | `15673` | Broker AMQP (`:5672`) y consola de administración | [http://localhost:15673](http://localhost:15673) (`guest` / `guest`) |
| **Grafana** | `logitrack-grafana` | `3000` | Consola unificada de observabilidad y dashboards | [http://localhost:3000](http://localhost:3000) (`admin` / `admin`) |
| **Prometheus** | `logitrack-prometheus` | `9090` | Recolección periódica (scraping) de métricas TSDB | [http://localhost:9090](http://localhost:9090) |
| **Grafana Loki** | `logitrack-loki` | `3100` | Almacenamiento e indexación centralizada de logs | [http://localhost:3100/ready](http://localhost:3100/ready) |
| **Promtail** | `logitrack-promtail` | *-* | Agente de streaming de logs Docker hacia Loki | Integrado en red interna |
| **Zipkin UI** | `logitrack-zipkin` | `9411` | Servidor de trazas y latencias distribuidas | [http://localhost:9411](http://localhost:9411) |
| **MySQL Unificado** | `logitrack-mysql` | `3309` | Motor de base de datos relacional (puerto host `3309`) | `mysql -h 127.0.0.1 -P 3309 -u root -proot` |

---

## 📊 Épica 10 — Observabilidad y Monitoreo Unificado

El ecosistema integra los tres pilares fundamentales de la observabilidad mediante aprovisionamiento automático (*Infrastructure as Code*):
1. **Métricas (Prometheus + Micrometer):** Recolecta métricas de JVM (Heap, hilos, GC), conexiones JDBC (HikariCP) y latencias HTTP con endpoint `/actuator/prometheus`.
2. **Logs Centralizados (Loki + Promtail):** Promtail captura los logs de los contenedores Docker en tiempo real y los envía a Loki para indexación y consultas con LogQL.
3. **Trazabilidad Distribuida (Zipkin):** Rastreo de llamadas inter-servicio (Gateway, Feign, Circuit Breakers) con propagación de `traceId` y `spanId`.
4. **Correlación Log-to-Trace:** Configurada en Grafana Loki para que cada línea de log con `traceId` genere un enlace directo hacia la visualización de la traza en Zipkin con un solo clic.
5. **Dashboards Pre-Aprovisionados:**
   - **`LogiTrack — Salud y Rendimiento de Microservicios`:** Estado UP/DOWN, RPS, tasas de error 4xx/5xx, memoria Heap y conexiones HikariCP.
   - **`LogiTrack — Logs Centralizados y Correlación de Trazas`:** Explorador de logs con filtros dinámicos por contenedor/servicio y búsqueda de texto.

---

## 🚀 Modos de Despliegue

El archivo `docker-compose.yml` está configurado con **soporte dual**: permite tanto **descargar imágenes precompiladas de Docker Hub** (ideal para desplegar rápido sin clonar los demás repositorios) como **compilar desde el código fuente local** (ideal para desarrollo activo).

Debes ejecutar los comandos parado en la carpeta `logitrack-infra`:

```bash
cd logitrack-infra
```

---

### Opción A: Despliegue Rápido desde Docker Hub (Sin clonar otros repos)

Si solo clonaste este repositorio y querés levantar todo el ecosistema usando las imágenes oficiales publicadas en Docker Hub (`luism46/...`):

```bash
# 1. Descargar las últimas versiones de las imágenes de Docker Hub
docker compose pull

# 2. Levantar los contenedores ignorando la compilación local
docker compose up -d --no-build
```

> [!TIP]
> Al usar `--no-build`, Docker Compose no buscará los directorios de código fuente en tu máquina ni requerirá Java o Maven instalado.

---

### Opción B: Compilación Local desde Código Fuente (Modo Desarrollo)

Si clonaste todos los microservicios en la misma carpeta raíz (como repositorios hermanos: `api-gateway`, `eureka-server`, `security-service`, `courier-service`, `shipment-service`, `commerce-service`, `config-server`, `logitrack-frontend`) y realizaste modificaciones en el código:

```bash
# Compilar las imágenes localmente y levantar el ecosistema completo
docker compose up -d --build
```

---

### Verificación del Despliegue:

```bash
# Verificar que los 16 contenedores estén Up y healthy
docker compose ps
```
Deberías ver los 16 contenedores en estado `Up` y `healthy`:
* `logitrack-mysql`
* `logitrack-zipkin`
* `logitrack-configserver`
* `logitrack-eureka-server`
* `logitrack-security-service`
* `logitrack-courier-service`
* `logitrack-shipment-service`
* `logitrack-commerce-service`
* `logitrack-keycloak`
* `logitrack-rabbitmq`
* `logitrack-prometheus`
* `logitrack-loki`
* `logitrack-promtail`
* `logitrack-grafana`
* `logitrack-api-gateway`
* `logitrack-frontend`

---

## 🛠️ Comandos de Operación Frecuentes

```bash
# Ver estado de los contenedores
docker compose ps

# Ver logs en tiempo real (ejemplo del Gateway)
docker compose logs -f api-gateway

# Ver logs de todo el stack
docker compose logs -f

# Detener los contenedores conservando los datos
docker compose stop

# Reanudar los contenedores
docker compose start

# Apagar y eliminar los contenedores y redes
docker compose down

# Apagar y BORRAR las bases de datos para reiniciar de cero (Volúmenes limpios)
docker compose down -v
```

---

## 🧪 Tests Automatizados de Infraestructura

### Test de consumo de RabbitMQ

Desde `logitrack-infra`, ejecutar:

```bash
bash scripts/test-rabbitmq-consumo.sh
```

El script levanta RabbitMQ, prepara el virtual host `courier-consumo-it`, carga las credenciales de `.env` y ejecuta `RabbitMqConsumoIT` en el repositorio hermano `courier-service` con memoria limitada. El test debe configurar `spring.rabbitmq.virtual-host=courier-consumo-it` en `@SpringBootTest`. El virtual host se conserva para futuras ejecuciones.

Esto evita el error `406 PRECONDITION_FAILED` cuando la cola de desarrollo `courier.assignment.requests.q` fue creada sin `x-dead-letter-exchange`. También evita que otros servicios consuman los mensajes del test.

Después de preparar el virtual host, también se puede ejecutar Maven directamente desde `courier-service`, exportando `RABBITMQ_USER` y `RABBITMQ_PASSWORD` con los valores de `.env` de infraestructura.

### Validación de Seguridad y Control de Acceso RBAC

Para comprobar de forma automatizada que los roles (`CLIENTE`, `VENDEDOR`, `REPARTIDOR`, `ADMIN`) cumplen con las restricciones de seguridad y aislamiento perimetral definidas en el `api-gateway` con tokens de Keycloak:

**En PowerShell (Windows):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-rbac.ps1
```

**En Bash (Linux / Git Bash):**
```bash
bash scripts/test-rbac.sh
```

El script evalúa:
1. Peticiones anónimas sin token (401 Unauthorized).
2. Intentos de `CLIENTE` de crear/editar productos o repartidores (403 Forbidden) vs consultar su catálogo y sus envíos (200 OK).
3. Permisos de `VENDEDOR` sobre productos vs bloqueo en repartidores y clientes (403 Forbidden).
4. Permisos de `REPARTIDOR` sobre rutas de reparto vs bloqueo en productos y clientes (403 Forbidden).
5. Acceso irrestricto de `ADMIN` a todos los recursos.

---

## 👥 Repositorios de la Organización

* [logitrack-infra](https://github.com/logitrack-lazyhawk/logitrack-infra) (Orquestación con Docker Compose)
* [api-gateway](https://github.com/logitrack-lazyhawk/api-gateway) (Puerta de enlace perimetral, filtros JWT y CORS)
* [eureka-server](https://github.com/logitrack-lazyhawk/eureka-server) (Servidor de descubrimiento dinámico)
* [configserver-ms](https://github.com/logitrack-lazyhawk/configserver-ms) (Repositorio Git de propiedades centralizadas)
* [config-server](https://github.com/logitrack-lazyhawk/config-server) (Microservicio Spring Cloud Config Server)
* [shipment-service](https://github.com/logitrack-lazyhawk/shipment-service) (Microservicio de Envíos con Feign y Resiliencia)
* [courier-service](https://github.com/logitrack-lazyhawk/courier-service) (Microservicio de Repartidores)
* [commerce-service](https://github.com/logitrack-lazyhawk/commerce-service) (Microservicio de Comercio y Productos)
* [security-service](https://github.com/logitrack-lazyhawk/security-service) (Microservicio de Autenticación y JWT)
* [logitrack-frontend](https://github.com/logitrack-lazyhawk/logitrack-frontend) (Frontend Web SPA React + Vite)

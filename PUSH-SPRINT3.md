# Commits locales y push del Sprint 3

Los commits ya están creados. No ejecutar `git add .` ni volver a crear estos commits.
Todavía no se hizo push desde el entorno de revisión.

| Repositorio | Rama local | Commit preparado |
| --- | --- | --- |
| configserver-ms | main | `069e4b0` — fix(config): centralizar Feign resiliente y corregir exportacion Zipkin |
| config-server | main | `c0c4326` — feat(config): agregar trazabilidad Zipkin y pruebas sin red |
| security-service | refactor/limpiar-configuracion-local | `4c9fae9` — fix(security): integrar Eureka y Zipkin con Spring Boot 4 |
| courier-service | refactor/limpiar-configuracion-local | `d9faa15` — fix(courier): registrar Eureka y distinguir errores de disponibilidad |
| shipment-service | refactor/limpiar-configuracion-local | `a5938a0` — fix(shipment): completar resiliencia Feign y propagacion de trazas |
| logitrack-infra | feature/3-feattracing-incorporar-dependencias-de-trazabilidad-en-todos-los-microservicios | feat(infra): completar entorno de demostracion Feign y Zipkin |

## Validación con conexión

Desde logitrack-infra ejecutar los comandos de SPRINT3.md. La revisión dejó
documentados los límites de validación en VALIDACION-SPRINT3.md: aún falta ejecutar
los artefactos finales completos con Docker y las dependencias finales descargadas.

## Push

Desde `/home/t1/IdeaProjects`, después de la validación:

```bash
git -C configserver-ms push -u origin main
git -C config-server push -u origin main
git -C security-service push -u origin refactor/limpiar-configuracion-local
git -C courier-service push -u origin refactor/limpiar-configuracion-local
git -C shipment-service push -u origin refactor/limpiar-configuracion-local
git -C logitrack-infra push -u origin feature/3-feattracing-incorporar-dependencias-de-trazabilidad-en-todos-los-microservicios
```

Security, courier, shipment e infraestructura se publican en sus ramas de trabajo.
Después del push, integrar esas ramas mediante el flujo de pull requests del equipo
para que sus cambios lleguen a las ramas de entrega. Los repositorios config-server
y configserver-ms ya estaban sobre main, y sus commits locales quedaron allí.

No se modificó api-gateway. El Eureka de apoyo está incluido en logitrack-infra;
no necesita un séptimo repositorio ni otro push.

Los archivos locales de configuración del asistente, skills y el .env.example
preexistente de courier quedaron fuera de los commits. Pueden seguir apareciendo
como no rastreados en `git status`.

# Despliegue en Kubernetes (Kind/Minikube)

Este directorio contiene los manifiestos básicos para desplegar los componentes principales de LogiTrack en un clúster local.

## Requisitos
- Tener instalado `kubectl`.
- Tener un clúster local (minikube o kind) corriendo.

## Pasos para el despliegue

1. Iniciar el clúster local (ejemplo con minikube):
   ```bash
   minikube start
2. Aplicar los manifiestos:
    ```bash
   kubectl apply -f k8s/eureka-server.yaml
   kubectl apply -f k8s/api-gateway.yaml
3. Verificar que los pods estén corriendo:
   ```bash
   kubectl get pods
   kubectl get services
4. (Opcional) Para acceder al API Gateway desde tu navegador con minikube:
   ```bash
   minikube service api-gateway

---

### 🚀 Paso 5: Probar los manifiestos (Opcional pero recomendado)

Si tienes `minikube` o `kind` instalado, puedes probar que los manifiestos sean válidos:

```bash
# Validar sintaxis sin desplegar
kubectl apply --dry-run=client -f k8s/eureka-server.yaml
kubectl apply --dry-run=client -f k8s/api-gateway.yaml


## F42 - Prueba mínima en Kubernetes

### Objetivo

Validar el despliegue opcional de LogiTrack en Kubernetes
sin ejecutar el clúster en la computadora del desarrollador.

### Implementación

- Clúster temporal con Kind en GitHub Actions.
- Deployments y Services de Kubernetes.
- API Gateway, Eureka, Config Server.
- Shipment Service y Courier Service.
- MySQL y RabbitMQ temporales.
- Límites de memoria para los contenedores.

### Ejecución

GitHub > Actions > F42 - Kubernetes Smoke Test
> Run workflow.

También se ejecuta al crear un Pull Request
que modifique la carpeta k8s.

### Criterios de aceptación

- Los Deployments están disponibles.
- API Gateway responde HTTP 200 en /actuator/health.
- Courier Service responde HTTP 200.
- Shipment Service responde HTTP 200.
- Las respuestas de salud contienen status UP.

### Evidencia

GitHub Actions genera el artefacto:

F42-evidencia-kubernetes

Incluye:
- Estado de recursos de Kubernetes.
- Respuestas HTTP.
- Diagnóstico de Pods.
- Logs de los microservicios.

### Alcance

Smoke test de infraestructura. No incluye frontend,
Keycloak, operaciones de negocio ni pruebas de carga.

Las bases de datos son temporales.

### Resultado

La prueba se considera aprobada únicamente cuando
el workflow finaliza exitosamente.

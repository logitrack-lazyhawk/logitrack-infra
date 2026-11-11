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
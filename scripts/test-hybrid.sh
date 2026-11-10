
#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# -eq 1 ]] || {
  echo "Uso: $0 {shipment-service|courier-service}"
  exit 1
}

case "$1" in
  shipment-service)
    SERVICE=shipment-service
    PORT=8080
    APP=SHIPMENT-SERVICE
    ;;
  courier-service)
    SERVICE=courier-service
    PORT=8081
    APP=COURIER-SERVICE
    ;;
  *)
    echo "Servicio no soportado" >&2
    exit 1
    ;;
esac

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

compose() {
  (
    cd "$INFRA_DIR"
    docker compose \
      -f docker-compose.yml \
      -f docker-compose.hybrid.yml \
      "$@"
  )
}

if [[ -n "$(compose ps --status running -q "$SERVICE")" ]]; then
  echo "ERROR: $SERVICE sigue ejecutándose en Docker" >&2
  exit 1
fi

echo '[OK] El microservicio elegido no está ejecutándose en Docker'

response="$(curl -fsS --max-time 10 "http://localhost:$PORT/actuator/health")"

echo "$response" | grep -q '"status":"UP"' || {
  echo "ERROR: el servicio local no responde UP: $response" >&2
  exit 1
}

echo '[OK] Actuator de la instancia local responde UP'

registry="$(curl -fsS \
  -H 'Accept: application/json' \
  --max-time 10 \
  "http://localhost:8065/eureka/apps/$APP")"

echo "$registry" | grep -q 'host.docker.internal' || {
  echo 'ERROR: Eureka no anuncia host.docker.internal' >&2
  exit 1
}

echo '[OK] Eureka registra el microservicio local'

docker run --rm \
  --network logitrack-network \
  --add-host=host.docker.internal:host-gateway \
  curlimages/curl:8.12.1 \
  --fail --silent --show-error --max-time 10 \
  "http://host.docker.internal:$PORT/actuator/health" >/dev/null

echo '[OK] Un contenedor Docker alcanza la instancia local'

echo 'F33 validada en infraestructura. Falta documentar una operación autenticada mediante el Gateway.'

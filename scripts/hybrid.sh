
#!/usr/bin/env bash
set -Eeuo pipefail

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILES=(-f "$INFRA_DIR/docker-compose.yml" -f "$INFRA_DIR/docker-compose.hybrid.yml")

usage() {
  echo "Uso: $0 {up|run|restore|status} {shipment-service|courier-service}"
  echo "  up:      prepara el stack y detiene el contenedor del servicio elegido"
  echo "  run:     hace up y ejecuta ese microservicio con Maven en tu PC"
  echo "  restore: vuelve a ejecutar ese servicio dentro de Docker (detené antes el proceso local)"
  echo "  status:  muestra el estado de los contenedores"
}

[[ $# -eq 2 ]] || { usage; exit 1; }

ACTION="$1"
SERVICE="$2"

case "$ACTION" in
  up|run|restore|status) ;;
  *) usage; exit 1 ;;
esac

case "$SERVICE" in
  shipment-service)
    PORT=8080
    PEER=courier-service
    ;;
  courier-service)
    PORT=8081
    PEER=shipment-service
    ;;
  *)
    usage
    exit 1
    ;;
esac

command -v docker >/dev/null || {
  echo "Falta Docker" >&2
  exit 1
}

docker compose version >/dev/null || {
  echo "Falta Docker Compose V2" >&2
  exit 1
}

if [[ ! -f "$INFRA_DIR/.env" ]]; then
  echo "Falta $INFRA_DIR/.env; crealo desde .env.example y completá los valores locales" >&2
  exit 1
fi

set -a
# Archivo local ignorado por Git. No cargar contenido de terceros.
source "$INFRA_DIR/.env"
set +a

: "${MYSQL_ROOT_PASSWORD:?Falta MYSQL_ROOT_PASSWORD en .env}"
: "${MYSQL_PORT:?Falta MYSQL_PORT en .env}"
: "${RABBITMQ_USER:?Falta RABBITMQ_USER en .env}"
: "${RABBITMQ_PASSWORD:?Falta RABBITMQ_PASSWORD en .env}"

dc() {
  (
    cd "$INFRA_DIR"
    docker compose "${COMPOSE_FILES[@]}" "$@"
  )
}

wait_url() {
  local name="$1" url="$2" i
  printf 'Esperando %s' "$name"

  for ((i=1; i<=60; i++)); do
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      printf ' OK\n'
      return 0
    fi
    printf '.'
    sleep 2
  done

  printf '\nNo respondió %s: %s\n' "$name" "$url" >&2
  return 1
}

wait_healthy() {
  local name="$1" cid state i
  printf 'Esperando %s' "$name"

  for ((i=1; i<=60; i++)); do
    cid="$(dc ps -q "$name")"
    state=""

    if [[ -n "$cid" ]]; then
      state="$(docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "$cid" 2>/dev/null || true)"
    fi

    if [[ "$state" == healthy || "$state" == running ]]; then
      printf ' OK\n'
      return 0
    fi

    printf '.'
    sleep 2
  done

  printf '\n%s no está saludable; revisá docker compose logs %s\n' "$name" "$name" >&2
  return 1
}

start_stack() {
  command -v curl >/dev/null || {
    echo "Falta curl" >&2
    exit 1
  }

  echo "Deteniendo la instancia Docker de $SERVICE (si existe)..."
  dc stop "$SERVICE" >/dev/null 2>&1 || true

  echo "Iniciando dependencias con imágenes existentes..."
  dc up -d --no-deps --no-build \
    mysql rabbitmq zipkin-server keycloak configserver

  wait_healthy mysql
  wait_healthy rabbitmq
  wait_url 'Config Server' 'http://localhost:8085/actuator/health'

  dc up -d --no-deps --no-build eureka-server
  wait_url 'Eureka' 'http://localhost:8065/'

  dc up -d --no-deps --no-build "$PEER"
  dc up -d --no-deps --no-build api-gateway

  echo "Stack preparado: $SERVICE se ejecutará fuera de Docker, en el puerto $PORT."
  dc ps
}

run_local() {
  local project_dir="$INFRA_DIR/../$SERVICE"

  [[ -x "$project_dir/mvnw" ]] || {
    echo "No encontré $project_dir/mvnw (se espera el repositorio hermano del microservicio)." >&2
    exit 1
  }

  start_stack

  export SPRING_PROFILES_ACTIVE=dev
  export CONFIG_SERVER_URL=http://localhost:8085

  export DB_HOST=127.0.0.1
  export DB_PORT="$MYSQL_PORT"
  export DB_NAME="${SERVICE%-service}_db"
  export DB_USER=root
  export DB_PASSWORD="$MYSQL_ROOT_PASSWORD"

  export RABBITMQ_HOST=127.0.0.1
  export RABBITMQ_PORT=5673
  export RABBITMQ_LISTENER_AUTO_STARTUP=true

  export COURIER_SERVICE_URL=http://localhost:8081
  export EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE=http://localhost:8065/eureka/

  export ZIPKIN_ENDPOINT=http://localhost:9411/api/v2/spans
  export MANAGEMENT_ZIPKIN_TRACING_ENDPOINT="$ZIPKIN_ENDPOINT"
  export MANAGEMENT_TRACING_EXPORT_ZIPKIN_ENDPOINT="$ZIPKIN_ENDPOINT"

  export SECURITY_JWT_SECRET_KEY="${SECURITY_JWT_SECRET_KEY:-}"

  cd "$project_dir"

  echo "Ejecutando $SERVICE con registro Eureka en host.docker.internal:$PORT"

  exec ./mvnw spring-boot:run \
    "-Dspring-boot.run.arguments=--server.port=$PORT --spring.profiles.active=dev --eureka.client.service-url.defaultZone=http://localhost:8065/eureka/ --eureka.instance.hostname=host.docker.internal --eureka.instance.prefer-ip-address=false --eureka.instance.non-secure-port=$PORT --eureka.instance.instance-id=$SERVICE:local:$PORT --management.zipkin.tracing.endpoint=http://localhost:9411/api/v2/spans"
}

case "$ACTION" in
  up)
    start_stack
    ;;
  run)
    run_local
    ;;
  restore)
    echo "Detené primero la aplicación local (Ctrl+C), para liberar el puerto $PORT."
    dc up -d --no-deps --no-build "$SERVICE"
    dc ps
    ;;
  status)
    dc ps
    ;;
esac

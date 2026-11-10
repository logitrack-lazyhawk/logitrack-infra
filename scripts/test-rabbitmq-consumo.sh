#!/usr/bin/env bash
set -Eeuo pipefail

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$INFRA_DIR/.env" ]]; then
  echo "Falta $INFRA_DIR/.env; completalo desde .env.example" >&2
  exit 1
fi
set -a
source "$INFRA_DIR/.env"
set +a
: "${RABBITMQ_USER:?Falta RABBITMQ_USER en .env}"
: "${RABBITMQ_PASSWORD:?Falta RABBITMQ_PASSWORD en .env}"

docker compose -f "$INFRA_DIR/docker-compose.yml" up -d --wait rabbitmq
# Vhost exclusivo: las colas de desarrollo pueden tener argumentos antiguos
# y los consumidores de otros servicios no deben recibir eventos de este test.
docker compose -f "$INFRA_DIR/docker-compose.yml" exec -T rabbitmq \
  rabbitmqctl add_vhost courier-consumo-it
docker compose -f "$INFRA_DIR/docker-compose.yml" exec -T rabbitmq \
  rabbitmqctl set_permissions -p courier-consumo-it "$RABBITMQ_USER" '.*' '.*' '.*'

cd "$INFRA_DIR/../courier-service"
export MAVEN_OPTS="${MAVEN_OPTS:--Xms64m -Xmx384m}"
exec ./mvnw \
  -DargLine="-Xms64m -Xmx512m -XX:ActiveProcessorCount=2" \
  -DforkCount=1 \
  -Dtest=RabbitMqConsumoIT \
  test "$@"

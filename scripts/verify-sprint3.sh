#!/usr/bin/env bash
set -euo pipefail
infra_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_dir="$(dirname "$infra_dir")"
for service in config-server security-service courier-service shipment-service; do
  echo "Verificando $service"
  (cd "$workspace_dir/$service" && bash ./mvnw -B clean verify)
done
echo 'Compilando Eureka'
(cd "$workspace_dir/config-server" && bash ./mvnw -B -f "$infra_dir/eureka-server/pom.xml" clean verify)
docker compose -f "$infra_dir/docker-compose.yml" config --quiet
echo 'Compilación, pruebas y estructura de Compose verificadas.'


#!/usr/bin/env bash
set -Eeuo pipefail

BASE="http://localhost:8081"
cd "$(dirname "$0")/.."

echo "=== F34 - Mediciones LogiTrack ==="
date -Is

echo
echo "=== JDBC - HikariCP ==="

for metrica in active idle max min pending connections; do
  if [[ "$metrica" == "connections" ]]; then
    nombre="hikaricp.connections"
  else
    nombre="hikaricp.connections.$metrica"
  fi

  respuesta=$(curl -fsS --max-time 5 \
    "$BASE/actuator/metrics/$nombre")

  valor=$(printf '%s' "$respuesta" | python3 -c \
    'import json,sys
d=json.load(sys.stdin)
print(d["measurements"][0]["value"])')

  printf "%-12s %s\n" "$metrica" "$valor"
done

echo
echo "=== HTTP - 10 solicitudes ==="

for i in $(seq 1 10); do
  curl -fsS -o /dev/null --max-time 5 \
    -w "Prueba $i: HTTP %{http_code}, %{time_total}s\n" \
    "$BASE/actuator/health"
done

echo
echo "=== RabbitMQ - Conexiones ==="

docker compose exec -T rabbitmq \
  rabbitmqctl list_connections name state channels

echo
echo "=== RabbitMQ - Colas ==="

docker compose exec -T rabbitmq \
  rabbitmqctl list_queues \
  name messages_ready messages_unacknowledged \
  consumers arguments

echo
echo "=== Mediciones finalizadas ==="

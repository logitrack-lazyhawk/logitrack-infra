#!/usr/bin/env bash
# ==============================================================================
# LOGITRACK - FLUJO DE PRUEBAS RBAC (Role-Based Access Control)
# Valida permisos por rol a través del API Gateway (Keycloak JWT)
# ==============================================================================

set -uo pipefail

GATEWAY_URL="${GATEWAY_URL:-http://localhost:8066}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8082}"
REALM="${KEYCLOAK_REALM:-lazyhawk}"
CLIENT_ID="${KEYCLOAK_CLIENT_ID:-logitrack-frontend}"

# Colores para salida de terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

echo -e "\n${CYAN}========================================================${NC}"
echo -e "${CYAN}   LOGITRACK — SUITE DE PRUEBAS DE SEGURIDAD RBAC${NC}"
echo -e "${CYAN}   Gateway:  ${GATEWAY_URL}${NC}"
echo -e "${CYAN}   Keycloak: ${KEYCLOAK_URL} (Realm: ${REALM})${NC}"
echo -e "${CYAN}========================================================${NC}\n"

get_token() {
  local user="$1"
  local pass="$2"
  local endpoint="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
  
  local resp
  resp=$(curl -s -X POST "$endpoint" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=${CLIENT_ID}&username=${user}&password=${pass}")

  # Extraer token con grep/sed o python si está disponible
  local token
  if command -v jq >/dev/null 2>&1; then
    token=$(echo "$resp" | jq -r .access_token)
  elif command -v python3 >/dev/null 2>&1; then
    token=$(echo "$resp" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))")
  else
    token=$(echo "$resp" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
  fi

  if [[ -z "$token" || "$token" == "null" ]]; then
    echo ""
  else
    echo "$token"
  fi
}

test_endpoint() {
  local desc="$1"
  local method="$2"
  local path="$3"
  local token="$4"
  local expect_type="$5" # "forbidden", "unauthorized", or comma-separated status codes e.g. "200,201,400"
  local body="${6:-}"

  local url="${GATEWAY_URL}${path}"
  local status_code

  local auth_header=()
  if [[ -n "$token" ]]; then
    auth_header=(-H "Authorization: Bearer ${token}")
  fi

  local body_args=()
  if [[ -n "$body" ]]; then
    body_args=(-H "Content-Type: application/json" -d "$body")
  fi

  status_code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" "${auth_header[@]}" "${body_args[@]}")

  local is_ok=false

  if [[ "$expect_type" == "forbidden" ]]; then
    [[ "$status_code" -eq 403 ]] && is_ok=true
  elif [[ "$expect_type" == "unauthorized" ]]; then
    [[ "$status_code" -eq 401 ]] && is_ok=true
  else
    IFS=',' read -ra ALLOWED <<< "$expect_type"
    for allowed_code in "${ALLOWED[@]}"; do
      if [[ "$status_code" -eq "$allowed_code" ]]; then
        is_ok=true
        break
      fi
    done
  fi

  if [[ "$is_ok" == true ]]; then
    echo -e "  ${GREEN}[PASS]${NC} ${desc} (HTTP ${status_code})"
    PASSED=$((PASSED + 1))
  else
    echo -e "  ${RED}[FAIL]${NC} ${desc} (Obtenido: ${status_code} | Esperado: ${expect_type})"
    FAILED=$((FAILED + 1))
  fi
}

# ------------------------------------------------------------------------------
# 1. ACCESO ANÓNIMO (Sin Token JWT)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--- 1. Peticiones Anónimas (Sin Token JWT) ---${NC}"
test_endpoint "GET /api/v1/productos sin token debe ser 401" "GET" "/api/v1/productos" "" "unauthorized"
test_endpoint "GET /api/v1/repartidores sin token debe ser 401" "GET" "/api/v1/repartidores" "" "unauthorized"
test_endpoint "POST /api/v1/productos sin token debe ser 401" "POST" "/api/v1/productos" "" "unauthorized" '{"nombre":"Test"}'

# ------------------------------------------------------------------------------
# 2. ROL CLIENTE (cliente@logitrack.com)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- 2. Autenticación con Rol CLIENTE (cliente@logitrack.com) ---${NC}"
TOKEN_CLIENTE=$(get_token "cliente@logitrack.com" "cliente123")

if [[ -n "$TOKEN_CLIENTE" ]]; then
  echo -e "  ${CYAN}Token obtenido para CLIENTE.${NC}"

  # Permisos denegados
  test_endpoint "CLIENTE creando producto (POST /api/v1/productos) -> DENEGADO" \
    "POST" "/api/v1/productos" "$TOKEN_CLIENTE" "forbidden" '{"nombre":"Nuevo Producto"}'

  test_endpoint "CLIENTE actualizando producto (PUT /api/v1/productos/1) -> DENEGADO" \
    "PUT" "/api/v1/productos/1" "$TOKEN_CLIENTE" "forbidden" '{"nombre":"Modificado"}'

  test_endpoint "CLIENTE borrando producto (DELETE /api/v1/productos/1) -> DENEGADO" \
    "DELETE" "/api/v1/productos/1" "$TOKEN_CLIENTE" "forbidden"

  test_endpoint "CLIENTE creando repartidor (POST /api/v1/repartidores) -> DENEGADO" \
    "POST" "/api/v1/repartidores" "$TOKEN_CLIENTE" "forbidden" '{"nombre":"Repartidor Falso"}'

  test_endpoint "CLIENTE consultando repartidores (GET /api/v1/repartidores) -> DENEGADO" \
    "GET" "/api/v1/repartidores" "$TOKEN_CLIENTE" "forbidden"

  test_endpoint "CLIENTE creando envío directo/admin (POST /api/v1/envios) -> DENEGADO" \
    "POST" "/api/v1/envios" "$TOKEN_CLIENTE" "forbidden" '{"destino":"Centro"}'

  # Permisos permitidos
  test_endpoint "CLIENTE consultando catálogo (GET /api/v1/productos) -> PERMITIDO" \
    "GET" "/api/v1/productos" "$TOKEN_CLIENTE" "200"

  test_endpoint "CLIENTE consultando sus propios envíos (GET /api/v1/envios/mis-envios) -> PERMITIDO" \
    "GET" "/api/v1/envios/mis-envios" "$TOKEN_CLIENTE" "200,204"
else
  echo -e "  ${RED}[!] No se pudo obtener el token para CLIENTE.${NC}"
  FAILED=$((FAILED + 1))
fi

# ------------------------------------------------------------------------------
# 3. ROL VENDEDOR (vendedor@logitrack.com)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- 3. Autenticación con Rol VENDEDOR (vendedor@logitrack.com) ---${NC}"
TOKEN_VENDEDOR=$(get_token "vendedor@logitrack.com" "vendedor123")

if [[ -n "$TOKEN_VENDEDOR" ]]; then
  echo -e "  ${CYAN}Token obtenido para VENDEDOR.${NC}"

  test_endpoint "VENDEDOR creando producto (POST /api/v1/productos) -> PERMITIDO (no 403)" \
    "POST" "/api/v1/productos" "$TOKEN_VENDEDOR" "200,201,400" '{"nombre":"Test Vendedor"}'

  test_endpoint "VENDEDOR consultando productos (GET /api/v1/productos) -> PERMITIDO" \
    "GET" "/api/v1/productos" "$TOKEN_VENDEDOR" "200"

  test_endpoint "VENDEDOR gestionando repartidores (GET /api/v1/repartidores) -> DENEGADO" \
    "GET" "/api/v1/repartidores" "$TOKEN_VENDEDOR" "forbidden"

  test_endpoint "VENDEDOR consultando clientes (GET /api/v1/clientes) -> DENEGADO" \
    "GET" "/api/v1/clientes" "$TOKEN_VENDEDOR" "forbidden"
else
  echo -e "  ${RED}[!] No se pudo obtener el token para VENDEDOR.${NC}"
  FAILED=$((FAILED + 1))
fi

# ------------------------------------------------------------------------------
# 4. ROL REPARTIDOR (repartidor@logitrack.com)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- 4. Autenticación con Rol REPARTIDOR (repartidor@logitrack.com) ---${NC}"
TOKEN_REPARTIDOR=$(get_token "repartidor@logitrack.com" "repartidor123")

if [[ -n "$TOKEN_REPARTIDOR" ]]; then
  echo -e "  ${CYAN}Token obtenido para REPARTIDOR.${NC}"

  test_endpoint "REPARTIDOR creando producto (POST /api/v1/productos) -> DENEGADO" \
    "POST" "/api/v1/productos" "$TOKEN_REPARTIDOR" "forbidden" '{"nombre":"Test Repartidor"}'

  test_endpoint "REPARTIDOR gestionando repartidores (GET /api/v1/repartidores/disponibles) -> PERMITIDO (no 403)" \
    "GET" "/api/v1/repartidores/disponibles" "$TOKEN_REPARTIDOR" "200,204,500"

  test_endpoint "REPARTIDOR consultando clientes (GET /api/v1/clientes) -> DENEGADO" \
    "GET" "/api/v1/clientes" "$TOKEN_REPARTIDOR" "forbidden"
else
  echo -e "  ${RED}[!] No se pudo obtener el token para REPARTIDOR.${NC}"
  FAILED=$((FAILED + 1))
fi

# ------------------------------------------------------------------------------
# 5. ROL ADMIN (admin@logitrack.com)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- 5. Autenticación con Rol ADMIN (admin@logitrack.com) ---${NC}"
TOKEN_ADMIN=$(get_token "admin@logitrack.com" "admin123")

if [[ -n "$TOKEN_ADMIN" ]]; then
  echo -e "  ${CYAN}Token obtenido para ADMIN.${NC}"

  test_endpoint "ADMIN consultando productos (GET /api/v1/productos) -> PERMITIDO" \
    "GET" "/api/v1/productos" "$TOKEN_ADMIN" "200"

  test_endpoint "ADMIN gestionando repartidores (GET /api/v1/repartidores/disponibles) -> PERMITIDO (no 403)" \
    "GET" "/api/v1/repartidores/disponibles" "$TOKEN_ADMIN" "200,204,500"

  test_endpoint "ADMIN gestionando clientes (GET /api/v1/clientes) -> PERMITIDO (no 403)" \
    "GET" "/api/v1/clientes" "$TOKEN_ADMIN" "200,204,500"
else
  echo -e "  ${RED}[!] No se pudo obtener el token para ADMIN.${NC}"
  FAILED=$((FAILED + 1))
fi

# ------------------------------------------------------------------------------
# RESUMEN FINAL
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}========================================================${NC}"
echo -e "${CYAN}   RESUMEN DE RESULTADOS RBAC${NC}"
echo -e "${CYAN}========================================================${NC}"
echo -e "  ${GREEN}Total pruebas pasadas: ${PASSED}${NC}"
if [[ "$FAILED" -gt 0 ]]; then
  echo -e "  ${RED}Total pruebas falladas: ${FAILED}${NC}"
else
  echo -e "  ${GREEN}Total pruebas falladas: 0${NC}"
fi

TOTAL=$((PASSED + FAILED))
if [[ "$TOTAL" -gt 0 ]]; then
  PERCENT=$(( (PASSED * 100) / TOTAL ))
  echo -e "  ${CYAN}Efectividad de cumplimiento RBAC: ${PERCENT}%${NC}"
fi
echo -e "${CYAN}========================================================${NC}\n"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0


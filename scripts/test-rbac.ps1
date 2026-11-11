# ==============================================================================
# LOGITRACK - FLUJO DE PRUEBAS RBAC (Role-Based Access Control)
# Valida permisos por rol a través del API Gateway (Keycloak JWT)
# ==============================================================================

param (
    [string]$GatewayUrl  = "http://localhost:8066",
    [string]$KeycloakUrl = "http://localhost:8082",
    [string]$Realm       = "lazyhawk",
    [string]$ClientId    = "logitrack-frontend"
)

$ErrorActionPreference = "Continue"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   LOGITRACK — SUITE DE PRUEBAS DE SEGURIDAD RBAC" -ForegroundColor Cyan
Write-Host "   Gateway:  $GatewayUrl" -ForegroundColor Cyan
Write-Host "   Keycloak: $KeycloakUrl (Realm: $Realm)" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$Passed = 0
$Failed = 0

function Get-KeycloakToken {
    param (
        [string]$Username,
        [string]$Password
    )
    $tokenEndpoint = "$KeycloakUrl/realms/$Realm/protocol/openid-connect/token"
    try {
        $body = @{
            grant_type = "password"
            client_id  = $ClientId
            username   = $Username
            password   = $Password
        }
        $resp = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ErrorAction Stop
        return $resp.access_token
    } catch {
        Write-Host "  [!] Error al autenticar usuario $Username en Keycloak: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Test-Endpoint {
    param (
        [string]$Description,
        [string]$Method,
        [string]$Path,
        [string]$Token,
        [int[]]$ExpectedStatuses,
        [string]$Body = $null,
        [bool]$ExpectForbidden = $false
    )

    $url = "$GatewayUrl$Path"
    $headers = @{}
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }
    if ($Body) {
        $headers["Content-Type"] = "application/json"
    }

    $statusCode = 0
    try {
        $curlArgs = @("-s", "-o", "nul", "-w", "%{http_code}", "-X", $Method, $url)
        if ($Token) {
            $curlArgs += @("-H", "Authorization: Bearer $Token")
        }
        if ($Body) {
            $curlArgs += @("-H", "Content-Type: application/json", "-d", $Body)
        }

        $codeStr = & curl.exe @curlArgs
        $statusCode = [int]$codeStr
    } catch {
        Write-Host "  [ERROR] Fallo al invocar endpoint: $($_.Exception.Message)" -ForegroundColor Red
        $script:Failed++
        return
    }

    $isOk = $false
    if ($ExpectForbidden) {
        $isOk = ($statusCode -eq 403)
    } else {
        $isOk = ($ExpectedStatuses -contains $statusCode)
    }

    if ($isOk) {
        Write-Host "  [PASS] $Description (HTTP $statusCode)" -ForegroundColor Green
        $script:Passed++
    } else {
        $expectedStr = if ($ExpectForbidden) { "403 (FORBIDDEN)" } else { ($ExpectedStatuses -join ", ") }
        Write-Host "  [FAIL] $Description (Obtenido: $statusCode | Esperado: $expectedStr)" -ForegroundColor Red
        $script:Failed++
    }
}

# ------------------------------------------------------------------------------
# 1. ACCESO ANÓNIMO (Sin Token JWT)
# ------------------------------------------------------------------------------
Write-Host "--- 1. Peticiones Anónimas (Sin Token JWT) ---" -ForegroundColor Yellow
Test-Endpoint -Description "GET /api/v1/productos sin token debe ser 401 Unauthorized" `
              -Method "GET" -Path "/api/v1/productos" -Token "" -ExpectedStatuses @(401)
Test-Endpoint -Description "GET /api/v1/repartidores sin token debe ser 401 Unauthorized" `
              -Method "GET" -Path "/api/v1/repartidores" -Token "" -ExpectedStatuses @(401)
Test-Endpoint -Description "POST /api/v1/productos sin token debe ser 401 Unauthorized" `
              -Method "POST" -Path "/api/v1/productos" -Token "" -ExpectedStatuses @(401) -Body '{"nombre":"Test"}'

# ------------------------------------------------------------------------------
# 2. ROL CLIENTE (cliente@logitrack.com)
# ------------------------------------------------------------------------------
Write-Host "`n--- 2. Autenticación con Rol CLIENTE (cliente@logitrack.com) ---" -ForegroundColor Yellow
$tokenCliente = Get-KeycloakToken -Username "cliente@logitrack.com" -Password "cliente123"

if ($tokenCliente) {
    Write-Host "  Token obtenido para CLIENTE." -ForegroundColor Cyan

    # Permisos denegados para CLIENTE
    Test-Endpoint -Description "CLIENTE creando producto (POST /api/v1/productos) -> DENEGADO" `
                  -Method "POST" -Path "/api/v1/productos" -Token $tokenCliente -ExpectForbidden $true -Body '{"nombre":"Nuevo Producto"}'

    Test-Endpoint -Description "CLIENTE actualizando producto (PUT /api/v1/productos/1) -> DENEGADO" `
                  -Method "PUT" -Path "/api/v1/productos/1" -Token $tokenCliente -ExpectForbidden $true -Body '{"nombre":"Modificado"}'

    Test-Endpoint -Description "CLIENTE borrando producto (DELETE /api/v1/productos/1) -> DENEGADO" `
                  -Method "DELETE" -Path "/api/v1/productos/1" -Token $tokenCliente -ExpectForbidden $true

    Test-Endpoint -Description "CLIENTE creando repartidor (POST /api/v1/repartidores) -> DENEGADO" `
                  -Method "POST" -Path "/api/v1/repartidores" -Token $tokenCliente -ExpectForbidden $true -Body '{"nombre":"Repartidor Falso"}'

    Test-Endpoint -Description "CLIENTE consultando repartidores (GET /api/v1/repartidores) -> DENEGADO" `
                  -Method "GET" -Path "/api/v1/repartidores" -Token $tokenCliente -ExpectForbidden $true

    Test-Endpoint -Description "CLIENTE creando envío directo/admin (POST /api/v1/envios) -> DENEGADO" `
                  -Method "POST" -Path "/api/v1/envios" -Token $tokenCliente -ExpectForbidden $true -Body '{"destino":"Centro"}'

    # Permisos permitidos para CLIENTE
    Test-Endpoint -Description "CLIENTE consultando catálogo (GET /api/v1/productos) -> PERMITIDO" `
                  -Method "GET" -Path "/api/v1/productos" -Token $tokenCliente -ExpectedStatuses @(200)

    Test-Endpoint -Description "CLIENTE consultando sus propios envíos (GET /api/v1/envios/mis-envios) -> PERMITIDO" `
                  -Method "GET" -Path "/api/v1/envios/mis-envios" -Token $tokenCliente -ExpectedStatuses @(200, 204)
}

# ------------------------------------------------------------------------------
# 3. ROL VENDEDOR (vendedor@logitrack.com)
# ------------------------------------------------------------------------------
Write-Host "`n--- 3. Autenticación con Rol VENDEDOR (vendedor@logitrack.com) ---" -ForegroundColor Yellow
$tokenVendedor = Get-KeycloakToken -Username "vendedor@logitrack.com" -Password "vendedor123"

if ($tokenVendedor) {
    Write-Host "  Token obtenido para VENDEDOR." -ForegroundColor Cyan

    Test-Endpoint -Description "VENDEDOR creando producto (POST /api/v1/productos) -> PERMITIDO (no 403)" `
                  -Method "POST" -Path "/api/v1/productos" -Token $tokenVendedor -ExpectedStatuses @(200, 201, 400) -Body '{"nombre":"Test Vendedor"}'

    Test-Endpoint -Description "VENDEDOR consultando productos (GET /api/v1/productos) -> PERMITIDO" `
                  -Method "GET" -Path "/api/v1/productos" -Token $tokenVendedor -ExpectedStatuses @(200)

    Test-Endpoint -Description "VENDEDOR gestionando repartidores (GET /api/v1/repartidores) -> DENEGADO" `
                  -Method "GET" -Path "/api/v1/repartidores" -Token $tokenVendedor -ExpectForbidden $true

    Test-Endpoint -Description "VENDEDOR consultando clientes (GET /api/v1/clientes) -> DENEGADO" `
                  -Method "GET" -Path "/api/v1/clientes" -Token $tokenVendedor -ExpectForbidden $true
}

# ------------------------------------------------------------------------------
# 4. ROL REPARTIDOR (repartidor@logitrack.com)
# ------------------------------------------------------------------------------
Write-Host "`n--- 4. Autenticación con Rol REPARTIDOR (repartidor@logitrack.com) ---" -ForegroundColor Yellow
$tokenRepartidor = Get-KeycloakToken -Username "repartidor@logitrack.com" -Password "repartidor123"

if ($tokenRepartidor) {
    Write-Host "  Token obtenido para REPARTIDOR." -ForegroundColor Cyan

    Test-Endpoint -Description "REPARTIDOR creando producto (POST /api/v1/productos) -> DENEGADO" `
                  -Method "POST" -Path "/api/v1/productos" -Token $tokenRepartidor -ExpectForbidden $true -Body '{"nombre":"Test Repartidor"}'

    Test-Endpoint -Description "REPARTIDOR gestionando repartidores (GET /api/v1/repartidores/disponibles) -> PERMITIDO (no 403)" `
                  -Method "GET" -Path "/api/v1/repartidores/disponibles" -Token $tokenRepartidor -ExpectedStatuses @(200, 204, 500)

    Test-Endpoint -Description "REPARTIDOR consultando clientes (GET /api/v1/clientes) -> DENEGADO" `
                  -Method "GET" -Path "/api/v1/clientes" -Token $tokenRepartidor -ExpectForbidden $true
}

# ------------------------------------------------------------------------------
# 5. ROL ADMIN (admin@logitrack.com)
# ------------------------------------------------------------------------------
Write-Host "`n--- 5. Autenticación con Rol ADMIN (admin@logitrack.com) ---" -ForegroundColor Yellow
$tokenAdmin = Get-KeycloakToken -Username "admin@logitrack.com" -Password "admin123"

if ($tokenAdmin) {
    Write-Host "  Token obtenido para ADMIN." -ForegroundColor Cyan

    Test-Endpoint -Description "ADMIN consultando productos (GET /api/v1/productos) -> PERMITIDO" `
                  -Method "GET" -Path "/api/v1/productos" -Token $tokenAdmin -ExpectedStatuses @(200)

    Test-Endpoint -Description "ADMIN gestionando repartidores (GET /api/v1/repartidores/disponibles) -> PERMITIDO (no 403)" `
                  -Method "GET" -Path "/api/v1/repartidores/disponibles" -Token $tokenAdmin -ExpectedStatuses @(200, 204, 500)

    Test-Endpoint -Description "ADMIN gestionando clientes (GET /api/v1/clientes) -> PERMITIDO (no 403)" `
                  -Method "GET" -Path "/api/v1/clientes" -Token $tokenAdmin -ExpectedStatuses @(200, 204, 500)
}

# ------------------------------------------------------------------------------
# RESUMEN FINAL
# ------------------------------------------------------------------------------
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   RESUMEN DE RESULTADOS RBAC" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Total pruebas pasadas: $Passed" -ForegroundColor Green
if ($Failed -gt 0) {
    Write-Host "  Total pruebas falladas: $Failed" -ForegroundColor Red
} else {
    Write-Host "  Total pruebas falladas: 0" -ForegroundColor Green
}
$total = $Passed + $Failed
if ($total -gt 0) {
    $pct = [math]::Round(($Passed / $total) * 100, 2)
    Write-Host "  Efectividad de cumplimiento RBAC: $pct%" -ForegroundColor Cyan
}
Write-Host "========================================================`n" -ForegroundColor Cyan


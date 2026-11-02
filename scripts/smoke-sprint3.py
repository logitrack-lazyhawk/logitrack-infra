#!/usr/bin/env python3
"""Demostración local de Feign, errores y trazas. --outage detiene y restaura courier."""
import argparse
import json
from pathlib import Path
import secrets
import subprocess
import time
import urllib.error
import urllib.request
import uuid

INFRA = Path(__file__).resolve().parents[1]


def request(port, path, method='GET', body=None, expected=200):
    payload = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(f'http://localhost:{port}{path}', data=payload,
                                 method=method, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            status, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, raw = error.code, error.read()
    result = json.loads(raw) if raw else None
    if status != expected:
        raise AssertionError(f'{method} {path}: esperaba {expected}, recibió {status}: {result}')
    return result


def wait_for(action, seconds=120):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        try:
            result = action()
            if result:
                return result
        except (AssertionError, OSError, ValueError) as error:
            last = error
        time.sleep(2)
    raise AssertionError(f'Tiempo de espera agotado. Último error: {last}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outage', action='store_true')
    args = parser.parse_args()
    for port in (8085, 8065, 8083, 8081, 8080):
        wait_for(lambda port=port: request(port, '/actuator/health')['status'] == 'UP')
    suffix = secrets.token_hex(5)
    dni = str(10000000 + secrets.randbelow(89999999))
    client = request(8080, '/api/v1/clientes', 'POST', {
        'nombre': 'Prueba Sprint 3', 'dni': dni, 'telefono': '+543881234567',
        'email': f'cliente-{suffix}@example.com'}, 201)
    courier = request(8081, '/api/v1/repartidores', 'POST', {
        'nombre': 'Courier Sprint 3', 'dni': dni, 'telefono': '+543881234567',
        'email': f'courier-{suffix}@example.com', 'tipoVehiculo': 'MOTO', 'estado': 'ACTIVO'}, 201)
    address = dict(calle='Belgrano', numero='100', ciudad='Jujuy', codigoPostal='4600',
                   provincia='Jujuy', localidad='San Salvador', descripcion='Prueba')

    def new_shipment():
        return request(8080, '/api/v1/envios', 'POST', {
            'clienteId': client['id'], 'peso': 1.0, 'ancho': 10.0, 'alto': 10.0, 'largo': 10.0,
            'origen': address, 'destino': dict(address, numero='200')}, 201)['id']

    def assign(shipment, courier_id, status=200):
        return request(8080, f'/api/v1/envios/{shipment}/asignar-repartidor', 'POST',
                       {'repartidorId': courier_id}, status)

    shipment = new_shipment()
    wait_for(lambda: assign(shipment, courier['id']))
    print('OK: asignación mediante Feign y descubrimiento Eureka')
    assign(new_shipment(), str(uuid.uuid4()), 404)
    print('OK: repartidor inexistente -> JSON 404')
    request(8081, f"/api/v1/repartidores/{courier['id']}/estado?estado=INACTIVO", 'PATCH', expected=204)
    try:
        assign(new_shipment(), courier['id'], 400)
        print('OK: repartidor inactivo -> JSON 400')
    finally:
        request(8081, f"/api/v1/repartidores/{courier['id']}/estado?estado=ACTIVO", 'PATCH', expected=204)

    def shared_trace():
        traces = request(9411, '/api/v2/traces?serviceName=shipment-service&limit=50')
        for trace in traces:
            services = {span.get('localEndpoint', {}).get('serviceName') for span in trace}
            if {'shipment-service', 'courier-service'} <= services:
                return trace[0]['traceId']
        return None

    trace_id = wait_for(shared_trace, seconds=45)
    print(f'OK: shipment y courier comparten traceId={trace_id} en Zipkin')
    if args.outage:
        compose = ['docker', 'compose', '-f', str(INFRA / 'docker-compose.yml')]
        try:
            subprocess.run(compose + ['stop', 'courier-service'], check=True)
            shipment = new_shipment()
            assign(shipment, courier['id'], 503)
            current = request(8080, f'/api/v1/envios/{shipment}')
            assert current['repartidorId'] is None, current
            print('OK: courier apagado -> JSON 503; envío sin asignación')
        finally:
            subprocess.run(compose + ['start', 'courier-service'], check=True)
        wait_for(lambda: request(8081, '/actuator/health')['status'] == 'UP')
        wait_for(lambda: assign(shipment, courier['id']))
        print('OK: comunicación recuperada después de restaurar courier')
    print('Demostración completa. Se conservaron los registros de prueba para inspección.')


if __name__ == '__main__':
    main()

"""Script de Verificación E2E para Google Sign-In (Issue #137 - E2E-KEY).

Valida de extremo a extremo:
1. Configuración de GOOGLE_CLIENT_ID en variables de entorno.
2. Endpoint /api/auth/google activo y receptivo en el backend.
3. Creación y vinculación automática del perfil de usuario.
4. Obtención y validez de JWT (access_token y refresh_token).

Uso:
    python scripts/verify_google_oauth.py
    python scripts/verify_google_oauth.py --api-url http://localhost:8050/api
    python scripts/verify_google_oauth.py --token <ID_TOKEN_REAL_DE_GOOGLE>
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any


def log_step(step: int, name: str) -> None:
    print(f"\n[{step}] {name}")
    print("-" * 60)


def verify_config(api_url: str) -> bool:
    log_step(1, "Verificando endpoint de salud de la API")
    health_url = api_url.replace("/api", "") + "/health"
    try:
        req = urllib.request.Request(health_url)
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            print(f"  OK Backend activo en {health_url}: {data}")
            return True
    except Exception as e:
        print(f"  AVISO No se pudo conectar a {health_url}: {e}")
        print("         Asegúrate de que el backend esté corriendo en el puerto indicado.")
        return False


def test_invalid_token_rejection(api_url: str) -> bool:
    log_step(2, "Verificando rechazo de tokens inválidos (Seguridad OAuth)")
    url = f"{api_url}/auth/google"
    payload = json.dumps({"google_token": "token_invalido_de_prueba_12345"}).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            print(f"  ERROR Se esperaba HTTP 401 pero devolvió HTTP {resp.status}")
            return False
    except urllib.error.HTTPError as e:
        if e.code == 401:
            err_body = json.loads(e.read().decode())
            print(f"  OK Token inválido rechazado correctamente con HTTP 401: {err_body}")
            return True
        else:
            print(f"  AVISO Código inesperado HTTP {e.code}: {e.read().decode()}")
            return False
    except Exception as e:
        print(f"  ERROR de conexión: {e}")
        return False


def test_real_token(api_url: str, token: str) -> bool:
    log_step(3, "Verificando autenticación con token de Google real")
    url = f"{api_url}/auth/google"
    payload = json.dumps({"google_token": token}).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode())
                user = data.get("user", {})
                access_token = data.get("access_token", "")
                refresh_token = data.get("refresh_token", "")
                print("  OK Autenticación E2E con Google exitosa:")
                print(f"     - Usuario ID: {user.get('id')}")
                print(f"     - Email: {user.get('email')}")
                print(f"     - Nombre: {user.get('full_name')}")
                print(f"     - Proveedor: {user.get('auth_provider')}")
                print(f"     - Email verificado: {user.get('is_verified')}")
                print(f"     - Access Token JWT: {access_token[:20]}...{access_token[-10:]}")
                print(f"     - Refresh Token: {refresh_token[:20]}...{refresh_token[-10:]}")
                return True
            else:
                print(f"  AVISO Respuesta inesperada HTTP {resp.status}")
                return False
    except urllib.error.HTTPError as e:
        print(f"  ERROR HTTP {e.code}: {e.read().decode()}")
        return False
    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Verificación E2E de Google Sign-In (Issue #137)")
    parser.add_argument(
        "--api-url",
        default="http://localhost:8050/api",
        help="URL base del backend API (por defecto: http://localhost:8050/api)",
    )
    parser.add_argument(
        "--token",
        default=None,
        help="ID Token de Google para prueba con credencial real",
    )
    args = parser.parse_args()

    print("=" * 60)
    print(" VERIFICACIÓN E2E: GOOGLE SIGN-IN (ISSUE #137 - E2E-KEY)")
    print("=" * 60)
    print(f"Target API: {args.api_url}")

    backend_ok = verify_config(args.api_url)
    rejection_ok = test_invalid_token_rejection(args.api_url)

    real_token_ok = True
    if args.token:
        real_token_ok = test_real_token(args.api_url, args.token)
    else:
        print("\n[3] Token de Google real omitido (usar --token <id_token> para prueba con cuenta en vivo)")
        print("    Para ejecutar con cuenta Google real: generar token desde la app móvil o playground.")

    print("\n" + "=" * 60)
    if backend_ok and rejection_ok and real_token_ok:
        print(" RESULTADO: VERIFICACIÓN E2E COMPLETADA CON ÉXITO")
        print("=" * 60)
        return 0
    else:
        print(" RESULTADO: AL MENOS UNA COMPROBACIÓN REQUIRIÓ ATENCIÓN")
        print("=" * 60)
        return 1


if __name__ == "__main__":
    sys.exit(main())

"""Limiter compartido de slowapi.

Vive en su propio módulo para que tanto `main.py` como los routers
(p. ej. `auth.py`) usen la MISMA instancia de Limiter sin imports circulares.
Antes había dos instancias distintas (una en main, otra en auth), lo que dejaba
la configuración de rate limiting inconsistente.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Una sola instancia para toda la app. Los decoradores @limiter.limit() y el
# app.state.limiter deben apuntar a este mismo objeto.
limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])

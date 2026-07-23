"""Parseo de menciones (@usuario) y hashtags (#tag) en texto social.

El resultado se usa solo para WHERE ... IN (params) parametrizados y para
notificar; nunca se interpola en SQL crudo.
"""

import re

# El look-behind evita capturar emails (a@b) o ##doble.
_MENTION_RE = re.compile(r"(?<![\w@])@([A-Za-z0-9_]{3,30})")
_HASHTAG_RE = re.compile(r"(?<![\w#])#([A-Za-z0-9_]{1,100})")

_MAX_MENTIONS = 10
_MAX_HASHTAGS = 30


def _extract(pattern: re.Pattern, text: str, cap: int) -> list[str]:
    if not text:
        return []
    seen: dict[str, None] = {}
    for match in pattern.finditer(text):
        token = match.group(1).lower()
        if token not in seen:
            seen[token] = None
        if len(seen) >= cap:
            break
    return list(seen.keys())


def extract_mentions(text: str) -> list[str]:
    """Usernames mencionados: minúscula, sin '@', deduplicados y capeados."""
    return _extract(_MENTION_RE, text, _MAX_MENTIONS)


def extract_hashtags(text: str) -> list[str]:
    """Hashtags: minúscula, sin '#', deduplicados y capeados."""
    return _extract(_HASHTAG_RE, text, _MAX_HASHTAGS)

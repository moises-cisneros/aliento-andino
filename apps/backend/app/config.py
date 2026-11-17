from pathlib import Path

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings

_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"

# Valores de SECRET_KEY que NUNCA deben usarse en producción.
_WEAK_SECRET_KEYS = {"", "dev-secret-key-cambiar-en-produccion", "changeme", "secret"}


class Settings(BaseSettings):
    """Configuración central de la aplicación Aliento Andino."""

    # General
    app_name: str = "Aliento Andino API"
    debug: bool = False

    # Base de datos PostgreSQL (DEBE configurarse en .env)
    database_url: str

    # JWT (DEBE configurarse en .env)
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    # Google OAuth
    google_client_id: str = ""

    # CORS - orígenes permitidos (configurar en .env para producción)
    cors_origins: list[str] | str = []

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, v):
        if isinstance(v, str):
            import json

            try:
                parsed = json.loads(v)
                if isinstance(parsed, list):
                    return parsed
            except (json.JSONDecodeError, TypeError):
                pass
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v

    # Email (SMTP)
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from_name: str = "Aliento Andino"
    smtp_from_email: str = ""

    # URL del frontend para links de reset password
    frontend_url: str = ""

    # Vertex AI / Gemini
    google_application_credentials: str = ""
    vertex_project_id: str = ""
    vertex_location: str = "us-central1"
    gemini_model: str = "gemini-2.5-flash"

    # Cloud Storage
    gcs_bucket_name: str = ""

    @model_validator(mode="after")
    def _validate_production_secrets(self):
        """Falla el arranque si la config de producción es insegura.

        Solo se aplica cuando debug=False (producción). En desarrollo/tests
        (debug=True) no interfiere.
        """
        if self.debug:
            return self

        if self.secret_key in _WEAK_SECRET_KEYS or len(self.secret_key) < 32:
            raise ValueError(
                "SECRET_KEY inseguro para producción (debug=False). "
                'Generá una clave fuerte con: python -c "import secrets; '
                'print(secrets.token_hex(32))" y configurala en el entorno.'
            )

        if "*" in self.cors_origins:
            raise ValueError(
                "CORS_ORIGINS no puede contener '*' en producción con "
                "allow_credentials=True. Especificá los orígenes explícitos."
            )

        return self

    model_config = {"env_file": str(_ENV_FILE), "env_file_encoding": "utf-8"}


settings = Settings()

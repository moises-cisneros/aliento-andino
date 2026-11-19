# Configuración y Verificación de Entrega Real de Emails vía SMTP

> **Issue**: [#138 [E2E-KEY] Verificación de entrega real de correos electrónicos vía SMTP](https://github.com/moises-cisneros/aliento-andino/issues/138)  
> **Parent Issue**: [#136 [TRACKING] E2E: Seguimiento de Pruebas con Dependencia de Claves Externas y Hardware Físico](https://github.com/moises-cisneros/aliento-andino/issues/136)  
> **Área**: `area:backend` | **Sprint**: 3

---

## 1. Arquitectura de Mensajería y Entrega de Correo

El sistema emite correos transaccionales para:

1. **Verificación de Email**: Código de 6 dígitos estilo PIN (`/api/auth/send-verification-code` y `/api/auth/verify-email`).
2. **Restablecimiento de Contraseña**: Token de 6 dígitos numéricos con expiración de 15 minutos (`/api/auth/forgot-password` y `/api/auth/reset-password`).
3. **Bienvenida / Onboarding**: Notificación de registro exitoso.

### Diagrama de Secuencia E2E

```mermaid
sequenceDiagram
    autonumber
    actor Usuario
    participant Backend as FastAPI Backend (Port 8050)
    participant DB as PostgreSQL
    participant SMTP as Servidor SMTP (SendGrid/Resend)
    actor Inbox as Buzón del Usuario

    Usuario->>Backend: POST /api/auth/send-verification-code
    Backend->>DB: Genera PIN 6 dígitos y expires (now + 15m)
    Backend->>SMTP: Enviar Email (aiosmtplib STARTTLS:587 / SSL:465)
    SMTP->>Inbox: Entrega física con cabeceras SPF / DKIM / DMARC
    Inbox-->>Usuario: Usuario lee código en su bandeja de entrada
    Usuario->>Backend: POST /api/auth/verify-email { code: "123456" }
    Backend->>DB: Valida PIN y expira; marca is_verified = True
    Backend-->>Usuario: 200 OK (Email verificado)
```

---

## 2. Criterio 1: Configuración de Variables en Staging / Producción

En entorno local sin credenciales, el sistema opera en **modo stub** (registra en logs sin arrojar errores ni bloquear el flujo). Para entornos de Staging y Producción, configurar en `apps/backend/.env`:

```env
# ==========================================
# Configuración del Servidor SMTP
# ==========================================
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxx
SMTP_FROM_NAME="Aliento Andino"
SMTP_FROM_EMAIL=notificaciones@alientoandino.org
```

### Proveedores Compatibles y Puertos

| Proveedor       | `SMTP_HOST`         | `SMTP_PORT`     | `SMTP_USER`            | Cifrado                 |
| :-------------- | :------------------ | :-------------- | :--------------------- | :---------------------- |
| **SendGrid**    | `smtp.sendgrid.net` | `587`           | `apikey`               | STARTTLS                |
| **Resend**      | `smtp.resend.com`   | `587`           | `resend`               | STARTTLS                |
| **Mailgun**     | `smtp.mailgun.org`  | `587` (o `465`) | `postmaster@<dominio>` | STARTTLS / SSL          |
| **Gmail Relay** | `smtp.gmail.com`    | `587`           | tu-cuenta@gmail.com    | STARTTLS (App Password) |

> [!NOTE]  
> El servicio detecta automáticamente el puerto: `465` utiliza TLS directo (`use_tls=True`), mientras que `587` o `25` utilizan negociación STARTTLS (`start_tls=True`).

---

## 3. Criterio 2: Envío y Recepción del Código de 6 Dígitos

1. **Construcción del Mensaje (Multipart MIME)**:
   - Los correos se envían en formato dual: versión de **texto plano** (para clientes simples y filtros antispam) y versión **HTML responsive** con diseño PIN de 6 dígitos.
2. **Ciclo de Vida del Código**:
   - Generado con criptografía segura: `secrets.randbelow(1_000_000):06d`.
   - Persistido en `User.email_verification_code`.
   - Tiempo de expiración estricto: 15 minutos en UTC.
   - Normalización de zona horaria para prevenir incompatibilidades entre bases de datos y Python.

---

## 4. Criterio 3: Validación de Cabeceras SPF, DKIM y DMARC

Para asegurar que los correos no sean clasificados como SPAM y lleguen a la bandeja de entrada principal, el dominio remitente (`alientoandino.org`) debe contar con los siguientes registros DNS:

### 1. Registro SPF (Sender Policy Framework)

Autoriza a los servidores SMTP del proveedor a enviar correos en nombre del dominio.

- **Tipo**: `TXT`
- **Host**: `@`
- **Valor**: `v=spf1 include:sendgrid.net ~all` (o `include:resend.com ~all`)

### 2. Registro DKIM (DomainKeys Identified Mail)

Firma criptográfica que garantiza que el mensaje no fue modificado en tránsito.

- **Tipo**: `CNAME` o `TXT`
- **Host**: `s1._domainkey.alientoandino.org`
- **Valor**: Provisto por el proveedor SMTP al verificar el dominio.

### 3. Registro DMARC (Domain-based Message Authentication)

Define la política de acción ante fallos de SPF o DKIM.

- **Tipo**: `TXT`
- **Host**: `_dmarc`
- **Valor**: `v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@alientoandino.org; pct=100`

### Validación en la Bandeja de Entrada

Al recibir un correo en Gmail o Thunderbird, seleccione **"Mostrar original"** y compruebe:

```text
Authentication-Results: mx.google.com;
       dkim=pass header.i=@alientoandino.org header.s=s1 header.b=...;
       spf=pass (google.com: domain of notificaciones@alientoandino.org designates ... as permitted sender);
       dmarc=pass (p=QUARANTINE sp=QUARANTINE dis=NONE) header.from=alientoandino.org
```

---

## 5. Verificación y Pruebas Automatizadas

### Ejecución de Pruebas Unitarias y de Integración

```bash
cd apps/backend
.\.venv\Scripts\pytest tests/test_email_delivery.py -v
```

### Ejecución del Script de Verificación CLI

```bash
# Diagnóstico de DNS y configuración local/stub
python scripts/verify_smtp_delivery.py

# Envío real a un buzón físico (con credenciales en apps/backend/.env)
python scripts/verify_smtp_delivery.py --to tu-correo@ejemplo.com
```

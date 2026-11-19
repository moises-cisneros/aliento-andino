# Modelo C4 de Arquitectura de Software — Aliento Andino

> **Sistema**: Plataforma de Tutoría Virtual y Red Social para Instrumentos de Viento Andinos (Quena, Zampoña y Tarka).  
> **Estándar**: C4 Model (Context, Containers, Components, Code) por Simon Brown.  
> **Trazabilidad**: Enlazado con [`ARCHITECTURE.md`](ARCHITECTURE.md), [`SPRINTS_AND_USER_STORIES.md`](SPRINTS_AND_USER_STORIES.md), [`QUALITY_STANDARDS.md`](QUALITY_STANDARDS.md), [`CODING_STANDARDS.md`](CODING_STANDARDS.md) y tokens en [`../DESIGN.md`](../DESIGN.md).

---

## 1. Nivel 1: Diagrama de Contexto del Sistema (System Context)

El diagrama de contexto ubica a **Aliento Andino** dentro de su ecosistema operativo, delimitando a los usuarios y los sistemas externos con los que se relaciona.

```mermaid
flowchart TD
    subgraph Actores ["Usuarios del Sistema"]
        Estudiante["👤 Estudiante de Viento Andino<br/>[Persona]<br/>Aprende Quena, Zampoña o Tarka con práctica en vivo"]
        Docente["👤 Docente / Administrador<br/>[Persona]<br/>Gestiona lecciones, curricula, digitaciones y audita reportes"]
    end

    subgraph FronteraSistema ["Frontera del Sistema Aliento Andino"]
        SistemaCore["🏔️ Plataforma Aliento Andino<br/>[Sistema de Software]<br/>Tutoría interactiva on-device, inferencia de audio/postura, red social y gestión curricular"]
    end

    subgraph SistemasExternos ["Sistemas Externos"]
        FCM["🔔 Firebase Cloud Messaging (FCM)<br/>[Sistema Externo]<br/>Envío de notificaciones push de racha y retos"]
        GHPages["📚 GitHub Pages CDN<br/>[Sistema Externo]<br/>Alojamiento estático de manual de usuario (Docusaurus)"]
        ObjectStorage["💾 Cloud Object Storage / S3<br/>[Sistema Externo]<br/>Backups cifrados diarios de PostgreSQL"]
    end

    Estudiante -->|"1. Practica afinación, postura y recibe feedback on-device [HTTPS/Audio]"| SistemaCore
    Docente -->|"2. Crea lecciones, administra usuarios y modera contenido [HTTPS/Web]"| SistemaCore
    SistemaCore -->|"3. Despacha alertas de racha diaria y recordatorios"| FCM
    FCM -->|"4. Notificaciones push al móvil"| Estudiante
    Docente -.->|"5. Consulta manuales y documentación de arquitectura"| GHPages
    Estudiante -.->|"6. Consulta guías de digitación y calibración"| GHPages
    SistemaCore -->|"7. Descarga periódica de backups automatizados"| ObjectStorage
```

### Descripción de Elementos de Contexto

| Elemento                        | Tipo                | Descripción                                                                                                                 |
| :------------------------------ | :------------------ | :-------------------------------------------------------------------------------------------------------------------------- |
| **Estudiante de Viento Andino** | Persona             | Usuario móvil que interpreta Quena, Zampoña o Tarka frente al micrófono y cámara.                                           |
| **Docente / Administrador**     | Persona             | Usuario del panel web encargado de la curaduría pedagógica y moderación comunitaria.                                        |
| **Plataforma Aliento Andino**   | Sistema de Software | Núcleo integral que procesa la telemetría, autentica usuarios, almacena progreso y brinda tutoría interactiva.              |
| **Firebase Cloud Messaging**    | Sistema Externo     | Servicio de mensajería para alertas de inactividad, preservación de racha (_Streak Flame_) y retos semanales.               |
| **GitHub Pages CDN**            | Sistema Externo     | Red de distribución de contenido que aloja el portal Docusaurus con manuales y especificaciones técnicas.                   |
| **Cloud Object Storage**        | Sistema Externo     | Repositorio de almacenamiento de objetos donde se depositan los backups comprimidos (`pg_dump`) generados por scripts cron. |

---

## 2. Nivel 2: Diagrama de Contenedores (Containers)

El diagrama de contenedores describe las aplicaciones, almacenes de datos y microservicios que componen **Aliento Andino**, indicando protocolos de comunicación y límites tecnológicos.

```mermaid
flowchart TB
    subgraph DispositivoMovil ["📱 Dispositivo Móvil del Estudiante (Android 8+ / iOS 14+)"]
        MobileApp["📱 Aplicación Móvil<br/>[Flutter 3.x / Dart]<br/>BLoC, GoRouter, Dio, SharedPreferences, Drift SQLite"]

        subgraph MotorLocal ["⚡ Motor de Inferencia On-Device (Edge AI)"]
            YIN["🎙️ YIN / SPICE Engine<br/>[C++ / FFI Dart]<br/>Pitch fundamental f0 y cents (<50ms)"]
            MediaPipe["👁️ MediaPipe Pose & Hands<br/>[TFLite / GPU]<br/>Postura y digitación a 30 FPS"]
            SLM["🤖 SLM Tutor Local<br/>[Gemma 2 2B / Llama 3.2 1B]<br/>Consejos pedagógicos offline"]
        end

        MobileApp <-->|"Buffer PCM / Isolates"| YIN
        MobileApp <-->|"RGB Frames / GPU Pipeline"| MediaPipe
        MobileApp <-->|"Telemetría JSON / Prompt"| SLM
    end

    subgraph NavegadorAdmin ["💻 Estación de Trabajo Docente"]
        WebAdmin["💻 Panel Web Admin<br/>[Angular 21 Standalone]<br/>Signals, Angular Material, Lucide Icons"]
    end

    subgraph ServidorProduccion ["🖥️ Servidor de Producción (VPS / Cloud Host)"]
        ReverseProxy["🔀 Reverse Proxy & API Gateway<br/>[Nginx Alpine]<br/>Terminación SSL, rate limiting, routing /api/* y /"]
        BackendAPI["⚙️ Backend Core API REST<br/>[FastAPI / Python 3.12]<br/>Uvicorn async, Pydantic v2, SQLAlchemy 2 Async"]
        MicroML["🧠 Microservicio ML Auxiliar<br/>[FastAPI / PyTorch / Puerto 8001]<br/>FAQ semántico, validación armónica pesada"]
        Database[("🗄️ Base de Datos Relacional<br/>[PostgreSQL 16 Alpine]<br/>Tablas normalizadas, JSONB telemetría, Alembic")]
    end

    subgraph Documentacion ["📚 Portal de Documentación"]
        DocsSite["📖 Manual de Usuario y Wiki<br/>[Docusaurus 3.x]<br/>GitHub Pages estático"]
    end

    WebAdmin -->|"HTTPS / JSON [REST API]"| ReverseProxy
    MobileApp -->|"HTTPS / JSON [REST API Sync]"| ReverseProxy
    ReverseProxy -->|"Proxy pass :8000"| BackendAPI
    ReverseProxy -->|"Proxy pass :8001"| MicroML
    BackendAPI -->|"TCP / SQL asíncrono (asyncpg :5432)"| Database
    BackendAPI -.->|"Llamada interna RPC/HTTP"| MicroML
```

> **Nota:** el motor YIN se ejecuta 100 % on-device dentro de un Isolate C++/Dart en Flutter. No se envía audio a la nube en tiempo de ejecución.

### Especificación de Contenedores

| Contenedor           | Tecnología                     | Responsabilidad                                                                                             | Protocolos                      |
| :------------------- | :----------------------------- | :---------------------------------------------------------------------------------------------------------- | :------------------------------ |
| **Mobile App**       | Flutter 3.x (Dart)             | Interfaz de práctica, captura de audio/video, orquestación de feedback, sincronización offline.             | HTTPS (REST), FFI a C++         |
| **Motor On-Device**  | C++, TFLite, MediaPipe, WebLLM | Detección de pitch $<50\text{ms}$, visión a 30 FPS y generación de consejos con 0 bytes enviados a la nube. | En memoria (Pointers / JSON)    |
| **Web Admin**        | Angular 21 Standalone          | Panel administrativo para gestión curricular de notas/digitaciones, estadísticas de uso y moderación.       | HTTPS (REST/JSON)               |
| **Reverse Proxy**    | Nginx Alpine                   | Gateway perimetral, balanceador de carga local, terminación SSL, rate limiting contra abusos (DDoS).        | HTTP/1.1, HTTPS (TLS 1.3)       |
| **Backend API**      | FastAPI / Python 3.12          | Autenticación JWT rotativa, lógica de negocio de lecciones, evaluación de rachas, rankings y muro social.   | HTTPS / REST / asyncpg          |
| **Microservicio ML** | FastAPI / Python 3.12 (8001)   | Motor complementario de embeddings semánticos para FAQ musical y validaciones armónicas complejas.          | HTTP / REST                     |
| **Base de Datos**    | PostgreSQL 16 Alpine           | Persistencia de usuarios, secuencias de notas, intentos de práctica, auditoría y relaciones sociales.       | PostgreSQL Wire Protocol (5432) |
| **Docs Site**        | Docusaurus 3 (pnpm)            | Wiki técnica y manual de usuario desplegado en GitHub Pages.                                                | HTTPS estático CDN              |

---

## 3. Nivel 3: Diagramas de Componentes (Components)

### 3.1 Componentes de Backend Core API (`apps/backend`)

El backend sigue una arquitectura en capas estrictamente desacoplada: **Routers $\rightarrow$ Services $\rightarrow$ Models / Database**.

```mermaid
flowchart TD
    subgraph RoutersLayer ["Capa de Routers (HTTP / Endpoints)"]
        AuthR["AuthRouter<br/>/api/v1/auth"]
        UsersR["UsersRouter<br/>/api/v1/users"]
        LessonR["LessonsRouter<br/>/api/v1/lessons"]
        FingeringR["FingeringsRouter<br/>/api/v1/fingerings"]
        PracticeR["PracticeRouter<br/>/api/v1/practice"]
        SocialR["SocialRouter<br/>/api/v1/social"]
        RankingR["RankingsRouter<br/>/api/v1/rankings"]
        NotificationR["NotificationsRouter<br/>/api/v1/notifications"]
        AnalyticsR["AnalyticsRouter<br/>/api/v1/analytics"]
        TutorR["TutorRouter<br/>/api/v1/tutor"]
        AuditR["AuditRouter<br/>/api/v1/admin/audit"]
    end

    subgraph SecurityLayer ["Capa de Seguridad & Dependencias"]
        AuthDep["AuthDependency<br/>(get_current_user, get_current_admin)"]
        RateLimit["RateLimiter<br/>(Slowapi / TokenBucket)"]
        DBSession["DatabaseSession<br/>(get_db asyncpg)"]
    end

    subgraph SchemasLayer ["Capa de Contratos (Pydantic v2)"]
        AuthSchemas["AuthSchemas<br/>(UserRegister, UserLogin, TokenResponse)"]
        UserSchemas["UserSchemas<br/>(UserUpdate, UserProfileResponse)"]
        LessonSchemas["LessonSchemas<br/>(LessonCreate, LessonResponse, NoteSequenceCreate)"]
        FingeringSchemas["FingeringSchemas<br/>(FingeringCreate, FingeringResponse)"]
        PracticeSchemas["PracticeSchemas<br/>(PracticeSubmitRequest, PracticeSessionResponse)"]
        SocialSchemas["SocialSchemas<br/>(PostCreate, PostResponse, CommentCreate)"]
        RankingSchemas["RankingSchemas<br/>(LeaderboardResponse, StreakResponse)"]
        AnalyticsSchemas["AnalyticsSchemas<br/>(InstrumentMetricsResponse, DropoffResponse)"]
    end

    subgraph ServicesLayer ["Capa de Servicios de Negocio"]
        AuthSvc["AuthService<br/>(login, register, rotate_refresh_token)"]
        UserSvc["UserService<br/>(update_profile, update_breath_profile)"]
        LessonSvc["LessonService<br/>(get_lessons, create_lesson, get_by_id)"]
        FingeringSvc["FingeringService<br/>(create_fingering, get_by_instrument)"]
        PracticeSvc["PracticeService<br/>(submit_session, get_history, calculate_xp)"]
        SocialSvc["SocialService<br/>(create_post, get_feed, toggle_reaction)"]
        RankingSvc["RankingService<br/>(get_leaderboard, update_streaks)"]
        NotificationSvc["NotificationDispatcher<br/>(send_push, schedule_reminder)"]
        AnalyticsSvc["AnalyticsService<br/>(get_instrument_metrics, get_dropoff)"]
        TutorSvc["TutorService<br/>(generate_fallback_advice, log_ai_usage)"]
        AuditSvc["AuditService<br/>(log_admin_action, query_audit_logs)"]
    end

    subgraph ModelsLayer ["Capa de Persistencia (SQLAlchemy 2 Async)"]
        UserModel["UserModel & RefreshTokenModel (users, refresh_tokens)"]
        LessonModel["LessonModel, CategoryModel, NoteSequenceModel"]
        FingeringModel["FingeringModel (fingerings)"]
        PracticeModel["PracticeSessionModel (practice_sessions)"]
        SocialModel["PostModel, CommentModel, LikeModel, FollowModel, ReportModel"]
        RankingModel["UserXPModel, AchievementModel, UserAchievementModel"]
        NotificationModel["NotificationModel, NotificationTokenModel"]
        AnalyticsModel["AdminAuditLogModel, AiUsageLogModel, AppSettingModel"]
    end

    RoutersLayer --> SecurityLayer
    RoutersLayer --> SchemasLayer
    RoutersLayer --> ServicesLayer
    ServicesLayer --> ModelsLayer
    ModelsLayer --> DBSession
```

---

### 3.2 Componentes de la Aplicación Web Admin (`apps/web`)

Desarrollada en Angular 21 con arquitectura Standalone, Signals y control de acceso RBAC.

```mermaid
flowchart TD
    subgraph WebCore ["Capa Core & Infraestructura"]
        AuthGuard["AdminGuard & AuthGuard<br/>(Control de rutas por rol)"]
        AuthInterceptor["AuthInterceptor<br/>(Inyección Bearer + refresh de token)"]
        HttpService["HttpClient Engine"]
    end

    subgraph WebServices ["Servicios de Dominio con Signals"]
        AuthAdminSvc["AuthAdminService<br/>(currentUser, isAuthenticated signal)"]
        LessonAdminSvc["LessonAdminService<br/>(lessonsList, categories, activeLesson)"]
        FingeringAdminSvc["FingeringAdminService<br/>(fingeringsList, activeInstrument)"]
        AuditAdminSvc["AuditAdminService<br/>(auditLogs signal, filters)"]
        ModerationSvc["SocialModerationService<br/>(reportedPosts, banUser, usersList)"]
        AnalyticsSvc["AnalyticsAdminService<br/>(instrumentMetrics, dropoffData, exportCsv)"]
    end

    subgraph WebViews ["Vistas y Componentes Standalone"]
        LayoutComp["AdminLayoutComponent<br/>(Navbar, Sidebar, ToastContainer)"]
        LessonListComp["LessonListComponent<br/>(Tabla reactiva, filtros por instrumento)"]
        LessonEditorComp["LessonEditorComponent<br/>(Editor de secuencias de notas y respiración)"]
        FingeringCatalogComp["FingeringCatalogComponent<br/>(Editor visual de digitaciones de Quena/Zampoña/Tarka)"]
        ModerationComp["ModerationDashboardComponent<br/>(Gestión de reportes comunitarios y usuarios)"]
        AnalyticsComp["AnalyticsDashboardComponent<br/>(Gráficos de precisión tonal y retención)"]
        AuditLogsComp["AuditLogsComponent<br/>(Visor de eventos de seguridad)"]
    end

    WebViews --> WebServices
    WebServices --> WebCore
    WebCore -->|"HTTP /api/v1/*"| HttpService
```

---

### 3.3 Componentes de la Aplicación Móvil (`apps/mobile`)

Estructurada en Flutter 3.x con Clean Architecture, BLoC reactivo e inferencia local desacoplada.

```mermaid
flowchart TD
    subgraph UIViews ["Capa de Presentación (UI)"]
        TunerScreen["AfinadorScreen<br/>(Aguja reactiva, cents, calado/alto, tema claro/oscuro)"]
        PracticeScreen["PracticeScreen<br/>(Reproductor de melodía, digitación interactiva)"]
        QuenaFingeringWidget["QuenaFingeringWidget<br/>(7 orificios)"]
        ZamponaFingeringWidget["ZamponaFingeringWidget<br/>(2 filas: Ira y Arca)"]
        TarkaFingeringWidget["TarkaFingeringWidget<br/>(6 orificios)"]
        PostureCameraView["PostureCameraView<br/>(Overlay de hombros, verticalidad y puntuación 0-100)"]
        InstrumentSelector["InstrumentSelectorAppBar<br/>(Conmutador dinámico Quena/Zampoña/Tarka)"]
        OfflineLessonsScreen["OfflineLessonsScreen<br/>(Gestor de lecciones cacheadas y descargas)"]
        ProfileEditScreen["ProfileEditScreen<br/>(Datos, estado de calibración respiratoria y recordatorios)"]
        SocialFeedView["SocialFeedView<br/>(Muro comunitario, audio player, reacciones)"]
    end

    subgraph BlocsLayer ["Gestión de Estado (BLoC / Cubit)"]
        ActiveInstrumentBloc["ActiveInstrumentBloc (SwitchInstrumentEvent)"]
        TunerBloc["TunerBloc (AudioStreamEvent -> NoteDetectedState)"]
        PracticeBloc["PracticeBloc (Start, NoteHit, CompleteSession)"]
        PostureBloc["PostureBloc (CameraFrame -> AlignmentEvaluated)"]
        LessonDownloadBloc["LessonDownloadBloc (DownloadRequested, CacheCleared)"]
        ProfileBloc["ProfileBloc (ProfileUpdated, CalibrationSaved)"]
        SocialBloc["SocialBloc (FetchFeed, LikePost, SubmitComment)"]
        AuthBloc["AuthBloc (LoginRequested, TokenRefreshed, Logout)"]
    end

    subgraph DomainEngines ["Motores de Procesamiento On-Device"]
        YinEngine["YinPitchDetector<br/>(FFI C++ Isolate, Buffer circular 1024)"]
        BreathCalibrator["BreathCalibrator<br/>(Cálculo RMS de 3s para 'Soplo Suave')"]
        MediaPipePipeline["MediaPipePipeline<br/>(Pose 33 landmarks + Hands 21 landmarks)"]
        LocalNotifications["LocalNotificationService<br/>(Alarmas locales de práctica diaria)"]
        SlmOrchestrator["LocalSlmOrchestrator<br/>(Inferencia pedagógica offline con Gemma/Llama)"]
    end

    subgraph DataRepositories ["Capa de Datos y Repositorios"]
        LessonRepo["LessonRepository (API REST + Local Cache)"]
        FingeringRepo["FingeringRepository (Mapeo local de notas a digigramas)"]
        PracticeRepo["PracticeRepository (Idempotencia offline + Sync)"]
        AuthRepo["AuthRepository (FlutterSecureStorage JWT)"]
        DioClient["DioApiClient (Interceptors, Retry Policy)"]
        LocalDb["Drift / SQLite Database (Almacenamiento offline de lecciones y sesiones)"]
    end

    UIViews --> BlocsLayer
    BlocsLayer --> DomainEngines
    BlocsLayer --> DataRepositories
    DataRepositories --> DioClient
    DataRepositories --> LocalDb
    PracticeScreen --> QuenaFingeringWidget
    PracticeScreen --> ZamponaFingeringWidget
    PracticeScreen --> TarkaFingeringWidget
```

> La especialización refleja la organología andina distinta por instrumento (orificios vs tubos, embocadura, digitación).

---

## 4. Nivel 4: Diagrama Entidad-Relación y Clases Clave (Code & Data Level)

### 4.1 Diagrama Entidad-Relación Completo de la Base de Datos (PostgreSQL 16)

El siguiente diagrama formaliza la **topología relacional completa de la base de datos**, garantizando que **todas las tablas estén interconectadas** mediante claves foráneas íntegras y reglas de cascada (`ON DELETE CASCADE` o `SET NULL`):

```mermaid
erDiagram
    USERS ||--o{ REFRESH_TOKENS : "posee"
    USERS ||--o| USER_XP : "acumula"
    USERS ||--o{ USER_ACHIEVEMENTS : "desbloquea"
    USERS ||--o{ PRACTICE_SESSIONS : "realiza"
    USERS ||--o{ POSTS : "publica"
    USERS ||--o{ COMMENTS : "escribe"
    USERS ||--o{ LIKES : "reacciona"
    USERS ||--o{ FOLLOWS : "sigue_a (following)"
    USERS ||--o{ FOLLOWS : "es_seguido (follower)"
    USERS ||--o{ REPORTS : "reporta"
    USERS ||--o{ NOTIFICATIONS : "recibe"
    USERS ||--o{ NOTIFICATION_TOKENS : "registra"
    USERS ||--o{ ADMIN_AUDIT_LOGS : "audita"
    USERS ||--o{ AI_USAGE_LOGS : "consume"
    USERS ||--o{ LESSONS : "crea (docente)"

    CATEGORIES ||--o{ LESSONS : "agrupa"
    LESSONS ||--o{ NOTE_SEQUENCES : "compone"
    LESSONS ||--o{ PRACTICE_SESSIONS : "es_practicada"

    FINGERINGS ||--o{ NOTE_SEQUENCES : "asocia_digitacion"

    PRACTICE_SESSIONS ||--o| POSTS : "comparte_como_post"

    POSTS ||--o{ COMMENTS : "recibe"
    POSTS ||--o{ LIKES : "recibe"
    POSTS ||--o{ POST_HASHTAGS : "etiqueta"
    POSTS ||--o{ SAVED_POSTS : "es_guardado"
    POSTS ||--o{ REPORTS : "es_reportado"

    COMMENTS ||--o{ COMMENTS : "responde_a (parent)"
    COMMENTS ||--o{ COMMENT_LIKES : "recibe"

    HASHTAGS ||--o{ POST_HASHTAGS : "contiene"

    ACHIEVEMENTS ||--o{ USER_ACHIEVEMENTS : "otorga"

    USERS {
        uuid id PK
        string email UK
        string username UK
        string full_name
        string hashed_password
        string avatar_url
        string bio
        string preferred_instruments
        float breath_sensitivity_rms
        string role
        boolean is_active
        boolean is_admin
        boolean is_banned
        int total_xp
        int current_streak
        int streak_freezes
        datetime created_at
    }

    REFRESH_TOKENS {
        uuid id PK
        uuid user_id FK
        string token UK
        datetime expires_at
        boolean is_revoked
        datetime created_at
    }

    USER_XP {
        uuid id PK
        uuid user_id FK,UK
        int total_xp
        int weekly_xp
        int level
        int current_streak
        int longest_streak
        int streak_freezes
        int total_practice_sessions
        float total_practice_minutes
        float average_score
        date last_practice_date
        datetime updated_at
    }

    CATEGORIES {
        uuid id PK
        string name UK
        string description
        string icon
        int order
        boolean is_active
        datetime created_at
    }

    LESSONS {
        uuid id PK
        uuid category_id FK
        uuid created_by FK
        string title
        string description
        string instrument
        string difficulty
        int tempo_bpm
        string time_signature
        string key_signature
        string audio_preview_url
        boolean is_active
        boolean is_premium
        int total_plays
        float average_score
        datetime created_at
    }

    NOTE_SEQUENCES {
        uuid id PK
        uuid lesson_id FK
        uuid fingering_id FK
        int position
        string note
        float duration
        boolean is_rest
        boolean breath_mark
        int velocity
        jsonb fingering_data
    }

    FINGERINGS {
        uuid id PK
        string instrument
        string note
        int octave
        jsonb holes_covered
        boolean is_alternate
        string description
        string audio_sample_url
        datetime created_at
    }

    PRACTICE_SESSIONS {
        uuid id PK
        uuid user_id FK
        uuid lesson_id FK
        string client_id UK
        string instrument
        float score
        int correct_notes
        int total_notes
        int wrong_notes
        int missed_notes
        float pitch_accuracy_percentage
        float posture_score_percentage
        float rhythm_accuracy_percentage
        float average_tempo
        float total_time_seconds
        jsonb errors_detail
        jsonb telemetry_data
        string ai_feedback
        boolean completed
        datetime created_at
    }

    POSTS {
        uuid id PK
        uuid user_id FK
        uuid practice_session_id FK,UK
        string content
        string post_type
        string media_url
        int likes_count
        int comments_count
        boolean is_active
        boolean is_reported
        datetime created_at
    }

    COMMENTS {
        uuid id PK
        uuid post_id FK
        uuid user_id FK
        uuid parent_comment_id FK
        string content
        int likes_count
        boolean is_active
        datetime created_at
    }

    LIKES {
        uuid id PK
        uuid post_id FK
        uuid user_id FK
        datetime created_at
    }

    FOLLOWS {
        uuid id PK
        uuid follower_id FK
        uuid following_id FK
        datetime created_at
    }

    REPORTS {
        uuid id PK
        uuid reporter_id FK
        uuid post_id FK
        string reason
        string status
        string action_taken
        datetime created_at
    }

    ACHIEVEMENTS {
        uuid id PK
        string code UK
        string name
        string description
        string icon
        string category
        int xp_reward
        string requirement_type
        int requirement_value
        string rarity
        datetime created_at
    }

    USER_ACHIEVEMENTS {
        uuid id PK
        uuid user_id FK
        uuid achievement_id FK
        datetime unlocked_at
    }

    HASHTAGS {
        uuid id PK
        string tag UK
        int usage_count
        datetime created_at
    }

    POST_HASHTAGS {
        uuid id PK
        uuid post_id FK
        uuid hashtag_id FK
    }

    NOTIFICATIONS {
        uuid id PK
        uuid user_id FK
        string title
        string body
        string notification_type
        boolean is_read
        datetime created_at
    }

    NOTIFICATION_TOKENS {
        uuid id PK
        uuid user_id FK
        string fcm_token UK
        string device_type
        datetime updated_at
    }

    ADMIN_AUDIT_LOGS {
        uuid id PK
        uuid admin_id FK
        string action
        string target_entity
        string target_id
        jsonb details
        datetime created_at
    }

    AI_USAGE_LOGS {
        uuid id PK
        uuid user_id FK
        string model_name
        int prompt_tokens
        int completion_tokens
        float latency_ms
        datetime created_at
    }
```

---

### 4.2 Diagrama de Clases del Dominio de Software

```mermaid
classDiagram
    class InstrumentType {
        <<enumeration>>
        QUENA
        ZAMPONA
        TARKA
    }

    class DifficultyLevel {
        <<enumeration>>
        PRINCIPIANTE
        INTERMEDIO
        AVANZADO
    }

    class User {
        +UUID id
        +string email
        +string username
        +string full_name
        +string preferred_instruments
        +float breath_sensitivity_rms
        +string role
        +int total_xp
        +int current_streak
        +int streak_freezes
        +bool is_active
        +update_breath_profile(float rms) void
        +switch_active_instrument(InstrumentType inst) void
    }

    class Lesson {
        +UUID id
        +UUID category_id
        +string title
        +InstrumentType instrument
        +DifficultyLevel difficulty
        +int tempo_bpm
        +string time_signature
        +string key_signature
        +int total_plays
        +float average_score
        +List~NoteSequence~ notes
        +validate_notes_sequence() bool
    }

    class NoteSequence {
        +UUID id
        +UUID lesson_id
        +UUID fingering_id
        +int position
        +string note
        +float duration
        +bool is_rest
        +bool breath_mark
        +int velocity
        +Map fingering_data
    }

    class Fingering {
        +UUID id
        +InstrumentType instrument
        +string note
        +int octave
        +Map holes_covered
        +bool is_alternate
        +string audio_sample_url
        +validate_unique_primary() bool
    }

    class PracticeSession {
        +UUID id
        +UUID user_id
        +UUID lesson_id
        +string client_id
        +InstrumentType instrument
        +float score
        +float pitch_accuracy_percentage
        +float posture_score_percentage
        +float rhythm_accuracy_percentage
        +Map telemetry_data
        +string ai_feedback
        +bool completed
        +calculate_final_xp() int
    }

    class UserXP {
        +UUID id
        +UUID user_id
        +int total_xp
        +int weekly_xp
        +int level
        +int current_streak
        +int streak_freezes
        +add_xp(int xp) void
        +consume_freeze_if_needed() bool
    }

    class Post {
        +UUID id
        +UUID user_id
        +UUID practice_session_id
        +string content
        +string post_type
        +int likes_count
        +int comments_count
        +bool is_active
    }

    User "1" --o "*" PracticeSession : ejecuta
    Lesson "1" --* "*" NoteSequence : contiene
    Lesson "1" --o "*" PracticeSession : evalúa
    Fingering "1" --o "*" NoteSequence : mapea
    User "1" --|{ "1" UserXP : posee
    PracticeSession "0..1" --o "1" Post : genera
    User "1" --o "*" Post : publica
```

---

## 5. Matriz de Continuidad de Nomenclatura y Contratos Unificados

Para cumplir con la directriz de **tolerancia cero a discrepancias de nombres**, la siguiente tabla define el estándar canónico en todas las capas tecnológicas:

| Concepto de Negocio             | Campo en Base de Datos (SQL) | Schema Backend (Pydantic)                     | DTO Web Admin (TypeScript)                    | Modelo Mobile (Dart)                                |
| :------------------------------ | :--------------------------- | :-------------------------------------------- | :-------------------------------------------- | :-------------------------------------------------- |
| **Identificador Lección**       | `id` (UUID)                  | `id: UUID`                                    | `id: string`                                  | `String id`                                         |
| **Categoría Asignada**          | `category_id` (UUID)         | `category_id: UUID`                           | `category_id: string`                         | `String categoryId` (con `@JsonKey('category_id')`) |
| **Tempo en BPM**                | `tempo_bpm` (INTEGER)        | `tempo_bpm: int`                              | `tempo_bpm: number`                           | `int tempoBpm`                                      |
| **Instrumento Andino**          | `instrument` (VARCHAR)       | `instrument: str` (`quena`/`zampona`/`tarka`) | `instrument: 'quena' \| 'zampona' \| 'tarka'` | `InstrumentType instrument`                         |
| **Digitación Asociada**         | `fingering_id` (UUID)        | `fingering_id: UUID \| None`                  | `fingering_id: string \| null`                | `String? fingeringId`                               |
| **Orificios / Tubos Cubiertos** | `holes_covered` (JSONB)      | `holes_covered: dict`                         | `holes_covered: Record<string, boolean>`      | `Map<String, dynamic> holesCovered`                 |
| **Marca de Respiración**        | `breath_mark` (BOOLEAN)      | `breath_mark: bool`                           | `breath_mark: boolean`                        | `bool breathMark`                                   |
| **Desviación en Cents**         | `cents_deviation` (JSONB)    | `cents_deviation: float`                      | `cents_deviation: number`                     | `double centsDeviation`                             |
| **Sensibilidad de Soplo**       | `breath_sensitivity_rms`     | `breath_sensitivity_rms: float`               | `breath_sensitivity_rms: number`              | `double breathSensitivityRms`                       |
| **Puntuación de Postura**       | `posture_score_percentage`   | `posture_score_percentage: float`             | `posture_score_percentage: number`            | `double postureScorePercentage`                     |
| **Precisión de Tono**           | `pitch_accuracy_percentage`  | `pitch_accuracy_percentage: float`            | `pitch_accuracy_percentage: number`           | `double pitchAccuracyPercentage`                    |
| **Secuencia de Notas**          | `note_sequences` (Tabla)     | `notes: list[NoteSequenceResponse]`           | `notes: NoteSequence[]`                       | `List<NoteSequenceModel> notes`                     |
| **Idempotencia Cliente**        | `client_id` (UUID único)     | `client_id: UUID \| None`                     | N/A                                           | `String clientId`                                   |
| **Racha de Días**               | `current_streak` (INTEGER)   | `current_streak: int`                         | `current_streak: number`                      | `int currentStreak`                                 |
| **Congeladores Racha**          | `streak_freezes` (INTEGER)   | `streak_freezes: int`                         | `streak_freezes: number`                      | `int streakFreezes`                                 |

### Regla Canónica de Métodos y Endpoints por Capa

- **Catálogo de Lecciones**:
  - Endpoint: `GET /api/v1/lessons?instrument={inst}&difficulty={diff}`
  - Backend Service: `LessonService.get_lessons(db, instrument, difficulty, skip, limit)`
  - Web Admin Service: `LessonAdminService.getLessons(instrument?, difficulty?)`
  - Mobile Repository: `LessonRepository.getLessons({required InstrumentType instrument, String? difficulty})`

- **Catálogo Oficial de Digitaciones**:
  - Endpoint: `GET /api/v1/fingerings?instrument={inst}` / `POST /api/v1/fingerings`
  - Backend Service: `FingeringService.get_fingerings_by_instrument(db, instrument)` / `create_fingering(db, data)`
  - Web Admin Service: `FingeringAdminService.getFingerings(instrument)` / `createFingering(data)`
  - Mobile Repository: `FingeringRepository.getFingeringForNote(instrument, note)`

- **Sesión de Práctica e Idempotencia**:
  - Endpoint: `POST /api/v1/practice/session`
  - Backend Service: `PracticeService.submit_practice_session(db, user_id, session_data)`
  - Mobile Repository: `PracticeRepository.submitPracticeSession(PracticeSessionModel session)`

- **Perfil de Usuario y Soplo Suave**:
  - Endpoint: `GET /api/v1/users/me` / `PUT /api/v1/users/me`
  - Backend Service: `UserService.update_profile(db, user_id, user_update)`
  - Mobile Repository: `UserRepository.updateProfile(UserModel user)`

- **Reportes Analíticos Docentes**:
  - Endpoint: `GET /api/v1/analytics/instruments?instrument={inst}&date_range={range}`
  - Backend Service: `AnalyticsService.get_instrument_metrics(db, instrument, date_range)`
  - Web Admin Service: `AnalyticsAdminService.getInstrumentMetrics(instrument, dateRange)`

---

## 6. Estrategia de Manejo de Errores y Fallos en la Arquitectura

La arquitectura implementa patrones explícitos de resiliencia y manejo de excepciones en cada componente:

```mermaid
flowchart TD
    ErrorOrigin["Origen del Fallo"] --> CatA["A. Falla de Entrada / Validación"]
    ErrorOrigin --> CatB["B. Falla de Sensores / Audio / Cámara"]
    ErrorOrigin --> CatC["C. Falla de Red / Modo Offline"]
    ErrorOrigin --> CatD["D. Falla de Servidor / Transacción"]

    CatA --> ResA["HTTP 422 Unprocessable Entity<br/>Error descriptivo Pydantic / Angular Form validation"]
    CatB --> ResB["Degradación Agraciada On-Device<br/>Reintento de buffer, aviso ergonómico sin interrumpir sonido"]
    CatC --> ResC["Almacenamiento Local Drift SQLite<br/>Queue offline con reintento exponencial idempotente"]
    CatD --> ResD["Rollback de Transacción SQLAlchemy<br/>Log estructurado en AuditLog + HTTP 500 canónico"]
```

1. **Integridad Referencial y Cascadas en Base de Datos**:
   - Eliminación de lecciones (`lessons`) elimina en cascada sus secuencias de notas (`note_sequences`) e intentos de práctica (`practice_sessions`).
   - Eliminación de usuarios (`users`) elimina sus publicaciones (`posts`), comentarios (`comments`), likes, tokens y registros de XP en cascada.
   - Eliminación de publicaciones (`posts`) preserva la sesión de práctica asociada seteando `practice_session_id = NULL`.
2. **Idempotencia de Sesiones y Sync Offline**:
   - El cliente móvil genera un `client_id` (UUIDv4) antes de iniciar la práctica.
   - Si la red falla y el cliente reintenta enviar la sesión múltiples veces, la restricción `UNIQUE` sobre `client_id` en PostgreSQL previene duplicación de registros de práctica y duplicación de XP.
3. **Resiliencia de Inferencia On-Device**:
   - Si la señal del micrófono tiene energía RMS por debajo del umbral de "Soplo Suave", el motor YIN ignora el bloque PCM sin emitir notas falsas.
   - Si la cámara pierde visibilidad del alumno (confianza $<0.5$), el pipeline de MediaPipe suspende la evaluación postural sin interrumpir la evaluación tonal de audio.

---

## Ciclo de Práctica Interactiva (Secuencia)

```mermaid
sequenceDiagram
    participant E as Estudiante
    participant App as AppMobile
    participant YIN as YINEngine
    participant MP as MediaPipe
    participant ML as MLService
    participant API as BackendAPI
    participant DB as DB

    E->>App: inicia práctica
    App->>YIN: abre stream de audio
    YIN-->>App: pitch (Hz) + cents
    App->>MP: frame de cámara
    MP-->>App: landmarks pose/manos
    App->>App: sintetiza telemetría a prompt
    App->>ML: POST /feedback (prompt)
    ML-->>App: feedback pedagógico
    App->>API: POST /practice/session (XP, racha)
    API->>DB: persiste sesión
    API-->>App: ACK + XP otorgado
```

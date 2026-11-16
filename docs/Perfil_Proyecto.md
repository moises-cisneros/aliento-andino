# 1. Perfil

## 1.1 Introducción

En la actualidad, el uso de tecnologías digitales ha transformado significativamente los procesos de aprendizaje, permitiendo el acceso a la educación desde cualquier lugar y en cualquier momento. En el ámbito musical, las plataformas digitales han facilitado la enseñanza de instrumentos y teoría musical mediante recursos interactivos, contenidos multimedia y metodologías innovadoras. Sin embargo, los instrumentos de viento andinos —como la quena, la zampoña, la tarka y la flauta— han sido históricamente excluidos de estas plataformas digitales, a pesar de representar una rica herencia cultural de los pueblos andinos.

El presente proyecto propone el desarrollo de un **Sistema Inteligente de Aprendizaje de Instrumentos de Viento Andinos basado en Inteligencia Artificial y Gamificación**, orientado al aprendizaje progresivo de quena, zampoña, tarka y flauta mediante una plataforma web y móvil. El sistema permitirá a los usuarios aprender estos instrumentos de manera personalizada, interactiva y culturalmente contextualizada, a través de lecciones estructuradas, ejercicios prácticos y retroalimentación inmediata generada por agentes inteligentes.

La plataforma integrará tecnologías de inteligencia artificial para el **análisis en tiempo real del soplo y la afinación** del usuario, adaptando automáticamente el nivel de dificultad según la capacidad pulmonar y respiratoria de cada estudiante. Un elemento diferenciador clave del sistema es su capacidad de calibrar el rendimiento individual: dado que no todos los usuarios poseen la misma capacidad respiratoria, la IA ajusta las evaluaciones y ejercicios para que incluso quienes soplan con menor fuerza puedan avanzar correctamente en el aprendizaje del aliento andino.

Asimismo, mediante visión computacional, el sistema evaluará la postura, el agarre del instrumento y la embocadura del estudiante, guiándolo desde el primer contacto físico con el instrumento hasta la ejecución de melodías andinas completas. El uso de elementos de gamificación como puntos, niveles, logros y retos culturales fomentará la motivación y el compromiso del estudiante a lo largo de su proceso de aprendizaje.

De esta manera, el sistema busca democratizar el acceso a la educación de instrumentos de viento andinos, preservando el patrimonio musical de los pueblos andinos y permitiendo que cualquier persona interesada pueda desarrollar estas habilidades sin necesidad de asistir a clases presenciales.

---

## 1.2 Antecedentes

El aprendizaje de instrumentos de viento andinos ha estado históricamente ligado a la transmisión oral y a clases presenciales en comunidades, academias de folklore o con maestros artesanales. Este modelo requiere cercanía geográfica con comunidades andinas, acceso a maestros especializados —cada vez más escasos— y disponibilidad de tiempo, lo que limita significativamente el alcance de esta práctica cultural.

Con el avance de la tecnología, han surgido diversas plataformas digitales orientadas al aprendizaje musical general (como Yousician, Simply Piano o Flowkey). Sin embargo, estas plataformas están diseñadas exclusivamente para instrumentos occidentales como piano, guitarra o batería, y no contemplan las particularidades técnicas y culturales de los instrumentos de viento andinos.

Las soluciones digitales existentes para música andina presentan limitaciones significativas como:

- Ausencia de plataformas especializadas en instrumentos de viento andinos (quena, zampoña, tarka, flauta)
- Falta de análisis inteligente del soplo y la capacidad respiratoria del usuario
- Nula consideración de la embocadura y postura específica de cada instrumento andino
- Carencia de contenido cultural contextualizado (historia, origen, tradiciones)
- Baja motivación del usuario a largo plazo por falta de gamificación
- Sin adaptación al nivel respiratorio individual del estudiante

Por esta razón surge la necesidad de desarrollar una plataforma que combine educación de instrumentos andinos, inteligencia artificial de audio y visión computacional, y gamificación, permitiendo un aprendizaje adaptado tanto al ritmo como a la capacidad pulmonar de cada estudiante.

### 1.2.1 Fundamentación teórica

El desarrollo del sistema se fundamenta en diversas teorías y enfoques educativos y tecnológicos que respaldan su diseño y funcionamiento.

**Aprendizaje basado en gamificación**
La gamificación consiste en la aplicación de elementos propios de los videojuegos en contextos educativos con el objetivo de aumentar la motivación, participación y compromiso de los usuarios. Elementos como niveles, recompensas, logros y retos —adaptados al contexto cultural andino— fomentan el aprendizaje activo y sostenido en el tiempo.

**Aprendizaje autodidacta asistido por tecnología**
Las plataformas digitales permiten que los usuarios aprendan a su propio ritmo mediante recursos interactivos, videos, ejercicios prácticos y evaluaciones automáticas, sin depender de la presencia física de un instructor.

**Aprendizaje progresivo y adaptativo**
El contenido educativo se organiza en niveles (básico, intermedio y avanzado), permitiendo que el estudiante avance gradualmente según su progreso. La clave diferenciadora del sistema es la **adaptación respiratoria**: la IA calibra los parámetros de evaluación según la capacidad pulmonar individual, reconociendo que el aliento suave también es una forma válida de interpretación andina.

**Análisis inteligente del soplo y la afinación**
Mediante el procesamiento de señales de audio (DSP) con algoritmos de detección de pitch (YIN/CREPE) y modelos de clasificación de calidad del soplo, el sistema puede evaluar si el usuario produce correctamente las notas, la intensidad del aliento y la afinación en cents, proporcionando retroalimentación inmediata y personalizada.

**Visión computacional aplicada a la postura musical**
Mediante el uso de MediaPipe y modelos de clasificación entrenados por instrumento, el sistema analiza en tiempo real la postura corporal, el agarre del instrumento y la embocadura del estudiante, ofreciendo correcciones visuales antes de que los errores se conviertan en hábitos.

**Preservación del patrimonio cultural inmaterial**
El aprendizaje de instrumentos andinos no es solo técnico; implica conocer el contexto histórico, cultural y espiritual de cada instrumento. El sistema integra contenido cultural como parte del currículo, promoviendo la identidad y valoración del patrimonio andino.

---

## 1.3 Descripción del problema

Los instrumentos de viento andinos —quena, zampoña, tarka y flauta— representan una parte fundamental del patrimonio musical e identidad cultural de los pueblos andinos de Bolivia, Perú, Ecuador y Chile. Sin embargo, su aprendizaje enfrenta barreras significativas que amenazan la continuidad de esta tradición musical.

Entre los principales problemas identificados se encuentran:

- **Escasez de maestros especializados** en instrumentos de viento andinos fuera de las comunidades originarias.
- **Alto costo y baja disponibilidad** de clases presenciales de quena, zampoña, tarka o flauta andina.
- **Ausencia total de plataformas digitales** especializadas en estos instrumentos con soporte de IA.
- **Falta de adaptación a la capacidad respiratoria** del estudiante: los sistemas actuales no distinguen entre soplo fuerte y suave, penalizando injustamente a quienes tienen menor capacidad pulmonar.
- **Sin guía de postura ni embocadura** digital: los errores físicos en el agarre o la posición de los labios son difíciles de detectar sin un instructor presencial.
- **Pérdida progresiva del patrimonio cultural andino** por falta de medios modernos de transmisión.
- **Métodos tradicionales poco motivadores** para las nuevas generaciones de estudiantes.

Además, las plataformas actuales de aprendizaje musical no contemplan las particularidades técnicas de los instrumentos de viento (control del aliento, embocadura, digitación específica) ni el contexto cultural andino que les da significado.

Por lo tanto, se requiere una solución tecnológica inteligente que permita aprender instrumentos de viento andinos de forma interactiva, adaptativa, culturalmente contextualizada y accesible para cualquier persona, independientemente de su capacidad respiratoria o ubicación geográfica.

---

## 1.4 Objetivos

### 1.4.1 General

Implementar un sistema inteligente de aprendizaje de instrumentos de viento andinos mediante agentes de IA, análisis de soplo en tiempo real y gamificación interactiva, que permita a los usuarios aprender quena, zampoña, tarka y flauta de forma progresiva, adaptada a su capacidad respiratoria individual y culturalmente contextualizada, a través de una plataforma web y móvil.

### 1.4.2 Específicos

- Diseñar una plataforma interactiva que permita el aprendizaje de quena, zampoña, tarka y flauta mediante lecciones estructuradas con contenido técnico y cultural.
- Implementar un sistema de calibración respiratoria que analice la capacidad pulmonar de cada usuario y adapte los criterios de evaluación del soplo de forma individualizada.
- Implementar ejercicios prácticos que permitan al usuario practicar notas, escalas pentatónicas andinas, ritmo y técnicas de aliento específicas de cada instrumento.
- Incorporar un módulo de visión computacional que evalúe en tiempo real la postura, el agarre del instrumento y la embocadura del estudiante, ofreciendo retroalimentación visual inmediata.
- Incorporar elementos de gamificación como puntos, niveles, logros culturales y retos para aumentar la motivación y el compromiso del usuario.
- Implementar un sistema de seguimiento del progreso del estudiante que incluya métricas de soplo, afinación y postura.
- Integrar agentes inteligentes para analizar el desempeño del usuario y ofrecer retroalimentación automática y personalizada.
- Desarrollar perfiles de usuario que almacenen el perfil respiratorio, estadísticas, logros y avance en el aprendizaje.
- Crear una red de estudiantes que compartan el proceso de aprendizaje de instrumentos andinos, fomentando la comunidad cultural.

---

## 1.5 Alcance

El presente sistema consiste en una plataforma digital de aprendizaje de instrumentos de viento andinos con inteligencia artificial, orientada a la enseñanza de quena, zampoña, tarka y flauta andina, mediante análisis inteligente del soplo, visión computacional para la postura, técnicas de gamificación y contenido cultural contextualizado.

El sistema permitirá a los usuarios aprender de forma progresiva a través de lecciones personalizadas según su nivel y capacidad respiratoria, ejercicios prácticos, evaluaciones y retos culturales, además de fomentar la interacción social mediante una comunidad de estudiantes de música andina.

Su implementación facilitará el aprendizaje autónomo, preservará el patrimonio musical andino, mejorará la motivación del usuario y permitirá un seguimiento continuo del progreso, adaptando el contenido tanto a las habilidades técnicas como a la capacidad pulmonar individual del estudiante.

### 1.5.1 Gestión de Usuarios y Acceso

**Objetivo:** Permitir el acceso seguro al sistema y la gestión de perfiles de usuario con información musical y respiratoria.

Funcionalidades incluidas:

- Registro de usuarios con datos básicos
- Inicio y cierre de sesión (con Google OAuth)
- Edición de perfil
- Selección del instrumento principal (quena, zampoña, tarka o flauta)
- Gestión del nivel inicial (principiante, intermedio)
- Almacenamiento del perfil respiratorio calibrado del usuario

### 1.5.2 Gestión de Instrumentos Andinos

**Objetivo:** Permitir al usuario seleccionar y aprender distintos instrumentos de viento andinos con contenido técnico y cultural específico.

Funcionalidades incluidas — Selección de instrumentos disponibles:

- Quena
- Zampoña
- Tarka
- Flauta andina
- Visualización de contenido técnico y cultural específico por instrumento
- Información histórica y cultural de cada instrumento
- Cambio de instrumento (con preservación del progreso por instrumento)

### 1.5.3 Calibración Respiratoria Personalizada

**Objetivo:** Medir y registrar la capacidad pulmonar de cada usuario para adaptar los criterios de evaluación del soplo de forma individualizada.

Funcionalidades incluidas:

- Sesión guiada de calibración al inicio (soplo suave → sostenido → fuerte)
- Registro del perfil respiratorio del usuario (intensidad mínima, media y máxima)
- Ajuste automático de los umbrales de evaluación según el perfil de cada usuario
- Recalibración periódica opcional para registrar mejoras
- Reconocimiento de que el soplo suave también es válido en la interpretación del aliento andino

### 1.5.4 Gestión de Lecciones y Tutoriales Personalizados

**Objetivo:** Proporcionar contenido educativo técnico y cultural adaptado al nivel y al perfil respiratorio del usuario.

Funcionalidades incluidas:

- Lecciones organizadas por niveles:
  - Principiante (postura, agarre, primera nota)
  - Intermedio (escala pentatónica, melodías simples)
- Tutoriales personalizados:
  - Adaptados al progreso y al perfil respiratorio del usuario
  - No genéricos, ajustados a desempeño individual
- Contenido teórico (historia, técnica, digitación) y práctico (ejercicios con micrófono)
- Contenido cultural contextualizado por instrumento
- Acceso progresivo (bloqueo/desbloqueo de lecciones según avance)

### 1.5.5 Análisis de Soplo y Afinación en Tiempo Real

**Objetivo:** Evaluar mediante IA la calidad del soplo, la nota producida y la afinación del usuario durante la práctica.

Funcionalidades incluidas:

- Detección de pitch en tiempo real (algoritmo YIN/CREPE via `librosa` + `aubio`)
- Medición de intensidad del soplo normalizada al perfil respiratorio del usuario (`0.0–1.0`)
- Clasificación de calidad del tono (`limpio`, `con aire`, `soplado`)
- Medición de afinación en cents (desviación respecto a la nota objetivo)
- Visualizador gráfico del soplo en tiempo real (onda, intensidad, precisión)
- Retroalimentación inmediata sobre nota producida vs nota esperada

### 1.5.6 Análisis de Postura y Embocadura (Visión Computacional)

**Objetivo:** Evaluar mediante la cámara del dispositivo la postura corporal, el agarre del instrumento y la embocadura del estudiante.

Funcionalidades incluidas:

- Análisis del agarre del instrumento por instrumento (quena, zampoña, tarka, flauta)
- Evaluación de la posición de las manos (mano superior e inferior)
- Puntuación de la embocadura (calidad de la posición de los labios)
- Retroalimentación visual en pantalla con indicaciones de corrección
- Guía paso a paso: postura → agarre → embocadura → primera nota

### 1.5.7 Ejercicios Interactivos

**Objetivo:** Permitir al usuario practicar lo aprendido mediante actividades dinámicas adaptadas a los instrumentos andinos.

Funcionalidades incluidas:

- Identificación de notas en la digitación del instrumento
- Ejercicios de escala pentatónica andina
- Ejercicios de ritmo y tempo
- Lectura de tablatura andina básica
- Ejercicios de control del aliento (sostenido, staccato, ligado)
- Retroalimentación inmediata (correcto/incorrecto con indicación específica)

### 1.5.8 Evaluaciones

**Objetivo:** Medir el nivel de aprendizaje técnico y cultural del usuario.

Funcionalidades incluidas:

- Evaluaciones por nivel (técnica + conocimiento cultural)
- Pruebas al finalizar cada módulo
- Resultados automáticos con análisis de soplo y afinación
- Retroalimentación detallada del desempeño (notas, soplo, postura)
- Evaluaciones adaptadas al perfil respiratorio del usuario

### 1.5.9 Sistema de Retos y Gamificación Cultural

**Objetivo:** Motivar al usuario mediante dinámicas de juego con enfoque cultural andino.

Funcionalidades incluidas:

- Retos diarios o semanales (ej. "Toca la escala pentatónica de quena 3 veces")
- Sistema de puntos (XP) por precisión de soplo, afinación y postura
- Niveles de progreso (Aprendiz → Intérprete → Maestro Andino)
- Desbloqueo de contenido cultural y melodías tradicionales
- Logros y recompensas con temática andina
- Racha de práctica diaria

### 1.5.10 Seguimiento de Progreso

**Objetivo:** Permitir al usuario visualizar su avance técnico, respiratorio y cultural dentro del sistema.

Funcionalidades incluidas:

- Visualización de nivel actual por instrumento
- Lecciones completadas y desbloqueadas
- Puntaje acumulado y logros obtenidos
- Estadísticas de rendimiento: evolución del soplo, afinación promedio, precisión de postura
- Gráfico de evolución del perfil respiratorio a lo largo del tiempo

### 1.5.11 Comunidad de Estudiantes

**Objetivo:** Fomentar la interacción entre usuarios que comparten el aprendizaje de la música andina.

Funcionalidades incluidas:

- Red de estudiantes por instrumento y nivel
- Sistema de seguidores y actividad compartida
- Publicaciones de progreso y logros en la comunidad
- Redirección a comunidad externa de soporte (WhatsApp o Telegram)
- Rankings de progreso entre estudiantes

### 1.5.12 Inteligencia Artificial y Agentes Inteligentes

**Objetivo:** Mejorar la experiencia de aprendizaje mediante análisis inteligente, recomendaciones personalizadas y un tutor virtual andino.

Funcionalidades incluidas:

- Tutor virtual con IA (Gemini) especializado en instrumentos andinos
- Adaptación de contenido según desempeño técnico y respiratorio
- Recomendación de ejercicios personalizados según perfil del usuario
- Análisis de audio en tiempo real mediante micrófono
- Análisis de postura mediante cámara en tiempo real
- Retroalimentación inteligente y contextualizada culturalmente
- Agente de respuesta a preguntas sobre técnica e historia andina

### 1.5.13 Modo Profesor / Mentor

**Objetivo:** Incorporar un rol intermedio para profesores de música andina que acompañen a un grupo de estudiantes.

Funcionalidades propuestas:

- Panel con la lista de estudiantes asignados y su progreso técnico y respiratorio
- Asignación de lecciones, ejercicios o retos personalizados a un estudiante o grupo
- Comentarios y retroalimentación manual sobre el desempeño de un estudiante
- Reporte agregado de la clase (promedios de afinación, soplo, postura; alumnos en riesgo de abandono)

### 1.5.14 Biblioteca de Melodías Andinas

**Objetivo:** Permitir practicar melodías y canciones tradicionales andinas completas.

Funcionalidades propuestas:

- Catálogo de melodías andinas filtrable por instrumento, nivel y región cultural
- Seguimiento nota-por-nota mientras se interpreta la melodía (usando el motor de análisis de soplo)
- Recomendación de repertorio según el nivel y el instrumento del usuario
- Información cultural sobre cada melodía (origen, festividad, región)

### 1.5.15 Práctica en Tiempo Real con Feedback Visual

**Objetivo:** Proveer una experiencia de práctica en vivo con retroalimentación visual inmediata del soplo y la afinación.

Funcionalidades propuestas:

- Visualización en tiempo real de la nota producida, intensidad del soplo y afinación
- Indicadores visuales inmediatos (semáforo de precisión) durante la ejecución
- Comparación visual entre la nota esperada y la producida
- Grabación opcional de la sesión para revisión posterior

### 1.5.16 Modo Offline para la Versión Móvil

**Objetivo:** Permitir práctica sin conexión a internet, esencial para zonas rurales o con conectividad limitada donde se practican instrumentos andinos.

Funcionalidades propuestas:

- Descarga de lecciones y ejercicios para uso sin conexión
- Análisis de soplo básico de forma local (on-device con TFLite)
- Sincronización automática del progreso al recuperar conexión

### 1.5.17 Notificaciones Push y Recordatorios de Racha

**Objetivo:** Aumentar la retención diaria mediante recordatorios nativos.

Funcionalidades propuestas:

- Notificaciones push en mobile para retos diarios y racha en riesgo
- Recordatorios configurables por el usuario (horario preferido de práctica)
- Notificaciones de logros culturales desbloqueados

### 1.5.18 Accesibilidad e Internacionalización

**Objetivo:** Ampliar el alcance de usuarios que pueden usar la plataforma, incluyendo comunidades andinas.

Funcionalidades propuestas:

- Soporte multilenguaje (español/inglés/quechua básico)
- Ajustes de accesibilidad (tamaño de fuente, alto contraste, subtítulos en contenido con audio)
- Adaptación a diferentes capacidades respiratorias (inclusividad por perfil pulmonar)

### 1.5.19 Práctica Social en Tiempo Real

**Objetivo:** Sumar un componente competitivo/colaborativo en vivo, diferenciador frente a apps de práctica individual.

Funcionalidades propuestas:

- Modo "dueto andino": dos usuarios interpretan la misma melodía en tiempo real
- Ligas o temporadas mensuales en el ranking por instrumento y nivel
- Retos de comunidad: toda la comunidad practica una melodía andina en la semana

---

## 1.6 Elementos del Sistema Basado en Computadoras

### 1.6.1 Hardware

#### 1.6.1.1 Servidor

El sistema se alojará en una infraestructura basada en entornos cloud (Google Cloud Platform) que permitirá el crecimiento horizontal para soportar múltiples usuarios concurrentes y sesiones simultáneas de análisis de audio sin que se vea afectado el rendimiento. Los servidores deben tener la capacidad de procesamiento necesaria para ejecutar modelos de inteligencia artificial (agentes Gemini), algoritmos de procesamiento de señales de audio (DSP) para análisis de soplo y modelos de visión computacional (MediaPipe) para evaluación de postura. La infraestructura se despliega mediante **Docker Compose en una VM de GCP**, con **Nginx** como proxy inverso y **PostgreSQL** como base de datos. Adicionalmente, se integra con **Google Cloud Storage** o Firebase Storage para gestionar recursos educativos, grabaciones de práctica e imágenes de perfil.

#### 1.6.1.2 Cliente

Para interactuar con la plataforma, los usuarios finales requerirán dispositivos móviles (Android/iOS) con la app Flutter instalada, o computadoras con acceso al panel web Angular. Los componentes de hardware externos más indispensables para el dispositivo del cliente son:

- **Micrófono funcional**: fundamental para capturar las señales de audio del soplo en tiempo real y permitir que la IA analice la nota producida, la intensidad del aliento, la afinación y la calidad del tono.
- **Cámara frontal**: necesaria para el módulo de visión computacional que evalúa la postura, el agarre del instrumento y la embocadura del estudiante.
- **El instrumento físico**: quena, zampoña, tarka o flauta andina, que el usuario debe poseer para practicar con el sistema.

#### 1.6.1.3 Medios de Comunicación

La comunicación y transmisión de datos del sistema exigirá una conexión a internet estable, ya sea mediante red WiFi o datos móviles, capaz de soportar la comunicación bidireccional de baja latencia requerida para el análisis de audio en tiempo real. El sistema utilizará **WebSockets** o comunicación en tiempo real para mantener el flujo constante de información entre la captura de audio/video del cliente y la respuesta del servidor. Toda la comunicación por internet se realizará de forma cifrada mediante el protocolo seguro **HTTPS**, con certificados gestionados por Certbot/Let's Encrypt. Para zonas con conectividad limitada, el modo offline permitirá análisis local básico en el dispositivo móvil mediante modelos TFLite.

#### 1.6.1.4 Otros Dispositivos

A nivel del usuario, el hardware externo principal son los instrumentos musicales físicos de viento andinos: **quena, zampoña, tarka y flauta andina**. A nivel interno y de gestión del proyecto, la infraestructura física requerida para el equipo de desarrollo consta de **5 computadoras portátiles** para la construcción del software. También se consideran periféricos de entrada habituales como teclado y ratón, así como pantallas táctiles en el caso de dispositivos móviles para la interacción con la app Flutter.

import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Política de privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Política de Privacidad',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Última actualización: 6 de abril de 2026',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _section(
            cs,
            '1. Información que Recopilamos',
            'Recopilamos la siguiente información cuando utilizas PianoVision AI:\n\n'
                '• Información de registro: nombre, nombre de usuario, correo electrónico y contraseña.\n'
                '• Datos de perfil: foto de avatar y biografía (opcional).\n'
                '• Datos de uso: progreso en lecciones, puntuaciones, logros y estadísticas de práctica.\n'
                '• Contenido social: publicaciones, comentarios e interacciones dentro de la plataforma.\n'
                '• Información del dispositivo: tipo de dispositivo y sistema operativo para mejorar la compatibilidad.',
          ),
          _section(
            cs,
            '2. Cómo Utilizamos tu Información',
            'Utilizamos la información recopilada para:\n\n'
                '• Proporcionar y mantener el servicio de la Aplicación.\n'
                '• Personalizar tu experiencia de aprendizaje.\n'
                '• Calcular rankings, niveles y logros.\n'
                '• Permitir la interacción social entre usuarios.\n'
                '• Mejorar y optimizar la Aplicación.\n'
                '• Enviar notificaciones relacionadas con tu progreso (si lo autorizas).',
          ),
          _section(
            cs,
            '3. Almacenamiento y Seguridad',
            'Tu información se almacena en servidores seguros. Implementamos medidas de seguridad '
                'técnicas y organizativas para proteger tus datos personales contra acceso no autorizado, '
                'pérdida o alteración. Las contraseñas se almacenan de forma cifrada y los tokens de '
                'autenticación tienen caducidad limitada.',
          ),
          _section(
            cs,
            '4. Compartir Información',
            'No vendemos ni compartimos tu información personal con terceros, excepto:\n\n'
                '• Información de perfil público (nombre de usuario, avatar) visible para otros usuarios.\n'
                '• Publicaciones y comentarios visibles en el feed social.\n'
                '• Rankings públicos que muestran tu posición y puntuación.\n'
                '• Cuando sea requerido por ley o para proteger nuestros derechos.',
          ),
          _section(
            cs,
            '5. Autenticación con Google',
            'Si inicias sesión con Google, recibimos tu nombre y correo electrónico de tu cuenta '
                'de Google. No accedemos a otros datos de tu cuenta de Google. Puedes desvincular '
                'tu cuenta de Google en cualquier momento.',
          ),
          _section(
            cs,
            '6. Tus Derechos',
            'Tienes derecho a:\n\n'
                '• Acceder a tus datos personales desde tu perfil.\n'
                '• Corregir información inexacta en la sección de edición de perfil.\n'
                '• Solicitar la eliminación de tu cuenta y datos asociados.\n'
                '• Retirar tu consentimiento para el procesamiento de datos en cualquier momento.',
          ),
          _section(
            cs,
            '7. Retención de Datos',
            'Mantenemos tu información mientras tu cuenta esté activa. '
                'Si solicitas la eliminación de tu cuenta, eliminaremos tus datos personales '
                'en un plazo razonable, excepto cuando la ley requiera su conservación.',
          ),
          _section(
            cs,
            '8. Cookies y Tecnologías Similares',
            'La Aplicación utiliza tokens de sesión para mantener tu autenticación. '
                'No utilizamos cookies de seguimiento ni tecnologías de rastreo publicitario.',
          ),
          _section(
            cs,
            '9. Menores de Edad',
            'La Aplicación no está dirigida a menores de 13 años. '
                'No recopilamos intencionalmente información de menores de 13 años. '
                'Si descubrimos que hemos recopilado datos de un menor, los eliminaremos.',
          ),
          _section(
            cs,
            '10. Cambios en esta Política',
            'Podemos actualizar esta Política de Privacidad periódicamente. '
                'Te notificaremos de cambios significativos a través de la Aplicación. '
                'Te recomendamos revisar esta política regularmente.',
          ),
          _section(
            cs,
            '11. Contacto',
            'Si tienes preguntas sobre esta Política de Privacidad o el tratamiento de tus datos, '
                'puedes contactarnos a través de la sección de soporte en la Aplicación.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(ColorScheme cs, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

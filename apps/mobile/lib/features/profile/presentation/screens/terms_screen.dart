import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Términos y condiciones')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Términos y Condiciones de Uso',
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
            '1. Aceptación de los Términos',
            'Al descargar, instalar o utilizar Aliento Andino ("la Aplicación"), '
                'aceptas cumplir y estar sujeto a estos Términos y Condiciones. '
                'Si no estás de acuerdo con alguno de estos términos, no debes utilizar la Aplicación.',
          ),
          _section(
            cs,
            '2. Descripción del Servicio',
            'Aliento Andino es una plataforma educativa para instrumentos andinos (Quena, Zampoña y Tarka) que ofrece lecciones interactivas, '
                'seguimiento de progreso, sistema de logros y funciones sociales. '
                'La Aplicación está diseñada para ayudar a los usuarios a aprender y practicar instrumentos de viento andinos '
                'de manera autodidacta.',
          ),
          _section(
            cs,
            '3. Registro y Cuenta',
            'Para utilizar la Aplicación, debes crear una cuenta proporcionando información '
                'veraz y actualizada. Eres responsable de mantener la confidencialidad de tu '
                'contraseña y de todas las actividades que ocurran bajo tu cuenta. '
                'Debes notificar inmediatamente cualquier uso no autorizado de tu cuenta.',
          ),
          _section(
            cs,
            '4. Uso Aceptable',
            'Te comprometes a utilizar la Aplicación únicamente con fines legales y de acuerdo '
                'con estos Términos. No debes:\n\n'
                '• Publicar contenido ofensivo, difamatorio o inapropiado.\n'
                '• Intentar acceder sin autorización a sistemas o datos de otros usuarios.\n'
                '• Utilizar la Aplicación para fines comerciales sin autorización.\n'
                '• Interferir con el funcionamiento normal de la Aplicación.',
          ),
          _section(
            cs,
            '5. Contenido del Usuario',
            'Al publicar contenido en la Aplicación (publicaciones, comentarios, etc.), '
                'otorgas a Aliento Andino una licencia no exclusiva para mostrar dicho contenido '
                'dentro de la plataforma. Mantienes los derechos de autor de tu contenido original. '
                'Nos reservamos el derecho de eliminar contenido que viole estos Términos.',
          ),
          _section(
            cs,
            '6. Propiedad Intelectual',
            'Todo el contenido educativo, diseños, logotipos y software de la Aplicación son '
                'propiedad de Aliento Andino y están protegidos por las leyes de propiedad intelectual. '
                'No se permite la reproducción o distribución sin autorización expresa.',
          ),
          _section(
            cs,
            '7. Limitación de Responsabilidad',
            'Aliento Andino se proporciona "tal cual" sin garantías de ningún tipo. '
                'No garantizamos que la Aplicación estará disponible de manera ininterrumpida '
                'o libre de errores. No somos responsables de daños indirectos derivados del uso '
                'de la Aplicación.',
          ),
          _section(
            cs,
            '8. Modificaciones',
            'Nos reservamos el derecho de modificar estos Términos en cualquier momento. '
                'Las modificaciones serán efectivas al publicarse en la Aplicación. '
                'El uso continuado de la Aplicación después de los cambios constituye la aceptación '
                'de los nuevos Términos.',
          ),
          _section(
            cs,
            '9. Terminación',
            'Podemos suspender o cancelar tu cuenta si incumples estos Términos. '
                'Puedes eliminar tu cuenta en cualquier momento desde la configuración de la Aplicación.',
          ),
          _section(
            cs,
            '10. Contacto',
            'Si tienes preguntas sobre estos Términos, puedes contactarnos a través de '
                'la sección de soporte en la Aplicación.',
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

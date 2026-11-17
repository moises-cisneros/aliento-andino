import 'package:flutter/material.dart';

import 'profile_edit_screen.dart';

export 'profile_edit_screen.dart';

/// Pantalla para editar el perfil del usuario (alias hacia [ProfileEditScreen]).
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileEditScreen();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../data/repositories/profile_repository.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/avatar_picker.dart';

/// Pantalla para editar el perfil del usuario.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  String? _avatarUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _initFields(ProfileLoaded state) {
    if (_fullNameController.text.isEmpty) {
      _fullNameController.text = state.user.fullName;
      _usernameController.text = state.user.username;
      _bioController.text = state.user.bio ?? '';
      _avatarUrl = state.user.avatarUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          ProfileBloc(profileRepository: ctx.read<ProfileRepository>())
            ..add(const ProfileLoadRequested()),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            // Actualizar AuthBloc también
            context.read<AuthBloc>().add(
              AuthProfileUpdateRequested(
                fullName: state.updatedUser.fullName,
                username: state.updatedUser.username,
                bio: state.updatedUser.bio,
                avatarUrl: state.updatedUser.avatarUrl,
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil actualizado'),
                backgroundColor: AppTheme.success,
              ),
            );
            context.pop();
          }
          if (state is ProfileError) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          if (state is ProfileLoaded) {
            _initFields(state);
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Editar perfil'),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => _save(context),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Text(
                          'Guardar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
            body: state is ProfileLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Avatar
                          AvatarPicker(
                            currentUrl: _avatarUrl,
                            fullName: _fullNameController.text,
                            onUrlChanged: (url) {
                              setState(
                                () => _avatarUrl = url.isEmpty ? null : url,
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          // Nombre completo
                          TextFormField(
                            controller: _fullNameController,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: _inputDecoration('Nombre completo'),
                            validator: (v) {
                              if (v == null || v.trim().length < 2) {
                                return 'Mínimo 2 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Username
                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: _inputDecoration('Nombre de usuario'),
                            validator: (v) {
                              if (v == null || v.trim().length < 3) {
                                return 'Mínimo 3 caracteres';
                              }
                              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                                return 'Solo minúsculas, números y guion bajo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Bio
                          TextFormField(
                            controller: _bioController,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: _inputDecoration('Bio').copyWith(
                              counterStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            maxLines: 3,
                            maxLength: 150,
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  void _save(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    context.read<ProfileBloc>().add(
      ProfileUpdateRequested(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _avatarUrl,
      ),
    );
  }
}

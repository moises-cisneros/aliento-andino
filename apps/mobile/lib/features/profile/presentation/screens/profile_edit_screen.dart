import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/profile_repository.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/breath_profile_card.dart';

/// [SUB-19-A] Pantalla completa para edición de datos de perfil, preferencias
/// de instrumentos andinos (Quena, Zampoña, Tarka) y estado de calibración de soplo.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  String? _avatarUrl;
  final Set<String> _selectedInstruments = {};
  double _rmsThreshold = 0.0500;
  DateTime _lastCalibrated = DateTime.now();
  bool _isSaving = false;
  bool _initialized = false;

  static const List<Map<String, String>> _andeanInstruments = [
    {
      'id': 'quena',
      'name': 'Quena',
      'desc': 'Flauta andina de bisel y 6 orificios',
    },
    {'id': 'zampona', 'name': 'Zampoña', 'desc': 'Siku bipolar (Ira y Arka)'},
    {
      'id': 'tarka',
      'name': 'Tarka',
      'desc': 'Flauta ortoédrica de madera tallada',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _initFromUser(authState.user);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _initFromUser(dynamic user) {
    if (_initialized) return;
    _initialized = true;
    _fullNameController.text = user.fullName as String;
    _usernameController.text = user.username as String;
    _bioController.text = (user.bio as String?) ?? '';
    _avatarUrl = user.avatarUrl as String?;
    final instruments =
        (user.preferredInstruments as List<dynamic>?)?.cast<String>() ?? [];
    if (instruments.isNotEmpty) {
      _selectedInstruments.clear();
      _selectedInstruments.addAll(instruments);
    } else {
      _selectedInstruments.add('quena');
    }
    if (user.breathSensitivityRms != null) {
      _rmsThreshold = (user.breathSensitivityRms as num).toDouble();
    }
    if (user.updatedAt != null) {
      final parsed = DateTime.tryParse(user.updatedAt as String);
      if (parsed != null) _lastCalibrated = parsed;
    }
  }

  void _initFields(ProfileLoaded state) {
    _initFromUser(state.user);
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
                content: Text('Perfil y preferencias actualizados'),
                backgroundColor: AppTheme.success,
              ),
            );
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
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
          final colorScheme = Theme.of(context).colorScheme;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Editar perfil'),
              actions: [
                TextButton(
                  key: const Key('save_profile_button'),
                  onPressed: _isSaving ? null : () => _save(context),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text(
                          'Guardar',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
            body: state is ProfileLoading && !_initialized
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Selector de Avatar
                          Center(
                            child: AvatarPicker(
                              currentUrl: _avatarUrl,
                              fullName: _fullNameController.text,
                              onUrlChanged: (url) {
                                setState(
                                  () => _avatarUrl = url.isEmpty ? null : url,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 2. Sección: Datos Personales
                          Text(
                            'Información Personal',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('full_name_field'),
                            controller: _fullNameController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: _inputDecoration('Nombre completo'),
                            validator: (v) {
                              if (v == null || v.trim().length < 2) {
                                return 'Mínimo 2 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('username_field'),
                            controller: _usernameController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: _inputDecoration(
                              'Apodo o nombre de usuario',
                            ),
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
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('bio_field'),
                            controller: _bioController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: _inputDecoration('Biografía cultural')
                                .copyWith(
                                  counterStyle: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            maxLines: 3,
                            maxLength: 150,
                          ),
                          const SizedBox(height: 24),

                          // 3. Sección: Instrumentos Andinos de Interés
                          Text(
                            'Instrumentos Andinos Favoritos',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selecciona los instrumentos que estudias habitualmente:',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          ..._andeanInstruments.map((inst) {
                            final isSelected = _selectedInstruments.contains(
                              inst['id'],
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                key: Key('instrument_tile_${inst['id']}'),
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      if (_selectedInstruments.length > 1) {
                                        _selectedInstruments.remove(inst['id']);
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Debes seleccionar al menos un instrumento andino',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } else {
                                      _selectedInstruments.add(inst['id']!);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.12,
                                          )
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.outlineVariant,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inst['name']!,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? colorScheme.primary
                                                    : colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              inst['desc']!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 24),

                          // 4. Sección: Calibración Respiratoria "Soplo Suave"
                          BreathProfileCard(
                            rmsThreshold: _rmsThreshold,
                            lastCalibrated: _lastCalibrated,
                            onRecalibrate: () => context.push('/calibration'),
                          ),
                          const SizedBox(height: 32),

                          // 5. Botón principal de guardado (Ley de Fitts >= 52px)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              key: const Key('save_profile_button_large'),
                              onPressed: _isSaving
                                  ? null
                                  : () => _save(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Guardar Cambios',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
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
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
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
        preferredInstruments: _selectedInstruments.toList(),
        breathSensitivityRms: _rmsThreshold,
      ),
    );
  }
}

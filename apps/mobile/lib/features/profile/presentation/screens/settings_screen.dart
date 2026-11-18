import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/instrument.dart';
import '../../../../core/audio/instrument_service.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/practice/daily_goal_service.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../widgets/clean_switch.dart';
import '../widgets/notification_settings_tile.dart';
import '../widgets/skill_level_badge.dart';

/// Pantalla de configuración de la app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Configuración')),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final UserEntity? user = authState is AuthAuthenticated
              ? authState.user
              : authState is AuthProfileUpdated
              ? authState.user
              : authState is AuthRegistered
              ? authState.user
              : null;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // === CUENTA ===
              _SectionTitle(title: 'Cuenta'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: user?.email ?? '',
                onTap: null,
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.lock_outlined,
                title: 'Cambiar contraseña',
                subtitle: user?.authProvider == 'google'
                    ? 'Tu cuenta usa Google'
                    : 'Modificar tu contraseña actual',
                onTap: user?.authProvider == 'google'
                    ? null
                    : () => _showChangePasswordDialog(context),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Proveedor de auth',
                subtitle: user?.authProvider == 'google' ? 'Google' : 'Local',
                onTap: null,
              ),
              const SizedBox(height: 8),
              // Skill level — tile clickeable que abre la evaluación
              _SkillLevelTile(
                level: user?.skillLevel,
                onTap: () => context.push('/skill-assessment?retake=1'),
              ),

              const SizedBox(height: 24),

              // === APARIENCIA ===
              _SectionTitle(title: 'Apariencia'),
              const SizedBox(height: 8),
              _ThemeSelector(),

              const SizedBox(height: 24),

              // === NOTIFICACIONES ===
              _SectionTitle(title: 'Notificaciones'),
              const SizedBox(height: 8),
              _SettingsSwitch(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones push',
                value: user?.notificationsPushEnabled ?? true,
                onChanged: (val) async {
                  // Optimistic: enviar evento al backend
                  context.read<AuthBloc>().add(
                    AuthProfileUpdateRequested(notificationsPushEnabled: val),
                  );
                  // Sincronizar token FCM con el nuevo estado
                  final notifService = context.read<NotificationService>();
                  if (val) {
                    await notifService.initialize();
                  } else {
                    await notifService.unregister();
                  }
                },
              ),
              const SizedBox(height: 8),
              _SettingsSwitch(
                icon: Icons.email_outlined,
                title: 'Emails de progreso',
                value: user?.notificationsEmailEnabled ?? true,
                onChanged: (val) {
                  context.read<AuthBloc>().add(
                    AuthProfileUpdateRequested(notificationsEmailEnabled: val),
                  );
                },
              ),

              const SizedBox(height: 24),

              // === PRÁCTICA ===
              _SectionTitle(title: 'Práctica'),
              const SizedBox(height: 8),
              const NotificationSettingsTile(),
              const SizedBox(height: 8),
              const _DailyGoalTile(),
              const SizedBox(height: 8),
              const _InstrumentTile(),

              const SizedBox(height: 24),

              // === SOBRE LA APP ===
              _SectionTitle(title: 'Sobre la app'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Versión',
                subtitle: '1.0.0',
                onTap: null,
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Términos y condiciones',
                onTap: () => context.push('/terms'),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Política de privacidad',
                onTap: () => context.push('/privacy-policy'),
              ),

              const SizedBox(height: 24),

              // === ZONA PELIGROSA ===
              _SectionTitle(
                title: 'Zona peligrosa',
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Cerrar sesión',
                iconColor: Theme.of(context).colorScheme.error,
                titleColor: Theme.of(context).colorScheme.error,
                onTap: () => _confirmLogout(context),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Eliminar cuenta',
                iconColor: Theme.of(context).colorScheme.error,
                titleColor: Theme.of(context).colorScheme.error,
                onTap: () => _showDeleteAccountDialog(
                  context,
                  isLocal: user?.authProvider != 'google',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => RepositoryProvider.value(
        value: context.read<AuthRepository>(),
        child: const _ChangePasswordDialog(),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, {required bool isLocal}) {
    showDialog(
      context: context,
      builder: (_) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: context.read<AuthRepository>()),
          BlocProvider.value(value: context.read<AuthBloc>()),
        ],
        child: _DeleteAccountDialog(isLocal: isLocal),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: Text(
          '¿Cerrar sesión?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Se cerrará tu sesión actual.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile que muestra el nivel actual + abre el cuestionario de re-evaluación.
class _SkillLevelTile extends StatelessWidget {
  final String? level;
  final VoidCallback onTap;

  const _SkillLevelTile({required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.school_outlined, color: cs.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi nivel',
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tocá para retomar la evaluación',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SkillLevelBadge(level: level, compact: true),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionTitle({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 13,
                ),
              )
            : null,
        trailing: onTap != null
            ? Icon(
                Icons.chevron_right,
                color: Theme.of(context).hintColor,
                size: 20,
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: cs.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: cs.onSurface, fontSize: 15),
                ),
              ),
              CleanSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ThemeCubit>();
    final current = cubit.state.themeMode;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ThemeOption(
            icon: Icons.light_mode,
            label: 'Claro',
            isSelected: current == ThemeMode.light,
            onTap: () => cubit.setThemeMode(ThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.dark_mode,
            label: 'Oscuro',
            isSelected: current == ThemeMode.dark,
            onTap: () => cubit.setThemeMode(ThemeMode.dark),
          ),
          _ThemeOption(
            icon: Icons.brightness_auto,
            label: 'Auto',
            isSelected: current == ThemeMode.system,
            onTap: () => cubit.setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cs.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extrae el `detail` de un error del backend, si lo hay.
String? _errorDetail(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['detail'] is String) return data['detail'] as String;
  return null;
}

/// Diálogo para cambiar la contraseña (cuentas locales).
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_new.text.length < 8) {
      setState(
        () => _error = 'La nueva contraseña debe tener al menos 8 caracteres',
      );
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().changePassword(
        _current.text,
        _new.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorDetail(e) ?? 'No se pudo cambiar la contraseña';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cambiar la contraseña';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: Text('Cambiar contraseña', style: TextStyle(color: cs.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PasswordField(controller: _current, label: 'Contraseña actual'),
          const SizedBox(height: 12),
          _PasswordField(controller: _new, label: 'Nueva contraseña'),
          const SizedBox(height: 12),
          _PasswordField(controller: _confirm, label: 'Repetir nueva'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Cambiar'),
        ),
      ],
    );
  }
}

/// Diálogo de confirmación para eliminar la cuenta (irreversible).
class _DeleteAccountDialog extends StatefulWidget {
  final bool isLocal;
  const _DeleteAccountDialog({required this.isLocal});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    if (widget.isLocal && _password.text.isEmpty) {
      setState(() => _error = 'Ingresá tu contraseña para confirmar');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().deleteAccount(
        password: widget.isLocal ? _password.text : null,
      );
      if (!mounted) return;
      final authBloc = context.read<AuthBloc>();
      Navigator.of(context).pop();
      // Limpia tokens locales → el router redirige a /login.
      authBloc.add(AuthLogoutRequested());
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorDetail(e) ?? 'No se pudo eliminar la cuenta';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo eliminar la cuenta';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: Text('¿Eliminar cuenta?', style: TextStyle(color: cs.error)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta acción es irreversible. Se borrarán tu perfil, progreso, '
            'publicaciones y suscripción.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          if (widget.isLocal) ...[
            const SizedBox(height: 16),
            _PasswordField(controller: _password, label: 'Tu contraseña'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _confirmDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Eliminar'),
        ),
      ],
    );
  }
}

/// Meta diaria de práctica (minutos): muestra el valor y permite cambiarlo.
class _DailyGoalTile extends StatefulWidget {
  const _DailyGoalTile();

  @override
  State<_DailyGoalTile> createState() => _DailyGoalTileState();
}

class _DailyGoalTileState extends State<_DailyGoalTile> {
  final _service = DailyGoalService();
  int _goal = DailyGoalService.defaultGoal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goal = await _service.getGoalMinutes();
    if (mounted) setState(() => _goal = goal);
  }

  Future<void> _pickGoal() async {
    const options = [5, 10, 15, 20, 30, 45, 60];
    final cs = Theme.of(context).colorScheme;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        title: Text('Meta diaria', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (m) => ListTile(
                  title: Text(
                    '$m minutos',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  trailing: m == _goal
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(m),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      await _service.setGoalMinutes(picked);
      if (mounted) setState(() => _goal = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _pickGoal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: cs.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Meta diaria',
                  style: TextStyle(color: cs.onSurface, fontSize: 15),
                ),
              ),
              Text(
                '$_goal min',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de instrumento/sonido del sintetizador (quena, zampoña, tarka). Aplica la próxima vez que se abre una pantalla con sonido.
class _InstrumentTile extends StatefulWidget {
  const _InstrumentTile();

  @override
  State<_InstrumentTile> createState() => _InstrumentTileState();
}

class _InstrumentTileState extends State<_InstrumentTile> {
  final _service = InstrumentService();
  Instrument _instrument = InstrumentService.defaultInstrument;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final i = await _service.get();
    if (mounted) setState(() => _instrument = i);
  }

  Future<void> _pick() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDialog<Instrument>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        title: Text('Instrumento', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Instrument.values
              .map(
                (ins) => ListTile(
                  title: Text(
                    instrumentLabels[ins] ?? ins.name,
                    style: TextStyle(color: cs.onSurface),
                  ),
                  trailing: ins == _instrument
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(ins),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      await _service.set(picked);
      if (mounted) setState(() => _instrument = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _pick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.music_note, color: cs.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Instrumento',
                  style: TextStyle(color: cs.onSurface, fontSize: 15),
                ),
              ),
              Text(
                instrumentLabels[_instrument] ?? _instrument.name,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _PasswordField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: true,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

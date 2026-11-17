import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/profile_repository.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/profile_achievements_row.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_menu_item.dart';
import '../widgets/profile_stats_row.dart';
import '../widgets/profile_xp_card.dart';
import '../../../../core/connectivity/offline_banner.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/utils/auto_refresh_mixin.dart';
import '../../../instrument_select/presentation/widgets/instrument_selector_appbar.dart';
import '../../../tutor/presentation/tutor_targets.dart';

/// Pantalla principal del tab Perfil.
class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          ProfileBloc(profileRepository: ctx.read<ProfileRepository>())
            ..add(const ProfileLoadRequested()),
      child: const _MyProfileView(),
    );
  }
}

class _MyProfileView extends StatefulWidget {
  const _MyProfileView();

  @override
  State<_MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<_MyProfileView>
    with AutoRefreshOnResume {
  @override
  void onAutoRefresh() =>
      context.read<ProfileBloc>().add(const ProfileRefreshRequested());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          const InstrumentSelectorAction(),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, state) {
                if (state is ProfileLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
                if (state is ProfileError) {
                  final offline = state.message == offlineMessage;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          offline
                              ? Icons.wifi_off_rounded
                              : Icons.error_outline,
                          color: offline
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.message,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.read<ProfileBloc>().add(
                            const ProfileLoadRequested(),
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ProfileLoaded) {
                  return RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: () async {
                      context.read<ProfileBloc>().add(
                        const ProfileRefreshRequested(),
                      );
                    },
                    child: ListView(
                      children: [
                        // Header: avatar + nombre + bio
                        ProfileHeader(
                          user: state.user,
                          onAvatarTap: () => context.push('/edit-profile'),
                        ),

                        // Stats: Posts | Seguidores | Siguiendo
                        ProfileStatsRow(
                          profile: state.socialProfile,
                          onFollowersTap: () => context.push(
                            '/social/user/${state.user.id}/followers',
                          ),
                          onFollowingTap: () => context.push(
                            '/social/user/${state.user.id}/followers',
                          ),
                        ),

                        // Botón editar perfil
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: OutlinedButton(
                            onPressed: () => context.push('/edit-profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              side: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Editar perfil'),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // XP card
                        ProfileXPCard(
                          xpData: state.xpData,
                          onTap: () => context.push('/my-xp'),
                        ),

                        const SizedBox(height: 20),

                        // Logros recientes
                        ProfileAchievementsRow(
                          achievements: state.recentAchievements,
                          onViewAll: () => context.push('/achievements'),
                        ),

                        const SizedBox(height: 20),

                        // Suscripción premium (estado / CTA)
                        _PremiumBanner(),

                        // Menú de opciones
                        ProfileMenuItem(
                          icon: Icons.bar_chart,
                          title: 'Mi progreso',
                          onTap: () => context.push('/progress'),
                        ),
                        ProfileMenuItem(
                          key: const Key('profile_practice_history'),
                          icon: Icons.history,
                          title: 'Historial de prácticas',
                          onTap: () => context.push('/practice-history'),
                        ),
                        ProfileMenuItem(
                          icon: Icons.leaderboard,
                          title: 'Rankings',
                          onTap: () => context.push('/rankings'),
                        ),
                        ProfileMenuItem(
                          icon: Icons.emoji_events,
                          title: 'Mis logros',
                          onTap: () => context.push('/achievements'),
                        ),
                        ProfileMenuItem(
                          key: TutorTargets.keyFor('profile_saved'),
                          icon: Icons.bookmark,
                          title: 'Guardados',
                          onTap: () => context.push('/social/saved'),
                        ),
                        ProfileMenuItem(
                          icon: Icons.mic_rounded,
                          title: 'Mis grabaciones',
                          onTap: () => context.push('/recordings'),
                        ),
                        ProfileMenuItem(
                          key: TutorTargets.keyFor('profile_settings'),
                          icon: Icons.settings,
                          title: 'Configuración',
                          onTap: () => context.push('/settings'),
                        ),
                        const SizedBox(height: 4),
                        ProfileMenuItem(
                          icon: Icons.logout,
                          iconColor: Theme.of(context).colorScheme.error,
                          title: 'Cerrar sesión',
                          onTap: () => _confirmLogout(context),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
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

/// Tarjeta de suscripción: muestra el estado premium activo o un CTA para
/// hacerse premium (abre el paywall).
class _PremiumBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<AuthBloc>().state;
    final user = state is AuthAuthenticated
        ? state.user
        : state is AuthRegistered
        ? state.user
        : null;
    final isPremium = user?.isPremium ?? false;

    if (isPremium) {
      final expiry = _formatDate(user?.subscriptionExpiresAt);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aliento Andino Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiry == null
                        ? 'Suscripción activa'
                        : 'Activa hasta el $expiry',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/subscription/paywall'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hazte Premium',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Desbloqueá todas las lecciones, IA y cámara',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Formatea una fecha ISO a dd/MM/yyyy; null si no se puede parsear.
  String? _formatDate(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }
}

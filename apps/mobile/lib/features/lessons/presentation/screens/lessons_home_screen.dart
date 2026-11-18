import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/models/lesson_model.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../../instrument_select/bloc/active_instrument_bloc.dart';
import '../../../instrument_select/presentation/widgets/instrument_selector_appbar.dart';
import '../bloc/lessons/lessons_bloc.dart';
import '../bloc/lessons/lessons_event.dart';
import '../bloc/lessons/lessons_state.dart';
import '../widgets/difficulty_badge.dart';
import '../widgets/lesson_card.dart';
import '../widgets/pending_sync_badge.dart';
import '../../../tutor/presentation/tutor_targets.dart';
import '../../../../core/practice/daily_goal_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auto_refresh_mixin.dart';

/// Pantalla principal del módulo de lecciones.
class LessonsHomeScreen extends StatefulWidget {
  const LessonsHomeScreen({super.key});

  @override
  State<LessonsHomeScreen> createState() => _LessonsHomeScreenState();
}

class _LessonsHomeScreenState extends State<LessonsHomeScreen>
    with AutoRefreshOnResume {
  final _searchController = TextEditingController();
  static const _difficulties = [
    'principiante',
    'intermedio',
    'avanzado',
    'experto',
  ];

  late Future<List<LessonModel>> _recommendedFuture;
  int _goalTick = 0;
  Set<String> _downloadedIds = const {};

  @override
  void initState() {
    super.initState();
    final activeInstrument = (() {
      try {
        return context.read<ActiveInstrumentBloc>().state.activeInstrument;
      } catch (_) {
        return null;
      }
    })();
    if (activeInstrument != null) {
      context.read<LessonsBloc>().add(
        LessonsFilterByInstrument(activeInstrument),
      );
    }
    context.read<LessonsBloc>().add(const LessonsLoadCategories());
    _recommendedFuture = context.read<LessonRepository>().getRecommended();
    _loadDownloadedIds();
  }

  /// Ids de las lecciones disponibles sin conexión (para el ícono offline).
  Future<void> _loadDownloadedIds() async {
    try {
      final downloaded = await context
          .read<LessonRepository>()
          .getDownloadedLessons();
      if (!mounted) return;
      setState(() => _downloadedIds = {for (final l in downloaded) l.id});
    } catch (_) {
      // El ícono es informativo: si falla la lectura local, no se muestra.
    }
  }

  void _refreshRecommended() {
    _loadDownloadedIds();
    setState(() {
      _recommendedFuture = context.read<LessonRepository>().getRecommended();
      _goalTick++; // refresca la tarjeta de meta diaria
    });
  }

  @override
  void onAutoRefresh() {
    // Refresco silencioso al reabrir la app: ruta/scores + recomendadas.
    context.read<LessonsBloc>().add(const LessonsRefresh());
    _refreshRecommended();
  }

  /// Abre una lección y, al volver, refresca scores/ruta/recomendadas para que
  /// la pantalla se actualice sola (sin tener que recargar a mano).
  Future<void> _openLesson(String id) async {
    await context.push('/lessons/$id');
    if (!mounted) return;
    context.read<LessonsBloc>().add(const LessonsRefresh());
    _refreshRecommended();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActiveInstrumentBloc, ActiveInstrumentState>(
      listener: (context, activeState) {
        context.read<LessonsBloc>().add(
          LessonsFilterByInstrument(activeState.activeInstrument),
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Lecciones'),
          actions: [
            const InstrumentSelectorAction(),
            const PendingSyncBadge(),
            IconButton(
              icon: const Icon(Icons.offline_pin_outlined),
              tooltip: 'Lecciones sin conexión',
              onPressed: () async {
                await context.push('/offline-lessons');
                if (mounted) _loadDownloadedIds();
              },
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Mi progreso',
              onPressed: () => context.push('/progress'),
            ),
          ],
        ),
        body: BlocBuilder<LessonsBloc, LessonsState>(
          builder: (context, state) {
            if (state is LessonsLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }

            if (state is LessonsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<LessonsBloc>().add(
                        const LessonsLoadCategories(),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            if (state is LessonsLoaded) {
              return _buildContent(state);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(LessonsLoaded state) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        context.read<LessonsBloc>().add(const LessonsLoadCategories());
        _refreshRecommended();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Continuar tu ruta (próximo paso del camino de aprendizaje)
          _buildPathHero(state),

          // Accesos rápidos compactos: meta diaria + teoría, lado a lado
          // (antes eran dos tarjetas full-width apiladas).
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _DailyGoalCard(key: ValueKey(_goalTick))),
                const SizedBox(width: 10),
                const Expanded(child: _PracticeToolsCard()),
              ],
            ),
          ),

          // Recomendadas para vos
          const SizedBox(height: 14),
          _buildRecommendedSection(),

          // Buscar + filtros en una sola fila (el filtro ya no es full-width;
          // los filtros activos se muestran como chips removibles debajo).
          const SizedBox(height: 14),
          _buildSearchAndFilter(state),

          // Lista de lecciones
          const SizedBox(height: 20),
          Text(
            'Lecciones (${state.lessons.length})',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (state.lessons.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No se encontraron lecciones',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...() {
              final isPremium = _isPremium;
              return state.lessons.asMap().entries.map((entry) {
                final lesson = entry.value;
                final premiumLocked = lesson.requiresPremium && !isPremium;
                // El bloqueo por ruta (desbloqueo por dominio) es estructura del
                // plan GRATIS. Premium = acceso total a toda la biblioteca, en
                // cualquier orden (como flowkey/Yousician); la ruta queda solo
                // como guía (hero + recomendadas), nunca como candado.
                final locked =
                    !isPremium && !premiumLocked && state.isLocked(lesson);
                return LessonCard(
                  key: entry.key == 0
                      ? TutorTargets.keyFor('first_lesson_card')
                      : null,
                  lesson: lesson,
                  locked: locked,
                  premiumLocked: premiumLocked,
                  isDownloaded: _downloadedIds.contains(lesson.id),
                  onTap: premiumLocked
                      ? () => _openPaywall()
                      : locked
                      ? () => _showLockedMessage()
                      : () => _openLesson(lesson.id),
                );
              });
            }(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Buscador + botón de filtros (ícono compacto con badge) en una sola fila,
  /// y debajo los chips de filtros activos (removibles).
  Widget _buildSearchAndFilter(LessonsLoaded state) {
    final cs = Theme.of(context).colorScheme;
    final count =
        (state.activeCategory != null ? 1 : 0) +
        (state.activeDifficulty != null ? 1 : 0) +
        (state.activeGenre != null ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: TextField(
                  key: TutorTargets.keyFor('lessons_search'),
                  controller: _searchController,
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    hintText: 'Buscar lecciones...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).hintColor,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 18,
                              color: Theme.of(context).hintColor,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              context.read<LessonsBloc>().add(
                                const LessonsSearch(''),
                              );
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) =>
                      context.read<LessonsBloc>().add(LessonsSearch(value)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón de filtros: compacto (ícono + badge de conteo).
            Material(
              color: count > 0
                  ? cs.primary.withValues(alpha: 0.12)
                  : cs.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: TutorTargets.keyFor('lessons_categories'),
                onTap: _openFiltersSheet,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 46,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 20,
                          color: count > 0 ? cs.primary : cs.onSurfaceVariant,
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ..._activeFilterChips(state),
      ],
    );
  }

  /// Chips de los filtros activos (vacío si no hay ninguno).
  List<Widget> _activeFilterChips(LessonsLoaded state) {
    String? categoryName;
    if (state.activeCategory != null) {
      for (final c in state.categories) {
        if (c.id == state.activeCategory) {
          categoryName = c.name;
          break;
        }
      }
    }
    final chips = <Widget>[
      if (categoryName != null)
        _activeChip(
          categoryName,
          () => context.read<LessonsBloc>().add(
            LessonsLoadByCategory(state.activeCategory!),
          ),
        ),
      if (state.activeDifficulty != null)
        _activeChip(
          state.activeDifficulty![0].toUpperCase() +
              state.activeDifficulty!.substring(1),
          () => context.read<LessonsBloc>().add(
            const LessonsFilterByDifficulty(null),
          ),
        ),
      if (state.activeGenre != null)
        _activeChip(
          state.activeGenre!,
          () =>
              context.read<LessonsBloc>().add(const LessonsFilterByGenre(null)),
        ),
    ];
    if (chips.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 4, children: chips),
    ];
  }

  Widget _activeChip(String label, VoidCallback onRemove) {
    final cs = Theme.of(context).colorScheme;
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 15),
      backgroundColor: cs.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: cs.primary),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Panel modal con todos los filtros (categoría + dificultad + género).
  void _openFiltersSheet() {
    final bloc = context.read<LessonsBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: BlocBuilder<LessonsBloc, LessonsState>(
          builder: (ctx, st) => st is LessonsLoaded
              ? _buildFilterSheet(ctx, st)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildFilterSheet(BuildContext sheetCtx, LessonsLoaded st) {
    final cs = Theme.of(context).colorScheme;
    final bloc = sheetCtx.read<LessonsBloc>();
    final hasActive =
        st.activeCategory != null ||
        st.activeDifficulty != null ||
        st.activeGenre != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Filtros',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (hasActive)
                  TextButton(
                    onPressed: () {
                      if (st.activeCategory != null) {
                        bloc.add(LessonsLoadByCategory(st.activeCategory!));
                      }
                      bloc.add(const LessonsFilterByDifficulty(null));
                      bloc.add(const LessonsFilterByGenre(null));
                    },
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
            _sheetSection('Categoría'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in st.categories)
                  _sheetChip(
                    label: cat.name,
                    selected: st.activeCategory == cat.id,
                    color: cs.primary,
                    onTap: () => bloc.add(LessonsLoadByCategory(cat.id)),
                  ),
              ],
            ),
            _sheetSection('Dificultad'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sheetChip(
                  label: 'Todas',
                  selected: st.activeDifficulty == null,
                  color: cs.primary,
                  onTap: () => bloc.add(const LessonsFilterByDifficulty(null)),
                ),
                for (final d in _difficulties)
                  _sheetChip(
                    label: d[0].toUpperCase() + d.substring(1),
                    selected: st.activeDifficulty == d,
                    color: DifficultyBadge.colorForDifficulty(d),
                    onTap: () => bloc.add(LessonsFilterByDifficulty(d)),
                  ),
              ],
            ),
            if (st.availableGenres.isNotEmpty) ...[
              _sheetSection('Género'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _sheetChip(
                    label: 'Todos',
                    selected: st.activeGenre == null,
                    color: cs.secondary,
                    onTap: () => bloc.add(const LessonsFilterByGenre(null)),
                  ),
                  for (final g in st.availableGenres)
                    _sheetChip(
                      label: g,
                      selected: st.activeGenre == g,
                      color: cs.secondary,
                      onTap: () => bloc.add(LessonsFilterByGenre(g)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Ver ${st.lessons.length} lecciones',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetSection(String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sheetChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      backgroundColor: cs.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? Colors.white : cs.onSurface,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  /// Hero "Continuar tu ruta": el próximo paso del camino de aprendizaje
  /// (primera lección no dominada). Navega a esa lección al tocar.
  Widget _buildPathHero(LessonsLoaded state) {
    final next = state.nextLesson;
    if (next == null) return const SizedBox(height: 8);
    final cs = Theme.of(context).colorScheme;
    final premiumLocked = next.requiresPremium && !_isPremium;
    final label = next.difficulty.isEmpty
        ? ''
        : next.difficulty[0].toUpperCase() + next.difficulty.substring(1);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => premiumLocked ? _openPaywall() : _openLesson(next.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continuar tu ruta',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$label · ${next.tempoBpm} BPM',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  void _showLockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bloqueada. Completá la lección anterior con 70% o más para '
          'desbloquearla.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// ¿El usuario actual tiene suscripción premium activa?
  bool get _isPremium {
    final state = context.watch<AuthBloc>().state;
    if (state is AuthAuthenticated) return state.user.isPremium;
    if (state is AuthRegistered) return state.user.isPremium;
    return false;
  }

  /// Abre el paywall y, al volver, refresca por si activó premium.
  Future<void> _openPaywall() async {
    await context.push('/subscription/paywall');
    if (!mounted) return;
    context.read<LessonsBloc>().add(const LessonsRefresh());
    _refreshRecommended();
  }

  /// Sección horizontal con lecciones recomendadas según skill_level.
  Widget _buildRecommendedSection() {
    final theme = Theme.of(context);

    return FutureBuilder<List<LessonModel>>(
      future: _recommendedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 138,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Recomendadas para vos',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final l = items[i];
                  final premiumLocked = l.requiresPremium && !_isPremium;
                  return _RecommendedCard(
                    lesson: l,
                    onTap: () =>
                        premiumLocked ? _openPaywall() : _openLesson(l.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Card horizontal compacta para la fila de recomendadas.
class _RecommendedCard extends StatelessWidget {
  final LessonModel lesson;
  final VoidCallback onTap;

  const _RecommendedCard({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diffColor = DifficultyBadge.colorForDifficulty(lesson.difficulty);

    return SizedBox(
      width: 178,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.music_note, color: diffColor, size: 20),
                    ),
                    const Spacer(),
                    if (lesson.userBestScore != null &&
                        lesson.userBestScore! < 70)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Reforzar ${lesson.userBestScore!.toInt()}%',
                          style: const TextStyle(
                            color: AppTheme.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lesson.title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    DifficultyBadge(difficulty: lesson.difficulty),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.speed,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${lesson.tempoBpm}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile compacto reutilizable (ícono/indicador arriba, título + subtítulo).
/// Usado por la fila de accesos rápidos (meta diaria + teoría) lado a lado.
class _CompactInfoTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? subtitleColor;

  const _CompactInfoTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.surfaceContainerHighest),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor ?? cs.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de acceso al hub de teoría y entrenamiento (oído, lectura, quiz).
class _PracticeToolsCard extends StatelessWidget {
  const _PracticeToolsCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _CompactInfoTile(
      onTap: () => context.push('/theory'),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.school, color: cs.secondary, size: 20),
      ),
      title: 'Teoría y entrenamiento',
      subtitle: 'Oído · lectura · quiz',
    );
  }
}

/// Tarjeta de meta diaria de práctica (minutos de hoy vs objetivo).
class _DailyGoalCard extends StatefulWidget {
  const _DailyGoalCard({super.key});

  @override
  State<_DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<_DailyGoalCard> {
  final _service = DailyGoalService();
  int _goal = DailyGoalService.defaultGoal;
  int _today = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goal = await _service.getGoalMinutes();
    final today = await _service.getTodayMinutes();
    if (mounted) {
      setState(() {
        _goal = goal;
        _today = today;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (_loaded && _goal > 0)
        ? (_today / _goal).clamp(0.0, 1.0)
        : 0.0;
    final done = _loaded && _goal > 0 && _today >= _goal;
    final accent = done ? AppTheme.success : cs.primary;
    return _CompactInfoTile(
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            Icon(done ? Icons.check : Icons.flag, size: 15, color: accent),
          ],
        ),
      ),
      title: 'Meta diaria',
      subtitle: !_loaded
          ? '—'
          : (done ? '¡Cumplida! $_today min' : '$_today / $_goal min hoy'),
      subtitleColor: done ? AppTheme.success : null,
    );
  }
}

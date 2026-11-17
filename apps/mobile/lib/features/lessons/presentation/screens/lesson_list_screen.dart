import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/instrument.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/lesson_model.dart';
import '../../data/repositories/lesson_repository.dart';
import 'lesson_player_screen.dart';

/// Pantalla de catálogo curricular de lecciones andinas (HU-04, SUB-04-B).
/// Permite filtrar por instrumento (Quena, Zampoña, Tarka) y nivel de dificultad.
class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  InstrumentType _selectedInstrument = InstrumentType.quena;
  String? _selectedDifficulty; // null = todos

  bool _isLoading = false;
  bool _isOffline = false;
  String? _errorMessage;
  List<LessonModel> _lessons = [];

  final List<String> _difficulties = [
    'Todos',
    'Principiante',
    'Intermedio',
    'Avanzado',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchLessons();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    final instrument = InstrumentType.values[_tabController.index];
    if (instrument != _selectedInstrument) {
      setState(() {
        _selectedInstrument = instrument;
      });
      _fetchLessons();
    }
  }

  Future<void> _fetchLessons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<LessonRepository>();
      final result = await repo.getLessons(
        instrument: _selectedInstrument,
        difficulty: _selectedDifficulty?.toLowerCase(),
      );
      if (mounted) {
        setState(() {
          _lessons = result;
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
          _errorMessage =
              'Modo sin conexión: mostrando lecciones disponibles en caché local.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Lecciones'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Container(
            height: 52.0, // Touch target ergonómico >= 48px
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(
                  height: 48.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Quena',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Tab(
                  height: 48.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_column_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Zampoña',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Tab(
                  height: 48.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grain, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tarka',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isOffline)
            MaterialBanner(
              key: const Key('offline_banner'),
              padding: const EdgeInsets.all(12),
              content: Text(
                _errorMessage ??
                    'Sin conexión a internet. Usando almacenamiento local.',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              leading: const Icon(Icons.wifi_off, color: AppTheme.warning),
              backgroundColor: const Color(0xFF1F2937),
              actions: [
                TextButton(
                  onPressed: _fetchLessons,
                  child: const Text(
                    'REINTENTAR',
                    style: TextStyle(color: AppTheme.cyan),
                  ),
                ),
              ],
            ),
          // Chips de filtro por dificultad
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: _difficulties.map((diff) {
                final isSelected =
                    (_selectedDifficulty == null && diff == 'Todos') ||
                    (_selectedDifficulty?.toLowerCase() == diff.toLowerCase());
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48.0,
                    ), // Ergonomía >= 48px
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(diff),
                      onSelected: (_) {
                        setState(() {
                          _selectedDifficulty = diff == 'Todos' ? null : diff;
                        });
                        _fetchLessons();
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Lista de lecciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _lessons.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 64,
                          color: theme.hintColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron lecciones para ${_selectedInstrument.name.toUpperCase()}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchLessons,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _lessons.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final lesson = _lessons[index];
                        return _LessonCard(
                          lesson: lesson,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LessonPlayerScreen(lessonId: lesson.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final LessonModel lesson;
  final VoidCallback onTap;

  const _LessonCard({required this.lesson, required this.onTap});

  Color _getDifficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'principiante':
        return AppTheme.success;
      case 'intermedio':
        return AppTheme.warning;
      case 'avanzado':
        return AppTheme.orange;
      default:
        return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diffColor = _getDifficultyColor(lesson.difficulty);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 88.0,
          ), // Ergonomía táctil
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.music_note,
                      color: AppTheme.cyan,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: diffColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              lesson.difficulty.toUpperCase(),
                              style: TextStyle(
                                color: diffColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.speed, size: 16, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Text(
                            '${lesson.tempoBpm} BPM',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.queue_music,
                            size: 16,
                            color: theme.hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lesson.timeSignature,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

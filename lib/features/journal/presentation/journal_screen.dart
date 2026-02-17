// lib/features/journal/presentation/journal_screen.dart

import 'package:collection/collection.dart';
import 'package:animations/animations.dart'; // 🚀 Added for OpenContainer
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/core/routes/hero_dialog_route.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/journal/presentation/widgets/hoverable_card.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart'; // Import NumerologyEngine
import 'package:uuid/uuid.dart'; // Import Uuid
import 'journal_editor_screen.dart'; // Restore Editor
import 'widgets/journal_entry_card.dart'; // Restore Card
import 'widgets/journal_filter_panel.dart'; // Restore Filter
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart'; // Restore Popup Utils
import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart'; // Restore Opacity Manager
import 'package:sincro_app_flutter/features/journal/models/journal_view_scope.dart'; // Add Import

class JournalScreen extends StatefulWidget {
  final UserModel userData;
  const JournalScreen({super.key, required this.userData});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final GlobalKey _filterButtonKey = GlobalKey();

  JournalViewScope _currentScope = JournalViewScope.todas;
  DateTime? _dateFilter;
  int? _vibrationFilter;
  int? _moodFilter;
  
  // Calculate Personal Day for duplication
  int _calculatePersonalDay(DateTime date) {
    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );
    return engine.calculatePersonalDayForDate(date);
  }

  Future<void> _handleDuplicate(JournalEntry entry) async {
    try {
      final now = DateTime.now();
      final newId = const Uuid().v4();
      final personalDay = _calculatePersonalDay(now);
      
      final newEntry = JournalEntry(
        id: newId,
        // userID removed as it's not in the model
        content: entry.content,
        createdAt: now,
        updatedAt: now,
        personalDay: personalDay,
        title: entry.title, // Copy title exactly
        mood: entry.mood,
      );

      // Optimistic updat is hard with stream, so just await DB insert
      await _supabaseService.createJournalEntry(newEntry);
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anotação duplicada com sucesso!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao duplicar anotação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  final FabOpacityController _fabOpacityController = FabOpacityController();

  // Cached stream to avoid recreating on every build
  late Stream<List<JournalEntry>> _entriesStream;

  bool get _isFilterActive =>
      _dateFilter != null || _vibrationFilter != null || _moodFilter != null;

  @override
  void initState() {
    super.initState();
    _rebuildStream();
  }

  void _rebuildStream() {
    _entriesStream = _supabaseService.getJournalEntriesStream(
      widget.userData.uid,
      date: _dateFilter,
      mood: _moodFilter,
      vibration: _vibrationFilter,
    );
  }

  @override
  void dispose() {
    _fabOpacityController.dispose();
    super.dispose();
  }

  // Removed _openJournalEditor as we now use OpenContainer directly or Navigator.push


  void _openFilterUI() {
    showSmartPopup(
      context: _filterButtonKey.currentContext!,
      builder: (context) => JournalFilterPanel(
        initialScope: _currentScope,
        initialDate: _dateFilter,
        initialVibration: _vibrationFilter,
        initialMood: _moodFilter,
        onApply: (scope, date, vibration, mood) {
          setState(() {
            _currentScope = scope;
            _dateFilter = date;
            _vibrationFilter = vibration;
            _moodFilter = mood;
            _rebuildStream();
          });
          Navigator.pop(context);
        },
        onClearInPanel: () {
          setState(() {
            _currentScope = JournalViewScope.todas;
            _dateFilter = null;
            _vibrationFilter = null;
            _moodFilter = null;
            _rebuildStream();
          });
        },
        userData: widget.userData,
      ),
    );
  }

  Future<void> _handleDelete(JournalEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir anotação?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir esta anotação? Esta ação não pode ser desfeita.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabaseService.deleteJournalEntry(
            widget.userData.uid, entry.id);
        if (mounted) {
          // Force stream refresh to update UI immediately
          setState(() {
            _rebuildStream();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anotação excluída com sucesso.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }



  Widget _buildNewNoteCard(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      return Hero(
        tag: 'journal_new_note', // Unique tag for new note
        createRectTween: (begin, end) {
          return MaterialRectCenterArcTween(begin: begin, end: end);
        },
        child: HoverableCard(
        borderRadius: 12,
        borderColor: AppColors.primary,
        onTap: () {
          Navigator.of(context).push(
            HeroDialogRoute(
              builder: (context) {
                return JournalEditorScreen(
                  userData: widget.userData,
                  entry: null,
                );
              },
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Nova Anotação",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
     );
    }

    if (MediaQuery.of(context).size.width > 800) {
      // Desktop: Hero Action
      return Hero(
        tag: 'new_note_fab',
        createRectTween: (begin, end) {
          return MaterialRectCenterArcTween(begin: begin, end: end);
        },
        child: Material(
         type: MaterialType.transparency,
         child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              HeroDialogRoute(
                builder: (context) {
                   return JournalEditorScreen(
                      userData: widget.userData,
                      entry: null,
                   );
                },
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 150),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Nova Anotação",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
         ),
        ),
      );
    }

    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 500),
      transitionType: ContainerTransitionType.fadeThrough,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      middleColor: AppColors.background,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
          style: BorderStyle.solid, 
        ),
      ),
      openBuilder: (context, closeContainer) {
        return JournalEditorScreen(
          userData: widget.userData,
          entry: null, 
        );
      },
      closedBuilder: (context, openContainer) {
        return Container(
          constraints: const BoxConstraints(minHeight: 150),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Nova Anotação",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
      tappable: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: ScreenInteractionListener(
        controller: _fabOpacityController,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    isDesktop ? 24 : 16, 8, isDesktop ? 24 : 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Diário de Bordo",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 32 : 28,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      key: _filterButtonKey,
                      onPressed: _openFilterUI,
                      icon: Icon(
                        Icons.filter_alt_outlined,
                        color: _isFilterActive
                            ? AppColors.primary
                            : AppColors.secondaryText,
                      ),
                      tooltip: 'Filtros',
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: _isFilterActive
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              if (_isFilterActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ActionChip(
                    avatar:
                        const Icon(Icons.clear, size: 16, color: Colors.white),
                    label: const Text('Limpar todos os filtros'),
                    labelStyle: const TextStyle(color: Colors.white),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    onPressed: () {
                      setState(() {
                        _dateFilter = null;
                        _vibrationFilter = null;
                        _moodFilter = null;
                        _rebuildStream();
                      });
                    },
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<JournalEntry>>(
                  stream: _entriesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CustomLoadingSpinner());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text("Erro ao carregar anotações.",
                              style: TextStyle(color: Colors.red.shade300)));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          _isFilterActive
                              ? "Nenhuma anotação encontrada para estes filtros."
                              : "Nenhuma anotação encontrada.\nClique no '+' para criar a primeira.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 16),
                        ),
                      );
                    }

                    final entries = snapshot.data!;

                    if (isDesktop) {
                      return MasonryGridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0)
                            .copyWith(bottom: 100),
                        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                        ),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        itemCount: entries.length + 1, // +1 for "New Note" card
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildNewNoteCard(context);
                          }
                          final entry = entries[index - 1];
                          return JournalEntryCard(
                            entry: entry,
                            userData: widget.userData,
                            onDelete: () => _handleDelete(entry),
                            onDuplicate: () => _handleDuplicate(entry),
                          );
                        },
                      );
                    } else {
                      // MOBILE: Masonry Grid (Visual Parity) but NO "New Note" card (uses FAB)
                      return MasonryGridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0)
                            .copyWith(bottom: 100),
                         // Mobile typically expects 2 columns. 
                         // maxCrossAxisExtent 200 allows 2 cols on screens > 400px width, 
                         // or 1 col on very small screens. 
                         // To force 2 columns on most mobiles (360px+), use count or smaller extent.
                         // Using fixed count 2 is safer for standard "Pinterest" look on mobile.
                        gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, 
                        ),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        itemCount: entries.length, // No "New Note" card
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return JournalEntryCard(
                            entry: entry,
                            userData: widget.userData,
                             onDelete: () => _handleDelete(entry),
                             onDuplicate: () => _handleDuplicate(entry),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isDesktop
          ? null
          : OpenContainer(
              transitionDuration: const Duration(milliseconds: 500),
              transitionType: ContainerTransitionType.fadeThrough,
              closedElevation: 6,
              openElevation: 0,
              closedShape: const CircleBorder(),
              closedColor: AppColors.primary,
              openColor: AppColors.cardBackground,
              middleColor: AppColors.cardBackground,
              openBuilder: (context, closeContainer) {
                return JournalEditorScreen(
                  userData: widget.userData,
                  entry: null,
                );
              },
              closedBuilder: (context, openContainer) {
                return const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                );
              },
              tappable: true,
            ),
    );
  }
}

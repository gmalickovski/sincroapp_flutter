// lib/features/journal/presentation/journal_screen.dart

import 'package:animations/animations.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/common/widgets/server_status_wrapper.dart'; // Ensure this exists
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'journal_editor_screen.dart';

import 'widgets/journal_entry_card.dart';
import 'widgets/journal_filter_panel.dart';
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';
import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart';

enum JournalViewScope { todas }

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

  void _openJournalEditor({JournalEntry? entry}) {
    // Desktop/Web Check
    if (kIsWeb ||
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      showJournalEditorDialog(
        context,
        userData: widget.userData,
        entry: entry,
      );
    } else {
      // Mobile - Fullscreen Page
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => JournalEditorScreen(
            userData: widget.userData,
            entry: entry,
          ),
        ),
      );
    }
  }

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




  Widget _buildDesktopNewEntryCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openJournalEditor(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground
                .withValues(alpha: 0.5), // Slightly transparent
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
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
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Nova Anotação",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Escreva sobre seu dia...",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                      return MasonryGridView.count(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0)
                            .copyWith(bottom: 100),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        // Add 1 for the "New Entry" card
                        itemCount: entries.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildDesktopNewEntryCard(context);
                          }
                          final entryIndex = index - 1;
                          return JournalEntryCard(
                            entry: entries[entryIndex],
                            userData: widget.userData,
                            onDelete: () => _handleDelete(entries[entryIndex]),
                          );
                        },
                      );
                    } else {
                      final groupedEntries = groupBy<JournalEntry, String>(
                        entries,
                        (entry) =>
                            DateFormat.yMMMM('pt_BR').format(entry.createdAt),
                      );
                      final List<Widget> listItems = [];
                      groupedEntries.forEach((monthYear, entriesInMonth) {
                        listItems.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4.0, vertical: 16),
                            child: Text(
                              toBeginningOfSentenceCase(monthYear)!,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                        listItems.addAll(
                          entriesInMonth
                              .map((entry) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: JournalEntryCard(
                                      entry: entry,
                                      userData: widget.userData,
                                      onDelete: () => _handleDelete(entry),
                                    ),
                                  ))
                              .toList(),
                        );
                      });
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0)
                            .copyWith(bottom: 100),
                        itemCount: listItems.length,
                        itemBuilder: (context, index) => listItems[index],
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
          ? null // Hide FAB on desktop (using Grid Card instead)
          : TransparentFabWrapper(
              controller: _fabOpacityController,
              child: OpenContainer(
                transitionType: ContainerTransitionType.fadeThrough,
                openBuilder: (BuildContext context, VoidCallback _) {
                  return ServerStatusWrapper(
                    userData: widget.userData,
                    child: JournalEditorScreen(
                      userData: widget.userData,
                    ),
                  );
                },
                closedElevation: 4,
                closedShape: const CircleBorder(),
                closedColor: AppColors.primary,
                openColor: AppColors.cardBackground,
                tappable: true,
                closedBuilder:
                    (BuildContext context, VoidCallback openContainer) {
                  return FloatingActionButton(
                    onPressed: openContainer,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.add),
                  );
                },
              ),
            ),
    );
  }
}

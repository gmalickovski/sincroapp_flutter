// lib/features/journal/presentation/journal_screen.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'journal_editor_screen.dart';
import 'package:sincro_app_flutter/features/assistant/widgets/expanding_assistant_fab.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/assistant_panel.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'widgets/journal_entry_card.dart';
import 'widgets/journal_filter_panel.dart';

class JournalScreen extends StatefulWidget {
  final UserModel userData;
  const JournalScreen({super.key, required this.userData});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final GlobalKey _filterButtonKey = GlobalKey();

  DateTime? _dateFilter;
  int? _vibrationFilter;
  int? _moodFilter;

  bool get _isFilterActive =>
      _dateFilter != null || _vibrationFilter != null || _moodFilter != null;

  void _openJournalEditor({JournalEntry? entry}) {
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

  void _handleDelete(JournalEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirmar Exclusão',
              style: TextStyle(color: Colors.white)),
          content: const Text('Tem certeza que deseja excluir esta anotação?',
              style: TextStyle(color: AppColors.secondaryText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                _firestoreService.deleteJournalEntry(
                    widget.userData.uid, entry.id);
                Navigator.of(ctx).pop();
              },
              child:
                  Text('Excluir', style: TextStyle(color: Colors.red.shade400)),
            ),
          ],
        );
      },
    );
  }

  // A função agora sempre chamará o popover
  void _openFilterUI() {
    void applyFilters(DateTime? newDate, int? newVibration, int? newMood) {
      setState(() {
        _dateFilter = newDate;
        _vibrationFilter = newVibration;
        _moodFilter = newMood;
      });
      Navigator.of(context).pop();
    }

    void clearFilters() {
      setState(() {
        _dateFilter = null;
        _vibrationFilter = null;
        _moodFilter = null;
      });
    }

    _showFilterPopover(applyFilters, clearFilters);
  }

  void _showFilterPopover(
      Function(DateTime?, int?, int?) onApply, VoidCallback onClear) {
    final RenderBox renderBox =
        _filterButtonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      color: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 8,
        offset.dx + size.width,
        offset.dy + size.height + 8,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: JournalFilterPanel(
            initialDate: _dateFilter,
            initialMood: _moodFilter,
            initialVibration: _vibrationFilter,
            onApply: onApply,
            onClearInPanel: onClear,
            userData: widget.userData,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                isDesktop ? 40 : 16, 24, isDesktop ? 40 : 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Diário de Bordo",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 32 : 28,
                        fontWeight: FontWeight.bold)),
                Badge(
                  key: _filterButtonKey,
                  isLabelVisible: _isFilterActive,
                  child: OutlinedButton.icon(
                    onPressed: _openFilterUI,
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: const Text("Filtros"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
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
                avatar: const Icon(Icons.clear, size: 16, color: Colors.white),
                label: const Text('Limpar todos os filtros'),
                labelStyle: const TextStyle(color: Colors.white),
                backgroundColor: AppColors.primary.withValues(alpha: 0.5),
                onPressed: () {
                  setState(() {
                    _dateFilter = null;
                    _vibrationFilter = null;
                    _moodFilter = null;
                  });
                },
              ),
            ),
          Expanded(
            child: StreamBuilder<List<JournalEntry>>(
              stream: _firestoreService.getJournalEntriesStream(
                widget.userData.uid,
                date: _dateFilter,
                mood: _moodFilter,
                vibration: _vibrationFilter,
              ),
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
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return JournalEntryCard(
                        entry: entries[index],
                        onEdit: () => _openJournalEditor(entry: entries[index]),
                        onDelete: () => _handleDelete(entries[index]),
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
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: JournalEntryCard(
                                  entry: entry,
                                  onEdit: () =>
                                      _openJournalEditor(entry: entry),
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
      floatingActionButton: (widget.userData.subscription.isActive &&
              widget.userData.subscription.plan == SubscriptionPlan.premium)
          ? ExpandingAssistantFab(
              onPrimary: () => _openJournalEditor(),
              primaryIcon: Icons.book_outlined, // Ícone de diário
              primaryTooltip: 'Nova anotação',
              onOpenAssistant: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AssistantPanel(userData: widget.userData),
                );
              },
              onMic: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Entrada por voz chegará em breve.'),
                  ),
                );
              },
            )
          : FloatingActionButton(
              onPressed: () => _openJournalEditor(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
    );
  }
}

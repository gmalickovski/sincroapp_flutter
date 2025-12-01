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

import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart';

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

  final FabOpacityController _fabOpacityController = FabOpacityController();

  bool get _isFilterActive =>
      _dateFilter != null || _vibrationFilter != null || _moodFilter != null;
  
  @override
  void dispose() {
    _fabOpacityController.dispose();
    super.dispose();
  }

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

  void _openFilterUI() {
    final RenderBox? renderBox =
        _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox != null
        ? renderBox.localToGlobal(Offset.zero)
        : const Offset(0, 0);
    final size = renderBox?.size ?? const Size(0, 0);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            top: offset.dy + size.height + 8,
            right: MediaQuery.of(context).size.width - (offset.dx + size.width),
            child: JournalFilterPanel(
              initialDate: _dateFilter,
              initialVibration: _vibrationFilter,
              initialMood: _moodFilter,
              onApply: (date, vibration, mood) {
                setState(() {
                  _dateFilter = date;
                  _vibrationFilter = vibration;
                  _moodFilter = mood;
                });
                Navigator.pop(context);
              },
              onClearInPanel: () {
                setState(() {
                  _dateFilter = null;
                  _vibrationFilter = null;
                  _moodFilter = null;
                });
              },
              userData: widget.userData,
            ),
          ),
        ],
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
        await _firestoreService.deleteJournalEntry(
            widget.userData.uid, entry.id);
        if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: ScreenInteractionListener(
        controller: _fabOpacityController,
        child: Column(
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
      ),
      floatingActionButton: TransparentFabWrapper(
        controller: _fabOpacityController,
        child: (widget.userData.subscription.isActive &&
                widget.userData.subscription.plan == SubscriptionPlan.premium)
            ? ExpandingAssistantFab(
                onPrimary: () => _openJournalEditor(),
                primaryIcon: Icons.edit_note,
                primaryTooltip: 'Nova Anotação',
                onOpenAssistant: (message) => AssistantPanel.show(context, widget.userData, initialMessage: message),
              )
            : FloatingActionButton(
                onPressed: () => _openJournalEditor(),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

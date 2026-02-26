import 'package:collection/collection.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/core/routes/hero_dialog_route.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/journal/presentation/widgets/hoverable_card.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:uuid/uuid.dart';
import 'journal_editor_screen.dart';
import 'widgets/journal_entry_card.dart';
// import 'widgets/journal_filter_panel.dart'; // Deleted
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';
import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_view_scope.dart';
import 'package:sincro_app_flutter/common/widgets/sincro_toolbar.dart';
// New Generic Filter Popup
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/common/widgets/sincro_filter_selector.dart'; // Unified Selector
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart'; // Helper for colors
import 'package:sincro_app_flutter/common/widgets/mobile_filter_sheet.dart'; // Mobile Filter Sheet

class JournalScreen extends StatefulWidget {
  final UserModel userData;
  const JournalScreen({super.key, required this.userData});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with WidgetsBindingObserver {
  final SupabaseService _supabaseService = SupabaseService();

  // Keys for Popup Anchoring
  final GlobalKey _dateFilterKey = GlobalKey();
  final GlobalKey _moodFilterKey = GlobalKey();
  final GlobalKey _vibrationFilterKey = GlobalKey();
  final GlobalKey _sortFilterKey = GlobalKey();

  JournalViewScope _currentScope = JournalViewScope.todas;
  DateTime? _dateFilter;
  DateTime? _startDateFilter; // New Range Start
  DateTime? _endDateFilter; // New Range End
  int? _vibrationFilter;
  int? _moodFilter;
  String? _selectedSort;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedEntryIds = {};

  // Search State
  String _searchQuery = '';

  // Calculate Personal Day for duplication
  int _calculatePersonalDay(DateTime date) {
    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );
    return engine.calculatePersonalDayForDate(date);
  }


  final FabOpacityController _fabOpacityController = FabOpacityController();

  late Stream<List<JournalEntry>> _entriesStream;

  bool get _isFilterActive =>
      _dateFilter != null ||
      _startDateFilter != null ||
      _endDateFilter != null ||
      _vibrationFilter != null ||
      _moodFilter != null;

  // Selection Mode Logic
  List<JournalEntry> _currentEntriesList = [];

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedEntryIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedEntryIds.length == _currentEntriesList.length) {
        _selectedEntryIds.clear();
      } else {
        _selectedEntryIds.addAll(_currentEntriesList.map((e) => e.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedEntryIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Anotações'),
        content: Text(
            'Tem certeza que deseja excluir ${_selectedEntryIds.length} anotações?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
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
        for (final id in _selectedEntryIds) {
          await _supabaseService.deleteJournalEntry(widget.userData.uid, id);
        }

        setState(() {
          _selectedEntryIds.clear();
          // Stay in selection mode or exit? Usually exit if empty or stay if user wants to select more.
          // Let's exit selection mode if all deleted?
          // For now, just clear selection.
          if (_currentEntriesList.isEmpty) {
            _isSelectionMode = false;
          }
          _rebuildStream();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anotações excluídas com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao excluir: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rebuildStream();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed from background/standby
      debugPrint("🔄 [JournalScreen] App resumed. Refreshing stream...");
      setState(() {
        _rebuildStream();
      });
    }
  }

  void _rebuildStream() {
    _entriesStream = _supabaseService.getJournalEntriesStream(
      widget.userData.uid,
      date: _dateFilter,
      startDate: _startDateFilter,
      endDate: _endDateFilter,
      mood: _moodFilter,
      vibration: _vibrationFilter,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabOpacityController.dispose();
    super.dispose();
  }

  // ─── Mobile Filter Sheets ───

  void _showMobileDateFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileFilterSheet(
        type: MobileFilterType.date,
        selectedDate: _dateFilter,
        selectedStartDate: _startDateFilter,
        selectedEndDate: _endDateFilter,
        userData: widget.userData,
      ),
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          // If result has keys, update. If not, it means we probably just adhere to what was passed back.
          // The sheet returns explicit nulls if cleared.
          _dateFilter = result['date'];
          _startDateFilter = result['startDate'];
          _endDateFilter = result['endDate'];
          _rebuildStream();
        });
      }
    }
  }

  void _showMobileMoodFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileFilterSheet(
        type: MobileFilterType.mood,
        selectedMood: _moodFilter,
      ),
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          _moodFilter = result['mood'];
          _rebuildStream();
        });
      }
    }
  }

  void _showMobileSortFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.sort,
        selectedOption: _selectedSort,
      ),
    ).then((result) {
      if (result != null && result is Map && result.containsKey('value')) {
        setState(() {
          _selectedSort = result['value'] as String?;
        });
      }
    });
  }

  void _showDesktopSortFilter() {
    showSmartPopup(
      context: _sortFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.sort,
          selectedOption: _selectedSort,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map && result.containsKey('value')) {
        setState(() {
          _selectedSort = result['value'] as String?;
        });
      }
    });
  }

  void _showMobileVibrationFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileFilterSheet(
        type: MobileFilterType.vibration,
        selectedVibration: _vibrationFilter,
      ),
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          _vibrationFilter = result['vibration'];
          _rebuildStream();
        });
      }
    }
  }

  // ─── Filter Popups (Desktop) ───

  void _showDesktopDateFilter() async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: SizedBox(
            width: 360, // Compact width for desktop
            child: MobileFilterSheet(
              type: MobileFilterType.date,
              selectedDate: _dateFilter,
              selectedStartDate: _startDateFilter,
              selectedEndDate: _endDateFilter,
              isDesktop: true,
              userData: widget.userData,
            ),
          ),
        );
      },
    ).then((result) {
      if (result != null) {
        if (mounted) {
          setState(() {
            _dateFilter = result['date'];
            _startDateFilter = result['startDate'];
            _endDateFilter = result['endDate'];
            _rebuildStream();
          });
        }
      }
    });
  }

  void _showMoodPopup() {
    showSmartPopup(
      context: _moodFilterKey.currentContext!,
      builder: (context) {
        return SincroFilterSelector.mood(
          selectedMood: _moodFilter,
          onSelected: (mood) {
            setState(() {
              _moodFilter = mood;
              _rebuildStream();
            });
            Navigator.pop(context); // Close on selection
          },
        );
      },
    );
  }

  void _showVibrationPopup() {
    showSmartPopup(
      context: _vibrationFilterKey.currentContext!,
      builder: (context) {
        return SincroFilterSelector.vibration(
          selectedVibration: _vibrationFilter,
          onSelected: (vibration) {
            setState(() {
              _vibrationFilter = vibration;
              _rebuildStream();
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  // ─── Selection Mode Logic ───
  // Methods are defined below in the class


  // ─── Cards ───

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

  // ─── Toolbar Construction ───

  List<SincroFilterItem> _buildFilterItems(bool isDesktop) {
    // Determine Date Filter Label
    String dateLabel = "Data";
    bool isDateActive = _startDateFilter != null ||
        _endDateFilter != null ||
        _dateFilter != null;

    if (isDateActive) {
      if (_startDateFilter != null && _endDateFilter != null) {
        if (isSameDay(_startDateFilter!, _endDateFilter!)) {
          dateLabel = "Dia ${DateFormat('dd/MM').format(_startDateFilter!)}";
        } else {
          final isFullMonth = _startDateFilter!.day == 1 &&
              _endDateFilter!.day ==
                  DateTime(_endDateFilter!.year, _endDateFilter!.month + 1, 0)
                      .day;
          final isFullYear = _startDateFilter!.month == 1 &&
              _startDateFilter!.day == 1 &&
              _endDateFilter!.month == 12 &&
              _endDateFilter!.day == 31;

          if (isFullYear) {
            dateLabel = "Ano ${_startDateFilter!.year}";
          } else if (isFullMonth) {
            dateLabel =
                "Mês ${DateFormat('MMM', 'pt_BR').format(_startDateFilter!)}";
          } else {
            dateLabel =
                "${DateFormat('dd/MM').format(_startDateFilter!)} - ${DateFormat('dd/MM').format(_endDateFilter!)}";
          }
        }
      } else if (_startDateFilter != null) {
        dateLabel =
            "A partir de ${DateFormat('dd/MM').format(_startDateFilter!)}";
      } else if (_dateFilter != null) {
        dateLabel = "Dia ${DateFormat('dd/MM').format(_dateFilter!)}";
      }
    }

    // Sort Filter
    String sortLabel = 'Ordenar';
    if (_selectedSort == 'date_desc') sortLabel = 'Mais recentes';
    if (_selectedSort == 'date_asc') sortLabel = 'Mais antigas';
    if (_selectedSort == 'alpha_asc') sortLabel = 'A-Z';
    if (_selectedSort == 'alpha_desc') sortLabel = 'Z-A';

    return [
      // Sort filter first (after divider)
      SincroFilterItem(
        icon: Icons.sort,
        label: sortLabel,
        isSelected: _selectedSort != null,
        onTap: isDesktop ? _showDesktopSortFilter : _showMobileSortFilter,
        activeColor: _selectedSort != null ? AppColors.primary : null,
        key: _sortFilterKey,
      ),
      SincroFilterItem(
        icon: Icons.calendar_today_outlined,
        label: dateLabel,
        isSelected: isDateActive,
        onTap: isDesktop ? _showDesktopDateFilter : _showMobileDateFilter,
        activeColor: AppColors.primary,
        key: _dateFilterKey,
      ),

      // Mood Filter
      SincroFilterItem(
        icon: _moodFilter != null
            ? SincroFilterSelector.getMoodIcon(_moodFilter!)
            : Icons.mood,
        label: _moodFilter != null ? _getMoodLabel(_moodFilter!) : "Humor",
        isSelected: _moodFilter != null,
        onTap: isDesktop ? _showMoodPopup : _showMobileMoodFilter,
        activeColor: _moodFilter != null
            ? SincroFilterSelector.getMoodColor(_moodFilter!)
            : null,
        key: _moodFilterKey,
      ),
      // Vibration Filter
      SincroFilterItem(
        icon: Icons.waves,
        label: _vibrationFilter != null
            ? "Vibração $_vibrationFilter"
            : "Vibração",
        isSelected: _vibrationFilter != null,
        onTap: isDesktop ? _showVibrationPopup : _showMobileVibrationFilter,
        activeColor: _vibrationFilter != null
            ? getColorsForVibration(_vibrationFilter!).background
            : null,
        key: _vibrationFilterKey,
      ),
    ];
  }

  String _getMoodLabel(int mood) {
    switch (mood) {
      case 1:
        return 'Péssimo';
      case 2:
        return 'Ruim';
      case 3:
        return 'Neutro';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente';
      default:
        return 'Humor';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    final filters = _buildFilterItems(isDesktop);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: ScreenInteractionListener(
        controller: _fabOpacityController,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SincroToolbar(
                title: "Diário de Bordo",
                forceDesktop: isDesktop,
                filters: filters,
                isSelectionMode: _isSelectionMode,
                isAllSelected: _currentEntriesList.isNotEmpty &&
                    _selectedEntryIds.length == _currentEntriesList.length,
                onToggleSelectionMode: _toggleSelectionMode,
                onToggleSelectAll: _toggleSelectAll,
                onDeleteSelected: _deleteSelected,
                onSearchChanged: (query) {
                  setState(() => _searchQuery = query);
                },
                onClearFilters: _isFilterActive
                    ? () {
                        setState(() {
                          _dateFilter = null;
                          _startDateFilter = null;
                          _endDateFilter = null;
                          _vibrationFilter = null;
                          _moodFilter = null;
                          _selectedSort = null;
                          _currentScope = JournalViewScope.todas;
                          _selectedEntryIds.clear();
                          _isSelectionMode = false;
                          _rebuildStream();
                        });
                      }
                    : null,
                hasActiveFilters: _isFilterActive,
                selectedCount: _selectedEntryIds.length,
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

                    // Apply local search filtering
                    var entries = snapshot.data!;
                    if (_searchQuery.isNotEmpty) {
                      entries = entries
                          .where((e) =>
                              e.content
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              (e.title
                                      ?.toLowerCase()
                                      .contains(_searchQuery.toLowerCase()) ??
                                  false))
                          .toList();
                    }

                    // Apply sort
                    if (_selectedSort != null) {
                      entries.sort((a, b) {
                        if (_selectedSort == 'alpha_asc') {
                          return (a.title ?? a.content)
                              .toLowerCase()
                              .compareTo((b.title ?? b.content).toLowerCase());
                        } else if (_selectedSort == 'alpha_desc') {
                          return (b.title ?? b.content)
                              .toLowerCase()
                              .compareTo((a.title ?? a.content).toLowerCase());
                        } else if (_selectedSort == 'date_asc') {
                          return a.createdAt.compareTo(b.createdAt);
                        } else if (_selectedSort == 'date_desc') {
                          return b.createdAt.compareTo(a.createdAt);
                        }
                        return 0;
                      });
                    }

                    // Update current entries list for "Select All" functionality
                    _currentEntriesList = entries;

                    if (isDesktop) {
                      return MasonryGridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0)
                            .copyWith(bottom: 100),
                        gridDelegate:
                            const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
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
                          // Selection Logic for Cards
                          final isSelected =
                              _selectedEntryIds.contains(entry.id);

                          return GestureDetector(
                            onLongPress: () {
                              // Trigger selection mode
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedEntryIds.add(entry.id);
                                });
                              }
                            },
                            onTap: _isSelectionMode
                                ? () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedEntryIds.remove(entry.id);
                                        if (_selectedEntryIds.isEmpty)
                                          _isSelectionMode = false;
                                      } else {
                                        _selectedEntryIds.add(entry.id);
                                      }
                                    });
                                  }
                                : null, // Default behavior handled by card internal tap
                            child: Stack(
                              children: [
                                JournalEntryCard(
                                  entry: entry,
                                  userData: widget.userData,
                                ),
                                if (_isSelectionMode)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.3)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(
                                                color: AppColors.primary,
                                                width: 3)
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
                        gridDelegate:
                            const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        itemCount: entries.length, // No "New Note" card
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          // Selection Logic for Cards (Mobile matches Desktop)
                          final isSelected =
                              _selectedEntryIds.contains(entry.id);

                          return GestureDetector(
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedEntryIds.add(entry.id);
                                });
                              }
                            },
                            onTap: _isSelectionMode
                                ? () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedEntryIds.remove(entry.id);
                                        if (_selectedEntryIds.isEmpty)
                                          _isSelectionMode = false;
                                      } else {
                                        _selectedEntryIds.add(entry.id);
                                      }
                                    });
                                  }
                                : null,
                            child: Stack(
                              children: [
                                JournalEntryCard(
                                  entry: entry,
                                  userData: widget.userData,
                                ),
                                if (_isSelectionMode)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.3)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(
                                                color: AppColors.primary,
                                                width: 3)
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

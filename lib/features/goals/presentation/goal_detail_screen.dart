// lib/features/goals/presentation/goal_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart'; // Added
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/tasks/services/task_action_service.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_image_card.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/image_upload_dialog.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/assistant_panel.dart';

import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_filter_panel.dart';
import 'package:sincro_app_flutter/common/widgets/mobile_filter_sheet.dart';

import 'package:sincro_app_flutter/common/widgets/sincro_toolbar.dart';

import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/agent_star_icon.dart';

import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/assistant_layout_manager.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal initialGoal;
  final UserModel userData;

  const GoalDetailScreen({
    super.key,
    required this.initialGoal,
    required this.userData,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TaskActionService _taskActionService = TaskActionService();
  final bool _isLoading = false;
  bool _isAiSidebarOpen = false;
  // NEW STATE: Controls the visibility of the top carousel
  bool _isMilestonesExpanded = false;
  bool _hasTriggeredFirstMilestone = false;
  final FabOpacityController _fabOpacityController = FabOpacityController();

  static const double kDesktopBreakpoint = 768.0;
  static const double kMaxContentWidth = 1200.0;

  // Filter States
  String? _activeFilter = 'foco';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  DateTime? _selectedDate; // Single-date filter (alinhado com FocoDoDia)
  int? _filterVibration;
  String? _filterTag;
  String? _selectedSort;
  String _searchQuery = ''; // Added for SincroToolbar search

  // Selection Mode States
  bool _isSelectionMode = false;
  Set<String> _selectedTaskIds = {}; // IDs of selected tasks

  OverlayEntry? _filterOverlay;
  final GlobalKey _dateFilterKey = GlobalKey();
  final GlobalKey _vibrationFilterKey = GlobalKey();
  final GlobalKey _tagFilterKey = GlobalKey();
  final GlobalKey _sortFilterKey = GlobalKey();
  final GlobalKey<AssistantLayoutManagerState> _assistantLayoutKey =
      GlobalKey<AssistantLayoutManagerState>();

  // Carousel Controller
  late PageController _pageController;
  int _currentPage = 0; // 0 = Image, 1 = Info

  // Stream Controllers
  late Stream<Goal> _goalStream;
  late Stream<List<TaskModel>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);

    // Initialize Streams ONCE
    _goalStream = _supabaseService.getSingleGoalStream(
        widget.userData.uid, widget.initialGoal.id);
    _tasksStream = _supabaseService.getTasksForGoalStream(
        widget.userData.uid, widget.initialGoal.id);
  }

  @override
  void dispose() {
    _fabOpacityController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleEditGoal(Goal goal) {
    final bool isDesktop =
        MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      // Desktop: Show dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return CreateGoalDialog(
            userData: widget.userData,
            goalToEdit: goal,
          );
        },
      ).then((result) {
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jornada atualizada com sucesso!'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      });
    } else {
      // Mobile: Show as Bottom Sheet (matches mobile_filter_sheet style)
      CreateGoalDialog.showAsBottomSheet(
        context,
        userData: widget.userData,
        goalToEdit: goal,
      ).then((result) {
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jornada atualizada com sucesso!'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      });
    }
  }

  // Handle goal deletion
  Future<void> _handleDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Jornada?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir esta jornada? Esta ação não pode ser desfeita.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.deleteGoal(widget.userData.uid, goal.id);
        if (mounted) {
          Navigator.of(context).pop(); // Return to previous screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jornada excluída com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir jornada: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // Função para adicionar novo marco
  void _addMilestone(Goal goal) {
    if (widget.userData.uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do usuário não encontrado.')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TaskInputModal(
          userData: widget.userData,
          userId: widget.userData.uid,
          preselectedGoal: goal,
          initialDueDate: DateTime.now(),
          onAddTask: (ParsedTask parsedTask) {
            DateTime? finalDueDateUtc = parsedTask.dueDate?.toUtc();
            DateTime dateForPersonalDay;

            if (finalDueDateUtc != null) {
              dateForPersonalDay = finalDueDateUtc;
            } else {
              final now = DateTime.now().toLocal();
              dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
            }

            final int? finalPersonalDay =
                _calculatePersonalDay(dateForPersonalDay);

            final newTask = TaskModel(
              id: '',
              text: parsedTask.cleanText,
              createdAt: DateTime.now().toUtc(),
              dueDate: finalDueDateUtc,
              journeyId: goal.id,
              journeyTitle: goal.title,
              tags: parsedTask.tags,
              personalDay: finalPersonalDay,
              // Recurrence Mapping
              recurrenceType:
                  parsedTask.recurrenceRule.type ?? RecurrenceType.none,
              recurrenceDaysOfWeek: parsedTask.recurrenceRule.daysOfWeek ?? [],
              recurrenceEndDate: parsedTask.recurrenceRule.endDate,
              // Reminder Mapping
              reminderTime: parsedTask.reminderTime,
              reminderAt: parsedTask.reminderAt,
            );

            _supabaseService
                .addTask(widget.userData.uid, newTask)
                .then((_) {}, onError: (error) {
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Erro ao salvar marco: $error'),
                      backgroundColor: Colors.red),
                );
              }
            });
          },
        );
      },
    );
  }

  void _handleMilestoneTap(TaskModel task) {
    final isDesktopLayout = MediaQuery.of(context).size.width > 600;

    if (isDesktopLayout) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return TaskDetailModal(
            task: task,
            userData: widget.userData,
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TaskDetailModal(
          task: task,
          userData: widget.userData,
        ),
      );
    }
  }

  // --- SELECTION MODE LOGIC ---
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedTaskIds.clear();
    });
  }

  void _onTaskSelected(String taskId, bool selected) {
    setState(() {
      if (selected) {
        _selectedTaskIds.add(taskId);
      } else {
        _selectedTaskIds.remove(taskId);
      }
    });
  }

  // (Solicitação 2) Select All Logic
  void _selectAll(List<TaskModel> tasksToShow) {
    setState(() {
      if (_selectedTaskIds.length == tasksToShow.length) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds = tasksToShow.map((t) => t.id).toSet();
      }
    });
  }

  // Bulk Delete
  Future<void> _deleteSelectedTasks() async {
    if (_selectedTaskIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Excluir ${_selectedTaskIds.length} marcos?',
            style: const TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir os marcos selecionados? Esta ação não pode ser desfeita.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (var id in _selectedTaskIds) {
          await _supabaseService.deleteTask(widget.userData.uid, id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Marcos excluídos com sucesso!'),
              backgroundColor: AppColors.success));
          _toggleSelectionMode(); // Exit selection mode
          setState(() {
            _tasksStream = _supabaseService.getTasksForGoalStream(
                widget.userData.uid, widget.initialGoal.id);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  // --- SincroToolbar Integration ---

  bool get _isFilterActive {
    return _activeFilter != null ||
        _filterStartDate != null ||
        _selectedDate != null ||
        _filterVibration != null ||
        _filterTag != null ||
        _selectedSort != null ||
        _searchQuery.isNotEmpty;
  }

  Widget _buildToolbar(bool isDesktop, List<TaskModel> visibleTasks,
      List<String> availableTags) {
    return SincroToolbar(
      contentPadding: isDesktop ? EdgeInsets.zero : null,
      title: widget.initialGoal.title,
      titleTrailing: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _isMilestonesExpanded = !_isMilestonesExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0), // Adds a nice generous hit area
          child: AnimatedRotation(
            turns: _isMilestonesExpanded ? 0.0 : 0.5, // 0 = original icon orientation, 0.5 = 180 deg flip
            duration: const Duration(milliseconds: 300),
            child: const Icon(
              Icons.expand_more, // When true (expanded), it points down (expand_more). When false (collapsed) it flips 180 deg to point up (expand_less)
              color: AppColors.secondaryText,
              size: 28,
            ),
          ),
        ),
      ),
      forceDesktop: isDesktop,
      filters: _buildFilterItems(isDesktop, availableTags),
      isSelectionMode: _isSelectionMode,
      isAllSelected: visibleTasks.isNotEmpty &&
          _selectedTaskIds.length == visibleTasks.length,
      selectedCount: _selectedTaskIds.length,
      hasActiveFilters: _isFilterActive,
      onSearchChanged: (val) => setState(() => _searchQuery = val),
      onToggleSelectionMode: _toggleSelectionMode,
      onToggleSelectAll: () => _selectAll(visibleTasks),
      onDeleteSelected: _deleteSelectedTasks,
      onClearFilters: () {
        setState(() {
          _activeFilter = null;
          _filterStartDate = null;
          _filterEndDate = null;
          _selectedDate = null;
          _filterVibration = null;
          _filterTag = null;
          _selectedSort = null;
          _searchQuery = '';
          _selectedTaskIds.clear();
        });
      },
    );
  }

  List<SincroFilterItem> _buildFilterItems(
      bool isDesktop, List<String> availableTags) {
    // Standalone view filters
    void _setFilter(String? filter) {
      setState(() {
        _activeFilter = (_activeFilter == filter) ? null : filter;
        _selectedTaskIds.clear();
      });
    }

    final focoItem = SincroFilterItem(
      label: 'Foco',
      icon: Icons.bolt,
      isSelected: _activeFilter == 'foco',
      activeColor: const Color(0xFFFF6D3F),
      onTap: () => _setFilter('foco'),
    );

    final tarefasItem = SincroFilterItem(
      label: 'Tarefas',
      icon: Icons.inbox_outlined,
      isSelected: _activeFilter == 'tarefas',
      activeColor: Colors.amber,
      onTap: () => _setFilter('tarefas'),
    );

    final agendamentoItem = SincroFilterItem(
      label: 'Agendamentos',
      icon: Icons.event_available,
      isSelected: _activeFilter == 'agendamentos',
      activeColor: Colors.amber,
      onTap: () => _setFilter('agendamentos'),
    );

    final concluidasItem = SincroFilterItem(
      label: 'Concluídas',
      icon: Icons.check_circle_outline,
      isSelected: _activeFilter == 'concluidas',
      activeColor: const Color(0xFF22C55E),
      onTap: () => _setFilter('concluidas'),
    );

    final atrasadasItem = SincroFilterItem(
      label: 'Atrasadas',
      icon: Icons.warning_amber_rounded,
      isSelected: _activeFilter == 'atrasadas',
      activeColor: const Color(0xFFEF5350),
      onTap: () => _setFilter('atrasadas'),
    );

    // 2. Date (rich label como FocoDoDia)
    String dateLabel = 'Data';
    bool isDateActive = _filterStartDate != null || _filterEndDate != null || _selectedDate != null;
    if (isDateActive) {
      if (_filterStartDate != null && _filterEndDate != null) {
        if (isSameDay(_filterStartDate!, _filterEndDate!)) {
          dateLabel = 'Dia ${DateFormat('dd/MM').format(_filterStartDate!)}';
        } else {
          final isFullMonth = _filterStartDate!.day == 1 &&
              _filterEndDate!.day == DateTime(_filterEndDate!.year, _filterEndDate!.month + 1, 0).day;
          final isFullYear = _filterStartDate!.month == 1 &&
              _filterStartDate!.day == 1 &&
              _filterEndDate!.month == 12 &&
              _filterEndDate!.day == 31;
          if (isFullYear) {
            dateLabel = 'Ano ${_filterStartDate!.year}';
          } else if (isFullMonth) {
            dateLabel = 'Mês ${DateFormat('MMM', 'pt_BR').format(_filterStartDate!)}';
          } else {
            dateLabel = '${DateFormat('dd/MM').format(_filterStartDate!)} - ${DateFormat('dd/MM').format(_filterEndDate!)}';
          }
        }
      } else if (_filterStartDate != null) {
        dateLabel = 'A partir de ${DateFormat('dd/MM').format(_filterStartDate!)}';
      } else if (_selectedDate != null) {
        dateLabel = 'Dia ${DateFormat('dd/MM').format(_selectedDate!)}';
      }
    }
    final dateItem = SincroFilterItem(
      key: _dateFilterKey,
      label: dateLabel,
      icon: Icons.calendar_today,
      isSelected: isDateActive,
      onTap: isDesktop
          ? () => _showDesktopDateFilter()
          : () => _showMobileDateFilter(),
    );

    // 3. Vibration (label = 'Vibração X')
    Color? vibrationColor;
    if (_filterVibration != null) {
      vibrationColor = getColorsForVibration(_filterVibration!).background;
    }

    final vibrationItem = SincroFilterItem(
      key: _vibrationFilterKey,
      label: _filterVibration != null ? 'Vibração $_filterVibration' : 'Vibração',
      icon: Icons.waves,
      isSelected: _filterVibration != null,
      activeColor: vibrationColor,
      onTap: isDesktop
          ? () => _showDesktopVibrationFilter()
          : () => _showMobileVibrationFilter(),
    );

    // 4. Tag
    final tagItem = SincroFilterItem(
      key: _tagFilterKey,
      label: _filterTag != null ? '#$_filterTag' : 'Tag',
      icon: Icons.label_outline,
      isSelected: _filterTag != null,
      onTap: isDesktop
          ? () => _showDesktopTagFilter(availableTags)
          : () => _showMobileTagFilter(availableTags),
    );

    // 5. Sort Filter
    String sortLabel = 'Ordenar';
    if (_selectedSort == 'date_desc') sortLabel = 'Mais recentes';
    if (_selectedSort == 'date_asc') sortLabel = 'Mais antigas';
    if (_selectedSort == 'alpha_asc') sortLabel = 'A-Z';
    if (_selectedSort == 'alpha_desc') sortLabel = 'Z-A';

    final sortItem = SincroFilterItem(
      key: _sortFilterKey,
      label: sortLabel,
      icon: Icons.sort,
      isSelected: _selectedSort != null,
      activeColor: _selectedSort != null ? AppColors.primary : null,
      onTap: isDesktop
          ? () => _showDesktopSortFilter()
          : () => _showMobileSortFilter(),
    );

    return [focoItem, tarefasItem, agendamentoItem, concluidasItem, atrasadasItem, tagItem, vibrationItem, sortItem, dateItem];
  }



  void _showMobileDateFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.date,
        selectedDate: _selectedDate,
        selectedStartDate: _filterStartDate,
        selectedEndDate: _filterEndDate,
        userData: widget.userData,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedDate = result['date'] as DateTime?;
          _filterStartDate = result['startDate'] as DateTime?;
          _filterEndDate = result['endDate'] as DateTime?;
          _selectedTaskIds.clear();
        });
      }
    });
  }

  void _showMobileVibrationFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.vibration,
        userData: widget.userData,
        selectedVibration: _filterVibration,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _filterVibration = result['vibration'] as int?;
          _selectedTaskIds.clear();
        });
      }
    });
  }

  void _showMobileTagFilter(List<String> availableTags) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.tag,
        availableTags: availableTags,
        selectedTag: _filterTag,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _filterTag = result['tag'] as String?;
          _selectedTaskIds.clear();
        });
      }
    });
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
          _selectedTaskIds.clear();
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
          _selectedTaskIds.clear();
        });
      }
    });
  }

  void _showDesktopDateFilter() {
    showSmartPopup(
      context: _dateFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 400,
        child: MobileFilterSheet(
          type: MobileFilterType.date,
          selectedDate: _selectedDate,
          selectedStartDate: _filterStartDate,
          selectedEndDate: _filterEndDate,
          userData: widget.userData,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedDate = result['date'] as DateTime?;
          _filterStartDate = result['startDate'] as DateTime?;
          _filterEndDate = result['endDate'] as DateTime?;
          _selectedTaskIds.clear();
        });
      }
    });
  }

  void _showDesktopVibrationFilter() {
    showSmartPopup(
      context: _vibrationFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.vibration,
          userData: widget.userData,
          selectedVibration: _filterVibration,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _filterVibration = result['vibration'] as int?;
          _selectedTaskIds.clear();
        });
      }
    });
  }

  void _showDesktopTagFilter(List<String> availableTags) {
    showSmartPopup(
      context: _tagFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.tag,
          availableTags: availableTags,
          selectedTag: _filterTag,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _filterTag = result['tag'] as String?;
          _selectedTaskIds.clear();
        });
      }
    });
  }

  // _closeFilterUI removed as showDialog manages dismissal

  void _handleImageTap(Goal goal) {
    final bool isDesktop =
        MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => ImageUploadDialog(
          userData: widget.userData,
          goal: goal,
        ),
      );
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ImageUploadDialog(
          userData: widget.userData,
          goal: goal,
        ),
        fullscreenDialog: true,
      ));
    }
  }

  // _refreshGoal removed as stream handles updates

  int? _calculatePersonalDay(DateTime? date) {
    if (widget.userData.dataNasc.isEmpty ||
        widget.userData.nomeAnalise.isEmpty ||
        date == null) {
      return null;
    }

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );

    try {
      final dateUtc = date.toUtc();
      final day = engine.calculatePersonalDayForDate(dateUtc);
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool?> _handleSwipeLeft(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title:
            const Text('Excluir Marco?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir este marco? Esta ação não pode ser desfeita.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.deleteTask(widget.userData.uid, task.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marco excluído com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir marco: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  Future<bool?> _handleSwipeRight(TaskModel task) async {
    // Tarefas sem data: toggle foco
    if (!task.hasDeadline) {
      try {
        await _supabaseService.updateTaskFields(
          widget.userData.uid, task.id, {'is_focus': !task.isFocus},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(task.isFocus ? 'Foco removido' : 'Em foco ⚡'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (_) {}
      return false;
    }

    // Tarefas com data: reagendar
    await _taskActionService.rescheduleTask(
      context,
      task,
      widget.userData,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Goal>(
      stream: _goalStream,
      initialData: widget.initialGoal, // INSTANT LOAD - No Spinner
      builder: (context, goalSnapshot) {
        // Only show error if strictly necessary.
        // With initialData, we might not need loading check,
        // but if stream errors out, we might want to show it.
        // If connection is waiting, we use initialData.

        if (goalSnapshot.hasError) {
          return Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                  child: Text("Erro ao carregar meta: ${goalSnapshot.error}")));
        }

        final Goal currentGoal = goalSnapshot.data ?? widget.initialGoal;

        return StreamBuilder<List<TaskModel>>(
          stream: _tasksStream,
          builder: (context, snapshot) {
            // Note: Tasks depend on Goal ID, which doesn't change.
            // If we changed goals, we would need to update stream,
            // but this is a detail screen for a specific ID.

            if (snapshot.connectionState == ConnectionState.waiting) {
              // Tasks loading... show spinner only for tasks part?
              // Or show empty list until loaded?
              // Ideally show spinner.
              return const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(child: CustomLoadingSpinner()));
            }

            if (snapshot.hasError) {
              debugPrint(
                  "Erro no Stream de Tarefas da Meta: ${snapshot.error}");
              return Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(
                      child: Text("Erro ao carregar marcos: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red))));
            }

            final allMilestones = snapshot.data ?? [];

            // Auto-trigger milestone creation if goal has no milestones
            if (allMilestones.isEmpty && !_hasTriggeredFirstMilestone) {
              _hasTriggeredFirstMilestone = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _addMilestone(currentGoal);
              });
            }

            final allTags =
                allMilestones.expand((t) => t.tags).toSet().toList();
            var milestones = List<TaskModel>.from(allMilestones);

            final int progress = allMilestones.isEmpty
                ? 0
                : (allMilestones.where((m) => m.completed).length /
                        allMilestones.length *
                        100)
                    .round();

            // Apply Filters locally (standalone toggles)
            switch (_activeFilter) {
              case 'foco':
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final tomorrowStart = todayStart.add(const Duration(days: 1));
                milestones = milestones.where((t) {
                  if (t.completed) return false;
                  if (!t.hasDeadline && t.isFocus) return true;
                  if (t.isOverdue) return true;
                  if (t.hasDeadline) {
                    final taskDateLocal = t.dueDate!.toLocal();
                    final taskDateOnly = DateTime(taskDateLocal.year, taskDateLocal.month, taskDateLocal.day);
                    return !taskDateOnly.isBefore(todayStart) && taskDateOnly.isBefore(tomorrowStart);
                  }
                  return false;
                }).toList();
                break;
              case 'tarefas':
                milestones = milestones.where((t) => !t.completed && !t.hasDeadline).toList();
                break;
              case 'agendamentos':
                milestones = milestones.where((t) => !t.completed && t.hasDeadline).toList();
                break;
              case 'concluidas':
                milestones = milestones.where((t) => t.completed).toList();
                break;
              case 'atrasadas':
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                milestones = milestones.where((t) {
                  if (t.completed) return false;
                  if (!t.hasDeadline) return false;
                  final taskDateLocal = t.dueDate!.toLocal();
                  final taskDateOnly = DateTime(taskDateLocal.year, taskDateLocal.month, taskDateLocal.day);
                  return taskDateOnly.isBefore(todayStart);
                }).toList();
                break;
              default:
                milestones = milestones.where((t) => !t.completed).toList();
                break;
            }

            // Date Filter (supports single date and range) — usa effectiveDate
            if (_filterStartDate != null || _filterEndDate != null || _selectedDate != null) {
              milestones = milestones.where((t) {
                final effectiveLocal = t.effectiveDate.toLocal();
                final taskDate = DateTime(effectiveLocal.year, effectiveLocal.month, effectiveLocal.day);
                if (_filterStartDate != null && _filterEndDate != null) {
                  final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
                  final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
                  return !taskDate.isBefore(start) && !taskDate.isAfter(end);
                } else if (_selectedDate != null) {
                  return isSameDay(effectiveLocal, _selectedDate!);
                }
                return true;
              }).toList();
            }

            // Vibration Filter — usa effectiveDate para calcular dia pessoal
            if (_filterVibration != null) {
              milestones = milestones.where((t) {
                int? pd = t.personalDay;
                if (pd == null &&
                    widget.userData.nomeAnalise.isNotEmpty &&
                    widget.userData.dataNasc.isNotEmpty) {
                  final engine = NumerologyEngine(
                    nomeCompleto: widget.userData.nomeAnalise,
                    dataNascimento: widget.userData.dataNasc,
                  );
                  final effectiveLocal = t.effectiveDate.toLocal();
                  final dateForCalc = DateTime.utc(effectiveLocal.year, effectiveLocal.month, effectiveLocal.day);
                  pd = engine.calculatePersonalDayForDate(dateForCalc);
                }
                return pd == _filterVibration;
              }).toList();
            }

            if (_filterTag != null && _filterTag!.isNotEmpty) {
              milestones =
                  milestones.where((t) => t.tags.contains(_filterTag)).toList();
            }

            // Search Filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              milestones = milestones.where((t) {
                final textMatch = t.text.toLowerCase().contains(query);
                final tagMatch =
                    t.tags.any((tag) => tag.toLowerCase().contains(query));
                return textMatch || tagMatch;
              }).toList();
            }

            // Apply sort
            if (_selectedSort != null) {
              milestones.sort((a, b) {
                if (_selectedSort == 'alpha_asc') {
                  return a.text.toLowerCase().compareTo(b.text.toLowerCase());
                } else if (_selectedSort == 'alpha_desc') {
                  return b.text.toLowerCase().compareTo(a.text.toLowerCase());
                } else if (_selectedSort == 'date_asc') {
                  final aDate = a.dueDate ?? a.createdAt;
                  final bDate = b.dueDate ?? b.createdAt;
                  return aDate.compareTo(bDate);
                } else if (_selectedSort == 'date_desc') {
                  final aDate = a.dueDate ?? a.createdAt;
                  final bDate = b.dueDate ?? b.createdAt;
                  return bDate.compareTo(aDate);
                }
                return 0;
              });
            }

            return AssistantLayoutManager(
                key: _assistantLayoutKey,
                isMobile:
                    MediaQuery.of(context).size.width < kDesktopBreakpoint,
                isAiSidebarOpen: _isAiSidebarOpen,
                onToggleAiSidebar: () =>
                    setState(() => _isAiSidebarOpen = !_isAiSidebarOpen),
                assistant: AssistantPanel(
                  userData: widget.userData,
                  activeContext: 'Goal Detail: ${currentGoal.title}',
                  onClose: () {
                    if (MediaQuery.of(context).size.width >= kDesktopBreakpoint) {
                      setState(() => _isAiSidebarOpen = false);
                    } else {
                      _assistantLayoutKey.currentState?.closeAssistant();
                    }
                  },
                ),
                child: Scaffold(
                  backgroundColor: AppColors.background,
                  body: ScreenInteractionListener(
                    controller: _fabOpacityController,
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isDesktop =
                                constraints.maxWidth >= kDesktopBreakpoint;
                            final double horizontalPadding =
                                isDesktop ? 40.0 : 16.0;
                            final double listHorizontalPadding =
                                isDesktop ? 40.0 : 16.0;

                            if (isDesktop) {
                              return _buildDesktopLayout(context, currentGoal,
                                  milestones, progress, allTags);
                            }

                            return SafeArea(
                              child: Column(
                                children: [
                                  // ─── FIXED: App Bar ───
                                  AppBar(
                                    backgroundColor: AppColors.background,
                                    elevation: 0,
                                    titleSpacing: 0,
                                    leading: const BackButton(color: AppColors.primary),
                                    title: const Text('Metas',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 18)),
                                    actions: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: GestureDetector(
                                            onTap: () {
                                              _assistantLayoutKey.currentState
                                                  ?.openAssistant();
                                              setState(() {}); // For visual update if needed
                                            },
                                            child: const AgentStarIcon(
                                              size: 28,
                                              isStatic: true,
                                              isHollow: false,
                                              isWhiteFilled: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // ─── COLLAPSIBLE: Card Carousel ───
                                  AnimatedCrossFade(
                                    firstChild: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: PageView(
                                            padEnds: false,
                                            controller: _pageController,
                                            onPageChanged: (index) {
                                              setState(() {
                                                _currentPage = index;
                                              });
                                            },
                                            children: [
                                              // 1. Image Card (First)
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        horizontalPadding,
                                                    vertical: 8.0),
                                                child: GoalImageCard(
                                                  goal: currentGoal,
                                                  onTap: () =>
                                                      _handleImageTap(
                                                          currentGoal),
                                                ),
                                              ),
                                              // 2. Info Card (Second)
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        horizontalPadding,
                                                    vertical: 8.0),
                                                child:
                                                    _CollapsibleGoalInfoCard(
                                                  goal: currentGoal,
                                                  progress: progress,
                                                  onEdit: () =>
                                                      _handleEditGoal(
                                                          currentGoal),
                                                  onDelete: () =>
                                                      _handleDeleteGoal(
                                                          currentGoal),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Custom Icon Indicators
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildIndicatorIcon(
                                                0, Icons.image),
                                            const SizedBox(width: 16),
                                            _buildIndicatorIcon(
                                                1, Icons.bar_chart_rounded),
                                          ],
                                        ),
                                      ],
                                    ),
                                    secondChild: const SizedBox.shrink(),
                                    crossFadeState: _isMilestonesExpanded
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    duration:
                                        const Duration(milliseconds: 300),
                                    sizeCurve: Curves.easeInOut,
                                  ),

                                  // ─── FIXED: Toolbar ───
                                  _buildToolbar(false, milestones,
                                      allTags),

                                  // ─── SCROLLABLE: Milestones List ───
                                  Expanded(
                                    child: _buildMilestonesListWidget(
                                        milestones: milestones,
                                        horizontalPadding: listHorizontalPadding),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (_isLoading)
                          Container(
                              color: Colors.black.withValues(alpha: 0.6),
                              child:
                                  const Center(child: CustomLoadingSpinner())),
                      ],
                    ),
                  ),
                  floatingActionButton: TransparentFabWrapper(
                          controller: _fabOpacityController,
                          child: FloatingActionButton(
                            onPressed: () => _addMilestone(currentGoal),
                            backgroundColor: AppColors.primary,
                            tooltip: 'Novo Marco',
                            heroTag: 'fab_goal_detail',
                            shape: const CircleBorder(),
                            child: const Icon(Icons.add,
                                color: Colors.white),
                          ),
                        ),
                ));
          },
        );
      },
    );
  }

  Widget _buildMilestonesListWidget(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
    if (milestones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 64.0, horizontal: 20),
          child: Text(
            'Nenhum marco adicionado ainda.\nUse o botão "+" para começar!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.secondaryText, fontSize: 16, height: 1.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
          left: horizontalPadding, right: horizontalPadding, bottom: 80),
      itemCount: milestones.length,
      itemBuilder: (context, index) {
        final task = milestones[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: TaskItem(
            key: ValueKey(task.id),
            task: task,
            showGoalIconFlag: false,
            showTagsIconFlag: true,
            showVibrationPillFlag: true,
            selectionMode: _isSelectionMode,
            selectedTaskIds: _selectedTaskIds,
            onTaskSelected: _onTaskSelected,
            onToggle: (isCompleted) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _supabaseService.updateTaskCompletion(
                    widget.userData.uid, task.id,
                    completed: isCompleted);
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('Erro ao atualizar marco: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            onSwipeLeft: (t) => _handleSwipeLeft(t),
            onTap: () => _handleMilestoneTap(task),
          ),
        );
      },
    );
  }

  Widget _buildMilestonesListSliver(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
    if (milestones.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 64.0, horizontal: 20),
            child: Text(
              'Nenhum marco adicionado ainda.\nUse o botão ✨ ou o "+" para começar!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.secondaryText, fontSize: 16, height: 1.5),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = milestones[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TaskItem(
                key: ValueKey(task.id),
                task: task,
                showGoalIconFlag: false,
                showTagsIconFlag: true,
                showVibrationPillFlag: true,
                selectionMode: _isSelectionMode,
                selectedTaskIds: _selectedTaskIds,
                onTaskSelected: _onTaskSelected,
                onToggle: (isCompleted) async {
                  try {
                    await _supabaseService.updateTaskCompletion(
                        widget.userData.uid, task.id,
                        completed: isCompleted);
                  } catch (e) {
                    // handled
                  }
                },
                onTap: () => _handleMilestoneTap(task),
                // Fix: Pass swipe callbacks directly to TaskItem
                onSwipeLeft: (t) => _handleSwipeLeft(t),
                onSwipeRight: (t) => _handleSwipeRight(t),
              ),
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Goal currentGoal,
      List<TaskModel> milestones, int progress, List<String> allTags) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.primary),
        title: const Text('Metas',
            style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN (Fixed width, scrollable if height overflows)
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: Column(
                        children: [
                          GoalImageCard(
                              goal: currentGoal,
                              onTap: () => _handleImageTap(currentGoal)),
                          const SizedBox(height: 24),
                          _CircularGoalInfoCard(
                            goal: currentGoal,
                            progress: progress,
                            onEdit: () => _handleEditGoal(currentGoal),
                            onDelete: () => _handleDeleteGoal(currentGoal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // RIGHT COLUMN (Fixed Header + Scrollable List)
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildToolbar(true, milestones, allTags),
                      ),

                      // SCROLLABLE LIST
                      Expanded(
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            _buildMilestonesListSliver(
                              milestones: milestones,
                              horizontalPadding: 0,
                            ),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 80)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Custom Indicator Builder - Subtle dot-style with tiny icons
  Widget _buildIndicatorIcon(int index, IconData icon) {
    final bool isSelected = _currentPage == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : AppColors.tertiaryText,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Circular (Desktop e Mobile) - Refatorado para remover botões de ação interna
// ---------------------------------------------------------------------------
// Card Circular (Desktop e Mobile) - Refatorado para remover botões de ação interna
class _CircularGoalInfoCard extends StatefulWidget {
  final Goal goal;
  final int progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CircularGoalInfoCard({
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CircularGoalInfoCard> createState() => _CircularGoalInfoCardState();
}

class _CircularGoalInfoCardState extends State<_CircularGoalInfoCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovering
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border.withValues(alpha: 0.3),
            width: _isHovering ? 1.5 : 1.0,
          ),
          boxShadow: _isHovering
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Title (Centered or Left? Original was centered column but inside Row?)
                // Original had Row(Expanded(Text), Menu).
                // Now we Center the content but Menu is absolute.
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0), // Avoid overlap with menu
                  child: Text(
                    widget.goal.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 24),
                // Circular Progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: widget.progress / 100,
                        strokeWidth: 12,
                        backgroundColor: AppColors.background,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.progress}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Concluído',
                          style: TextStyle(
                              color: AppColors.secondaryText, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Details
                if (widget.goal.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      widget.goal.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                  ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag,
                          color: Color(0xFF8B5CF6), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.goal.targetDate != null
                            ? DateFormat('dd MMM yyyy')
                                .format(widget.goal.targetDate!)
                            : 'Sem data',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Menu Button (Absolute Top Right)
            Positioned(
              top: -10, // Adjust to move higher
              right: -10, // Adjust to move right
              child: PopupMenuButton<String>(
                icon:
                    const Icon(Icons.more_vert, color: AppColors.secondaryText),
                color: AppColors.cardBackground,
                onSelected: (value) {
                  if (value == 'edit') widget.onEdit();
                  if (value == 'delete') widget.onDelete();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.white),
                      title:
                          Text('Editar', style: TextStyle(color: Colors.white)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.redAccent),
                      title: Text('Excluir',
                          style: TextStyle(color: Colors.redAccent)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Retangular Colapsável (Mobile)
class _CollapsibleGoalInfoCard extends StatefulWidget {
  final Goal goal;
  final int progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollapsibleGoalInfoCard({
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CollapsibleGoalInfoCard> createState() =>
      _CollapsibleGoalInfoCardState();
}

class _CollapsibleGoalInfoCardState extends State<_CollapsibleGoalInfoCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onEdit, // Entire card triggers edit
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovering
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: _isHovering ? 1.5 : 0.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
              if (_isHovering)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max, // Fill parent
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.goal.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.goal.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.goal.description,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 32), // Spacer + more height

              // Footer: Date + Percent + Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.goal.targetDate != null)
                    _buildDateBadge(widget.goal.targetDate!)
                  else
                    const SizedBox(),
                  Text(
                    '${widget.progress}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.progress / 100,
                  backgroundColor: AppColors.background,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateBadge(DateTime date) {
    final months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C3E), // Darker background (Card Surface)
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag,
              color: Color(0xFF8B5CF6), size: 16), // Purple Flag
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

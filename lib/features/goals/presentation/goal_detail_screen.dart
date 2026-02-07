// lib/features/goals/presentation/goal_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart'; // Added
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
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
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_filter_panel.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/foco_do_dia_screen.dart'; // For TaskViewScope
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';

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
  bool _isLoading = false;
  bool _isAiSidebarOpen = false;
  // NEW STATE: Controls the visibility of the top carousel
  bool _isMilestonesExpanded = false; 
  final FabOpacityController _fabOpacityController = FabOpacityController(); 

  static const double kDesktopBreakpoint = 768.0;
  static const double kMaxContentWidth = 1200.0;
  
  // Filter States
  TaskViewScope _currentScope = TaskViewScope.todas;
  DateTime? _filterDate;
  int? _filterVibration;
  String? _filterTag;
  
  // Selection Mode States
  bool _isSelectionMode = false;
  Set<String> _selectedTaskIds = {}; // IDs of selected tasks

  OverlayEntry? _filterOverlay;
  final GlobalKey _filterButtonKey = GlobalKey();

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

  // Handle goal editing
  void _handleEditGoal(Goal goal) {
    final bool isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

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
      // Mobile: Navigate to full screen
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => CreateGoalScreen(
          userData: widget.userData,
          goalToEdit: goal,
        ),
        fullscreenDialog: true,
      ));
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
        await _supabaseService.deleteGoal(
            widget.userData.uid, goal.id);
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
              recurrenceType: parsedTask.recurrenceRule?.type ?? RecurrenceType.none,
              recurrenceDaysOfWeek: parsedTask.recurrenceRule?.daysOfWeek ?? [],
              recurrenceEndDate: parsedTask.recurrenceRule?.endDate,
              // Reminder Mapping
              reminderTime: parsedTask.reminderTime,
              reminderAt: parsedTask.reminderAt,
            );

            _supabaseService
                .addTask(widget.userData.uid, newTask)
                .catchError((error) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                    content: Text('Erro ao salvar marco: $error'),
                    backgroundColor: Colors.red),
              );
            });
          },
        );
      },
    );
  }

  void _handleMilestoneTap(TaskModel task) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return TaskDetailModal(
          task: task,
          userData: widget.userData,
        );
      },
    );
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
          title: Text('Excluir ${_selectedTaskIds.length} marcos?', style: const TextStyle(color: Colors.white)),
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
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marcos excluídos com sucesso!'), backgroundColor: AppColors.success));
             _toggleSelectionMode(); // Exit selection mode
           }
         } catch (e) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
           }
         }
      }
  }

  void _openFilterUI() {
    showSmartPopup(
      context: _filterButtonKey.currentContext!,
      builder: (context) => GoalFilterPanel(
        initialScope: _currentScope,
        initialDate: _filterDate,
        initialVibration: _filterVibration,
        initialTag: _filterTag,
        availableTags: const [], // TODO: Tags
        userData: widget.userData,
        onApply: (scope, date, vibe, tag) {
          setState(() {
            _currentScope = scope;
            _filterDate = date;
            _filterVibration = vibe;
            _filterTag = tag;
          });
          Navigator.pop(context); // Close dialog
        },
        onClearInPanel: () {
            setState(() {
              _currentScope = TaskViewScope.todas;
              _filterDate = null;
              _filterVibration = null;
              _filterTag = null;
            });
            // goal_filter_panel handles pop on Clear internally
        },
      ),
    );
  }

  // _closeFilterUI removed as showDialog manages dismissal


  void _handleImageTap(Goal goal) {
    final bool isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

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
        title: const Text('Excluir Marco?',
            style: TextStyle(color: Colors.white)),
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
              body: Center(child: Text("Erro ao carregar meta: ${goalSnapshot.error}")));
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
              debugPrint("Erro no Stream de Tarefas da Meta: ${snapshot.error}");
              return Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(
                      child: Text("Erro ao carregar marcos: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red))));
            }

            var milestones = snapshot.data ?? [];
            final int progress = milestones.isEmpty
                ? 0
                : (milestones.where((m) => m.completed).length /
                        milestones.length *
                        100)
                    .round();

            // Apply Filters locally
            if (_currentScope == TaskViewScope.concluidas) {
              milestones = milestones.where((t) => t.completed).toList();
            } else if (_currentScope == TaskViewScope.atrasadas) {
               final now = DateTime.now();
               milestones = milestones.where((t) => !t.completed && t.dueDate != null && t.dueDate!.isBefore(now)).toList();
            } 

            if (_filterDate != null) {
              milestones = milestones.where((t) {
                if (t.dueDate == null) return false;
                final tDate = t.dueDate!.toLocal();
                final fDate = _filterDate!;
                return tDate.year == fDate.year && tDate.month == fDate.month && tDate.day == fDate.day;
              }).toList();
            }

            if (_filterVibration != null) {
              milestones = milestones.where((t) => t.personalDay == _filterVibration).toList();
            }

            if (_filterTag != null && _filterTag!.isNotEmpty) {
              milestones = milestones.where((t) => t.tags.contains(_filterTag)).toList();
            }

            return AssistantLayoutManager(
              isMobile: MediaQuery.of(context).size.width < kDesktopBreakpoint,
              isAiSidebarOpen: _isAiSidebarOpen,
              onToggleAiSidebar: () => setState(() => _isAiSidebarOpen = !_isAiSidebarOpen),
              assistant: AssistantPanel(
                userData: widget.userData,
                activeContext: 'Goal Detail: ${currentGoal.title}',
                onClose: () => setState(() => _isAiSidebarOpen = false),
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
                          final double horizontalPadding = isDesktop ? 24.0 : 12.0;
                          final double listHorizontalPadding = isDesktop ? 24.0 : 12.0;

                          if (isDesktop) {
                            return _buildDesktopLayout(context, currentGoal, milestones, progress);
                          }

                          return SafeArea(
                            child: CustomScrollView(
                              physics: _isMilestonesExpanded 
                                  ? const ClampingScrollPhysics() 
                                  : const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // Mobile App Bar
                                const SliverAppBar(
                            backgroundColor: AppColors.background,
                            elevation: 0,
                            pinned: true,
                            leading: BackButton(color: AppColors.primary),
                            title: Text('Jornadas',
                                style:
                                    TextStyle(color: Colors.white, fontSize: 18)),
                          ),
                          
                          // Mobile Content
                          // Collapsible Header (Carousel)
                          SliverToBoxAdapter(
                            child: AnimatedCrossFade(
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
                                            horizontal: horizontalPadding, vertical: 8.0),
                                        child: GoalImageCard(
                                          goal: currentGoal,
                                          onTap: () => _handleImageTap(currentGoal),
                                        ),
                                      ),
                                      // 2. Info Card (Second)
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: horizontalPadding, vertical: 8.0),
                                        child: _CollapsibleGoalInfoCard(
                                          goal: currentGoal,
                                          progress: progress,
                                          onEdit: () => _handleEditGoal(currentGoal),
                                          onDelete: () => _handleDeleteGoal(currentGoal),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Custom Icon Indicators
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildIndicatorIcon(0, Icons.image),
                                    const SizedBox(width: 16),
                                    _buildIndicatorIcon(1, Icons.bar_chart_rounded),
                                  ],
                                ),
                                ],
                              ),
                              secondChild: const SizedBox.shrink(),
                              crossFadeState: _isMilestonesExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 300),
                              sizeCurve: Curves.easeInOut,
                            ),
                          ),
                          
                          // Header for Milestones
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(horizontalPadding,
                                  8.0, horizontalPadding, 8.0),
                              child: _buildMilestonesHeader(currentGoal),
                            ),
                          ),
                          
                          // Selection Actions (only if active)
                           if (_isSelectionMode || _currentScope != TaskViewScope.todas || _filterDate != null || _filterVibration != null || _filterTag != null)
                              SliverToBoxAdapter(
                                child: _buildSelectionControls(milestones, horizontalPadding: horizontalPadding),
                              ),

                          _buildMilestonesListSliver(
                              milestones: milestones,
                              horizontalPadding: listHorizontalPadding),
                              
                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
                    );
                  },
                ),



                if (_isLoading)
                  Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: const Center(child: CustomLoadingSpinner())),
              ],
            ),
          ),
          floatingActionButton: milestones.isEmpty
              ? null
              : TransparentFabWrapper(
                  controller: _fabOpacityController,
                  child: FloatingActionButton(
                          onPressed: () => _addMilestone(currentGoal),
                          backgroundColor: AppColors.primary,
                          tooltip: 'Novo Marco',
                          heroTag: 'fab_goal_detail',
                          shape: const CircleBorder(),
                          child: const Icon(Icons.place, color: Colors.white), // Free: Novo Marco direto
                        ),
                ),
            ));
          },
        );
      },
    );
  }

  // Controls for Selection Mode (Shared between Mobile/Desktop)
  Widget _buildSelectionControls(List<TaskModel> milestones, {double horizontalPadding = 0}) {
    if (!_isSelectionMode) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8.0),
      child: Row(
        children: [
          // 1. Selecionar Todas (Primeiro)
          Transform.scale(
            scale: 0.9,
            child: Checkbox(
              value: milestones.isNotEmpty &&
                  _selectedTaskIds.length == milestones.length,
              onChanged: milestones.isEmpty
                  ? null
                  : (value) => _selectAll(milestones),
              visualDensity: VisualDensity.compact,
              checkColor: Colors.white,
              activeColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border, width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          InkWell(
            onTap: milestones.isEmpty ? null : () => _selectAll(milestones),
            child: const Text(
              'Selecionar Todas',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),

          const SizedBox(width: 16),

          // 2. Botão Excluir (Segundo)
          TextButton.icon(
            onPressed:
                _selectedTaskIds.isEmpty ? null : _deleteSelectedTasks,
            icon: Icon(Icons.delete_outline,
                color: _selectedTaskIds.isNotEmpty
                    ? Colors.redAccent
                    : AppColors.tertiaryText),
            label: Text('Excluir (${_selectedTaskIds.length})',
                style: TextStyle(
                    color: _selectedTaskIds.isNotEmpty
                        ? Colors.redAccent
                        : AppColors.tertiaryText)),
          ),

          const Spacer(),

          // 3. Fechar (Direita)
          IconButton(
            onPressed: _toggleSelectionMode,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Cancelar Seleção',
          ),
        ],
      ),
    );
  }

  // Header do marcos (com botão de expandir e IA simplificado)
  Widget _buildMilestonesHeader(Goal goal) {
    final bool isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Marcos da Jornada',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Suggestion Button (Icon Only)
            // Selection Button
            IconButton(
              onPressed: _toggleSelectionMode,
              icon: Icon(
                  _isSelectionMode ? Icons.close : Icons.checklist_rounded,
                  color: _isSelectionMode ? Colors.white : AppColors.secondaryText,
              ),
              tooltip: _isSelectionMode ? 'Cancelar' : 'Selecionar',
               style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(8),
                   side: BorderSide(color: _isSelectionMode ? Colors.white : AppColors.border),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Filter Button
            // Filter Button
            IconButton(
              key: _filterButtonKey,
              onPressed: _openFilterUI,
              icon: Icon(
                Icons.filter_alt_outlined, // Funnel Icon
                color: (_currentScope != TaskViewScope.todas || _filterDate != null || _filterVibration != null || _filterTag != null) 
                    ? AppColors.primary 
                    : AppColors.secondaryText,
              ),
              tooltip: 'Filtrar',
               style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(8),
                   side: BorderSide(color: (_currentScope != TaskViewScope.todas || _filterDate != null || _filterVibration != null || _filterTag != null) ? AppColors.primary : AppColors.border),
                ),
              ),
            ),
            
            // Expand/Collapse Button (Mobile Only)
            if (!isDesktop)
              IconButton(
                onPressed: () {
                  setState(() {
                    _isMilestonesExpanded = !_isMilestonesExpanded;
                  });
                },
                icon: AnimatedRotation(
                  turns: _isMilestonesExpanded ? 0.5 : 0.0, 
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(
                    Icons.keyboard_arrow_up,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
          ],
        ),
      ],
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
            'Nenhum marco adicionado ainda.\nUse o botão ✨ ou o "+" para começar!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.secondaryText, fontSize: 16, height: 1.5),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: List.generate(milestones.length, (index) {
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
        }),
      ),
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
  Widget _buildDesktopLayout(BuildContext context, Goal currentGoal, List<TaskModel> milestones, int progress) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.primary),
        title: const Text('Jornadas', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                            onTap: () => _handleImageTap(currentGoal)
                          ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMilestonesHeader(currentGoal),
                             if (_isSelectionMode || _currentScope != TaskViewScope.todas || _filterDate != null || _filterVibration != null || _filterTag != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: _buildSelectionControls(milestones, horizontalPadding: 0),
                                ),
                          ],
                        ),
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
                             const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
        _pageController.animateToPage(
          index, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeInOut
        );
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
            color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.4),
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
                ? AppColors.primary.withOpacity(0.5) 
                : AppColors.border.withOpacity(0.3),
            width: _isHovering ? 1.5 : 1.0,
          ),
          boxShadow: _isHovering ? [
             BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0), // Avoid overlap with menu
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
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C), 
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag, color: Color(0xFF8B5CF6), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.goal.targetDate != null
                            ? DateFormat('dd MMM yyyy').format(widget.goal.targetDate!)
                            : 'Sem data',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
                icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
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
                      title: Text('Editar', style: TextStyle(color: Colors.white)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.redAccent),
                      title: Text('Excluir', style: TextStyle(color: Colors.redAccent)),
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
class _CollapsibleGoalInfoCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
         boxShadow: [
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
          mainAxisSize: MainAxisSize.max, // Fill parent
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Header: Title (With padding right to avoid menu)
             Padding(
                padding: const EdgeInsets.only(right: 32.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (goal.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          goal.description,
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
             ),
            
            const SizedBox(height: 32), // Spacer + more height

            // Footer: Date + Percent + Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (goal.targetDate != null)
                   _buildDateBadge(goal.targetDate!)
                else
                   const SizedBox(),
                Text(
                  '$progress%',
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
                value: progress / 100,
                backgroundColor: AppColors.background,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ),
        // Menu Button (Top Right)
        Positioned(
          top: -8,
          right: -8,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, color: AppColors.secondaryText, size: 20),
            color: AppColors.cardBackground,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit, color: Colors.white),
                  title: Text('Editar', style: TextStyle(color: Colors.white)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.redAccent),
                  title: Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ]
      ),
    );
  }

  Widget _buildDateBadge(DateTime date) {
    final months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
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
          const Icon(Icons.flag, color: Color(0xFF8B5CF6), size: 16), // Purple Flag
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

  // Helper method needs to be outside or we need to add it to state class
  // Since we are inside _CollapsibleGoalInfoCard (Stateless), we can't add methods to State class from here easily unless we move it.
  // Wait, I am replacing _CollapsibleGoalInfoCard. 
  // The _buildIndicatorIcon must correspond to the State class method, but I am editing _CollapsibleGoalInfoCard here.
  // I will add the _buildIndicatorIcon method to the _GoalDetailScreenState class (previous chunk).
  // This chunk ONLY updates _buildDateBadge inside _CollapsibleGoalInfoCard.

}

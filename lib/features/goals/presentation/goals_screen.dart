import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

import 'package:sincro_app_flutter/features/goals/presentation/goal_detail_screen.dart';
// IMPORT ADICIONADO
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_card.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/common/widgets/sincro_toolbar.dart';
import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart';
import 'package:sincro_app_flutter/common/widgets/mobile_filter_sheet.dart';
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';

class GoalsScreen extends StatefulWidget {
  final UserModel userData;
  const GoalsScreen({super.key, required this.userData});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final String _userId = AuthRepository().currentUser?.id ?? '';
  final FabOpacityController _fabOpacityController = FabOpacityController();

  String _searchQuery = '';
  String? _selectedSort;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  DateTime? _selectedDate; // Single-date filter

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedGoalIds = {};

  final GlobalKey _sortFilterKey = GlobalKey();
  final GlobalKey _dateFilterKey = GlobalKey();

  static const double kDesktopBreakpoint = 768.0;

  late Stream<List<Goal>> _goalsStream;

  @override
  void initState() {
    super.initState();
    if (_userId.isNotEmpty) {
      _goalsStream = _supabaseService.getGoalStream(_userId);
    }
    if (_userId.isEmpty) {
      debugPrint("GoalsScreen: Erro crítico - UID do usuário não encontrado!");
    }
  }

  @override
  void dispose() {
    _fabOpacityController.dispose();
    super.dispose();
  }

  // *** MÉTODO ATUALIZADO PARA LIDAR COM DESKTOP/MOBILE ***
  void _navigateToCreateGoal([Goal? goalToEdit]) {
    if (!mounted) return;

    final bool isDesktop =
        MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      final messenger = ScaffoldMessenger.of(context);
      // --- VERSÃO DESKTOP: CHAMA O DIÁLOGO ---
      showDialog(
        context: context,
        barrierDismissible: false, // Impede fechar clicando fora
        builder: (BuildContext dialogContext) {
          return CreateGoalDialog(
            userData: widget.userData,
            goalToEdit: goalToEdit,
          );
        },
      ).then((result) {
        if (result == true) {
          if (!mounted) return;
          setState(() {
            _goalsStream = _supabaseService.getGoalStream(_userId);
          });
          // Meta salva com sucesso, opcionalmente mostrar um SnackBar
          messenger.showSnackBar(
            SnackBar(
              content: Text(goalToEdit != null
                  ? "Jornada atualizada com sucesso!"
                  : "Nova jornada criada com sucesso!"),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      });
    } else {
      // --- VERSÃO MOBILE: BOTTOM SHEET ---
      CreateGoalDialog.showAsBottomSheet(
        context,
        userData: widget.userData,
        goalToEdit: goalToEdit,
      ).then((result) {
        if (result == true) {
          if (!mounted) return;
          setState(() {
            _goalsStream = _supabaseService.getGoalStream(_userId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(goalToEdit != null
                  ? "Meta atualizada com sucesso!"
                  : "Nova meta criada com sucesso!"),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      });
    }
  }

  void _navigateToGoalDetail(Goal goal) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => GoalDetailScreen(
        initialGoal: goal,
        userData: widget.userData,
      ),
      settings: RouteSettings(name: '/goal-detail', arguments: {
        'goalId': goal.id,
        'goalTitle': goal.title,
      }),
    ));
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedGoalIds.clear();
    });
  }

  void _onGoalSelected(String goalId) {
    setState(() {
      if (_selectedGoalIds.contains(goalId)) {
        _selectedGoalIds.remove(goalId);
      } else {
        _selectedGoalIds.add(goalId);
      }
      // Auto-exit selection mode if no items selected
      if (_selectedGoalIds.isEmpty) _isSelectionMode = false;
    });
  }

  Future<void> _handleDeleteSelectedGoals(List<Goal> allGoals) async {
    if (_selectedGoalIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final count = _selectedGoalIds.length;
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirmar Exclusão',
              style: TextStyle(color: AppColors.primaryText)),
          content: Text(
              'Tem certeza que deseja excluir $count jornada${count > 1 ? 's' : ''} selecionada${count > 1 ? 's' : ''}? Esta ação não pode ser desfeita.',
              style: const TextStyle(color: AppColors.secondaryText)),
          actions: [
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.secondaryText)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child:
                  Text('Excluir', style: TextStyle(color: Colors.red.shade400)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        for (final goalId in _selectedGoalIds.toList()) {
          await _supabaseService.deleteGoal(_userId, goalId);
        }
        setState(() {
          _selectedGoalIds.clear();
          _isSelectionMode = false;
          _goalsStream = _supabaseService.getGoalStream(_userId);
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('$count jornada${count > 1 ? 's' : ''} excluída${count > 1 ? 's' : ''} com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir jornadas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // *** NOVO MÉTODO PARA DELETAR JORNADA ***
  Future<void> _handleDeleteGoal(BuildContext context, Goal goal) async {
    final messenger = ScaffoldMessenger.of(context);
    // 1. Mostrar diálogo de confirmação
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirmar Exclusão',
              style: TextStyle(color: AppColors.primaryText)),
          content: Text(
              'Tem certeza que deseja excluir a jornada "${goal.title}"? Esta ação não pode ser desfeita.',
              style: const TextStyle(color: AppColors.secondaryText)),
          actions: [
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.secondaryText)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child:
                  Text('Excluir', style: TextStyle(color: Colors.red.shade400)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    // 2. Se confirmado, deletar do Firestore
    if (confirmDelete == true) {
      try {
        await _supabaseService.deleteGoal(_userId, goal.id);
        setState(() {
          _goalsStream = _supabaseService.getGoalStream(_userId);
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Jornada excluída com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint("Erro ao deletar meta: $e");
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir jornada: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: Text("Erro: Usuário não identificado.",
                style: TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: ScreenInteractionListener(
        controller: _fabOpacityController,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StreamBuilder<List<Goal>>(
                        stream: _goalsStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(child: CustomLoadingSpinner());
                          }
                          if (snapshot.hasError) {
                            debugPrint(
                                "GoalsScreen: Erro no Stream de Metas: ${snapshot.error}");
                            return Center(
                                child: Text(
                                    'Erro ao carregar jornadas: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red)));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            if (_searchQuery.isEmpty) {
                              return Column(
                                children: [
                                  _buildToolbar(isDesktop, []),
                                  Expanded(child: _buildEmptyState()),
                                ],
                              );
                            }
                          }

                          final allGoals = snapshot.data ?? [];

                          // Filter by search query
                          var goals = allGoals.where((g) {
                            if (_searchQuery.isEmpty) return true;
                            return g.title
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase());
                          }).toList();

                          // Apply Date filter (by targetDate)
                          if (_filterStartDate != null || _filterEndDate != null || _selectedDate != null) {
                            goals = goals.where((g) {
                              final date = g.targetDate;
                              if (date == null) return false;
                              final d = DateTime(date.year, date.month, date.day);
                              if (_filterStartDate != null && _filterEndDate != null) {
                                final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
                                final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
                                return !d.isBefore(start) && !d.isAfter(end);
                              } else if (_selectedDate != null) {
                                final sel = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
                                return d == sel;
                              }
                              return true;
                            }).toList();
                          }

                          // Apply Sort
                          if (_selectedSort != null) {
                            goals.sort((a, b) {
                              if (_selectedSort == 'alpha_asc') {
                                return a.title
                                    .toLowerCase()
                                    .compareTo(b.title.toLowerCase());
                              } else if (_selectedSort == 'alpha_desc') {
                                return b.title
                                    .toLowerCase()
                                    .compareTo(a.title.toLowerCase());
                              } else if (_selectedSort == 'date_desc') {
                                final aDate = a.targetDate ?? a.createdAt;
                                final bDate = b.targetDate ?? b.createdAt;
                                return bDate.compareTo(aDate);
                              } else if (_selectedSort == 'date_asc') {
                                final aDate = a.targetDate ?? a.createdAt;
                                final bDate = b.targetDate ?? b.createdAt;
                                return aDate.compareTo(bDate);
                              }
                              return 0;
                            });
                          }

                          if (goals.isEmpty && _searchQuery.isNotEmpty) {
                            return Column(
                              children: [
                                _buildToolbar(isDesktop, goals),
                                const Expanded(
                                  child: Center(
                                      child: Text(
                                          "Nenhuma meta encontrada para a busca.",
                                          style: TextStyle(
                                              color: AppColors.secondaryText))),
                                ),
                              ],
                            );
                          }

                          if (goals.isEmpty && _searchQuery.isEmpty) {
                            return Column(
                              children: [
                                _buildToolbar(isDesktop, goals),
                                Expanded(child: _buildEmptyState()),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              _buildToolbar(isDesktop, goals),
                              Expanded(
                                child: isDesktop
                                    ? _buildDesktopGrid(constraints, goals)
                                    : _buildMobileList(goals),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ), // This closes ScreenInteractionListener
      floatingActionButton: TransparentFabWrapper(
        controller: _fabOpacityController,
        child: FloatingActionButton(
          onPressed: _navigateToCreateGoal,
          backgroundColor: AppColors.primary,
          tooltip: 'Nova Jornada',
          heroTag: 'fab_goals_screen',
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildToolbar(bool isDesktop, List<Goal> goals) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SincroToolbar(
        title: 'Metas',
        forceDesktop: isDesktop,
        filters: _buildFilterItems(isDesktop),
        isSelectionMode: _isSelectionMode,
        isAllSelected: _selectedGoalIds.length == goals.length && goals.isNotEmpty,
        selectedCount: _selectedGoalIds.length,
        onToggleSelectionMode: _toggleSelectionMode,
        onToggleSelectAll: () {
          setState(() {
            if (_selectedGoalIds.length == goals.length) {
              _selectedGoalIds.clear();
            } else {
              _selectedGoalIds.addAll(goals.map((g) => g.id));
            }
          });
        },
        onDeleteSelected: () => _handleDeleteSelectedGoals(goals),
        onSearchChanged: (val) => setState(() => _searchQuery = val),
        onClearFilters: () {
          setState(() {
            _selectedSort = null;
            _filterStartDate = null;
            _filterEndDate = null;
            _selectedDate = null;
          });
        },
      ),
    );
  }

  Widget _buildDesktopGrid(BoxConstraints constraints, List<Goal> goals) {
    final int columns = constraints.maxWidth >= 1200 ? 3 : 2;
    return MasonryGridView.count(
      padding: const EdgeInsets.only(top: 8, bottom: 100, left: 40, right: 40),
      crossAxisCount: columns,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        return GoalCard(
          goal: goal,
          userId: _userId,
          selectionMode: _isSelectionMode,
          isSelected: _selectedGoalIds.contains(goal.id),
          onTap: _isSelectionMode
              ? () => _onGoalSelected(goal.id)
              : () => _navigateToGoalDetail(goal),
          onDelete: () => _handleDeleteGoal(context, goal),
          onEdit: () => _navigateToCreateGoal(goal),
          onSelected: () => _onGoalSelected(goal.id),
        );
      },
    );
  }

  Widget _buildMobileList(List<Goal> goals) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100, left: 16, right: 16),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GoalCard(
            goal: goal,
            userId: _userId,
            selectionMode: _isSelectionMode,
            isSelected: _selectedGoalIds.contains(goal.id),
            onTap: _isSelectionMode
                ? () => _onGoalSelected(goal.id)
                : () => _navigateToGoalDetail(goal),
            onDelete: () => _handleDeleteGoal(context, goal),
            onEdit: () => _navigateToCreateGoal(goal),
            onSelected: () => _onGoalSelected(goal.id),
          ),
        );
      },
    );
  }

  List<SincroFilterItem> _buildFilterItems(bool isDesktop) {
    // 1. Sort Filter
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

    // 2. Date Filter (rich label como FocoDoDia)
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
      activeColor: isDateActive ? AppColors.primary : null,
      onTap: isDesktop
          ? () => _showDesktopDateFilter()
          : () => _showMobileDateFilter(),
    );

    return [sortItem, dateItem];
  }

  // --- Mobile Filter Handlers ---
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
        });
      }
    });
  }

  // --- Desktop Filter Handlers ---
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
        });
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              color: AppColors.tertiaryText,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhuma jornada iniciada',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Crie sua primeira jornada para começar a evoluir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.tertiaryText),
            ),
          ],
        ),
      ),
    );
  }
}

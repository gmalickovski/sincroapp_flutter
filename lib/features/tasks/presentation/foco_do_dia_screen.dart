// lib/features/tasks/presentation/foco_do_dia_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import necessário para DateFormat
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
// Import para getColorsForVibration e showVibrationInfoModal
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/tasks_list_view.dart';
import 'widgets/task_input_modal.dart'; // Mantido para o botão Adicionar (+)
import 'widgets/task_detail_modal.dart'; // Importa o novo modal de detalhes/edição

// Enum para tipos de filtro
enum TaskFilterType { focoDoDia, todas, vibracao }

class FocoDoDiaScreen extends StatefulWidget {
  final UserModel? userData;
  const FocoDoDiaScreen({super.key, required this.userData});
  @override
  State<FocoDoDiaScreen> createState() => _FocoDoDiaScreenState();
}

class _FocoDoDiaScreenState extends State<FocoDoDiaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final String _userId;

  // Variáveis de estado para filtros
  TaskFilterType _selectedFilter = TaskFilterType.focoDoDia; // Filtro inicial
  int? _selectedVibrationNumber; // Número da vibração selecionado
  // Lista dos números de vibração válidos para os filtros
  final List<int> _vibrationNumbers = List.generate(9, (i) => i + 1) + [11, 22];

  @override
  void initState() {
    super.initState();
    _userId = AuthRepository().getCurrentUser()?.uid ?? '';
    if (_userId.isEmpty) {
      print("ERRO: FocoDoDiaScreen acessada sem usuário logado!");
      // TODO: Considerar redirecionar ou mostrar mensagem mais clara na UI
    }
  }

  // Função _openAddTaskModal (inalterada)
  void _openAddTaskModal() {
    if (widget.userData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData!,
      ),
    );
  }

  // Função _handleTaskTap (inalterada)
  void _handleTaskTap(TaskModel task) {
    if (widget.userData == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    bool isDesktopLayout = screenWidth > 600;

    if (isDesktopLayout) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return TaskDetailModal(
            task: task,
            userData: widget.userData!,
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailModal(
            task: task,
            userData: widget.userData!,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  // Funções auxiliares de data e filtro (inalteradas)
  bool _isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) {
      return false;
    }
    final localDate1 = date1.toLocal();
    final localDate2 = date2.toLocal();
    return localDate1.year == localDate2.year &&
        localDate1.month == localDate2.month &&
        localDate1.day == localDate2.day;
  }

  List<TaskModel> _filterTasks(List<TaskModel> allTasks) {
    final today = DateTime.now();

    switch (_selectedFilter) {
      case TaskFilterType.focoDoDia:
        return allTasks.where((task) {
          return !task.completed &&
              (_isSameDay(task.dueDate, today) ||
                  (task.dueDate == null && _isSameDay(task.createdAt, today)));
        }).toList();

      case TaskFilterType.vibracao:
        if (_selectedVibrationNumber == null) {
          return [];
        }
        return allTasks.where((task) {
          return !task.completed &&
              task.personalDay == _selectedVibrationNumber;
        }).toList();

      case TaskFilterType.todas:
      default:
        return allTasks.where((task) => !task.completed).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userData == null || _userId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Erro: Dados do usuário não disponíveis.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile: isMobile), // Header atualizado
                  Expanded(
                    child: StreamBuilder<List<TaskModel>>(
                      stream: _firestoreService
                          .getTasksStream(_userId), // Sempre busca todas
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CustomLoadingSpinner());
                        }
                        if (snapshot.hasError) {
                          print(
                              "Erro no Stream de Tarefas: ${snapshot.error}"); // Log do erro
                          return Center(
                              child: Text(
                                  'Erro ao carregar tarefas: ${snapshot.error}'));
                        }

                        final allTasks = snapshot.data ?? [];
                        final tasksToShow =
                            _filterTasks(allTasks); // Aplica o filtro

                        // Define mensagens de lista vazia dinamicamente (inalterado)
                        String emptyMsg = 'Tudo limpo por aqui!';
                        String emptySubMsg = 'Nenhuma tarefa encontrada.';
                        if (_selectedFilter == TaskFilterType.focoDoDia &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Foco do dia concluído!';
                          emptySubMsg =
                              'Você não tem tarefas pendentes para hoje.';
                        } else if (_selectedFilter == TaskFilterType.vibracao &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Nenhuma tarefa encontrada.';
                          emptySubMsg = _selectedVibrationNumber != null
                              ? 'Não há tarefas pendentes para o dia pessoal $_selectedVibrationNumber.'
                              : 'Selecione um número de dia pessoal acima.';
                        } else if (_selectedFilter == TaskFilterType.todas &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Caixa de entrada vazia!';
                          emptySubMsg = 'Você não tem nenhuma tarefa pendente.';
                        }

                        // TasksListView (inalterado)
                        return TasksListView(
                          tasks: tasksToShow,
                          userData: widget.userData,
                          emptyListMessage: emptyMsg,
                          emptyListSubMessage: emptySubMsg,
                          onToggle: (task, isCompleted) {
                            _firestoreService
                                .updateTaskCompletion(
                              _userId,
                              task.id,
                              completed: isCompleted,
                            )
                                .then((_) {
                              if (task.journeyId != null &&
                                  task.journeyId!.isNotEmpty) {
                                _firestoreService.updateGoalProgress(
                                    _userId, task.journeyId!);
                              }
                            }).catchError((error) {
                              print(
                                  "Erro ao atualizar status da tarefa: $error");
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Erro ao atualizar tarefa: $error'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            });
                          },
                          onTaskTap: _handleTaskTap,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskModal,
        backgroundColor: AppColors.primary,
        tooltip: 'Adicionar Tarefa',
        heroTag: 'foco_fab', // Tag única
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- Widget do Header com filtros atualizados (Ícone Dia Pessoal) ---
  Widget _buildHeader({required bool isMobile}) {
    final double titleFontSize = isMobile ? 28 : 32;
    final double chipSpacing = isMobile ? 4.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Título (inalterado)
        Text('Tarefas',
            style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Chips de Filtro Principal (Foco, Todas, Dia Pessoal)
        Wrap(
          spacing: chipSpacing,
          runSpacing: chipSpacing,
          children: TaskFilterType.values.map((filterType) {
            String label;
            IconData? icon; // Ícone opcional
            switch (filterType) {
              case TaskFilterType.focoDoDia:
                label = 'Foco do Dia';
                icon = Icons.star_border_rounded; // Ícone de estrela
                break;
              case TaskFilterType.todas:
                label = 'Todas';
                icon = Icons.inbox_rounded; // Ícone de caixa de entrada
                break;
              // --- INÍCIO DA MUDANÇA: Ícone Dia Pessoal ---
              case TaskFilterType.vibracao:
                label = 'Dia Pessoal'; // Mantido
                icon = Icons.wb_sunny_rounded; // Novo Ícone (Sol/Dia)
                break;
              // --- FIM DA MUDANÇA ---
            }

            final isSelected = _selectedFilter == filterType;

            return ChoiceChip(
              label: Text(label),
              avatar: icon != null
                  ? Icon(
                      icon,
                      size: 18,
                      color:
                          isSelected ? Colors.white : AppColors.secondaryText,
                    )
                  : null,
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filterType;
                    // Reseta o número da vibração se o filtro principal mudar E NÃO for o filtro de vibração
                    if (filterType != TaskFilterType.vibracao) {
                      _selectedVibrationNumber = null;
                    }
                  });
                }
              },
              backgroundColor: AppColors.cardBackground,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              showCheckmark: false,
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),

        // Chips de Filtro de Dia Pessoal (condicional - inalterado)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Visibility(
            visible: _selectedFilter == TaskFilterType.vibracao,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: (_selectedFilter == TaskFilterType.vibracao)
                  ? Wrap(
                      spacing: chipSpacing,
                      runSpacing: chipSpacing,
                      children: _vibrationNumbers.map((number) {
                        final isSelected = _selectedVibrationNumber == number;
                        final colors = getColorsForVibration(number);

                        return ChoiceChip(
                          label: Text('$number'),
                          selected: isSelected,
                          onSelected: (selected) {
                            // Lógica de seleção/desseleção (sem modal)
                            setState(() {
                              if (!selected) {
                                // Se clicou para desmarcar
                                _selectedVibrationNumber = null;
                              } else {
                                // Se clicou para marcar
                                _selectedVibrationNumber = number;
                              }
                            });
                          },
                          backgroundColor: colors.background.withOpacity(0.2),
                          selectedColor: colors.background,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? colors.text
                                : colors.background.withOpacity(0.9),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          shape: StadiumBorder(
                              side: BorderSide(
                                  color: colors.background.withOpacity(0.5))),
                          showCheckmark: false,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        );
                      }).toList(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
      ],
    );
  }
} // Fim da classe _FocoDoDiaScreenState

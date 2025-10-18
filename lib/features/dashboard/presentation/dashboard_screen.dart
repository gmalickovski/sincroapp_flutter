// lib/features/dashboard/presentation/dashboard_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:collection/collection.dart'; // Necessário para ListEquality
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/focus_day_card.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/goals_progress_card.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/common/widgets/info_card.dart';
import 'package:sincro_app_flutter/common/widgets/bussola_card.dart';
import 'package:sincro_app_flutter/common/widgets/custom_app_bar.dart';
import 'package:sincro_app_flutter/common/widgets/dashboard_sidebar.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../journal/presentation/journal_screen.dart';
import '../../tasks/presentation/foco_do_dia_screen.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../goals/presentation/goal_detail_screen.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class DashboardCardData {
  final String id;
  final Widget Function(bool isEditMode, {Widget? dragHandle}) cardBuilder;
  DashboardCardData({required this.id, required this.cardBuilder});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _userData;
  NumerologyResult? _numerologyData;
  bool _isLoading = true;
  int _sidebarIndex = 0;
  List<DashboardCardData> _cards = [];
  bool _isEditMode = false;

  List<TaskModel> _todayTasks = [];
  List<Goal> _userGoals = [];

  bool _isDesktopSidebarExpanded = true;
  bool _isMobileDrawerOpen = false;

  late AnimationController _menuAnimationController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (_isDesktopSidebarExpanded) {
      _menuAnimationController.forward();
    }
    _loadData();
  }

  @override
  void dispose() {
    _menuAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authRepository = AuthRepository();
    final currentUser = authRepository.getCurrentUser();

    if (currentUser != null) {
      final results = await Future.wait([
        _firestoreService.getUserData(currentUser.uid),
        _firestoreService.getActiveGoals(currentUser.uid),
        _firestoreService.getTasksForToday(currentUser.uid),
      ]);

      final userData = results[0] as UserModel?;
      _userGoals = results[1] as List<Goal>;
      _todayTasks = results[2] as List<TaskModel>;

      if (mounted) {
        if (userData != null &&
            userData.nomeAnalise.isNotEmpty &&
            userData.dataNasc.isNotEmpty) {
          final engine = NumerologyEngine(
            nomeCompleto: userData.nomeAnalise,
            dataNascimento: userData.dataNasc,
          );
          _numerologyData = engine.calcular();
        }

        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handleTaskStatusChange(TaskModel task, bool isCompleted) {
    if (_userData == null) return;
    setState(() {
      final taskIndex = _todayTasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        _todayTasks[taskIndex] = task.copyWith(completed: isCompleted);
      }
    });

    _firestoreService
        .updateTaskCompletion(_userData!.uid, task.id, completed: isCompleted)
        .catchError((error) {
      // Reverte e mostra erro
      setState(() {
        final taskIndex = _todayTasks.indexWhere((t) => t.id == task.id);
        if (taskIndex != -1) {
          _todayTasks[taskIndex] = task.copyWith(completed: !isCompleted);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao atualizar a tarefa.'),
            backgroundColor: Colors.red),
      );
    });
  }

  void _handleTaskDeleted(TaskModel task) {
    if (_userData == null) return;
    _firestoreService.deleteTask(_userData!.uid, task.id).then((_) {
      setState(() {
        _todayTasks.removeWhere((t) => t.id == task.id);
      });
      if (task.journeyId != null) {
        _firestoreService.updateGoalProgress(_userData!.uid, task.journeyId!);
      }
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao deletar tarefa.'),
            backgroundColor: Colors.red),
      );
    });
  }

  void _handleTaskEdited(TaskModel task) {
    if (_userData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: _userData!,
        taskToEdit: task,
      ),
    ).then((_) => _loadData());
  }

  void _handleTaskDuplicated(TaskModel task) {
    if (_userData == null) return;
    final duplicatedTask = task.copyWith(
      id: '',
      text: '${task.text} (cópia)',
      createdAt: DateTime.now(),
      completed: false,
    );
    _firestoreService.addTask(_userData!.uid, duplicatedTask).then((_) {
      _loadData();
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao duplicar tarefa.'),
            backgroundColor: Colors.red),
      );
    });
  }

  void _navigateToPage(int index) {
    setState(() {
      _sidebarIndex = index;
      _isEditMode = false;
    });
  }

  void _navigateToGoalDetail(Goal goal) {
    if (_userData == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GoalDetailScreen(
          initialGoal: goal,
          userData: _userData!,
        ),
      ),
    );
  }

  // *** MÉTODO ATUALIZADO PARA INCLUIR TODOS OS CARDS ***
  void _buildCardList() {
    if (_userData == null) {
      _cards = [];
      return;
    }

    final List<DashboardCardData> allCards = [
      DashboardCardData(
        id: 'goalsProgress',
        cardBuilder: (isEditMode, {dragHandle}) => GoalsProgressCard(
          goals: _userGoals,
          onViewAll: () => _navigateToPage(4),
          onGoalSelected: _navigateToGoalDetail,
          // *** Passando dragHandle e isEditMode ***
          dragHandle: dragHandle,
          isEditMode: isEditMode,
        ),
      ),
      DashboardCardData(
        id: 'focusDay',
        cardBuilder: (isEditMode, {dragHandle}) => FocusDayCard(
          tasks: _todayTasks,
          onViewAll: () => _navigateToPage(3),
          onTaskStatusChanged: _handleTaskStatusChange,
          userData: _userData!,
          onTaskDeleted: _handleTaskDeleted,
          onTaskEdited: _handleTaskEdited,
          onTaskDuplicated: _handleTaskDuplicated,
          // *** Passando dragHandle e isEditMode ***
          dragHandle: dragHandle,
          isEditMode: isEditMode,
        ),
      ),
    ];

    if (_numerologyData != null) {
      final diaPessoalNum = _numerologyData!.numeros['diaPessoal']!;
      final diaPessoal = _getInfoContent('diaPessoal', diaPessoalNum);
      final mesPessoal = _getInfoContent(
          'mesPessoal', _numerologyData!.numeros['mesPessoal']!);
      final anoPessoal = _getInfoContent(
          'anoPessoal', _numerologyData!.numeros['anoPessoal']!);
      // *** CARDS RESTAURADOS ***
      final arcanoRegente =
          _getArcanoContent(_numerologyData!.estruturas['arcanoRegente']);
      final arcanoVigente = _getArcanoContent(
          _numerologyData!.estruturas['arcanoAtual']['numero'] ?? 0);
      final cicloDeVida = _getCicloDeVidaContent(
          _numerologyData!.estruturas['cicloDeVidaAtual']['regente']);
      final bussola = _getBussolaContent(diaPessoalNum);

      allCards.addAll([
        DashboardCardData(
            id: 'vibracaoDia',
            cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
                dragHandle: dragHandle, // Passa o dragHandle
                title: "Vibração do Dia",
                number: diaPessoalNum.toString(),
                info: diaPessoal,
                icon: Icons.sunny,
                color: Colors.cyan.shade300,
                isEditMode: isEditMode,
                onTap: () {})),
        DashboardCardData(
            id: 'vibracaoMes',
            cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
                dragHandle: dragHandle, // Passa o dragHandle
                title: "Vibração do Mês",
                number: _numerologyData!.numeros['mesPessoal']!.toString(),
                info: mesPessoal,
                icon: Icons.nightlight_round,
                color: Colors.indigo.shade300,
                isEditMode: isEditMode,
                onTap: () {})),
        DashboardCardData(
            id: 'vibracaoAno',
            cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
                dragHandle: dragHandle, // Passa o dragHandle
                title: "Vibração do Ano",
                number: _numerologyData!.numeros['anoPessoal']!.toString(),
                info: anoPessoal,
                icon: Icons.star,
                color: Colors.amber.shade300,
                isEditMode: isEditMode,
                onTap: () {})),
        // *** CARD RESTAURADO ***
        DashboardCardData(
            id: 'arcanoRegente',
            cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
                dragHandle: dragHandle, // Passa o dragHandle
                title: "Arcano Regente",
                number: _numerologyData!.estruturas['arcanoRegente'].toString(),
                info: arcanoRegente,
                icon: Icons.shield_moon,
                color: Colors.purple.shade300,
                isEditMode: isEditMode,
                onTap: () {})),
        // *** CARD RESTAURADO ***
        DashboardCardData(
            id: 'arcanoVigente',
            cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
                dragHandle: dragHandle, // Passa o dragHandle
                title: "Arcano Vigente",
                number: (_numerologyData!.estruturas['arcanoAtual']['numero'] ??
                        '-')
                    .toString(),
                info: arcanoVigente,
                icon: Icons.shield_moon_outlined,
                color: Colors.purple.shade200,
                isEditMode: isEditMode,
                onTap: () {})),
        // *** CARD RESTAURADO ***
        DashboardCardData(
            id: 'cicloVida',
            cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
                dragHandle: dragHandle, // Passa o dragHandle
                title: "Ciclo de Vida",
                number: _numerologyData!.estruturas['cicloDeVidaAtual']
                        ['regente']
                    .toString(),
                info: cicloDeVida,
                icon: Icons.repeat,
                color: Colors.green.shade300,
                isEditMode: isEditMode,
                onTap: () {})),
        DashboardCardData(
            id: 'bussola',
            cardBuilder: (isEditMode, {dragHandle}) => BussolaCard(
                dragHandle: dragHandle, // Passa o dragHandle
                bussolaContent: bussola,
                isEditMode: isEditMode,
                onTap: () {})),
      ]);
    }

    if (!ListEquality().equals(
        _cards.map((c) => c.id).toList(), allCards.map((c) => c.id).toList())) {
      // Atualiza o estado apenas se a lista de IDs mudou
      // Isso evita rebuilds desnecessários se a ordem for a mesma
      setState(() {
        _cards = allCards;
      });
    } else {
      // Se apenas a ordem mudou (drag n drop), atualiza sem setState completo
      // para evitar piscar, a ReorderableListView/GridView já cuida da UI
      _cards = allCards;
    }
  }

  VibrationContent _getInfoContent(String category, int number) {
    return ContentData.vibracoes[category]?[number] ??
        const VibrationContent(
            titulo: 'Indisponível',
            descricaoCurta: 'Não foi possível carregar os dados.',
            descricaoCompleta: '',
            inspiracao: '');
  }

  // *** NOVAS FUNÇÕES GETTER RESTAURADAS ***
  VibrationContent _getArcanoContent(int number) {
    return ContentData.textosArcanos[number] ??
        const VibrationContent(
            titulo: 'Arcano Desconhecido',
            descricaoCurta: 'Não foi possível carregar os dados do arcano.',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getCicloDeVidaContent(int number) {
    return ContentData.textosCiclosDeVida[number] ??
        const VibrationContent(
            titulo: 'Ciclo Desconhecido',
            descricaoCurta: 'Não foi possível carregar os dados do ciclo.',
            descricaoCompleta: '',
            inspiracao: '');
  }

  BussolaContent _getBussolaContent(int number) {
    return ContentData.bussolaAtividades[number] ??
        ContentData.bussolaAtividades[0]!;
  }

  Widget _buildCurrentPage() {
    if (_userData == null) return const Center(child: CustomLoadingSpinner());
    return IndexedStack(
      index: _sidebarIndex,
      children: [
        _buildDashboardContent(
            isDesktop: MediaQuery.of(context).size.width > 800),
        CalendarScreen(userData: _userData!),
        JournalScreen(userData: _userData!),
        FocoDoDiaScreen(userData: _userData!),
        GoalsScreen(userData: _userData!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    if (_isLoading) {
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CustomLoadingSpinner()));
    }

    // Chama _buildCardList no build para garantir que a lista esteja
    // atualizada com os dados mais recentes (_userGoals, _todayTasks)
    _buildCardList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        userData: _userData,
        menuAnimationController: _menuAnimationController,
        isEditMode: _isEditMode,
        onEditPressed: (_sidebarIndex == 0 &&
                isDesktop) // Só permite editar o dashboard (index 0)
            ? () => setState(() => _isEditMode = !_isEditMode)
            : null,
        onMenuPressed: () {
          setState(() {
            if (isDesktop) {
              _isDesktopSidebarExpanded = !_isDesktopSidebarExpanded;
              _isDesktopSidebarExpanded
                  ? _menuAnimationController.forward()
                  : _menuAnimationController.reverse();
            } else {
              _isMobileDrawerOpen = !_isMobileDrawerOpen;
              _isMobileDrawerOpen
                  ? _menuAnimationController.forward()
                  : _menuAnimationController.reverse();
            }
          });
        },
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_userData != null)
          DashboardSidebar(
            isExpanded: _isDesktopSidebarExpanded,
            selectedIndex: _sidebarIndex,
            userData: _userData!,
            onDestinationSelected: (index) {
              if (index < 5) {
                setState(() {
                  _sidebarIndex = index;
                  _isEditMode = false; // Sai do modo edição ao trocar de página
                });
              }
              // Ações para Configurações e Sair são tratadas dentro do Sidebar
            },
          ),
        Expanded(child: _buildCurrentPage()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    const double sidebarWidth = 280;
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (_isMobileDrawerOpen) {
              setState(() {
                _isMobileDrawerOpen = false;
                _menuAnimationController.reverse();
              });
            }
          },
          // Long press só ativa edição no dashboard (index 0)
          onLongPress: (_isEditMode || _sidebarIndex != 0)
              ? null
              : () => setState(() => _isEditMode = true),
          child: _buildCurrentPage(),
        ),
        if (_isMobileDrawerOpen)
          GestureDetector(
            onTap: () {
              setState(() {
                _isMobileDrawerOpen = false;
                _menuAnimationController.reverse();
              });
            },
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          left: _isMobileDrawerOpen ? 0 : -sidebarWidth,
          width: sidebarWidth,
          child: _userData != null
              ? DashboardSidebar(
                  isExpanded: true,
                  selectedIndex: _sidebarIndex,
                  userData: _userData!,
                  onDestinationSelected: (index) {
                    // Atualiza o estado da página selecionada
                    if (index < 5) {
                      setState(() {
                        _sidebarIndex = index;
                        _isEditMode = false; // Sai do modo edição
                      });
                    }
                    // Fecha o drawer
                    setState(() {
                      _isMobileDrawerOpen = false;
                      _menuAnimationController.reverse();
                    });
                  },
                )
              : const SizedBox.shrink(),
        ),
        // Botão de concluir edição (FAB)
        if (!_isMobileDrawerOpen && _isEditMode && _sidebarIndex == 0)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => setState(() => _isEditMode = false),
              backgroundColor: Colors.green,
              child: const Icon(Icons.check, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildDashboardContent({required bool isDesktop}) {
    if (_cards.isEmpty) {
      if (_isLoading || _userData == null) {
        return const Center(child: CustomLoadingSpinner());
      }
      return const Center(
          child: Text("Nenhum card para exibir.",
              style: TextStyle(color: AppColors.secondaryText)));
    }

    // Função para construir o Drag Handle
    Widget buildDragHandle(int index) {
      return ReorderableDragStartListener(
        index: index,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            // Área sensível ao toque para arrastar
            // Aumentei a área para facilitar em mobile
            padding: const EdgeInsets.all(8),
            color: Colors.transparent, // Invisível
            child: Icon(
              Icons.drag_indicator,
              color: AppColors.secondaryText.withOpacity(0.7),
              size: 24,
            ),
          ),
        ),
      );
    }

    if (!isDesktop) {
      return ReorderableListView.builder(
        // Desativa o handle padrão do ListView, usaremos o nosso
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80), // Ajuste no padding
        itemCount: _cards.length,
        proxyDecorator: (child, index, animation) =>
            Material(elevation: 8.0, color: Colors.transparent, child: child),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _cards.removeAt(oldIndex);
            _cards.insert(newIndex, item);
            // Aqui você poderia salvar a nova ordem no Firestore/preferências
          });
        },
        itemBuilder: (context, index) {
          final item = _cards[index];
          // *** PASSANDO O dragHandle CORRETAMENTE ***
          return Padding(
            key: ValueKey(item.id),
            padding: const EdgeInsets.only(bottom: 20.0),
            // Chama o cardBuilder passando o dragHandle apenas se estiver em modo edição
            child: item.cardBuilder(
              _isEditMode,
              dragHandle: _isEditMode ? buildDragHandle(index) : null,
            ),
          );
        },
      );
    } else {
      // Layout Desktop com ReorderableGridView
      final screenWidth = MediaQuery.of(context).size.width;
      const double cardMaxWidth = 420.0;
      const double spacing = 24.0;
      // Ajusta o número de colunas baseado na largura da sidebar
      final availableWidth =
          screenWidth - (_isDesktopSidebarExpanded ? 250 : 80);
      final crossAxisCount =
          (availableWidth > cardMaxWidth * 3 + spacing * 2) ? 3 : 2;
      final double gridMaxWidth =
          (crossAxisCount * cardMaxWidth) + ((crossAxisCount - 1) * spacing);
      // Ajuste no aspect ratio pode ser necessário dependendo da altura dos cards
      const double childAspectRatio = 1.2;

      return ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: gridMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(spacing),
                child: ReorderableGridView.builder(
                  itemCount: _cards.length,
                  shrinkWrap: true, // Essencial dentro de SingleChildScrollView
                  physics:
                      const NeverScrollableScrollPhysics(), // Desativa scroll interno
                  // Habilita arrastar apenas no modo de edição
                  dragEnabled: _isEditMode,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  onReorder: (oldIndex, newIndex) => setState(() {
                    final item = _cards.removeAt(oldIndex);
                    _cards.insert(newIndex, item);
                    // Salvar nova ordem
                  }),
                  itemBuilder: (context, index) {
                    final item = _cards[index];
                    // *** PASSANDO O dragHandle CORRETAMENTE ***
                    return Container(
                      key: ValueKey(item.id),
                      // Chama o cardBuilder passando o dragHandle apenas se estiver em modo edição
                      child: item.cardBuilder(
                        _isEditMode,
                        dragHandle: _isEditMode ? buildDragHandle(index) : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

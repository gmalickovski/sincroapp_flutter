// lib/features/dashboard/presentation/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:collection/collection.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/focus_day_card.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/goals_progress_card.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
// ATUALIZADO: Importa ParsedTask
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
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
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/reorder_dashboard_modal.dart';

// Comportamento de scroll (inalterado)
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
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
  List<Widget> _cards = [];
  bool _isEditMode = false;
  bool _isUpdatingLayout = false;
  List<Goal> _userGoals = [];
  bool _isDesktopSidebarExpanded = false;
  bool _isMobileDrawerOpen = false;
  late AnimationController _menuAnimationController;
  final FirestoreService _firestoreService = FirestoreService();
  Key _masonryGridKey = UniqueKey();
  StreamSubscription<List<TaskModel>>? _todayTasksSubscription;
  List<TaskModel> _currentTodayTasks = [];

  // initState, dispose, _loadInitialData, _initializeTasksStream,
  // _reloadDataNonStream, _handleTaskStatusChange, _handleTaskTap
  // (Seu código original, sem alterações)
  // --- (Código omitido para brevidade) ---
  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Atrasa o carregamento inicial para garantir que o widget está completamente montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    // Cancela streams e controllers de forma segura
    _cancelSubscriptions();
    _menuAnimationController.dispose();
    super.dispose();
  }

  void _cancelSubscriptions() {
    if (_todayTasksSubscription != null) {
      _todayTasksSubscription!.cancel().then((_) {
        _todayTasksSubscription = null;
      }).catchError((error) {
        print("Erro ao cancelar subscription: $error");
      });
    }
  }

  Future<void> _loadInitialData() async {
    if (mounted && _userData == null) setState(() => _isLoading = true);
    final authRepository = AuthRepository();
    final currentUser = authRepository.getCurrentUser();

    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        _firestoreService.getUserData(currentUser.uid),
        _firestoreService.getActiveGoals(currentUser.uid),
      ]);

      if (!mounted) return;

      final userData = results[0] as UserModel?;
      _userGoals = results[1] as List<Goal>;
      _userData = userData;

      if (userData != null &&
          userData.nomeAnalise.isNotEmpty &&
          userData.dataNasc.isNotEmpty) {
        final engine = NumerologyEngine(
          nomeCompleto: userData.nomeAnalise,
          dataNascimento: userData.dataNasc,
        );
        _numerologyData = engine.calcular();
      } else {
        _numerologyData = null;
      }
      _initializeTasksStream(currentUser.uid);
    } catch (e, stackTrace) {
      print(
          "Erro detalhado ao carregar dados iniciais do dashboard: $e\n$stackTrace");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUpdatingLayout = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erro ao carregar dados."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _initializeTasksStream(String userId) {
    _todayTasksSubscription?.cancel();
    _todayTasksSubscription =
        _firestoreService.getTasksStreamForToday(userId).listen(
      (tasks) {
        if (mounted) {
          setState(() {
            _currentTodayTasks = tasks;
            if (_isLoading) {
              _isLoading = false;
            }
            _buildCardList();
          });
        }
      },
      onError: (error, stackTrace) {
        print("Erro no stream de tarefas do dia: $error\n$stackTrace");
        if (mounted) {
          setState(() {
            _currentTodayTasks = [];
            _isLoading = false;
            _buildCardList();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Erro ao carregar tarefas do dia."),
                backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  Future<void> _reloadDataNonStream({bool rebuildCards = true}) async {
    final authRepository = AuthRepository();
    final currentUser = authRepository.getCurrentUser();
    if (currentUser == null || !mounted) return;

    try {
      final results = await Future.wait([
        _firestoreService.getUserData(currentUser.uid),
        _firestoreService.getActiveGoals(currentUser.uid),
      ]);
      if (!mounted) return;

      final userData = results[0] as UserModel?;
      _userGoals = results[1] as List<Goal>;

      _userData = userData;

      if (userData != null &&
          userData.nomeAnalise.isNotEmpty &&
          userData.dataNasc.isNotEmpty) {
        final engine = NumerologyEngine(
          nomeCompleto: userData.nomeAnalise,
          dataNascimento: userData.dataNasc,
        );
        _numerologyData = engine.calcular();
      } else {
        _numerologyData = null;
      }
      if (rebuildCards && mounted) {
        setState(() {
          _buildCardList();
        });
      }
    } catch (e, stackTrace) {
      print("Erro ao recarregar dados (não stream): $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erro ao recarregar dados."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleTaskStatusChange(TaskModel task, bool isCompleted) {
    if (!mounted || _userData == null) return;
    _firestoreService
        .updateTaskCompletion(_userData!.uid, task.id, completed: isCompleted)
        .then((_) {
      if (task.journeyId != null && task.journeyId!.isNotEmpty) {
        _firestoreService.updateGoalProgress(_userData!.uid, task.journeyId!);
      }
    }).catchError((error) {
      print("Erro ao atualizar status da tarefa: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erro ao atualizar tarefa."),
              backgroundColor: Colors.red),
        );
      }
    });
  }

  void _handleTaskTap(TaskModel task) {
    print("Dashboard: Tarefa tocada: ${task.id} - ${task.text}");
  }

  // ---
  // --- ATUALIZAÇÃO NESTA FUNÇÃO ---
  // ---
  void _handleAddTask() {
    if (_userData == null) return;

    // Obtém a data de hoje (meia-noite) para o vibration pill inicial
    final todayMidnight =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    showModalBottomSheet<void>(
      // Alterado para void, não precisamos do didCreate
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: _userData!,
        userId: _userData!.uid, // Passa o userId

        // --- ATUALIZADO: Passa a data inicial para o vibration pill ---
        initialDueDate: todayMidnight,
        // --- FIM DA ATUALIZAÇÃO ---

        // Usa a nova assinatura com ParsedTask
        onAddTask: (ParsedTask parsedTask) {
          final newTask = TaskModel(
            id: '',
            text: parsedTask.cleanText,
            createdAt: DateTime.now().toUtc(),
            // Usa a data do parser OU a data pré-selecionada (hoje) se o parser não encontrar
            dueDate: parsedTask.dueDate?.toUtc() ?? todayMidnight.toUtc(),
            journeyId: parsedTask.journeyId,
            journeyTitle: parsedTask.journeyTitle,
            tags: parsedTask.tags,
            // TODO: Adicionar lógica para pegar o personalDay se necessário
          );

          // Adiciona a tarefa
          _firestoreService
              .addTask(_userData!.uid, newTask)
              .catchError((error) {
            print("Erro ao adicionar tarefa pelo dashboard: $error");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Erro ao salvar tarefa: $error'),
                    backgroundColor: Colors.red),
              );
            }
          });
        },
        // REMOVIDO: taskToEdit não é usado aqui
        // REMOVIDO: preselectedGoal não existe mais
      ),
    );
    // REMOVIDO: .then(...) - O stream já atualiza a UI
  }
  // --- FIM DA ATUALIZAÇÃO ---
  // ---

  // Navegação, _buildCardList, _buildDragHandle, Getters de conteúdo,
  // _buildCurrentPage, _openReorderModal, build principal, layouts, _buildDashboardContent
  // (Seu código original, sem alterações)
  // --- (Código omitido para brevidade) ---
  void _navigateToPage(int index) {
    if (!mounted) return;
    setState(() {
      _sidebarIndex = index;
      _isEditMode = false;
      _isUpdatingLayout = false;
      if (_isMobileDrawerOpen) {
        _isMobileDrawerOpen = false;
        _menuAnimationController.reverse();
      }
    });
  }

  void _navigateToGoalDetail(Goal goal) {
    if (_userData == null) return;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
          builder: (context) =>
              GoalDetailScreen(initialGoal: goal, userData: _userData!)),
    )
        .then((_) {
      if (mounted) _reloadDataNonStream();
    });
  }

  void _buildCardList() {
    if (!mounted || _userData == null) {
      _cards = [];
      return;
    }
    int? todayPersonalDay;
    if (_numerologyData != null) {
      if (_numerologyData!.numeros.containsKey('diaPessoal')) {
        todayPersonalDay = _numerologyData!.numeros['diaPessoal'];
      }
    }
    final Map<String, Widget> allCardsMap = {
      'goalsProgress': GoalsProgressCard(
        key: const ValueKey('goalsProgress'),
        goals: _userGoals,
        onViewAll: () => _navigateToPage(4),
        onGoalSelected: _navigateToGoalDetail,
        isEditMode: _isEditMode,
        dragHandle: _isEditMode ? _buildDragHandle('goalsProgress') : null,
      ),
      'focusDay': FocusDayCard(
        key: const ValueKey('focusDay'),
        tasks: _currentTodayTasks,
        onViewAll: () => _navigateToPage(3),
        onTaskStatusChanged: _handleTaskStatusChange,
        userData: _userData!,
        onAddTask: _handleAddTask,
        onTaskTap: _handleTaskTap,
        isEditMode: _isEditMode,
        dragHandle: _isEditMode ? _buildDragHandle('focusDay') : null,
      ),
      if (_numerologyData != null) ...{
        'vibracaoDia': InfoCard(
            key: const ValueKey('vibracaoDia'),
            title: "Vibração do Dia",
            number: (_numerologyData!.numeros['diaPessoal'] ?? '-').toString(),
            info: _getInfoContent(
                'diaPessoal', _numerologyData!.numeros['diaPessoal'] ?? 0),
            icon: Icons.sunny,
            color: Colors.cyan.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('vibracaoDia') : null,
            onTap: () {}),
        'vibracaoMes': InfoCard(
            key: const ValueKey('vibracaoMes'),
            title: "Vibração do Mês",
            number: (_numerologyData!.numeros['mesPessoal'] ?? '-').toString(),
            info: _getInfoContent(
                'mesPessoal', _numerologyData!.numeros['mesPessoal'] ?? 0),
            icon: Icons.nightlight_round,
            color: Colors.indigo.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('vibracaoMes') : null,
            onTap: () {}),
        'vibracaoAno': InfoCard(
            key: const ValueKey('vibracaoAno'),
            title: "Vibração do Ano",
            number: (_numerologyData!.numeros['anoPessoal'] ?? '-').toString(),
            info: _getInfoContent(
                'anoPessoal', _numerologyData!.numeros['anoPessoal'] ?? 0),
            icon: Icons.star,
            color: Colors.amber.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('vibracaoAno') : null,
            onTap: () {}),
        'arcanoRegente': InfoCard(
            key: const ValueKey('arcanoRegente'),
            title: "Arcano Regente",
            number: (_numerologyData!.estruturas['arcanoRegente'] ?? '-')
                .toString(),
            info: _getArcanoContent(
                _numerologyData!.estruturas['arcanoRegente'] ?? 0),
            icon: Icons.shield_moon,
            color: Colors.purple.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('arcanoRegente') : null,
            onTap: () {}),
        'arcanoVigente': InfoCard(
            key: const ValueKey('arcanoVigente'),
            title: "Arcano Vigente",
            number:
                (_numerologyData!.estruturas['arcanoAtual']?['numero'] ?? '-')
                    .toString(),
            info: _getArcanoContent(
                _numerologyData!.estruturas['arcanoAtual']?['numero'] ?? 0),
            icon: Icons.shield_moon_outlined,
            color: Colors.purple.shade200,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('arcanoVigente') : null,
            onTap: () {}),
        'cicloVida': InfoCard(
            key: const ValueKey('cicloVida'),
            title: "Ciclo de Vida",
            number: (_numerologyData!.estruturas['cicloDeVidaAtual']
                        ?['regente'] ??
                    '-')
                .toString(),
            info: _getCicloDeVidaContent(
                _numerologyData!.estruturas['cicloDeVidaAtual']?['regente'] ??
                    0),
            icon: Icons.repeat,
            color: Colors.green.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('cicloVida') : null,
            onTap: () {}),
        'bussola': BussolaCard(
            key: const ValueKey('bussola'),
            bussolaContent:
                _getBussolaContent(_numerologyData!.numeros['diaPessoal'] ?? 0),
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('bussola') : null,
            onTap: () {}),
      }
    };
    final List<String> cardOrder = _userData!.dashboardCardOrder;
    final List<Widget> orderedCards = [];
    Set<String> addedKeys = {};
    for (String cardId in cardOrder) {
      if (allCardsMap.containsKey(cardId) && !addedKeys.contains(cardId)) {
        orderedCards.add(allCardsMap[cardId]!);
        addedKeys.add(cardId);
      }
    }
    allCardsMap.forEach((key, value) {
      if (!addedKeys.contains(key)) {
        orderedCards.add(value);
      }
    });
    _cards = orderedCards;
  }

  Widget _buildDragHandle(String cardKey) {
    int index = _cards.indexWhere((card) => card.key == ValueKey(cardKey));
    if (index == -1) {
      print(
          "AVISO: Não foi possível encontrar o índice para a key '$cardKey' em _buildDragHandle.");
      return const SizedBox(width: 24, height: 24);
    }
    return ReorderableDragStartListener(
      index: index,
      child: const MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Icon(Icons.drag_handle, color: AppColors.secondaryText)),
    );
  }

  VibrationContent _getInfoContent(String category, int number) {
    return ContentData.vibracoes[category]?[number] ??
        const VibrationContent(
            titulo: 'Indisponível',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getArcanoContent(int number) {
    return ContentData.textosArcanos[number] ??
        const VibrationContent(
            titulo: 'Arcano Desconhecido',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getCicloDeVidaContent(int number) {
    return ContentData.textosCiclosDeVida[number] ??
        const VibrationContent(
            titulo: 'Ciclo Desconhecido',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  BussolaContent _getBussolaContent(int number) {
    return ContentData.bussolaAtividades[number] ??
        ContentData.bussolaAtividades[0]!;
  }

  Widget _buildCurrentPage() {
    if (_isLoading && _cards.isEmpty && !_isUpdatingLayout) {
      return const Center(child: CustomLoadingSpinner());
    }
    if (_userData == null && !_isLoading) {
      return const Center(
          child: Text("Erro ao carregar dados do usuário.",
              style: TextStyle(color: Colors.red)));
    }
    if (!_isLoading &&
        _userData != null &&
        _cards.isEmpty &&
        _sidebarIndex == 0 &&
        !_isUpdatingLayout) {
      return const Center(
          child: Text("Nenhum card para exibir.",
              style: TextStyle(color: AppColors.secondaryText)));
    }

    return IndexedStack(
      index: _sidebarIndex,
      children: [
        _buildDashboardContent(
            isDesktop: MediaQuery.of(context).size.width > 800),
        _userData != null
            ? CalendarScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()), // Aba 1
        _userData != null
            ? JournalScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()), // Aba 2
        _userData != null
            ? FocoDoDiaScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()), // Aba 3
        _userData != null
            ? GoalsScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()), // Aba 4
      ],
    );
  }

  void _openReorderModal() {
    if (!mounted || _userData == null || _isUpdatingLayout) return;
    final BuildContext currentContext = context;
    setState(() => _isEditMode = true);

    showModalBottomSheet<void>(
      context: currentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          final currentOrder = List<String>.from(_userData!.dashboardCardOrder);
          return ReorderDashboardModal(
            userId: _userData!.uid,
            initialOrder: currentOrder,
            scrollController: scrollController,
            onSaveComplete: (bool success) async {
              if (!mounted) return;
              try {
                Navigator.of(currentContext).pop();
              } catch (e) {
                print("Erro ao fechar modal: $e");
              }
              await Future.delayed(const Duration(milliseconds: 50));
              if (!mounted) return;

              if (success) {
                setState(() => _isUpdatingLayout = true);
                await _reloadDataNonStream(rebuildCards: true);
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  setState(() {
                    _masonryGridKey = UniqueKey();
                    _isUpdatingLayout = false;
                    _isEditMode = false;
                  });
                }
              } else {
                if (mounted) setState(() => _isEditMode = false);
              }
            },
          );
        },
      ),
    ).whenComplete(() {
      if (mounted && (_isEditMode || _isUpdatingLayout)) {
        setState(() {
          _isEditMode = false;
          _isUpdatingLayout = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        userData: _userData,
        menuAnimationController: _menuAnimationController,
        isEditMode: _isEditMode,
        onEditPressed: (_sidebarIndex == 0 && !_isLoading && !_isUpdatingLayout)
            ? _openReorderModal
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
              onDestinationSelected: _navigateToPage),
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
          onLongPress: (_sidebarIndex != 0 || _isLoading || _isUpdatingLayout)
              ? null
              : _openReorderModal,
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
              child: Container(color: Colors.black.withOpacity(0.5))),
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
                    _navigateToPage(index);
                  },
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDashboardContent({required bool isDesktop}) {
    if (_isLoading && _cards.isEmpty) {
      return const Center(child: CustomLoadingSpinner());
    }
    if (_isUpdatingLayout) {
      return const Center(child: CustomLoadingSpinner());
    }
    if (!_isLoading && !_isUpdatingLayout && _cards.isEmpty) {
      return const Center(
          child: Text("Nenhum card para exibir.",
              style: TextStyle(color: AppColors.secondaryText)));
    }

    if (!isDesktop) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final itemWidget = _cards[index];
          return Padding(
              key: itemWidget.key ?? ValueKey('card_$index'),
              padding: const EdgeInsets.only(bottom: 20.0),
              child: itemWidget);
        },
      );
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      const double spacing = 24.0;
      final sidebarWidth = _isDesktopSidebarExpanded ? 250.0 : 80.0;
      final availableWidth = screenWidth - sidebarWidth - (spacing * 2);
      int crossAxisCount = 1;
      if (availableWidth > 1300)
        crossAxisCount = 3;
      else if (availableWidth > 850) crossAxisCount = 2;
      crossAxisCount = crossAxisCount.clamp(1, _cards.length);

      return ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: ListView(
          padding: const EdgeInsets.all(spacing),
          children: [
            MasonryGridView.count(
              key: _masonryGridKey,
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                return _cards[index];
              },
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }
  }
} // Fim da classe _DashboardScreenState

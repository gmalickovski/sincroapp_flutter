// lib/features/dashboard/presentation/dashboard_screen.dart

import 'dart:async'; // Importar async para StreamSubscription
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:collection/collection.dart'; // Usado para ListEquality
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/focus_day_card.dart'; // Import atualizado
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
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/reorder_dashboard_modal.dart';

// Comportamento de scroll (inalterado)
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // ... (código inalterado)
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

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _menuAnimationController.dispose();
    _todayTasksSubscription?.cancel();
    super.dispose();
  }

  // Carrega dados iniciais (inalterado)
  Future<void> _loadInitialData() async {
    // ... (código inalterado)
    // Mostra spinner apenas se ainda não houver dados carregados
    if (mounted && _userData == null) setState(() => _isLoading = true);

    final authRepository = AuthRepository();
    final currentUser = authRepository.getCurrentUser();

    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return; // Sai se não houver usuário
    }

    try {
      // Carrega UserData e Goals em paralelo (SEM as tarefas de hoje)
      final results = await Future.wait([
        _firestoreService.getUserData(currentUser.uid),
        _firestoreService.getActiveGoals(currentUser.uid),
        // REMOVIDO: _firestoreService.getTasksForToday(currentUser.uid), // Será carregado pelo stream
      ]);

      if (!mounted) return; // Verifica se o widget ainda está montado

      final userData = results[0] as UserModel?;
      _userGoals = results[1] as List<Goal>;
      // REMOVIDO: _todayTasks = results[2] as List<TaskModel>; // Será gerenciado pelo stream

      _userData = userData; // Guarda userData primeiro

      // Calcula Numerologia (depende de userData)
      if (userData != null &&
          userData.nomeAnalise.isNotEmpty &&
          userData.dataNasc.isNotEmpty) {
        final engine = NumerologyEngine(
          nomeCompleto: userData.nomeAnalise,
          dataNascimento: userData.dataNasc,
        );
        _numerologyData = engine.calcular();
      } else {
        _numerologyData = null; // Garante que não use dados antigos
      }

      // --- MUDANÇA: Inicia o Stream de tarefas DEPOIS de carregar outros dados ---
      _initializeTasksStream(currentUser.uid);

      // _buildCardList() e setState são chamados pelo listener do stream agora
      // Não desligamos o _isLoading aqui, o listener do stream fará isso
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

  // Inicializa stream de tarefas (inalterado)
  void _initializeTasksStream(String userId) {
    // ... (código inalterado)
    _todayTasksSubscription?.cancel(); // Cancela subscrição anterior se houver
    _todayTasksSubscription =
        _firestoreService.getTasksStreamForToday(userId).listen(
      (tasks) {
        // Callback chamado sempre que as tarefas de hoje mudam no Firestore
        if (mounted) {
          setState(() {
            _currentTodayTasks = tasks; // Atualiza a lista local
            // Só desliga o loading principal na primeira vez que o stream emite dados
            if (_isLoading) {
              _isLoading = false;
            }
            _buildCardList(); // Reconstrói a lista de cards com as novas tarefas
          });
        }
      },
      onError: (error, stackTrace) {
        // Callback chamado em caso de erro no stream
        print("Erro no stream de tarefas do dia: $error\n$stackTrace");
        if (mounted) {
          setState(() {
            _currentTodayTasks = []; // Limpa tarefas em caso de erro
            _isLoading = false; // Garante que o loading saia
            _buildCardList(); // Reconstrói sem tarefas
          });
          // Mostra um erro para o usuário
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Erro ao carregar tarefas do dia."),
                backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  // Recarrega dados não-stream (inalterado)
  Future<void> _reloadDataNonStream({bool rebuildCards = true}) async {
    // ... (código inalterado)
    final authRepository = AuthRepository();
    final currentUser = authRepository.getCurrentUser();
    if (currentUser == null || !mounted) return;

    // Opcional: Mostrar um indicador sutil de recarga se necessário
    // setState(() => _isUpdatingLayout = true);

    try {
      // Recarrega UserData e Goals
      final results = await Future.wait([
        _firestoreService.getUserData(currentUser.uid),
        _firestoreService.getActiveGoals(currentUser.uid),
      ]);
      if (!mounted) return;

      final userData = results[0] as UserModel?;
      _userGoals = results[1] as List<Goal>;

      _userData = userData; // Atualiza userData

      // Recalcula Numerologia
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

      // Reconstrói a lista de cards se solicitado (padrão é true)
      // Chama dentro de setState para garantir a atualização da UI
      if (rebuildCards && mounted) {
        setState(() {
          _buildCardList();
          // _isUpdatingLayout = false; // Desliga indicador de recarga se usado
        });
      }
    } catch (e, stackTrace) {
      print("Erro ao recarregar dados (não stream): $e\n$stackTrace");
      if (mounted) {
        // setState(() => _isUpdatingLayout = false); // Desliga indicador de recarga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erro ao recarregar dados."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Handle para marcar/desmarcar tarefa (inalterado)
  void _handleTaskStatusChange(TaskModel task, bool isCompleted) {
    // ... (código inalterado)
    if (!mounted || _userData == null) return;
    // A UI será atualizada automaticamente pelo Stream quando o Firestore notificar
    _firestoreService
        .updateTaskCompletion(_userData!.uid, task.id, completed: isCompleted)
        .then((_) {
      // Atualiza progresso da meta associada, se houver, APÓS sucesso
      if (task.journeyId != null && task.journeyId!.isNotEmpty) {
        // Não precisa 'await' aqui, pode rodar em background
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
      // Poderia tentar reverter a UI otimista se tivesse uma
    });
  }

  // --- INÍCIO DA MUDANÇA ---
  // Placeholder para lidar com o toque na tarefa (abrir detalhes)
  void _handleTaskTap(TaskModel task) {
    // TODO: Implementar navegação para a nova tela/modal de detalhes/edição
    print("Dashboard: Tarefa tocada: ${task.id} - ${task.text}");
    // Exemplo: Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task, userId: _userData!.uid)));
  }

  // REMOVIDO: _handleTaskDeleted
  // void _handleTaskDeleted(TaskModel task) { ... }

  // REMOVIDO: _handleTaskEdited
  // void _handleTaskEdited(TaskModel task) { ... }

  // REMOVIDO: _handleTaskDuplicated
  // void _handleTaskDuplicated(TaskModel task) { ... }
  // --- FIM DA MUDANÇA ---

  // Handle para adicionar tarefa (inalterado)
  void _handleAddTask() {
    // ... (código inalterado)
    if (_userData == null) return; // Precisa de userData para o modal
    // Obtém a data de hoje (sem horas/minutos/segundos)
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: _userData!,
        // Passa a data de hoje como pré-selecionada (oculta)
        preselectedDate: today,
        // Não passamos preselectedGoal
      ),
    ).then((didCreate) {
      // O stream já atualizará a lista (_currentTodayTasks),
      // mas recarregamos goals/user para caso a nova tarefa
      // tenha sido associada a uma meta, atualizando o GoalsProgressCard.
      if (didCreate == true && mounted) {
        // Não precisamos mais chamar _reloadDataNonStream aqui se o único
        // efeito visual for no GoalsProgressCard, pois ele também usa Stream.
        // Se a associação da tarefa à meta afetar _userGoals de alguma forma
        // que não seja via stream, mantenha a linha abaixo.
        // _reloadDataNonStream();
      }
    });
  }

  // Navegação (inalterada)
  void _navigateToPage(int index) {
    // ... (código inalterado)
    if (!mounted) return;
    setState(() {
      _sidebarIndex = index;
      _isEditMode = false; // Sempre sai do modo edição ao navegar
      _isUpdatingLayout =
          false; // Cancela qualquer atualização de layout pendente
      // Fecha o drawer mobile se estiver aberto
      if (_isMobileDrawerOpen) {
        _isMobileDrawerOpen = false;
        _menuAnimationController.reverse();
      }
    });
  }

  void _navigateToGoalDetail(Goal goal) {
    // ... (código inalterado)
    if (_userData == null) return;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
          builder: (context) =>
              GoalDetailScreen(initialGoal: goal, userData: _userData!)),
    )
        .then((_) {
      // Recarrega goals e user data ao voltar, pois o progresso pode ter mudado
      // O stream de goals na GoalsScreen cuidará da atualização lá, mas
      // aqui precisamos atualizar _userGoals para o GoalsProgressCard.
      if (mounted) _reloadDataNonStream();
    });
  }

  // Constrói a lista de cards
  void _buildCardList() {
    if (!mounted || _userData == null) {
      _cards = [];
      return;
    }

    // Calcula dia pessoal (inalterado)
    int? todayPersonalDay;
    // ... (código inalterado)
    if (_numerologyData != null) {
      // Acessa o mapa 'numeros' e a chave 'diaPessoal' de forma segura
      // Verifica se a chave existe antes de acessar
      if (_numerologyData!.numeros.containsKey('diaPessoal')) {
        todayPersonalDay = _numerologyData!.numeros['diaPessoal'];
      }
    }

    // Mapa de todos os cards
    final Map<String, Widget> allCardsMap = {
      'goalsProgress': GoalsProgressCard(
        // ... (inalterado) ...
        key: const ValueKey('goalsProgress'), // Key para reordenação
        goals: _userGoals,
        onViewAll: () => _navigateToPage(4),
        onGoalSelected: _navigateToGoalDetail,
        isEditMode: _isEditMode,
        dragHandle: _isEditMode ? _buildDragHandle('goalsProgress') : null,
      ),

      // --- INÍCIO DA MUDANÇA ---
      'focusDay': FocusDayCard(
        key: const ValueKey('focusDay'),
        tasks: _currentTodayTasks,
        onViewAll: () => _navigateToPage(3),
        onTaskStatusChanged: _handleTaskStatusChange,
        userData: _userData!,
        onAddTask: _handleAddTask,
        onTaskTap: _handleTaskTap, // Passa o novo handler de tap
        // REMOVIDO: onTaskDeleted: _handleTaskDeleted,
        // REMOVIDO: onTaskEdited: _handleTaskEdited,
        // REMOVIDO: onTaskDuplicated: _handleTaskDuplicated,
        isEditMode: _isEditMode,
        dragHandle: _isEditMode ? _buildDragHandle('focusDay') : null,
      ),
      // --- FIM DA MUDANÇA ---

      // Cards de Numerologia (inalterados)
      if (_numerologyData != null) ...{
        // ... (código inalterado)
        'vibracaoDia': InfoCard(
            key: const ValueKey('vibracaoDia'),
            title: "Vibração do Dia",
            number: (_numerologyData!.numeros['diaPessoal'] ?? '-')
                .toString(), // Tratamento nulo seguro
            info: _getInfoContent(
                'diaPessoal',
                _numerologyData!.numeros['diaPessoal'] ??
                    0), // Tratamento nulo seguro
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
                    .toString(), // Acesso seguro ao mapa aninhado
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
            bussolaContent: _getBussolaContent(
                _numerologyData!.numeros['diaPessoal'] ??
                    0), // Tratamento nulo seguro
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('bussola') : null,
            onTap: () {}),
      }
    };

    // Lógica de ordenação (inalterada)
    final List<String> cardOrder = _userData!.dashboardCardOrder;
    // ... (código inalterado)
    final List<Widget> orderedCards = [];
    Set<String> addedKeys = {};
    // Adiciona cards na ordem salva
    for (String cardId in cardOrder) {
      // Verifica se o card existe no mapa (pode ter sido removido ou não calculado, ex: numerologia)
      if (allCardsMap.containsKey(cardId) && !addedKeys.contains(cardId)) {
        orderedCards.add(allCardsMap[cardId]!);
        addedKeys.add(cardId);
      }
    }
    // Adiciona cards novos (que não estavam na ordem salva ou não existiam antes) no final
    allCardsMap.forEach((key, value) {
      if (!addedKeys.contains(key)) {
        orderedCards.add(value);
      }
    });
    // Atualiza a lista final que será usada no build
    // Não chama setState aqui, pois _buildCardList é chamado dentro de setState ou Stream listener
    _cards = orderedCards;
  }

  // Build Drag Handle (inalterado)
  Widget _buildDragHandle(String cardKey) {
    // ... (código inalterado)
    // Encontra o índice ATUAL do card na lista _cards para o ReorderableDragStartListener
    // Usa firstWhereOrNull para evitar erro se a key não for encontrada
    int index = _cards.indexWhere((card) => card.key == ValueKey(cardKey));
    // Se não encontrar (improvável, mas por segurança), retorna um placeholder ou ícone desabilitado
    if (index == -1) {
      print(
          "AVISO: Não foi possível encontrar o índice para a key '$cardKey' em _buildDragHandle.");
      return const SizedBox(width: 24, height: 24); // Placeholder
      // return const Icon(Icons.drag_handle_disabled, color: AppColors.tertiaryText); // Ícone desabilitado
    }
    // O ReorderableDragStartListener precisa do índice correto na lista _cards atual
    return ReorderableDragStartListener(
      index: index, // Usa o índice encontrado
      child: const MouseRegion(
          // Melhora a indicação visual no desktop
          cursor: SystemMouseCursors.grab,
          child: Icon(Icons.drag_handle, color: AppColors.secondaryText)),
    );
  }

  // Getters de conteúdo (inalterados)
  VibrationContent _getInfoContent(String category, int number) {
    // ... (código inalterado)
    return ContentData.vibracoes[category]?[number] ??
        const VibrationContent(
            titulo: 'Indisponível',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getArcanoContent(int number) {
    // ... (código inalterado)
    return ContentData.textosArcanos[number] ??
        const VibrationContent(
            titulo: 'Arcano Desconhecido',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getCicloDeVidaContent(int number) {
    // ... (código inalterado)
    return ContentData.textosCiclosDeVida[number] ??
        const VibrationContent(
            titulo: 'Ciclo Desconhecido',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  BussolaContent _getBussolaContent(int number) {
    // ... (código inalterado)
    return ContentData.bussolaAtividades[number] ??
        ContentData.bussolaAtividades[0]!;
  }

  // Build Current Page (inalterado)
  Widget _buildCurrentPage() {
    // ... (código inalterado)
    // Mostra loading inicial apenas se _cards ainda não foi populado pelo stream/load inicial
    // E se não estivermos atualizando o layout após reordenação
    if (_isLoading && _cards.isEmpty && !_isUpdatingLayout) {
      return const Center(child: CustomLoadingSpinner());
    }
    // Se não está carregando mas não tem user data (erro no load inicial)
    if (_userData == null && !_isLoading) {
      return const Center(
          child: Text("Erro ao carregar dados do usuário.",
              style: TextStyle(color: Colors.red)));
    }

    // Se não está carregando, temos user data, mas _cards está vazio (ex: erro no stream, ou usuário sem cards)
    // E estamos na aba do dashboard (_sidebarIndex == 0)
    // E não estamos atualizando o layout
    if (!_isLoading &&
        _userData != null &&
        _cards.isEmpty &&
        _sidebarIndex == 0 &&
        !_isUpdatingLayout) {
      // Poderia mostrar o _buildEmptyState geral do dashboard aqui, se desejado
      return const Center(
          child: Text("Nenhum card para exibir.",
              style: TextStyle(color: AppColors.secondaryText)));
    }

    return IndexedStack(
      index: _sidebarIndex,
      children: [
        // Aba 0: Dashboard Content
        _buildDashboardContent(
            isDesktop: MediaQuery.of(context).size.width > 800),

        // Outras Abas (garante que _userData não seja nulo ANTES de construir a tela)
        // Usar um placeholder como CustomLoadingSpinner enquanto _userData é nulo evita erros
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

  // Abrir Modal de Reordenação (inalterado)
  void _openReorderModal() {
    // ... (código inalterado)
    if (!mounted || _userData == null || _isUpdatingLayout) return;
    final BuildContext currentContext =
        context; // Guarda o contexto antes do showModalBottomSheet
    setState(() => _isEditMode = true); // Entra no modo edição (mostra handles)

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
          // Passa uma CÓPIA da ordem atual para o modal, não a referência direta
          final currentOrder = List<String>.from(_userData!.dashboardCardOrder);
          return ReorderDashboardModal(
            userId: _userData!.uid,
            initialOrder: currentOrder, // Usa a cópia
            scrollController: scrollController,
            onSaveComplete: (bool success) async {
              // Este callback é chamado DEPOIS que o Firestore foi atualizado (ou falhou) DENTRO do modal

              // Garante que o widget ainda está montado
              if (!mounted) return;

              // Fecha o modal ANTES de recarregar os dados para evitar conflitos de contexto
              // Usa o contexto guardado (currentContext) que ainda é válido
              try {
                Navigator.of(currentContext).pop();
              } catch (e) {
                print("Erro ao fechar modal: $e");
              }
              await Future.delayed(const Duration(
                  milliseconds:
                      50)); // Pequeno delay para garantir fechamento visual
              if (!mounted) return;

              if (success) {
                // 1. Ativa o estado de loading para a atualização do layout
                setState(() => _isUpdatingLayout = true);
                // 2. Recarrega UserData (para pegar a nova ordem salva do Firestore)
                // ...e reconstrói a lista _cards com a nova ordem.
                // ...O stream de tarefas continua rodando independentemente.
                await _reloadDataNonStream(
                    rebuildCards:
                        true); // Força rebuildCards que chama _buildCardList

                // 3. Pequeno delay para garantir rebuild completo antes de esconder loading
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  // 4. Desativa loading e modo edição, atualiza a key da Grid
                  setState(() {
                    _masonryGridKey =
                        UniqueKey(); // Nova key para forçar rebuild da Grid Desktop
                    _isUpdatingLayout = false; // Desativa loading
                    _isEditMode = false; // Sai do modo edição
                  });
                }
              } else {
                // Se cancelou ou deu erro ao salvar no modal
                // Apenas sai do modo edição, não precisa recarregar nada
                if (mounted) setState(() => _isEditMode = false);
              }
            },
          );
        },
      ),
    ).whenComplete(() {
      // Chamado sempre que o modal fecha (por pop, dismiss, etc.)
      // Garante resetar estados (_isEditMode, _isUpdatingLayout) se o usuário fechar o modal arrastando, etc.
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
    // ... (build principal inalterado) ...
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        userData: _userData,
        menuAnimationController: _menuAnimationController,
        isEditMode: _isEditMode,
        // Habilita o botão de editar apenas na aba Dashboard (index 0) e se não estiver carregando/atualizando
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
      // Body seleciona o layout baseado na largura
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // Layouts Desktop/Mobile (inalterados)
  Widget _buildDesktopLayout() {
    // ... (código inalterado)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mostra sidebar apenas se userData estiver carregado
        if (_userData != null)
          DashboardSidebar(
              isExpanded: _isDesktopSidebarExpanded,
              selectedIndex: _sidebarIndex,
              userData: _userData!,
              onDestinationSelected: _navigateToPage),
        // Conteúdo principal ocupa o resto
        Expanded(child: _buildCurrentPage()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    // ... (código inalterado)
    const double sidebarWidth = 280;
    return Stack(
      children: [
        // Conteúdo principal com GestureDetector para fechar drawer e long press
        GestureDetector(
          onTap: () {
            // Fecha drawer ao tocar fora
            if (_isMobileDrawerOpen) {
              setState(() {
                _isMobileDrawerOpen = false;
                _menuAnimationController.reverse();
              });
            }
          },
          // Ativa o long press para reordenar apenas na aba Dashboard e se não estiver carregando/atualizando
          onLongPress: (_sidebarIndex != 0 || _isLoading || _isUpdatingLayout)
              ? null
              : _openReorderModal,
          child: _buildCurrentPage(),
        ),
        // Overlay escuro quando o drawer está aberto
        if (_isMobileDrawerOpen)
          GestureDetector(
              // GestureDetector para fechar o drawer
              onTap: () {
                setState(() {
                  _isMobileDrawerOpen = false;
                  _menuAnimationController.reverse();
                });
              },
              child: Container(
                  color:
                      Colors.black.withOpacity(0.5)) // Fundo semi-transparente
              ),
        // Drawer animado (Sidebar no modo mobile)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0, bottom: 0,
          left:
              _isMobileDrawerOpen ? 0 : -sidebarWidth, // Anima a posição 'left'
          width: sidebarWidth,
          child: _userData != null
              ? DashboardSidebar(
                  isExpanded: true, // Sempre expandido no modo drawer
                  selectedIndex: _sidebarIndex,
                  userData: _userData!,
                  onDestinationSelected: (index) {
                    // Navega para a página E fecha o drawer (a lógica está em _navigateToPage)
                    _navigateToPage(index);
                  },
                )
              : const SizedBox.shrink(), // Não mostra nada se userData for nulo
        ),
      ],
    );
  }

  // Build Dashboard Content (inalterado)
  Widget _buildDashboardContent({required bool isDesktop}) {
    // ... (código inalterado)
    // A lista _cards já foi atualizada pelo listener do stream ou _reloadDataNonStream/reorder

    // Mostra loading inicial apenas se _cards ainda estiver vazio E _isLoading for true
    if (_isLoading && _cards.isEmpty) {
      return const Center(child: CustomLoadingSpinner());
    }
    // Mostra loading durante a atualização pós-reordenação
    if (_isUpdatingLayout) {
      return const Center(child: CustomLoadingSpinner());
    }

    // Se, após carregar/atualizar, a lista _cards ainda estiver vazia
    if (!_isLoading && !_isUpdatingLayout && _cards.isEmpty) {
      return const Center(
          child: Text("Nenhum card para exibir.",
              style: TextStyle(color: AppColors.secondaryText)));
    }

    if (!isDesktop) {
      // Mobile: ListView
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80), // Padding padrão
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final itemWidget = _cards[index];
          // Garante uma key única se o widget não tiver uma, importante para reordenação
          return Padding(
              key: itemWidget.key ?? ValueKey('card_$index'),
              padding: const EdgeInsets.only(bottom: 20.0),
              child: itemWidget);
        },
      );
    } else {
      // Desktop: MasonryGridView
      final screenWidth = MediaQuery.of(context).size.width;
      const double spacing = 24.0;
      final sidebarWidth = _isDesktopSidebarExpanded ? 250.0 : 80.0;
      final availableWidth = screenWidth -
          sidebarWidth -
          (spacing * 2); // Subtrai padding laterais
      int crossAxisCount = 1; // Mínimo 1 coluna
      // Define número de colunas baseado na largura disponível
      if (availableWidth > 1300)
        crossAxisCount = 3;
      else if (availableWidth > 850) crossAxisCount = 2;
      // Garante que não haja mais colunas que o número de cards
      crossAxisCount = crossAxisCount.clamp(1, _cards.length);

      return ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: ListView(
          // Usando ListView como wrapper para garantir scroll vertical se necessário
          padding: const EdgeInsets.all(spacing),
          children: [
            MasonryGridView.count(
              key: _masonryGridKey, // Usa a key que é atualizada na reordenação
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                return _cards[index]; // Exibe os cards da lista _cards
              },
              shrinkWrap:
                  true, // Necessário para funcionar dentro de um ListView/ScrollView
              physics:
                  const NeverScrollableScrollPhysics(), // Desabilita scroll interno da Grid
            ),
            const SizedBox(height: 60), // Espaço no final abaixo da grid
          ],
        ),
      );
    }
  }
} // Fim da classe _DashboardScreenState

// lib/features/dashboard/presentation/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
import 'package:sincro_app_flutter/common/widgets/multi_number_card.dart';
import 'package:sincro_app_flutter/common/widgets/bussola_card.dart';
import 'package:sincro_app_flutter/common/widgets/custom_app_bar.dart';
import 'package:sincro_app_flutter/common/widgets/dashboard_sidebar.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/assistant_panel.dart';
import 'package:sincro_app_flutter/features/assistant/widgets/expanding_assistant_fab.dart';
import 'package:sincro_app_flutter/features/assistant/widgets/assistant_insights_card.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../journal/presentation/journal_screen.dart';
import '../../tasks/presentation/foco_do_dia_screen.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../goals/presentation/goal_detail_screen.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/widgets/reorder_dashboard_modal.dart';
import 'package:sincro_app_flutter/common/widgets/numerology_detail_modal.dart';

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
  StreamSubscription<List<Goal>>?
      _goalsSubscription; // Stream de metas em tempo real

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

  Future<void> _cancelSubscriptions() async {
    if (_todayTasksSubscription != null) {
      try {
        await _todayTasksSubscription!.cancel();
      } catch (error, stack) {
        debugPrint("Erro ao cancelar subscription: $error\n$stack");
      } finally {
        _todayTasksSubscription = null;
      }
    }
    if (_goalsSubscription != null) {
      try {
        await _goalsSubscription!.cancel();
      } catch (error, stack) {
        debugPrint("Erro ao cancelar goals subscription: $error\n$stack");
      } finally {
        _goalsSubscription = null;
      }
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
      _initializeGoalsStream(currentUser.uid);
      _initializeGoalsStream(currentUser.uid); // ativa stream de metas
    } catch (e, stackTrace) {
      debugPrint(
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
        debugPrint("Erro no stream de tarefas do dia: $error\n$stackTrace");
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

  void _initializeGoalsStream(String userId) {
    _goalsSubscription?.cancel();
    _goalsSubscription = _firestoreService.getGoalsStream(userId).listen(
      (goals) {
        if (!mounted) return;
        setState(() {
          _userGoals = goals;
          _buildCardList();
        });
      },
      onError: (error) {
        debugPrint('Erro no stream de metas: $error');
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
      _initializeGoalsStream(currentUser.uid);
    } catch (e, stackTrace) {
      debugPrint("Erro ao recarregar dados (não stream): $e\n$stackTrace");
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
      debugPrint("Erro ao atualizar status da tarefa: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erro ao atualizar tarefa."),
              backgroundColor: Colors.red),
        );
      }
    });
  }

  void _handleTaskTap(TaskModel task) {}

  // ---
  // --- ATUALIZAÇÃO NESTA FUNÇÃO ---
  // ---
  Future<void> _handleAddTask() async {
    if (_userData == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: _userData!,
        userId: _userData!.uid,
        onAddTask: (ParsedTask parsedTask) {
          _createSingleTaskWithPersonalDay(parsedTask);
        },
      ),
    );
  }

  /// Cria uma única tarefa com cálculo do Dia Pessoal (mesma lógica do FocoDoDiaScreen)
  void _createSingleTaskWithPersonalDay(ParsedTask parsedTask) {
    if (_userData == null) return;

    DateTime? finalDueDateUtc;
    DateTime dateForPersonalDay;

    if (parsedTask.dueDate != null) {
      // Se tem data específica, usa ela
      final dateLocal = parsedTask.dueDate!.toLocal();
      finalDueDateUtc =
          DateTime.utc(dateLocal.year, dateLocal.month, dateLocal.day);
      dateForPersonalDay = finalDueDateUtc;
    } else {
      // Se não tem data específica, usa a data atual para calcular o personalDay
      final now = DateTime.now().toLocal();
      dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
      // NÃO define finalDueDateUtc - deixa null para tarefas sem data específica
    }

    // Calcula o dia pessoal usando a data determinada
    final int? finalPersonalDay = _calculatePersonalDay(dateForPersonalDay);

    final newTask = TaskModel(
      id: '',
      text: parsedTask.cleanText,
      createdAt: DateTime.now().toUtc(),
      dueDate: finalDueDateUtc,
      journeyId: parsedTask.journeyId,
      journeyTitle: parsedTask.journeyTitle,
      tags: parsedTask.tags,
      reminderTime: parsedTask.reminderTime,
      recurrenceType: parsedTask.recurrenceRule.type,
      recurrenceDaysOfWeek: parsedTask.recurrenceRule.daysOfWeek,
      recurrenceEndDate: parsedTask.recurrenceRule.endDate?.toUtc(),
      personalDay: finalPersonalDay,
    );

    _firestoreService.addTask(_userData!.uid, newTask).catchError((error) {
      debugPrint("Erro ao adicionar tarefa pelo dashboard: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar tarefa: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// Calcula o Dia Pessoal para uma data específica (mesma lógica do FocoDoDiaScreen)
  int? _calculatePersonalDay(DateTime? date) {
    if (_userData == null ||
        _userData!.dataNasc.isEmpty ||
        _userData!.nomeAnalise.isEmpty ||
        date == null) {
      return null;
    }

    final engine = NumerologyEngine(
      nomeCompleto: _userData!.nomeAnalise,
      dataNascimento: _userData!.dataNasc,
    );

    try {
      final dateUtc = date.toUtc();
      final day = engine.calculatePersonalDayForDate(dateUtc);
      return (day > 0) ? day : null;
    } catch (e) {
      debugPrint("Erro ao calcular dia pessoal para $date: $e");
      return null;
    }
  }

  // --- FIM DA ATUALIZAÇÃO ---

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
    // Conjunto de cards ocultos
    final Set<String> hidden = _userData?.dashboardHiddenCards.toSet() ?? {};

    final Map<String, Widget> allCardsMap = {
      // Card de insights IA: disponível para todos os planos, mas IA só responde se não excedeu limite
      'assistantInsights': AssistantInsightsCard(
        key: const ValueKey('assistantInsights'),
        user: _userData!,
      ),
      'goalsProgress': GoalsProgressCard(
        key: const ValueKey('goalsProgress'),
        goals: _userGoals,
        onViewAll: () => _navigateToPage(4),
        onGoalSelected: _navigateToGoalDetail,
        userId: _userData!.uid,
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
            title: "Dia Pessoal",
            number: (_numerologyData!.numeros['diaPessoal'] ?? '-').toString(),
            info: _getInfoContent(
                'diaPessoal', _numerologyData!.numeros['diaPessoal'] ?? 0),
            icon: Icons.sunny,
            color: Colors.cyan.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('vibracaoDia') : null,
            onTap: () => _showNumerologyDetail(
                  title: "Dia Pessoal",
                  number:
                      (_numerologyData!.numeros['diaPessoal'] ?? 0).toString(),
                  content: _getInfoContent('diaPessoal',
                      _numerologyData!.numeros['diaPessoal'] ?? 0),
                  color: Colors.cyan.shade300,
                  icon: Icons.sunny,
                  categoryIntro:
                      "O Dia Pessoal revela a energia que te acompanha hoje, influenciando suas emoções, decisões e oportunidades. Ele é calculado somando o dia atual com seu mês e ano pessoal, criando um ciclo de 1 a 9 que se renova diariamente.",
                )),
        'vibracaoMes': InfoCard(
            key: const ValueKey('vibracaoMes'),
            title: "Mês Pessoal",
            number: (_numerologyData!.numeros['mesPessoal'] ?? '-').toString(),
            info: _getInfoContent(
                'mesPessoal', _numerologyData!.numeros['mesPessoal'] ?? 0),
            icon: Icons.nightlight_round,
            color: Colors.indigo.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('vibracaoMes') : null,
            onTap: () => _showNumerologyDetail(
                  title: "Mês Pessoal",
                  number:
                      (_numerologyData!.numeros['mesPessoal'] ?? 0).toString(),
                  content: _getInfoContent('mesPessoal',
                      _numerologyData!.numeros['mesPessoal'] ?? 0),
                  color: Colors.indigo.shade300,
                  icon: Icons.nightlight_round,
                  categoryIntro:
                      "O Mês Pessoal define o tema energético que permeia todo este mês para você, trazendo lições, desafios e oportunidades específicas. É calculado combinando o mês atual com seu ano pessoal e se renova mensalmente.",
                )),
        'vibracaoAno': InfoCard(
            key: const ValueKey('vibracaoAno'),
            title: "Ano Pessoal",
            number: (_numerologyData!.numeros['anoPessoal'] ?? '-').toString(),
            info: _getInfoContent(
                'anoPessoal', _numerologyData!.numeros['anoPessoal'] ?? 0),
            icon: Icons.star,
            color: Colors.amber.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('vibracaoAno') : null,
            onTap: () => _showNumerologyDetail(
                  title: "Ano Pessoal",
                  number:
                      (_numerologyData!.numeros['anoPessoal'] ?? 0).toString(),
                  content: _getInfoContent('anoPessoal',
                      _numerologyData!.numeros['anoPessoal'] ?? 0),
                  color: Colors.amber.shade300,
                  icon: Icons.star,
                  categoryIntro:
                      "O Ano Pessoal representa o tema principal de todo o seu ano, indicando as grandes lições, transformações e oportunidades que você encontrará. É calculado somando seu dia e mês de nascimento com o ano atual, criando um ciclo de 9 anos que se repete ao longo da vida.",
                )),
        // REMOVIDOS: Cards de Arcanos (Regente e Vigente) – não fazem mais parte do sistema.
        'cicloVida': InfoCard(
            key: const ValueKey('cicloVida'),
            title: "Ciclo de Vida",
            number: (_numerologyData!.estruturas['cicloDeVidaAtual']
                        ?['regente'] ??
                    '-')
                .toString(),
            info: _buildCiclosDeVidaContent(
                _numerologyData!.estruturas['ciclosDeVida'] ?? {},
                _numerologyData!.idade),
            icon: Icons.repeat,
            color: Colors.green.shade300,
            isEditMode: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle('cicloVida') : null,
            onTap: () => _showNumerologyDetail(
                  title: "Ciclo de Vida",
                  number: (_numerologyData!.estruturas['cicloDeVidaAtual']
                              ?['regente'] ??
                          0)
                      .toString(),
                  content: _buildCiclosDeVidaContent(
                      _numerologyData!.estruturas['ciclosDeVida'] ?? {},
                      _numerologyData!.idade),
                  color: Colors.green.shade300,
                  icon: Icons.repeat,
                  categoryIntro:
                      "O Ciclo de Vida divide sua existência em três grandes fases, cada uma regida por um número diferente que traz temas, aprendizados e desafios específicos. O ciclo atual indica a energia que está moldando esta fase da sua jornada.",
                )),
        // NOVOS CARDS - Disponíveis apenas para planos pagos (Desperta e Sinergia)
        if (_userData!.subscription.plan != SubscriptionPlan.free) ...{
          'numeroDestino': InfoCard(
              key: const ValueKey('numeroDestino'),
              title: "Número de Destino",
              number: (_numerologyData!.numeros['destino'] ?? '-').toString(),
              info:
                  _getDestinoContent(_numerologyData!.numeros['destino'] ?? 0),
              icon: Icons.explore,
              color: Colors.blue.shade300,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('numeroDestino') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Número de Destino",
                    number:
                        (_numerologyData!.numeros['destino'] ?? 0).toString(),
                    content: _getDestinoContent(
                        _numerologyData!.numeros['destino'] ?? 0),
                    color: Colors.blue.shade300,
                    icon: Icons.explore,
                    categoryIntro:
                        "O Número de Destino revela o propósito principal da sua vida, as lições que você veio aprender e as experiências que moldarão seu caminho. É calculado a partir da sua data de nascimento completa e representa a missão de alma que você carrega nesta jornada.",
                  )),
          'numeroExpressao': InfoCard(
              key: const ValueKey('numeroExpressao'),
              title: "Número de Expressão",
              number: (_numerologyData!.numeros['expressao'] ?? '-').toString(),
              info: _getExpressaoContent(
                  _numerologyData!.numeros['expressao'] ?? 0),
              icon: Icons.face,
              color: Colors.orange.shade300,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('numeroExpressao') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Número de Expressão",
                    number:
                        (_numerologyData!.numeros['expressao'] ?? 0).toString(),
                    content: _getExpressaoContent(
                        _numerologyData!.numeros['expressao'] ?? 0),
                    color: Colors.orange.shade300,
                    icon: Icons.face,
                    categoryIntro:
                        "O Número de Expressão representa como você se comunica com o mundo, seus talentos naturais e a forma como você expressa sua essência. É calculado a partir do seu nome completo de nascimento e mostra suas habilidades inatas e o modo como você impacta os outros.",
                  )),
          'numeroMotivacao': InfoCard(
              key: const ValueKey('numeroMotivacao'),
              title: "Número da Motivação",
              number: (_numerologyData!.numeros['motivacao'] ?? '-').toString(),
              info: _getMotivacaoContent(
                  _numerologyData!.numeros['motivacao'] ?? 0),
              icon: Icons.favorite,
              color: Colors.pink.shade300,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('numeroMotivacao') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Número da Motivação",
                    number:
                        (_numerologyData!.numeros['motivacao'] ?? 0).toString(),
                    content: _getMotivacaoContent(
                        _numerologyData!.numeros['motivacao'] ?? 0),
                    color: Colors.pink.shade300,
                    icon: Icons.favorite,
                    categoryIntro:
                        "O Número da Motivação revela seus desejos mais profundos, o que realmente move seu coração e as aspirações da sua alma. É calculado pelas vogais do seu nome e representa sua força motriz interior, aquilo que você verdadeiramente valoriza e busca na vida.",
                  )),
          'numeroImpressao': InfoCard(
              key: const ValueKey('numeroImpressao'),
              title: "Número de Impressão",
              number: (_numerologyData!.numeros['impressao'] ?? '-').toString(),
              info: _getImpressaoContent(
                  _numerologyData!.numeros['impressao'] ?? 0),
              icon: Icons.visibility,
              color: Colors.teal.shade300,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('numeroImpressao') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Número de Impressão",
                    number:
                        (_numerologyData!.numeros['impressao'] ?? 0).toString(),
                    content: _getImpressaoContent(
                        _numerologyData!.numeros['impressao'] ?? 0),
                    color: Colors.teal.shade300,
                    icon: Icons.visibility,
                    categoryIntro:
                        "O Número de Impressão mostra como os outros te percebem no primeiro contato, a energia que você projeta e a primeira impressão que causa. É calculado pelas consoantes do seu nome e representa a 'máscara social' que você naturalmente usa ao interagir com o mundo.",
                  )),
          'missaoVida': InfoCard(
              key: const ValueKey('missaoVida'),
              title: "Missão de Vida",
              number: (_numerologyData!.numeros['missao'] ?? '-').toString(),
              info: _getMissaoContent(_numerologyData!.numeros['missao'] ?? 0),
              icon: Icons.flag,
              color: Colors.deepOrange.shade300,
              isEditMode: _isEditMode,
              dragHandle: _isEditMode ? _buildDragHandle('missaoVida') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Missão de Vida",
                    number:
                        (_numerologyData!.numeros['missao'] ?? 0).toString(),
                    content: _getMissaoContent(
                        _numerologyData!.numeros['missao'] ?? 0),
                    color: Colors.deepOrange.shade300,
                    icon: Icons.flag,
                    categoryIntro:
                        "A Missão de Vida representa o grande objetivo da sua existência, o legado que você veio deixar e a contribuição única que pode oferecer ao mundo. Este número indica o caminho de realização máxima e o propósito transcendental da sua jornada.",
                  )),
          'talentoOculto': InfoCard(
              key: const ValueKey('talentoOculto'),
              title: "Talento Oculto",
              number:
                  (_numerologyData!.numeros['talentoOculto'] ?? '-').toString(),
              info: ContentData.textosTalentoOculto[
                      _numerologyData!.numeros['talentoOculto'] ?? 0] ??
                  const VibrationContent(
                      titulo: 'Talento Oculto',
                      descricaoCurta:
                          'Habilidade latente aguardando uso consciente.',
                      descricaoCompleta:
                          'Seu Talento Oculto representa capacidades dormentes que emergem quando você integra suas motivações internas com a forma como se expressa no mundo.',
                      inspiracao:
                          'Quando você integra coração e expressão, talentos profundos despertam.'),
              icon: Icons.auto_awesome,
              color: Colors.yellow.shade300,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('talentoOculto') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Talento Oculto",
                    number: (_numerologyData!.numeros['talentoOculto'] ?? 0)
                        .toString(),
                    content: ContentData.textosTalentoOculto[
                            _numerologyData!.numeros['talentoOculto'] ?? 0] ??
                        const VibrationContent(
                            titulo: 'Talento Oculto',
                            descricaoCurta:
                                'Habilidade latente aguardando uso consciente.',
                            descricaoCompleta:
                                'Seu Talento Oculto representa capacidades dormentes que emergem quando você integra suas motivações internas com a forma como se expressa no mundo.',
                            inspiracao:
                                'Quando você integra coração e expressão, talentos profundos despertam.'),
                    color: Colors.yellow.shade300,
                    icon: Icons.auto_awesome,
                    categoryIntro:
                        "O Talento Oculto revela habilidades dormentes dentro de você, potenciais que ainda não foram completamente desenvolvidos ou reconhecidos. É uma força silenciosa que pode ser despertada e cultivada para transformar sua vida e ampliar suas possibilidades.",
                  )),
          'respostaSubconsciente': InfoCard(
              key: const ValueKey('respostaSubconsciente'),
              title: "Resposta Subconsciente",
              number: (_numerologyData!.numeros['respostaSubconsciente'] ?? '-')
                  .toString(),
              info: ContentData.textosRespostaSubconsciente[
                      _numerologyData!.numeros['respostaSubconsciente'] ?? 0] ??
                  const VibrationContent(
                      titulo: 'Resposta Subconsciente',
                      descricaoCurta: 'Como você reage sob pressão.',
                      descricaoCompleta:
                          'Este número revela padrões automáticos de reação diante de desafios e crises. Ao reconhecê-los, você pode transformá-los em respostas mais conscientes.',
                      inspiracao: 'Consciência transforma reação em escolha.'),
              icon: Icons.psychology,
              color: Colors.deepPurple.shade300,
              isEditMode: _isEditMode,
              dragHandle: _isEditMode
                  ? _buildDragHandle('respostaSubconsciente')
                  : null,
              onTap: () => _showNumerologyDetail(
                    title: "Resposta Subconsciente",
                    number:
                        (_numerologyData!.numeros['respostaSubconsciente'] ?? 0)
                            .toString(),
                    content: ContentData.textosRespostaSubconsciente[
                            _numerologyData!.numeros['respostaSubconsciente'] ??
                                0] ??
                        const VibrationContent(
                            titulo: 'Resposta Subconsciente',
                            descricaoCurta: 'Como você reage sob pressão.',
                            descricaoCompleta:
                                'Este número revela padrões automáticos de reação diante de desafios e crises. Ao reconhecê-los, você pode transformá-los em respostas mais conscientes.',
                            inspiracao:
                                'Consciência transforma reação em escolha.'),
                    color: Colors.deepPurple.shade300,
                    icon: Icons.psychology,
                    categoryIntro:
                        "A Resposta Subconsciente indica como você reage instintivamente a desafios e situações de pressão, revelando seus padrões automáticos de comportamento. Este número mostra a quantidade de números ausentes no seu nome e como isso influencia suas respostas inconscientes.",
                  )),
          'diaNatalicio': InfoCard(
              key: const ValueKey('diaNatalicio'),
              title: "Dia Natalício",
              number:
                  (_numerologyData!.numeros['diaNatalicio'] ?? '-').toString(),
              info: ContentData.diaNatalicioLookup(
                      _numerologyData!.numeros['diaNatalicio'] ?? 1) ??
                  const VibrationContent(
                      titulo: 'Dia Natalício',
                      descricaoCurta:
                          'Traços natos associados ao seu dia de nascimento.',
                      descricaoCompleta:
                          'O Dia Natalício é a vibração do próprio dia do seu nascimento (1–31) e revela qualidades naturais que acompanham sua personalidade desde o início da vida.',
                      inspiracao:
                          'Honre o que nasceu com você — é sua base de força.'),
              icon: Icons.cake,
              color: Colors.pink.shade300,
              isEditMode: _isEditMode,
              dragHandle: _isEditMode ? _buildDragHandle('diaNatalicio') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Dia Natalício",
                    number: (_numerologyData!.numeros['diaNatalicio'] ?? 0)
                        .toString(),
                    content: ContentData.diaNatalicioLookup(
                            _numerologyData!.numeros['diaNatalicio'] ?? 1) ??
                        const VibrationContent(
                            titulo: 'Dia Natalício',
                            descricaoCurta:
                                'Traços natos associados ao seu dia de nascimento.',
                            descricaoCompleta:
                                'O Dia Natalício é a vibração do próprio dia do seu nascimento (1–31) e revela qualidades naturais que acompanham sua personalidade desde o início da vida.',
                            inspiracao:
                                'Honre o que nasceu com você — é sua base de força.'),
                    color: Colors.pink.shade300,
                    icon: Icons.cake,
                    categoryIntro:
                        "O Dia Natalício revela as características naturais que você trouxe ao nascer, influenciando sua personalidade e seu caminho de vida desde o primeiro dia. É uma vibração que molda quem você é de forma inata e profunda.",
                  )),
          'numeroPsiquico': InfoCard(
              key: const ValueKey('numeroPsiquico'),
              title: "Número Psíquico",
              number: (_numerologyData!.numeros['numeroPsiquico'] ?? '-')
                  .toString(),
              info: _getNumeroPsiquicoContent(
                  _numerologyData!.numeros['numeroPsiquico'] ?? 0),
              icon: Icons.bubble_chart_outlined,
              color: Colors.lightBlue.shade300,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('numeroPsiquico') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Número Psíquico",
                    number: (_numerologyData!.numeros['numeroPsiquico'] ?? 0)
                        .toString(),
                    content: _getNumeroPsiquicoContent(
                        _numerologyData!.numeros['numeroPsiquico'] ?? 0),
                    color: Colors.lightBlue.shade300,
                    icon: Icons.bubble_chart_outlined,
                    categoryIntro:
                        "O Número Psíquico é a redução do dia do seu nascimento (1–9) e descreve sua essência íntima — como você sente, decide e reage de forma espontânea.",
                  )),
          'aptidoesProfissionais': InfoCard(
              key: const ValueKey('aptidoesProfissionais'),
              title: "Aptidões Profissionais",
              number: (_numerologyData!.numeros['aptidoesProfissionais'] ?? '-')
                  .toString(),
              info: _getAptidoesProfissionaisContent(
                  _numerologyData!.numeros['aptidoesProfissionais'] ?? 0),
              icon: Icons.work_outline,
              color: Colors.cyan.shade300,
              isEditMode: _isEditMode,
              dragHandle: _isEditMode
                  ? _buildDragHandle('aptidoesProfissionais')
                  : null,
              onTap: () => _showNumerologyDetail(
                    title: "Aptidões Profissionais",
                    number:
                        (_numerologyData!.numeros['aptidoesProfissionais'] ?? 0)
                            .toString(),
                    content: _getAptidoesProfissionaisContent(
                        _numerologyData!.numeros['aptidoesProfissionais'] ?? 0),
                    color: Colors.cyan.shade300,
                    icon: Icons.work_outline,
                    categoryIntro:
                        "As Aptidões Profissionais mostram áreas de maior potencial de atuação, talentos naturais e estilos de trabalho mais favoráveis. Aqui utilizamos a vibração da Expressão como referência prática.",
                  )),
          'desafios': InfoCard(
              key: const ValueKey('desafios'),
              title: "Desafio Pessoal",
              number: (_numerologyData!.numeros['desafio'] ?? '-').toString(),
              info: _buildDesafiosContent(
                  _numerologyData!.estruturas['desafios']
                          as Map<String, int>? ??
                      {},
                  _numerologyData!.idade),
              icon: Icons.warning_amber_outlined,
              color: Colors.orangeAccent.shade200,
              isEditMode: _isEditMode,
              dragHandle: _isEditMode ? _buildDragHandle('desafios') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Desafios",
                    number:
                        (_numerologyData!.numeros['desafio'] ?? 0).toString(),
                    content: _buildDesafiosContent(
                        _numerologyData!.estruturas['desafios']
                                as Map<String, int>? ??
                            {},
                        _numerologyData!.idade),
                    color: Colors.orangeAccent.shade200,
                    icon: Icons.warning_amber_outlined,
                    categoryIntro:
                        "Os Desafios representam áreas de crescimento e superação em diferentes fases da vida. Cada período tem seu próprio desafio específico.",
                  )),
          'momentosDecisivos': InfoCard(
              key: const ValueKey('momentosDecisivos'),
              title: "Momento Decisivo",
              number:
                  (_numerologyData!.estruturas['momentoDecisivoAtual'] ?? '-')
                      .toString(),
              info: _buildMomentosDecisivosContent(
                  _numerologyData!.estruturas['momentosDecisivos']
                          as Map<String, dynamic>? ??
                      {},
                  _numerologyData!.idade),
              icon: Icons.timelapse,
              color: Colors.indigoAccent.shade200,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('momentosDecisivos') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Momentos Decisivos",
                    number:
                        (_numerologyData!.estruturas['momentoDecisivoAtual'] ??
                                0)
                            .toString(),
                    content: _buildMomentosDecisivosContent(
                        _numerologyData!.estruturas['momentosDecisivos']
                                as Map<String, dynamic>? ??
                            {},
                        _numerologyData!.idade),
                    color: Colors.indigoAccent.shade200,
                    icon: Icons.timelapse,
                    categoryIntro:
                        "Os Momentos Decisivos (Pinnacles) marcam períodos de oportunidade e realização em sua vida, mudando com a idade.",
                  )),
          // Listas e Relacionamentos adicionais (mapa completo)
          'licoesCarmicas': MultiNumberCard(
              key: const ValueKey('licoesCarmicas'),
              title: "Lições Kármicas",
              numbers:
                  (_numerologyData!.listas['licoesCarmicas'] as List<int>?) ??
                      const [],
              numberTexts: _getLicoesCarmicasTexts(
                  (_numerologyData!.listas['licoesCarmicas'] as List<int>?) ??
                      const []),
              numberTitles: _getLicoesCarmicasTitles(
                  (_numerologyData!.listas['licoesCarmicas'] as List<int>?) ??
                      const []),
              info: _buildLicoesCarmicasContent(
                  (_numerologyData!.listas['licoesCarmicas'] as List<int>?) ??
                      const []),
              icon: Icons.menu_book_outlined,
              color: Colors.lightBlueAccent.shade200,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('licoesCarmicas') : null,
              onTap: () {
                final licoes =
                    (_numerologyData!.listas['licoesCarmicas'] as List<int>?) ??
                        const [];
                final content = _buildLicoesCarmicasContent(licoes);
                _showNumerologyDetail(
                  title: content
                      .titulo, // Usa o título do content que já tem os números
                  content: content,
                  color: Colors.lightBlueAccent.shade200,
                  icon: Icons.menu_book_outlined,
                  categoryIntro:
                      "As Lições Kármicas representam aprendizados que sua alma escolheu desenvolver nesta vida. Elas surgem quando determinados números de 1 a 9 estão ausentes no seu nome, indicando áreas onde a experiência prática e a consciência serão mais requisitadas.",
                );
              }),
          'debitosCarmicos': MultiNumberCard(
              key: const ValueKey('debitosCarmicos'),
              title: "Débitos Kármicos",
              numbers:
                  (_numerologyData!.listas['debitosCarmicos'] as List<int>?) ??
                      const [],
              numberTexts: _getDebitosCarmicosTexts(
                  (_numerologyData!.listas['debitosCarmicos'] as List<int>?) ??
                      const []),
              numberTitles: _getDebitosCarmicosTitles(
                  (_numerologyData!.listas['debitosCarmicos'] as List<int>?) ??
                      const []),
              info: _buildDebitosCarmicosContent(
                  (_numerologyData!.listas['debitosCarmicos'] as List<int>?) ??
                      const []),
              icon: Icons.balance_outlined,
              color: Colors.redAccent.shade200,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('debitosCarmicos') : null,
              onTap: () {
                final debitos = (_numerologyData!.listas['debitosCarmicos']
                        as List<int>?) ??
                    const [];
                final content = _buildDebitosCarmicosContent(debitos);
                _showNumerologyDetail(
                  title: content
                      .titulo, // Usa o título do content que já tem os números
                  content: content,
                  color: Colors.redAccent.shade200,
                  icon: Icons.balance_outlined,
                  categoryIntro:
                      "Os Débitos Kármicos (13, 14, 16 e 19) indicam experiências de ajuste e amadurecimento. Eles apontam hábitos ou padrões que precisam ser transformados para que a vida flua com mais leveza e propósito.",
                );
              }),
          'tendenciasOcultas': MultiNumberCard(
              key: const ValueKey('tendenciasOcultas'),
              title: "Tendências Ocultas",
              numbers: (_numerologyData!.listas['tendenciasOcultas']
                      as List<int>?) ??
                  const [],
              numberTexts: _getTendenciasOcultasTexts((_numerologyData!
                      .listas['tendenciasOcultas'] as List<int>?) ??
                  const []),
              numberTitles: _getTendenciasOcultasTitles((_numerologyData!
                      .listas['tendenciasOcultas'] as List<int>?) ??
                  const []),
              info: _buildTendenciasOcultasContent(
                  (_numerologyData!.listas['tendenciasOcultas'] as List<int>?) ??
                      const []),
              icon: Icons.visibility_off_outlined,
              color: Colors.deepOrange.shade200,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('tendenciasOcultas') : null,
              onTap: () {
                final tendencias = (_numerologyData!.listas['tendenciasOcultas']
                        as List<int>?) ??
                    const [];
                final content = _buildTendenciasOcultasContent(tendencias);
                _showNumerologyDetail(
                  title: content
                      .titulo, // Usa o título do content que já tem os números
                  content: content,
                  color: Colors.deepOrange.shade200,
                  icon: Icons.visibility_off_outlined,
                  categoryIntro:
                      "As Tendências Ocultas revelam números que aparecem com maior frequência no seu nome, indicando inclinações latentes que influenciam suas escolhas e comportamentos mesmo sem você perceber conscientemente.",
                );
              }),
          'harmoniaConjugal': InfoCard(
              key: const ValueKey('harmoniaConjugal'),
              title: "Harmonia Conjugal",
              number: (_numerologyData!.numeros['missao'] ?? '-').toString(),
              info: _buildHarmoniaConjugalContent(
                  (_numerologyData!.estruturas['harmoniaConjugal']
                          as Map<String, dynamic>?) ??
                      const {},
                  _numerologyData!.numeros['missao'] ?? 0),
              icon: Icons.favorite_border,
              color: Colors.pink.shade200,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('harmoniaConjugal') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Harmonia Conjugal",
                    number:
                        (_numerologyData!.numeros['missao'] ?? 0).toString(),
                    content: _buildHarmoniaConjugalContent(
                        (_numerologyData!.estruturas['harmoniaConjugal']
                                as Map<String, dynamic>?) ??
                            const {},
                        _numerologyData!.numeros['missao'] ?? 0),
                    color: Colors.pink.shade200,
                    icon: Icons.favorite_border,
                    categoryIntro:
                        "A Harmonia Conjugal apresenta combinações numéricas que vibram em sintonia com a sua Missão de Vida. Ela sugere perfis que naturalmente entram em ressonância com a sua energia, bem como dinâmicas que pedem maior consciência e diálogo.",
                  )),
          'diasFavoraveis': InfoCard(
              key: const ValueKey('diasFavoraveis'),
              title: "Dias Favoráveis",
              number: (_getNextFavorableDay() ?? 0).toString(),
              info: _buildProximoDiaFavoravelContent(),
              icon: Icons.event_available,
              color: Colors.greenAccent.shade200,
              isEditMode: _isEditMode,
              dragHandle:
                  _isEditMode ? _buildDragHandle('diasFavoraveis') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Dias Favoráveis",
                    number: (_getNextFavorableDay() ?? 0).toString(),
                    content: _buildDiasFavoraveisCompleteContent(),
                    color: Colors.greenAccent.shade200,
                    icon: Icons.event_available,
                    categoryIntro:
                        "Os Dias Favoráveis são datas do mês em que a vibração do seu Dia Pessoal entra em ressonância com números-chave do seu mapa (como Destino, Expressão, Motivação, Impressão e Missão). Nessas datas, decisões e iniciativas tendem a fluir com mais naturalidade.",
                  )),
        },
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
      if (allCardsMap.containsKey(cardId) &&
          !addedKeys.contains(cardId) &&
          !hidden.contains(cardId)) {
        orderedCards.add(allCardsMap[cardId]!);
        addedKeys.add(cardId);
      }
    }
    allCardsMap.forEach((key, value) {
      if (!addedKeys.contains(key) && !hidden.contains(key)) {
        orderedCards.add(value);
      }
    });
    _cards = orderedCards;
  }

  Widget _buildDragHandle(String cardKey) {
    int index = _cards.indexWhere((card) => card.key == ValueKey(cardKey));
    if (index == -1) {
      debugPrint(
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

  // Removido: getter de conteúdo de Arcanos

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

  // Novos getters para os cards adicionais
  VibrationContent _getDestinoContent(int number) {
    return ContentData.textosDestino[number] ??
        const VibrationContent(
            titulo: 'Destino Desconhecido',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getExpressaoContent(int number) {
    return ContentData.textosExpressao[number] ??
        const VibrationContent(
            titulo: 'Expressão Desconhecida',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getMotivacaoContent(int number) {
    return ContentData.textosMotivacao[number] ??
        const VibrationContent(
            titulo: 'Motivação Desconhecida',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getImpressaoContent(int number) {
    return ContentData.textosImpressao[number] ??
        const VibrationContent(
            titulo: 'Impressão Desconhecida',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getMissaoContent(int number) {
    return ContentData.textosMissao[number] ??
        const VibrationContent(
            titulo: 'Missão Desconhecida',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getNumeroPsiquicoContent(int number) {
    return ContentData.textosNumeroPsiquico[number] ??
        const VibrationContent(
            titulo: 'Número Psíquico',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getAptidoesProfissionaisContent(int number) {
    return ContentData.textosAptidoesProfissionais[number] ??
        const VibrationContent(
            titulo: 'Aptidões Profissionais',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getDesafioContent(int number) {
    return ContentData.textosDesafios[number] ??
        const VibrationContent(
            titulo: 'Desafio',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  VibrationContent _getMomentoDecisivoContent(int number) {
    return ContentData.textosMomentosDecisivos[number] ??
        const VibrationContent(
            titulo: 'Momento Decisivo',
            descricaoCurta: '...',
            descricaoCompleta: '',
            inspiracao: '');
  }

  // ====== CONTEÚDOS DINÂMICOS PARA LISTAS ======
  String _joinComE(List<int> numeros) {
    if (numeros.isEmpty) return '';
    if (numeros.length == 1) return numeros.first.toString();
    final partes = numeros.map((e) => e.toString()).toList();
    final ultimo = partes.removeLast();
    return '${partes.join(', ')} e $ultimo';
  }

  VibrationContent _buildLicoesCarmicasContent(List<int> licoes) {
    if (licoes.isEmpty) {
      return const VibrationContent(
        titulo: 'Sem Lições Kármicas',
        descricaoCurta: 'Nenhum número ausente entre 1 e 9.',
        descricaoCompleta:
            'Seu nome contém representação de todos os números de 1 a 9, indicando que os aprendizados fundamentais já estão integrados.\n\nIsso não elimina desafios, mas sugere maior fluidez para assimilar experiências.',
        inspiracao:
            'Integração é reconhecer que cada experiência já deixou sua marca de aprendizado.',
        tags: ['Integração'],
      );
    }

    final titulo = 'Lições Kármicas (${licoes.join(', ')})';

    // Curta (card): Cabeçalho + linhas por número no formato "n: texto curto".
    final linhasCurtas = <String>[];
    linhasCurtas.add('Lições Kármicas: ${_joinComE(licoes)}');
    // Completa: título do número + descrição completa original.
    final buffer = StringBuffer();
    buffer.writeln(
        'Estas lições indicam áreas onde a vida pedirá prática consciente e desenvolvimento gradual.');
    for (final n in licoes) {
      final content = ContentData.textosLicoesCarmicas[n];
      if (content != null) {
        linhasCurtas.add('$n: ${content.descricaoCurta}');
        buffer.writeln('\n**Lição Kármica $n**');
        buffer.writeln(content.descricaoCompleta.trim());
        if (content.inspiracao.isNotEmpty) {
          buffer.writeln('\n*Inspiração:* ${content.inspiracao.trim()}');
        }
      } else {
        linhasCurtas.add('$n: (conteúdo não encontrado)');
        buffer.writeln('\n**Lição Kármica $n**');
        buffer.writeln('Conteúdo não encontrado.');
      }
    }
    buffer.writeln(
        '\nA presença dessas lições não é punição — é convite de evolução. Ao reconhecer padrões, você acelera seu crescimento.');

    // Tags agregadas (deduplicadas)
    final tags = <String>{};
    for (final n in licoes) {
      final c = ContentData.textosLicoesCarmicas[n];
      if (c != null) tags.addAll(c.tags);
    }
    // Limitar a no máximo 4 tags inspiracionais e evitar rótulos numéricos
    final limitedTags = tags
        .where((t) => !RegExp(r'^L(i|í)\w+|^\d+$').hasMatch(t))
        .take(4)
        .toList();

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: linhasCurtas.join('\n'),
      descricaoCompleta: buffer.toString(),
      inspiracao:
          'Aprender conscientemente é libertar-se de repetições inconscientes.',
      tags: limitedTags,
    );
  }

  VibrationContent _buildDebitosCarmicosContent(List<int> debitos) {
    if (debitos.isEmpty) {
      return const VibrationContent(
        titulo: 'Sem Débitos Kármicos',
        descricaoCurta: 'Nenhum dos números clássicos (13,14,16,19) ativo.',
        descricaoCompleta:
            'Não há indicadores de débitos kármicos clássicos. Sua jornada foca mais em lapidar talentos do que em corrigir padrões críticos.',
        inspiracao: 'Fluxo livre favorece o aperfeiçoamento dos talentos.',
        tags: ['Fluxo'],
      );
    }

    final titulo = 'Débitos Kármicos (${debitos.join(', ')})';
    final linhasCurtas = <String>[];
    linhasCurtas.add('Débitos Kármicos: ${_joinComE(debitos)}');
    final buffer = StringBuffer();
    buffer.writeln(
        'Cada débito evidencia um ciclo de ajuste que, quando consciente, acelera evolução e clareza.');
    for (final d in debitos) {
      final content = ContentData.textosDebitosCarmicos[d];
      if (content != null) {
        linhasCurtas.add('$d: ${content.descricaoCurta}');
        buffer.writeln('\n**Débito Kármico $d**');
        buffer.writeln(content.descricaoCompleta.trim());
        if (content.inspiracao.isNotEmpty) {
          buffer.writeln('\n*Inspiração:* ${content.inspiracao.trim()}');
        }
      } else {
        linhasCurtas.add('$d: (conteúdo não encontrado)');
        buffer.writeln('\n**Débito Kármico $d**');
        buffer.writeln('Conteúdo não encontrado.');
      }
    }
    buffer.writeln(
        '\nA chave é transformar repetição inconsciente em escolha consciente alinhada ao seu propósito.');

    final tags = <String>{};
    for (final d in debitos) {
      final c = ContentData.textosDebitosCarmicos[d];
      if (c != null) tags.addAll(c.tags);
    }
    final limitedTags = tags
        .where((t) => !RegExp(r'^D(é|e)bito|^\d+$').hasMatch(t))
        .take(4)
        .toList();

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: linhasCurtas.join('\n'),
      descricaoCompleta: buffer.toString(),
      inspiracao: 'O que é encarado com coragem vira potência evolutiva.',
      tags: limitedTags,
    );
  }

  VibrationContent _buildTendenciasOcultasContent(List<int> tendencias) {
    if (tendencias.isEmpty) {
      return const VibrationContent(
        titulo: 'Sem Tendências Ocultas',
        descricaoCurta: 'Nenhum número aparece com frequência acima da média.',
        descricaoCompleta:
            'Seu campo energético não mostra sobrecarga em nenhum arquétipo. Há espaço para equilíbrio e desenvolvimento diversificado.',
        inspiracao: 'Equilíbrio abre espaço para expressão plena.',
        tags: ['Equilíbrio'],
      );
    }

    final titulo = 'Tendências Ocultas (${tendencias.join(', ')})';
    final linhasCurtas = <String>[];
    linhasCurtas.add('Tendências Ocultas: ${_joinComE(tendencias)}');
    final buffer = StringBuffer();
    buffer.writeln(
        'Esses números repetidos no nome sugerem potenciais intensificados que podem se manifestar de forma espontânea.');
    for (final t in tendencias) {
      final content = ContentData.textosTendenciasOcultas[t];
      if (content != null) {
        linhasCurtas.add('$t: ${content.descricaoCurta}');
        buffer.writeln('\n**Tendência Oculta $t**');
        buffer.writeln(content.descricaoCompleta.trim());
        if (content.inspiracao.isNotEmpty) {
          buffer.writeln('\n*Inspiração:* ${content.inspiracao.trim()}');
        }
      } else {
        linhasCurtas.add('$t: (conteúdo não encontrado)');
        buffer.writeln('\n**Tendência Oculta $t**');
        buffer.writeln('Conteúdo não encontrado.');
      }
    }
    buffer.writeln(
        '\nCanalize essas forças em ações consistentes e alinhadas ao seu propósito para evitar dispersão ou tensão interna.');

    final tags = <String>{};
    for (final t in tendencias) {
      final c = ContentData.textosTendenciasOcultas[t];
      if (c != null) tags.addAll(c.tags);
    }
    final limitedTags = tags
        .where((t) => !RegExp(r'^Intensidade|^\d+$').hasMatch(t))
        .take(4)
        .toList();

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: linhasCurtas.join('\n'),
      descricaoCompleta: buffer.toString(),
      inspiracao: 'Potencial reconhecido é potencial direcionado.',
      tags: limitedTags,
    );
  }

  // Helpers para extrair mapas de textos curtos para MultiNumberCard
  Map<int, String> _getLicoesCarmicasTexts(List<int> licoes) {
    final map = <int, String>{};
    for (final n in licoes) {
      final content = ContentData.textosLicoesCarmicas[n];
      if (content != null) {
        map[n] = content.descricaoCurta;
      }
    }
    return map;
  }

  // Títulos por número para Lições Kármicas
  Map<int, String> _getLicoesCarmicasTitles(List<int> licoes) {
    final map = <int, String>{};
    for (final n in licoes) {
      map[n] = 'Lição Kármica $n';
    }
    return map;
  }

  Map<int, String> _getDebitosCarmicosTexts(List<int> debitos) {
    final map = <int, String>{};
    for (final d in debitos) {
      final content = ContentData.textosDebitosCarmicos[d];
      if (content != null) {
        map[d] = content.descricaoCurta;
      }
    }
    return map;
  }

  // Títulos por número para Débitos Kármicos
  Map<int, String> _getDebitosCarmicosTitles(List<int> debitos) {
    final map = <int, String>{};
    for (final d in debitos) {
      map[d] = 'Débito Kármico $d';
    }
    return map;
  }

  Map<int, String> _getTendenciasOcultasTexts(List<int> tendencias) {
    final map = <int, String>{};
    for (final t in tendencias) {
      final content = ContentData.textosTendenciasOcultas[t];
      if (content != null) {
        map[t] = content.descricaoCurta;
      }
    }
    return map;
  }

  // Títulos por número para Tendências Ocultas
  Map<int, String> _getTendenciasOcultasTitles(List<int> tendencias) {
    final map = <int, String>{};
    for (final t in tendencias) {
      map[t] = 'Tendência Oculta $t';
    }
    return map;
  }

  VibrationContent _buildHarmoniaConjugalContent(
      Map<String, dynamic> harmonia, int missao) {
    final vibra = (harmonia['vibra'] as List?)?.cast<int>() ?? const [];
    final atrai = (harmonia['atrai'] as List?)?.cast<int>() ?? const [];
    final oposto = (harmonia['oposto'] as List?)?.cast<int>() ?? const [];
    final passivo = (harmonia['passivo'] as List?)?.cast<int>() ?? const [];
    const titulo = 'Harmonia Conjugal';
    const descricaoCurta =
        'Compatibilidades e dinâmicas afetivas relacionadas à sua Missão.';
    final buffer = StringBuffer();
    buffer.writeln(
        'Sua Missão estabelece padrões de afinidade, magnetismo e campo relacional.');

    // Visão geral rápida (linhas-resumo como no card)
    if (vibra.isNotEmpty) {
      buffer.writeln(
          '\n*Resumo:* Alta Sinergia — ${vibra.join(', ')}. Fluxo natural e fácil integração.');
    }
    if (atrai.isNotEmpty) {
      buffer.writeln(
          '*Resumo:* Atrai — ${atrai.join(', ')}. Perfis que estimulam crescimento e admiração mútua.');
    }
    if (oposto.isNotEmpty) {
      buffer.writeln(
          '*Resumo:* Desafio/Oposto — ${oposto.join(', ')}. Relações que pedem negociação consciente e respeito aos ritmos.');
    }
    if (passivo.isNotEmpty) {
      buffer.writeln(
          '*Resumo:* Passivo/Neutro — ${passivo.join(', ')}. Dinâmica suave; exige iniciativa para aprofundar vínculo.');
    }

    // Seções detalhadas com títulos destacados e texto completo por número
    if (vibra.isNotEmpty) {
      buffer.writeln('\n**Alta Sinergia**');
      for (final n in vibra) {
        final texto = ContentData.textosHarmoniaConjugal[n] ?? '';
        if (texto.isNotEmpty) {
          buffer.writeln('\n**$n**\n$texto');
        }
      }
    }
    if (atrai.isNotEmpty) {
      buffer.writeln('\n**Atrai**');
      for (final n in atrai) {
        final texto = ContentData.textosHarmoniaConjugal[n] ?? '';
        if (texto.isNotEmpty) {
          buffer.writeln('\n**$n**\n$texto');
        }
      }
    }
    if (oposto.isNotEmpty) {
      buffer.writeln('\n**Desafio/Oposto**');
      for (final n in oposto) {
        final texto = ContentData.textosHarmoniaConjugal[n] ?? '';
        if (texto.isNotEmpty) {
          buffer.writeln('\n**$n**\n$texto');
        }
      }
    }
    if (passivo.isNotEmpty) {
      buffer.writeln('\n**Passivo/Neutro**');
      for (final n in passivo) {
        final texto = ContentData.textosHarmoniaConjugal[n] ?? '';
        if (texto.isNotEmpty) {
          buffer.writeln('\n**$n**\n$texto');
        }
      }
    }

    buffer.writeln(
        '\nA harmonia não é destino fixo; é construção diária baseada em comunicação, autenticidade e propósito compartilhado.');
    return VibrationContent(
      titulo: titulo,
      descricaoCurta: descricaoCurta,
      descricaoCompleta: buffer.toString(),
      inspiracao: 'Relacionar-se é co-criar campos de evolução.',
      tags: const ['Relacionamentos', 'Sintonia'],
    );
  }

  // Removido helper _relacaoDescricaoPorNumero (agora usa ContentData.textosHarmoniaConjugal)

  // Dias favoráveis: aproximação — dias do mês em que o dia do calendário reduz
  // para algum dos números principais (destino, motivacao, expressao, missao, impressao)
  List<int> _computeFavorableDaysThisMonth({int limit = 30}) {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final destino = _numerologyData!.numeros['destino'] ?? 0;
    final motivacao = _numerologyData!.numeros['motivacao'] ?? 0;
    final expressao = _numerologyData!.numeros['expressao'] ?? 0;
    final missao = _numerologyData!.numeros['missao'] ?? 0;
    final impressao = _numerologyData!.numeros['impressao'] ?? 0;
    final chave = {destino, motivacao, expressao, missao, impressao};
    int daysInMonth = DateTime(year, month + 1, 0).day;
    final favorable = <int>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final redu = _reduzirLocal(d); // redução simples local
      if (chave.contains(redu)) favorable.add(d);
      if (favorable.length >= limit) break;
    }
    return favorable;
  }

  /// Retorna o dia favorável de hoje ou o próximo dia favorável do mês
  int? _getNextFavorableDay() {
    final now = DateTime.now();
    final todayDay = now.day;
    final allFavorableDays = _computeFavorableDaysThisMonth(limit: 200);

    // Procura por hoje ou próximo dia
    for (final day in allFavorableDays) {
      if (day >= todayDay) {
        return day;
      }
    }

    // Se não encontrou nenhum dia >= hoje, retorna o primeiro do próximo mês
    // ou null se não houver
    return allFavorableDays.isNotEmpty ? allFavorableDays.first : null;
  }

  /// Constrói o conteúdo do card mostrando apenas o próximo dia favorável
  VibrationContent _buildProximoDiaFavoravelContent() {
    final nextDay = _getNextFavorableDay();
    final now = DateTime.now();

    if (nextDay == null) {
      return const VibrationContent(
        titulo: 'Sem Dias Favoráveis',
        descricaoCurta: 'Nenhum dia favorável encontrado neste mês.',
        descricaoCompleta:
            'Este mês não apresenta alinhamentos com seus números principais. Ainda assim, intenção e preparo criam oportunidades.',
        inspiracao: 'Cada dia é uma chance de criar sua própria sorte.',
        tags: [],
      );
    }

    final isToday = nextDay == now.day;
    final titulo =
        isToday ? 'Hoje é dia favorável!' : 'Próximo dia favorável: $nextDay';
    final mensagemCurta = ContentData.textosDiasFavoraveis[nextDay] ??
        'Dia de energia especial para você.';

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: mensagemCurta,
      descricaoCompleta: '',
      inspiracao: '',
      tags: ['Dia $nextDay', 'Sintonia', 'Oportunidade'],
    );
  }

  /// Constrói o conteúdo completo para o modal dos Dias Favoráveis
  VibrationContent _buildDiasFavoraveisCompleteContent() {
    final nextDay = _getNextFavorableDay();
    final now = DateTime.now();
    final allFavorableDays = _computeFavorableDaysThisMonth(limit: 200);

    if (nextDay == null || allFavorableDays.isEmpty) {
      return const VibrationContent(
        titulo: 'Sem Dias Favoráveis',
        descricaoCurta: 'Nenhum dia favorável encontrado neste mês.',
        descricaoCompleta:
            'Este mês não apresenta alinhamentos com seus números principais. Ainda assim, intenção e preparo criam oportunidades.',
        inspiracao: 'Cada dia é uma chance de criar sua própria sorte.',
        tags: [],
      );
    }

    final isToday = nextDay == now.day;
    final titulo =
        isToday ? 'Hoje é dia favorável!' : 'Próximo dia favorável: $nextDay';
    final mensagemCurta = ContentData.textosDiasFavoraveis[nextDay] ??
        'Dia de energia especial para você.';
    final mensagemLonga = ContentData.textosDiasFavoraveisLongos[nextDay] ??
        'Este é um dia alinhado com seus números principais.';

    // Criar lista de todos os dias favoráveis do mês
    final diasFormatados = allFavorableDays.map((d) => d.toString()).join(', ');
    final monthName = _getMonthName(now.month);

    final descricaoCompleta = StringBuffer();
    descricaoCompleta.writeln(mensagemLonga);
    descricaoCompleta.writeln();
    descricaoCompleta.writeln('═══════════════════════════');
    descricaoCompleta.writeln();
    descricaoCompleta.writeln('📅 Todos os Dias Favoráveis de $monthName:');
    descricaoCompleta.writeln();
    descricaoCompleta.writeln(diasFormatados);
    descricaoCompleta.writeln();
    descricaoCompleta.writeln(
        'Estes dias estão em ressonância com seus números principais (Destino, Expressão, Motivação, Impressão e Missão).');
    descricaoCompleta.writeln();
    descricaoCompleta.writeln(
        'Aproveite essas datas para tomar decisões importantes, iniciar projetos ou realizar atividades que exigem maior fluidez energética.');

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: mensagemCurta,
      descricaoCompleta: descricaoCompleta.toString(),
      inspiracao: isToday
          ? 'Aproveite a energia de hoje!'
          : 'Prepare-se para estes dias especiais.',
      tags: ['Dia $nextDay', 'Sintonia', 'Oportunidade'],
    );
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return months[month];
  }

  int _reduzirLocal(int n) {
    while (n > 9) {
      n = n.toString().split('').map(int.parse).reduce((a, b) => a + b);
    }
    return n;
  }

  /// Builder para Ciclos de Vida: versão curta (card) mostra apenas o ciclo atual, versão completa mostra todos os ciclos com intervalos.
  VibrationContent _buildCiclosDeVidaContent(
      Map<String, dynamic> ciclos, int idadeAtual) {
    // Identifica ciclo atual
    Map<String, dynamic>? cicloAtual;
    for (final key in ['ciclo1', 'ciclo2', 'ciclo3']) {
      final ciclo = ciclos[key];
      if (ciclo == null) continue;
      final idadeInicio = ciclo['idadeInicio'] ?? 0;
      final idadeFim = ciclo['idadeFim'] ?? 200;
      if (idadeAtual >= idadeInicio && idadeAtual < idadeFim) {
        cicloAtual = ciclo;
        break;
      }
      // Para ciclo1, que só tem idadeFim
      if (key == 'ciclo1' && idadeAtual < (ciclo['idadeFim'] ?? 0)) {
        cicloAtual = ciclo;
        break;
      }
    }
    cicloAtual ??= ciclos['ciclo3'] ?? ciclos['ciclo2'] ?? ciclos['ciclo1'];

    // Card: só ciclo atual
    final regente = cicloAtual?['regente'] ?? 0;
    final nome = cicloAtual?['nome'] ?? '';
    final idadeIni = cicloAtual?['idadeInicio'];
    final idadeFim = cicloAtual?['idadeFim'];
    String intervalo = '';
    if (idadeIni != null && idadeFim != null) {
      intervalo = '$idadeIni a $idadeFim anos';
    } else if (idadeFim != null) {
      intervalo = 'até $idadeFim anos';
    } else if (idadeIni != null) {
      intervalo = 'a partir de $idadeIni anos';
    }
    final titulo = nome; // Removido o número do título do card
    final conteudoCiclo = _getCicloDeVidaContent(regente);
    // Remover número antes do texto: texto curto + nova linha + intervalo destacado
    final descricaoCurta = '${conteudoCiclo.descricaoCurta}\n\n$intervalo';

    // Modal: todos os ciclos com subtítulos destacados
    final buffer = StringBuffer();
    for (final key in ['ciclo1', 'ciclo2', 'ciclo3']) {
      final ciclo = ciclos[key];
      if (ciclo == null) continue;
      final reg = ciclo['regente'] ?? 0;
      final nm = ciclo['nome'] ?? '';
      final per = ciclo['periodo'] ?? '';
      final idIni = ciclo['idadeInicio'];
      final idFim = ciclo['idadeFim'];
      String intv = '';
      if (idIni != null && idFim != null) {
        intv = '$idIni a $idFim anos';
      } else if (idFim != null) {
        intv = 'até $idFim anos';
      } else if (idIni != null) {
        intv = 'a partir de $idIni anos';
      }
      // Subtítulo destacado: Nome + Número
      buffer.writeln('**$nm $reg**');
      // Período destacado em nova linha
      buffer.writeln('*$intv*');
      buffer.writeln('Período: $per\n');
      final conteudo = _getCicloDeVidaContent(reg);
      buffer.writeln(conteudo.descricaoCompleta);
      buffer.writeln('');
    }

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: descricaoCurta,
      descricaoCompleta: buffer.toString().trim(),
      inspiracao: conteudoCiclo.inspiracao,
      tags: conteudoCiclo.tags,
    );
  }

  /// Builder para Desafios: versão curta (card) mostra apenas o desafio atual, versão completa mostra todos os desafios com intervalos.
  VibrationContent _buildDesafiosContent(
      Map<String, int> desafios, int idadeAtual) {
    final desafioPrincipal = desafios['desafioPrincipal'] ?? 0;
    final desafio1 = desafios['desafio1'] ?? 0;
    final desafio2 = desafios['desafio2'] ?? 0;

    // Cálculo das idades baseado no número de destino
    final destino = _numerologyData?.numeros['destino'] ?? 1;
    final idadeFimDesafio1 = 37 - destino;
    final idadeFimDesafio2 = idadeFimDesafio1 + 9;

    // Identifica desafio atual
    int desafioAtual;
    String nomeAtual;
    String intervaloAtual;
    if (idadeAtual < idadeFimDesafio1) {
      desafioAtual = desafio1;
      nomeAtual = 'Primeiro Desafio';
      intervaloAtual = 'nascimento até $idadeFimDesafio1 anos';
    } else if (idadeAtual < idadeFimDesafio2) {
      desafioAtual = desafioPrincipal;
      nomeAtual = 'Desafio Principal';
      intervaloAtual = '$idadeFimDesafio1 a $idadeFimDesafio2 anos';
    } else {
      desafioAtual = desafio2;
      nomeAtual = 'Terceiro Desafio';
      intervaloAtual = 'a partir de $idadeFimDesafio2 anos';
    }

    final titulo = nomeAtual; // Removido o número do título do card
    final conteudoDesafio = _getDesafioContent(desafioAtual);
    // Remover número antes do texto: texto curto + nova linha + intervalo destacado
    final descricaoCurta =
        '${conteudoDesafio.descricaoCurta}\n\n$intervaloAtual';

    // Modal: todos os desafios com subtítulos destacados
    final buffer = StringBuffer();

    // Primeiro Desafio
    buffer.writeln('**Primeiro Desafio $desafio1**');
    buffer.writeln('*nascimento até $idadeFimDesafio1 anos*\n');
    final cont1 = _getDesafioContent(desafio1);
    buffer.writeln(cont1.descricaoCompleta);
    buffer.writeln('');

    // Desafio Principal
    buffer.writeln('**Desafio Principal $desafioPrincipal**');
    buffer.writeln('*$idadeFimDesafio1 a $idadeFimDesafio2 anos*\n');
    final contPrinc = _getDesafioContent(desafioPrincipal);
    buffer.writeln(contPrinc.descricaoCompleta);
    buffer.writeln('');

    // Terceiro Desafio
    buffer.writeln('**Terceiro Desafio $desafio2**');
    buffer.writeln('*a partir de $idadeFimDesafio2 anos*\n');
    final cont2 = _getDesafioContent(desafio2);
    buffer.writeln(cont2.descricaoCompleta);

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: descricaoCurta,
      descricaoCompleta: buffer.toString().trim(),
      inspiracao: conteudoDesafio.inspiracao,
      tags: conteudoDesafio.tags,
    );
  }

  /// Builder para Momentos Decisivos: versão curta (card) mostra apenas o momento atual, versão completa mostra todos os momentos com intervalos.
  VibrationContent _buildMomentosDecisivosContent(
      Map<String, dynamic> momentos, int idadeAtual) {
    final p1 = momentos['p1'] ?? 0;
    final p2 = momentos['p2'] ?? 0;
    final p3 = momentos['p3'] ?? 0;
    final p4 = momentos['p4'] ?? 0;

    // Identifica momento atual
    int momentoAtual;
    String nomeAtual;
    String intervaloAtual;
    if (idadeAtual <= 36) {
      momentoAtual = p1;
      nomeAtual = 'Primeiro Momento Decisivo';
      intervaloAtual = 'nascimento até 36 anos';
    } else if (idadeAtual <= 45) {
      momentoAtual = p2;
      nomeAtual = 'Segundo Momento Decisivo';
      intervaloAtual = '37 a 45 anos';
    } else if (idadeAtual <= 54) {
      momentoAtual = p3;
      nomeAtual = 'Terceiro Momento Decisivo';
      intervaloAtual = '46 a 54 anos';
    } else {
      momentoAtual = p4;
      nomeAtual = 'Quarto Momento Decisivo';
      intervaloAtual = 'a partir de 55 anos';
    }

    final titulo = nomeAtual; // Removido o número do título do card
    final conteudoMomento = _getMomentoDecisivoContent(momentoAtual);
    // Remover número antes do texto: texto curta + nova linha + intervalo destacado
    final descricaoCurta =
        '${conteudoMomento.descricaoCurta}\n\n$intervaloAtual';

    // Modal: todos os momentos decisivos com subtítulos destacados
    final buffer = StringBuffer();

    // Primeiro Momento Decisivo
    buffer.writeln('**Primeiro Momento Decisivo $p1**');
    buffer.writeln('*nascimento até 36 anos*\n');
    final cont1 = _getMomentoDecisivoContent(p1);
    buffer.writeln(cont1.descricaoCompleta);
    buffer.writeln('');

    // Segundo Momento Decisivo
    buffer.writeln('**Segundo Momento Decisivo $p2**');
    buffer.writeln('*37 a 45 anos*\n');
    final cont2 = _getMomentoDecisivoContent(p2);
    buffer.writeln(cont2.descricaoCompleta);
    buffer.writeln('');

    // Terceiro Momento Decisivo
    buffer.writeln('**Terceiro Momento Decisivo $p3**');
    buffer.writeln('*46 a 54 anos*\n');
    final cont3 = _getMomentoDecisivoContent(p3);
    buffer.writeln(cont3.descricaoCompleta);
    buffer.writeln('');

    // Quarto Momento Decisivo
    buffer.writeln('**Quarto Momento Decisivo $p4**');
    buffer.writeln('*a partir de 55 anos*\n');
    final cont4 = _getMomentoDecisivoContent(p4);
    buffer.writeln(cont4.descricaoCompleta);

    return VibrationContent(
      titulo: titulo,
      descricaoCurta: descricaoCurta,
      descricaoCompleta: buffer.toString().trim(),
      inspiracao: conteudoMomento.inspiracao,
      tags: conteudoMomento.tags,
    );
  }

  /// Abre o modal de detalhes numerológicos de forma responsiva
  /// Desktop: Modal centralizado
  /// Mobile: Tela completa
  void _showNumerologyDetail({
    required String title,
    String? number, // Agora opcional - não usado para cards multi-número
    required VibrationContent content,
    required Color color,
    required IconData icon,
    String? categoryIntro,
  }) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      // Desktop: showDialog
      showDialog(
        context: context,
        builder: (context) => NumerologyDetailModal(
          title: title,
          number: number,
          content: content,
          color: color,
          icon: icon,
          categoryIntro: categoryIntro,
        ),
      );
    } else {
      // Mobile: Navigator push full screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NumerologyDetailModal(
            title: title,
            number: number,
            content: content,
            color: color,
            icon: icon,
            categoryIntro: categoryIntro,
          ),
        ),
      );
    }
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
            initialHidden: _userData!.dashboardHiddenCards,
            scrollController: scrollController,
            onSaveComplete: (bool success) async {
              if (!mounted) return;
              try {
                Navigator.of(currentContext).pop();
              } catch (e) {
                debugPrint("Erro ao fechar modal: $e");
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
    Widget? fab;
    if (_userData != null &&
        _userData!.subscription.isActive &&
        _userData!.subscription.plan == SubscriptionPlan.premium) {
      switch (_sidebarIndex) {
        case 0: // Dashboard: chat e mic
          fab = ExpandingAssistantFab(
            onOpenAssistant: () {
              if (_userData == null) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AssistantPanel(userData: _userData!),
              );
            },
            onMic: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrada por voz chegará em breve.'),
                ),
              );
            },
          );
          break;
        case 1: // Calendar: usa o FAB nativo da tela CalendarScreen
          fab =
              null; // O CalendarScreen já tem seu próprio FAB com acesso ao _selectedDay
          break;
        case 2: // Journal: usa o FAB nativo da tela JournalScreen
          fab = null; // O JournalScreen já tem seu próprio FAB
          break;
        case 3: // Foco do Dia: usa o FAB nativo da tela FocoDoDiaScreen
          fab = null; // O FocoDoDiaScreen já tem seu próprio FAB
          break;
        case 4: // Goals: usa o FAB nativo da tela GoalsScreen
          fab = null; // O GoalsScreen já tem seu próprio FAB
          break;
        default:
          fab = null;
      }
    }
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
      floatingActionButton: fab,
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
              child: Container(color: Colors.black.withValues(alpha: 0.5))),
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
      if (availableWidth > 1300) {
        crossAxisCount = 3;
      } else if (availableWidth > 850) {
        crossAxisCount = 2;
      }
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

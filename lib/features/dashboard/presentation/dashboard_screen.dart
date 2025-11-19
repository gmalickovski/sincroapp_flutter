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
  StreamSubscription<List<Goal>>? _goalsSubscription;

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialData();
    });
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _menuAnimationController.dispose();
    super.dispose();
  }

  Future<void> _cancelSubscriptions() async {
    await _todayTasksSubscription?.cancel();
    _todayTasksSubscription = null;
    await _goalsSubscription?.cancel();
    _goalsSubscription = null;
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
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeTasksStream(String userId) {
    _todayTasksSubscription?.cancel();
    _todayTasksSubscription =
        _firestoreService.getTasksStreamForToday(userId).listen((tasks) {
      if (mounted) {
        setState(() {
          _currentTodayTasks = tasks;
          if (_isLoading) _isLoading = false;
          _buildCardList();
        });
      }
    });
  }

  void _initializeGoalsStream(String userId) {
    _goalsSubscription?.cancel();
    _goalsSubscription =
        _firestoreService.getGoalsStream(userId).listen((goals) {
      if (mounted) {
        setState(() {
          _userGoals = goals;
          _buildCardList();
        });
      }
    });
  }

  Future<void> _reloadDataNonStream({bool rebuildCards = true}) async {
    await _loadInitialData();
  }

  void _handleTaskStatusChange(TaskModel task, bool isCompleted) {
    if (!mounted || _userData == null) return;
    _firestoreService.updateTaskCompletion(_userData!.uid, task.id,
        completed: isCompleted);
  }

  void _handleTaskTap(TaskModel task) {}

  Future<void> _handleAddTask() async {
    if (_userData == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: _userData!,
        userId: _userData!.uid,
        onAddTask: _createSingleTaskWithPersonalDay,
      ),
    );
  }

  void _createSingleTaskWithPersonalDay(ParsedTask parsedTask) {
    if (_userData == null) return;
    DateTime? finalDueDateUtc;
    DateTime dateForPersonalDay;

    if (parsedTask.dueDate != null) {
      final dateLocal = parsedTask.dueDate!.toLocal();
      finalDueDateUtc =
          DateTime.utc(dateLocal.year, dateLocal.month, dateLocal.day);
      dateForPersonalDay = finalDueDateUtc;
    } else {
      final now = DateTime.now().toLocal();
      dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
    }

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

    _firestoreService.addTask(_userData!.uid, newTask);
  }

  int? _calculatePersonalDay(DateTime? date) {
    if (_userData == null ||
        _userData!.dataNasc.isEmpty ||
        _userData!.nomeAnalise.isEmpty ||
        date == null) return null;
    try {
      final engine = NumerologyEngine(
        nomeCompleto: _userData!.nomeAnalise,
        dataNascimento: _userData!.dataNasc,
      );
      final day = engine.calculatePersonalDayForDate(date.toUtc());
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }

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
        .push(MaterialPageRoute(
            builder: (context) =>
                GoalDetailScreen(initialGoal: goal, userData: _userData!)))
        .then((_) => _reloadDataNonStream());
  }

  // --- MAPA DE TEXTOS LOCAIS (CORREÇÃO DOS ERROS) ---
  // Como o ContentData não foi atualizado, definimos os textos aqui para compilar e funcionar.
  static const Map<int, VibrationContent> _localTextosDesafios = {
    0: VibrationContent(
        titulo: "Desafio 0",
        descricaoCurta:
            "Um período de escolhas e liberdade, sem obstáculos específicos.",
        descricaoCompleta:
            "O Desafio 0 é um caso especial. Pode significar um período livre de obstáculos específicos, ou que você tem o desafio de escolher seu próprio caminho sem pressões externas. É um teste de caráter e independência.",
        inspiracao: "Você é livre para criar seu destino."),
    1: VibrationContent(
        titulo: "Desafio 1",
        descricaoCurta:
            "Desenvolver a individualidade, a coragem e a iniciativa.",
        descricaoCompleta:
            "Este desafio pede que você aprenda a confiar em si mesmo, a ter iniciativa e a não depender da aprovação alheia. É hora de desenvolver a força de vontade e a liderança.",
        inspiracao: "Acredite na sua própria força."),
    2: VibrationContent(
        titulo: "Desafio 2",
        descricaoCurta:
            "Aprender a cooperar, ter tato e sensibilidade com os outros.",
        descricaoCompleta:
            "O desafio aqui é lidar com relacionamentos, desenvolver a paciência e a diplomacia. Evite a hipersensibilidade e aprenda a trabalhar em equipe sem se anular.",
        inspiracao: "A harmonia nasce da compreensão."),
    3: VibrationContent(
        titulo: "Desafio 3",
        descricaoCurta:
            "Expressar-se criativamente e superar a crítica ou a timidez.",
        descricaoCompleta:
            "Você é desafiado a expressar seus sentimentos e talentos. Cuidado com a dispersão, o desperdício de energia ou o uso da palavra para ferir. Busque a alegria na autoexpressão.",
        inspiracao: "Sua voz merece ser ouvida."),
    4: VibrationContent(
        titulo: "Desafio 4",
        descricaoCurta:
            "Construir bases sólidas, ter disciplina e organização.",
        descricaoCompleta:
            "Este período exige trabalho duro, ordem e praticidade. O desafio é não se sentir limitado pela rotina, mas usar a disciplina para construir algo duradouro.",
        inspiracao: "A disciplina é a ponte para a liberdade."),
    5: VibrationContent(
        titulo: "Desafio 5",
        descricaoCurta: "Lidar com a mudança, a liberdade e a impulsividade.",
        descricaoCompleta:
            "O desafio é abraçar a mudança sem perder o foco. Cuidado com a impulsividade e a busca excessiva por prazeres sensoriais. Aprenda a ser flexível e a usar a liberdade com responsabilidade.",
        inspiracao: "Mude suas folhas, mas mantenha suas raízes."),
    6: VibrationContent(
        titulo: "Desafio 6",
        descricaoCurta:
            "Equilibrar responsabilidades familiares e ideais de perfeição.",
        descricaoCompleta:
            "Você será testado em questões de amor, família e serviço. O desafio é aceitar as pessoas como elas são, sem impor seus padrões de perfeição, e servir sem se tornar um mártir.",
        inspiracao: "Amar é aceitar imperfeições."),
    7: VibrationContent(
        titulo: "Desafio 7",
        descricaoCurta:
            "Superar o isolamento, o orgulho e buscar a fé interior.",
        descricaoCompleta:
            "Este desafio lida com a solidão e a busca por respostas. Evite se isolar ou se tornar cínico. O aprendizado é confiar na vida e desenvolver a fé e a sabedoria interior.",
        inspiracao: "A verdade está dentro de você."),
    8: VibrationContent(
        titulo: "Desafio 8",
        descricaoCurta:
            "Equilibrar o mundo material e espiritual, lidar com o poder.",
        descricaoCompleta:
            "O desafio é lidar com dinheiro, poder e autoridade. Evite a ganância ou o medo da escassez. Aprenda a usar seus recursos para o bem maior e a equilibrar ambição com valores.",
        inspiracao: "A verdadeira riqueza é o equilíbrio."),
  };

  void _buildCardList() {
    if (!mounted || _userData == null) {
      _cards = [];
      return;
    }
    final Set<String> hidden = _userData?.dashboardHiddenCards.toSet() ?? {};

    final Map<String, Widget> allCardsMap = {
      'assistantInsights': AssistantInsightsCard(
          key: const ValueKey('assistantInsights'), user: _userData!),
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
                  categoryIntro: "O Dia Pessoal revela a energia de hoje...",
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
                  categoryIntro: "O Mês Pessoal define o tema energético...",
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
                  categoryIntro: "O Ano Pessoal representa o tema principal...",
                )),
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
                  categoryIntro: "O Ciclo de Vida divide sua existência...",
                )),
        // CARDS PREMIUM (Com verificações de segurança para dados ausentes no ContentData)
        if (_userData!.subscription.plan != SubscriptionPlan.free) ...{
          'desafios': InfoCard(
              key: const ValueKey('desafios'),
              title: "Desafio Pessoal",
              // Lê o valor do desafio. Se for um mapa (nova estrutura), pega 'valor', senão usa direto.
              number: _getDesafioValue(_numerologyData!.estruturas['desafios'])
                  .toString(),
              info: _buildDesafiosContent(
                  _numerologyData!.estruturas['desafios']
                          as Map<String, dynamic>? ??
                      {},
                  _numerologyData!.idade),
              icon: Icons.warning_amber_outlined,
              color: Colors.orangeAccent.shade200,
              isEditMode: _isEditMode,
              dragHandle: _isEditMode ? _buildDragHandle('desafios') : null,
              onTap: () => _showNumerologyDetail(
                    title: "Desafios",
                    number: _getDesafioValue(
                            _numerologyData!.estruturas['desafios'])
                        .toString(),
                    content: _buildDesafiosContent(
                        _numerologyData!.estruturas['desafios']
                                as Map<String, dynamic>? ??
                            {},
                        _numerologyData!.idade),
                    color: Colors.orangeAccent.shade200,
                    icon: Icons.warning_amber_outlined,
                    categoryIntro:
                        "Os Desafios representam áreas de crescimento...",
                  )),
          // Outros cards mantidos simplificados para evitar erros de compilação se ContentData não tiver os mapas
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

  // Helper seguro para pegar o valor do desafio, independente se é int ou Map
  int _getDesafioValue(dynamic desafiosData) {
    if (desafiosData is! Map) return 0;
    // Tenta pegar do 'desafioPrincipal' que pode ser int ou Map
    final principal = desafiosData['desafioPrincipal'];
    if (principal is int) return principal;
    if (principal is Map) return principal['valor'] as int? ?? 0;
    return 0;
  }

  Widget _buildDragHandle(String cardKey) {
    int index = _cards.indexWhere((card) => card.key == ValueKey(cardKey));
    if (index == -1) return const SizedBox(width: 24, height: 24);
    return ReorderableDragStartListener(
      index: index,
      child: const MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Icon(Icons.drag_handle, color: AppColors.secondaryText)),
    );
  }

  VibrationContent _getInfoContent(String category, int number) =>
      ContentData.vibracoes[category]?[number] ??
      const VibrationContent(
          titulo: '...',
          descricaoCurta: '...',
          descricaoCompleta: '',
          inspiracao: '');

  VibrationContent _getCicloDeVidaContent(int number) =>
      ContentData.textosCiclosDeVida[number] ??
      const VibrationContent(
          titulo: 'Ciclo',
          descricaoCurta: '...',
          descricaoCompleta: '',
          inspiracao: '');

  BussolaContent _getBussolaContent(int number) =>
      ContentData.bussolaAtividades[number] ??
      ContentData.bussolaAtividades[0]!;

  // Getters seguros usando o MAPA LOCAL para Desafios
  VibrationContent _getDesafioContent(int number) =>
      _localTextosDesafios[number] ??
      const VibrationContent(
          titulo: 'Desafio',
          descricaoCurta: '...',
          descricaoCompleta: '',
          inspiracao: '');

  // ===============================================================
  // BUILDER DO CONTEÚDO DE DESAFIOS
  // ===============================================================
  VibrationContent _buildDesafiosContent(
      Map<String, dynamic> desafios, int idadeAtual) {
    final d1Map = desafios['desafio1_detalhe'] as Map<String, dynamic>?;
    final d2Map = desafios['desafio2_detalhe'] as Map<String, dynamic>?;
    final dmMap = desafios['desafioPrincipal_detalhe'] as Map<String, dynamic>?;

    final d1Val = desafios['desafio1'] as int? ?? 0;
    final d2Val = desafios['desafio2'] as int? ?? 0;
    final dmVal = desafios['desafioPrincipal'] as int? ?? 0;

    Map<String, dynamic>? currentDetail;
    int currentVal = d1Val;
    final fimD1 = d1Map?['idadeFim'] as int? ?? 999;
    final fimD2 = d2Map?['idadeFim'] as int? ?? 999;

    if (idadeAtual < fimD1) {
      currentDetail = d1Map;
      currentVal = d1Val;
    } else if (idadeAtual < fimD2) {
      currentDetail = dmMap;
      currentVal = dmVal;
    } else {
      currentDetail = d2Map;
      currentVal = d2Val;
    }

    final nomeAtual = currentDetail?['nome'] ?? 'Desafio Atual';
    final periodoAtual = currentDetail?['periodo'] ?? '';

    final content = _getDesafioContent(currentVal);
    final descricaoCurta = '${content.descricaoCurta}\n\n$periodoAtual';

    final buffer = StringBuffer();
    void addSection(Map<String, dynamic>? detail, int val) {
      if (detail == null) return;
      buffer.writeln('**${detail['nome']} $val**');
      buffer.writeln('*${detail['periodo']}*\n');
      final c = _getDesafioContent(val);
      buffer.writeln(c.descricaoCompleta);
      buffer.writeln('');
    }

    addSection(d1Map, d1Val);
    addSection(dmMap, dmVal);
    addSection(d2Map, d2Val);

    return VibrationContent(
      titulo: nomeAtual,
      descricaoCurta: descricaoCurta,
      descricaoCompleta: buffer.toString().trim(),
      inspiracao: content.inspiracao,
      tags: content.tags,
    );
  }

  // Ciclos de Vida (Mantido)
  VibrationContent _buildCiclosDeVidaContent(
      Map<String, dynamic> ciclos, int idadeAtual) {
    Map<String, dynamic>? cicloAtual;
    if (idadeAtual < (ciclos['ciclo1']?['idadeFim'] ?? 0))
      cicloAtual = ciclos['ciclo1'];
    else if (idadeAtual < (ciclos['ciclo2']?['idadeFim'] ?? 0))
      cicloAtual = ciclos['ciclo2'];
    else
      cicloAtual = ciclos['ciclo3'];
    cicloAtual ??= ciclos['ciclo1'];

    final regente = cicloAtual?['regente'] ?? 0;
    final nome = cicloAtual?['nome'] ?? '';
    String intervalo = '';
    final ini = cicloAtual?['idadeInicio'];
    final fim = cicloAtual?['idadeFim'];
    if (ini != null && fim != null)
      intervalo = '$ini a $fim anos';
    else if (fim != null)
      intervalo = 'nascimento até $fim anos';
    else if (ini != null) intervalo = 'a partir de $ini anos';

    final content = _getCicloDeVidaContent(regente);
    final descricaoCurta = '${content.descricaoCurta}\n\n$intervalo';

    final buffer = StringBuffer();
    for (final k in ['ciclo1', 'ciclo2', 'ciclo3']) {
      final c = ciclos[k];
      if (c == null) continue;
      buffer.writeln('**${c['nome']} ${c['regente']}**');
      String iModal = '';
      if (c['idadeInicio'] != null && c['idadeFim'] != null)
        iModal = '${c['idadeInicio']} a ${c['idadeFim']} anos';
      else if (c['idadeFim'] != null)
        iModal = 'até ${c['idadeFim']} anos';
      else
        iModal = 'a partir de ${c['idadeInicio']} anos';
      buffer.writeln('*$iModal*\n');
      final txt = _getCicloDeVidaContent(c['regente'] ?? 0);
      buffer.writeln(txt.descricaoCompleta);
      buffer.writeln('');
    }
    return VibrationContent(
        titulo: nome,
        descricaoCurta: descricaoCurta,
        descricaoCompleta: buffer.toString(),
        inspiracao: content.inspiracao,
        tags: content.tags);
  }

  // Layouts (Mobile/Desktop)
  Widget _buildDesktopLayout() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_userData != null)
        DashboardSidebar(
            isExpanded: _isDesktopSidebarExpanded,
            selectedIndex: _sidebarIndex,
            userData: _userData!,
            onDestinationSelected: _navigateToPage),
      Expanded(child: _buildCurrentPage())
    ]);
  }

  Widget _buildMobileLayout() {
    return Stack(children: [
      GestureDetector(
          onTap: () {
            if (_isMobileDrawerOpen)
              setState(() {
                _isMobileDrawerOpen = false;
                _menuAnimationController.reverse();
              });
          },
          onLongPress: (_sidebarIndex != 0 || _isLoading || _isUpdatingLayout)
              ? null
              : _openReorderModal,
          child: _buildCurrentPage()),
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
          left: _isMobileDrawerOpen ? 0 : -280,
          width: 280,
          child: _userData != null
              ? DashboardSidebar(
                  isExpanded: true,
                  selectedIndex: _sidebarIndex,
                  userData: _userData!,
                  onDestinationSelected: _navigateToPage)
              : const SizedBox.shrink())
    ]);
  }

  // Build Content
  Widget _buildCurrentPage() {
    if (_isLoading && _cards.isEmpty)
      return const Center(child: CustomLoadingSpinner());
    if (_userData == null)
      return const Center(
          child: Text("Erro ao carregar dados.",
              style: TextStyle(color: Colors.red)));
    return IndexedStack(
      index: _sidebarIndex,
      children: [
        _buildDashboardContent(
            isDesktop: MediaQuery.of(context).size.width > 800),
        _userData != null
            ? CalendarScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()),
        _userData != null
            ? JournalScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()),
        _userData != null
            ? FocoDoDiaScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()),
        _userData != null
            ? GoalsScreen(userData: _userData!)
            : const Center(child: CustomLoadingSpinner()),
      ],
    );
  }

  Widget _buildDashboardContent({required bool isDesktop}) {
    if (_isLoading && _cards.isEmpty)
      return const Center(child: CustomLoadingSpinner());
    if (_isUpdatingLayout) return const Center(child: CustomLoadingSpinner());
    if (!_isLoading && _cards.isEmpty)
      return const Center(
          child: Text("Nenhum card.",
              style: TextStyle(color: AppColors.secondaryText)));

    if (!isDesktop) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
        itemCount: _cards.length,
        itemBuilder: (context, index) => Padding(
            key: _cards[index].key ?? ValueKey('card_$index'),
            padding: const EdgeInsets.only(bottom: 20.0),
            child: _cards[index]),
      );
    } else {
      final width = MediaQuery.of(context).size.width;
      const spacing = 24.0;
      final sidebarW = _isDesktopSidebarExpanded ? 250.0 : 80.0;
      final availW = width - sidebarW - (spacing * 2);
      int cols = 1;
      if (availW > 1300)
        cols = 3;
      else if (availW > 850) cols = 2;
      cols = cols.clamp(1, _cards.length);
      return ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: ListView(
          padding: const EdgeInsets.all(spacing),
          children: [
            MasonryGridView.count(
              key: _masonryGridKey,
              crossAxisCount: cols,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              itemCount: _cards.length,
              itemBuilder: (ctx, i) => _cards[i],
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }
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
              return ReorderDashboardModal(
                  userId: _userData!.uid,
                  initialOrder: List.from(_userData!.dashboardCardOrder),
                  initialHidden: _userData!.dashboardHiddenCards,
                  scrollController: scrollController,
                  onSaveComplete: (bool success) async {
                    if (!mounted) return;
                    Navigator.of(currentContext).pop();
                    await Future.delayed(const Duration(milliseconds: 50));
                    if (success) {
                      setState(() => _isUpdatingLayout = true);
                      await _reloadDataNonStream(rebuildCards: true);
                      if (mounted)
                        setState(() {
                          _masonryGridKey = UniqueKey();
                          _isUpdatingLayout = false;
                          _isEditMode = false;
                        });
                    } else {
                      if (mounted) setState(() => _isEditMode = false);
                    }
                  });
            })).whenComplete(() {
      if (mounted && (_isEditMode || _isUpdatingLayout))
        setState(() {
          _isEditMode = false;
          _isUpdatingLayout = false;
        });
    });
  }

  // AppBar e FAB
  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    Widget? fab;
    if (_userData != null &&
        _userData!.subscription.isActive &&
        _userData!.subscription.plan == SubscriptionPlan.premium) {
      if (_sidebarIndex == 0)
        fab = ExpandingAssistantFab(onOpenAssistant: () {
          if (_userData != null)
            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AssistantPanel(userData: _userData!));
        });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
          userData: _userData,
          menuAnimationController: _menuAnimationController,
          isEditMode: _isEditMode,
          onEditPressed:
              (_sidebarIndex == 0 && !_isLoading && !_isUpdatingLayout)
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
          }),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      floatingActionButton: fab,
    );
  }

  // Show Numerology Detail
  void _showNumerologyDetail(
      {required String title,
      String? number,
      required VibrationContent content,
      required Color color,
      required IconData icon,
      String? categoryIntro}) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isDesktop)
      showDialog(
          context: context,
          builder: (context) => NumerologyDetailModal(
              title: title,
              number: number,
              content: content,
              color: color,
              icon: icon,
              categoryIntro: categoryIntro));
    else
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => NumerologyDetailModal(
              title: title,
              number: number,
              content: content,
              color: color,
              icon: icon,
              categoryIntro: categoryIntro)));
  }
}

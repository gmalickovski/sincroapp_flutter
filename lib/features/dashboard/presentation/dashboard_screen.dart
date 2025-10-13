import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

import 'package:sincro_app_flutter/common/widgets/info_card.dart';
import 'package:sincro_app_flutter/common/widgets/bussola_card.dart';
import 'package:sincro_app_flutter/common/widgets/custom_app_bar.dart';
import 'package:sincro_app_flutter/common/widgets/dashboard_sidebar.dart';

import '../../calendar/presentation/calendar_screen.dart';
import '../../tasks/presentation/foco_do_dia_screen.dart';

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

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserModel? _userData;
  NumerologyResult? _numerologyData;
  bool _isLoading = true;
  int _sidebarIndex = 0;
  List<DashboardCardData> _cards = [];
  bool _isEditMode = false;
  bool _isSidebarExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authRepository = AuthRepository();
    final firestoreService = FirestoreService();
    final currentUser = authRepository.getCurrentUser();

    if (currentUser != null) {
      final userData = await firestoreService.getUserData(currentUser.uid);

      // ### DEBUGGING ADICIONADO AQUI ###
      print("================ DADOS DO USUÁRIO CARREGADOS ================");
      if (userData != null) {
        print("UserData Carregado: SUCESSO");
        print(
            "  -> nomeAnalise: '${userData.nomeAnalise}' (Vazio? ${userData.nomeAnalise.isEmpty})");
        print(
            "  -> dataNasc: '${userData.dataNasc}' (Vazio? ${userData.dataNasc.isEmpty})");
      } else {
        print(
            "UserData Carregado: FALHA (usuário não encontrado no Firestore)");
      }
      print("==========================================================");
      // ### FIM DO DEBUGGING ###

      if (userData != null &&
          userData.nomeAnalise.isNotEmpty &&
          userData.dataNasc.isNotEmpty) {
        final engine = NumerologyEngine(
          nomeCompleto: userData.nomeAnalise,
          dataNascimento: userData.dataNasc,
        );
        final numerologyData = engine.calcular();

        if (mounted) {
          setState(() {
            _userData = userData;
            _numerologyData = numerologyData;
            _buildCardList();
            _isLoading = false;
          });
        }
      } else {
        // Se os dados estiverem incompletos, ainda precisamos definir o _userData
        // para que o app não fique em loading infinito.
        if (mounted) {
          setState(() {
            _userData = userData; // Passa os dados, mesmo que incompletos
            _isLoading = false;
          });
        }
      }
    }
  }

  // O resto do arquivo permanece exatamente o mesmo...
  void _handleCardTap(String cardTitle, VibrationContent content) {
    if (_isEditMode) return;
    print("Card Clicado: $cardTitle");
  }

  void _handleBussolaTap(BussolaContent content) {
    if (_isEditMode) return;
    print("Card Clicado: Bússola de Atividades");
  }

  void _buildCardList() {
    if (_numerologyData == null) return;

    final diaPessoalNum = _numerologyData!.numeros['diaPessoal']!;
    final diaPessoal = _getInfoContent('diaPessoal', diaPessoalNum);
    final mesPessoal =
        _getInfoContent('mesPessoal', _numerologyData!.numeros['mesPessoal']!);
    final anoPessoal =
        _getInfoContent('anoPessoal', _numerologyData!.numeros['anoPessoal']!);
    final arcanoRegente =
        _getArcanoContent(_numerologyData!.estruturas['arcanoRegente']);
    final arcanoVigente = _getArcanoContent(
        _numerologyData!.estruturas['arcanoAtual']['numero'] ?? 0);
    final cicloDeVida = _getCicloDeVidaContent(
        _numerologyData!.estruturas['cicloDeVidaAtual']['regente']);
    final bussola = _getBussolaContent(diaPessoalNum);

    _cards = [
      DashboardCardData(
          id: 'vibracaoDia',
          cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
              dragHandle: dragHandle,
              title: "Vibração do Dia",
              number: diaPessoalNum.toString(),
              info: diaPessoal,
              icon: Icons.sunny,
              color: Colors.cyan.shade300,
              isEditMode: isEditMode,
              onTap: () => _handleCardTap("Vibração do Dia", diaPessoal))),
      DashboardCardData(
          id: 'vibracaoMes',
          cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
              dragHandle: dragHandle,
              title: "Vibração do Mês",
              number: _numerologyData!.numeros['mesPessoal']!.toString(),
              info: mesPessoal,
              icon: Icons.nightlight_round,
              color: Colors.indigo.shade300,
              isEditMode: isEditMode,
              onTap: () => _handleCardTap("Vibração do Mês", mesPessoal))),
      DashboardCardData(
          id: 'vibracaoAno',
          cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
              dragHandle: dragHandle,
              title: "Vibração do Ano",
              number: _numerologyData!.numeros['anoPessoal']!.toString(),
              info: anoPessoal,
              icon: Icons.star,
              color: Colors.amber.shade300,
              isEditMode: isEditMode,
              onTap: () => _handleCardTap("Vibração do Ano", anoPessoal))),
      DashboardCardData(
          id: 'arcanoRegente',
          cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
              dragHandle: dragHandle,
              title: "Arcano Regente",
              number: _numerologyData!.estruturas['arcanoRegente'].toString(),
              info: arcanoRegente,
              icon: Icons.shield_moon,
              color: Colors.purple.shade300,
              isEditMode: isEditMode,
              onTap: () => _handleCardTap("Arcano Regente", arcanoRegente))),
      DashboardCardData(
          id: 'arcanoVigente',
          cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
              dragHandle: dragHandle,
              title: "Arcano Vigente",
              number:
                  (_numerologyData!.estruturas['arcanoAtual']['numero'] ?? '-')
                      .toString(),
              info: arcanoVigente,
              icon: Icons.shield_moon_outlined,
              color: Colors.purple.shade200,
              isEditMode: isEditMode,
              onTap: () => _handleCardTap("Arcano Vigente", arcanoVigente))),
      DashboardCardData(
          id: 'cicloVida',
          cardBuilder: (isEditMode, {dragHandle}) => InfoCard(
              dragHandle: dragHandle,
              title: "Ciclo de Vida",
              number: _numerologyData!.estruturas['cicloDeVidaAtual']['regente']
                  .toString(),
              info: cicloDeVida,
              icon: Icons.repeat,
              color: Colors.green.shade300,
              isEditMode: isEditMode,
              onTap: () => _handleCardTap("Ciclo de Vida", cicloDeVida))),
      DashboardCardData(
          id: 'bussola',
          cardBuilder: (isEditMode, {dragHandle}) => BussolaCard(
              dragHandle: dragHandle,
              bussolaContent: bussola,
              isEditMode: isEditMode,
              onTap: () => _handleBussolaTap(bussola))),
    ];
  }

  VibrationContent _getInfoContent(String category, int number) {
    return ContentData.vibracoes[category]?[number] ??
        const VibrationContent(
            titulo: 'Indisponível',
            descricaoCurta: 'Não foi possível carregar os dados.',
            descricaoCompleta: '',
            inspiracao: '');
  }

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

  Widget _buildCurrentPage({required bool isDesktop}) {
    switch (_sidebarIndex) {
      case 0:
        return _buildDashboardContent(isDesktop: isDesktop);
      case 1:
        return CalendarScreen(userData: _userData);
      case 3:
        return FocoDoDiaScreen(userData: _userData);
      default:
        return _buildDashboardContent(isDesktop: isDesktop);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      bool isDesktop = constraints.maxWidth > 800;
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        appBar: isDesktop
            ? null
            : CustomAppBar(
                userName: _userData?.nomeAnalise,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        drawer: isDesktop ? null : _buildMobileDrawer(),
        body: _isLoading
            ? const Center(child: CustomLoadingSpinner())
            : isDesktop
                ? _buildDesktopLayout()
                : _buildMobileLayout(),
        floatingActionButton: (isDesktop == false &&
                _isEditMode &&
                _sidebarIndex == 0)
            ? FloatingActionButton(
                onPressed: () => setState(() => _isEditMode = false),
                backgroundColor: Colors.green,
                mini: true,
                shape: const CircleBorder(),
                child: const Icon(Icons.check, color: Colors.white, size: 24),
              )
            : null,
      );
    });
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: DashboardSidebar(
        isExpanded: true,
        selectedIndex: _sidebarIndex,
        onDestinationSelected: (index) {
          if (index < 5) {
            setState(() {
              _sidebarIndex = index;
              _isEditMode = false;
            });
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        CustomAppBar(
          userName: _userData?.nomeAnalise,
          isDesktop: true,
          isEditMode: _isEditMode,
          onEditPressed: _sidebarIndex == 0
              ? () => setState(() => _isEditMode = !_isEditMode)
              : null,
          onMenuPressed: () =>
              setState(() => _isSidebarExpanded = !_isSidebarExpanded),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardSidebar(
                isExpanded: _isSidebarExpanded,
                selectedIndex: _sidebarIndex,
                onDestinationSelected: (index) {
                  if (index < 5) {
                    setState(() {
                      _sidebarIndex = index;
                      _isEditMode = false;
                    });
                  }
                },
              ),
              Expanded(child: _buildCurrentPage(isDesktop: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return GestureDetector(
      onLongPress: (_isEditMode || _sidebarIndex != 0)
          ? null
          : () => setState(() => _isEditMode = true),
      child: _buildCurrentPage(isDesktop: false),
    );
  }

  Widget _buildDashboardContent({required bool isDesktop}) {
    if (_numerologyData == null) {
      return const Center(child: Text("Não foi possível calcular os dados."));
    }

    Widget buildDragHandle(int index) {
      return ReorderableDragStartListener(
        index: index,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            color: Colors.transparent,
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
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
        itemCount: _cards.length,
        proxyDecorator: (child, index, animation) =>
            Material(elevation: 8.0, color: Colors.transparent, child: child),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _cards.removeAt(oldIndex);
            _cards.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final item = _cards[index];
          return Padding(
            key: ValueKey(item.id),
            padding: const EdgeInsets.only(bottom: 20.0),
            child: item.cardBuilder(
              _isEditMode,
              dragHandle: _isEditMode ? buildDragHandle(index) : null,
            ),
          );
        },
      );
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      const double cardMaxWidth = 420.0;
      const double spacing = 24.0;
      final crossAxisCount =
          (screenWidth > cardMaxWidth * 3 + spacing * 2) ? 3 : 2;
      final double gridMaxWidth =
          (crossAxisCount * cardMaxWidth) + ((crossAxisCount - 1) * spacing);
      const double childAspectRatio = 1.35;

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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                  }),
                  itemBuilder: (context, index) {
                    final item = _cards[index];
                    return Container(
                      key: ValueKey(item.id),
                      child: item.cardBuilder(
                        _isEditMode,
                        dragHandle: _isEditMode
                            ? Icon(
                                Icons.drag_indicator,
                                color: AppColors.secondaryText.withOpacity(0.7),
                                size: 24,
                              )
                            : null,
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

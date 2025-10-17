// lib/features/dashboard/presentation/dashboard_screen.dart

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
import '../../journal/presentation/journal_screen.dart';
import '../../tasks/presentation/foco_do_dia_screen.dart';
import '../../goals/presentation/goals_screen.dart';

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

  bool _isDesktopSidebarExpanded = true;
  bool _isMobileDrawerOpen = false;

  late AnimationController _menuAnimationController;

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
    final firestoreService = FirestoreService();
    final currentUser = authRepository.getCurrentUser();

    if (currentUser != null) {
      final userData = await firestoreService.getUserData(currentUser.uid);

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
      } else if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    }
  }

  // ... (demais métodos _handle, _buildCardList, _get...Content permanecem os mesmos)
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

    if (_isLoading || _userData == null) {
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CustomLoadingSpinner()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        userData: _userData,
        menuAnimationController: _menuAnimationController,
        isEditMode: _isEditMode,
        onEditPressed: (_sidebarIndex == 0 && isDesktop)
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
                  _isEditMode = false;
                });
              }
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
          child: DashboardSidebar(
            isExpanded: true,
            selectedIndex: _sidebarIndex,
            userData: _userData!,
            onDestinationSelected: (index) {
              if (index < 5) {
                setState(() {
                  _sidebarIndex = index;
                  _isEditMode = false;
                });
              }
              setState(() {
                _isMobileDrawerOpen = false;
                _menuAnimationController.reverse();
              });
            },
          ),
        ),
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
    // ... (O restante do seu método _buildDashboardContent permanece o mesmo)
    if (_numerologyData == null) {
      return const Center(
          child: Text("Não foi possível calcular os dados.",
              style: TextStyle(color: Colors.white)));
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
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

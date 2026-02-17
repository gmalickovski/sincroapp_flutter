import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/core/theme/ai_modal_theme.dart';
// import 'package:sincro_app_flutter/common/widgets/custom_text_field.dart'; // Removed missing import
import 'package:sincro_app_flutter/features/harmony/services/love_compatibility_service.dart';
import 'package:sincro_app_flutter/services/harmony_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/features/harmony/presentation/widgets/select_user_modal.dart';

class LoveCompatibilityModal extends StatefulWidget {
  final UserModel currentUser;

  const LoveCompatibilityModal({super.key, required this.currentUser});

  @override
  State<LoveCompatibilityModal> createState() => _LoveCompatibilityModalState();
}

class _LoveCompatibilityModalState extends State<LoveCompatibilityModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = LoveCompatibilityService();
  final _harmonyService = HarmonyService();

  // Inputs
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController(); // dd/mm/yyyy
  UserModel? _selectedUser;

  // State
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _aiAnalysis;
  bool _isAnalyzingAI = false;
  bool _showResultFooter = false; // Controls footer visibility animation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (_nameController.text.isEmpty || _birthDateController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Preencha o nome e a data de nascimento corretamente.')),
      );
      return;
    }

    if (widget.currentUser.subscription.plan == SubscriptionPlan.free) {
      _showUpgradeDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _aiAnalysis = null;
    });

    // 1. Calculate Profiles Local
    final engineA = NumerologyEngine(
      nomeCompleto: widget.currentUser.nomeAnalise,
      dataNascimento: widget.currentUser.dataNasc,
    );
    final profileA = engineA.calculateProfile();

    final engineB = NumerologyEngine(
      nomeCompleto: _nameController.text,
      dataNascimento: _birthDateController.text,
    );
    final profileB = engineB.calculateProfile();

    // 2. Synastry
    final synastry = _harmonyService.calculateSynastry(
        profileA: profileA, profileB: profileB);

    // 3. Show Result
    setState(() {
      _result = synastry;
      _isLoading = false;
    });

    // Reset footer state and trigger animation after delay
    setState(() => _showResultFooter = false);
    final isPremium =
        widget.currentUser.subscription.plan == SubscriptionPlan.premium;
    Future.delayed(Duration(milliseconds: isPremium ? 200 : 4000), () {
      if (mounted && _result != null) {
        setState(() => _showResultFooter = true);
      }
    });

    // _tabController.animateTo(1); // Removed as we are not using TabController for swiping anymore
    // Since we use conditional rendering on the index, we simply update the state above
    // And ensure the TabController index is updated for the TabBar
    _tabController.animateTo(1);
  }

  Future<void> _requestAIAnalysis() async {
    if (_result == null) return;

    setState(() => _isAnalyzingAI = true);

    try {
      final engineA = NumerologyEngine(
        nomeCompleto: widget.currentUser.nomeAnalise,
        dataNascimento: widget.currentUser.dataNasc,
      );
      final profileA = engineA.calculateProfile();

      final engineB = NumerologyEngine(
          nomeCompleto: _nameController.text,
          dataNascimento: _birthDateController.text);
      final profileB = engineB.calculateProfile();

      final analysis = await _service.getDetailedAnalysis(
          currentUser: widget.currentUser,
          currentUserProfile: profileA,
          partnerName: _nameController.text,
          partnerBirthDate: _birthDateController.text,
          partnerProfile: profileB,
          synastryResult: _result!,
          // Pass attraction rules to context so AI understands "Why" they match
          relationshipRules: {
            'vibra': _result!['details']['vibra'],
            'atrai': _result!['details']['atrai'],
            'oposto': _result!['details']['oposto'],
            'passivo': _result!['details']['passivo'],
          });

      setState(() {
        _aiAnalysis = analysis;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na análise IA: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = MediaQuery.of(context).size.width > 600;

      if (isDesktop) {
        // Desktop: Original Modal Dialog
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: _buildModalContent(context,
                isDesktop: true), // Extract content logic
          ),
        );
      } else {
        // Mobile: Full Screen Scaffold
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: Colors.pink.shade400, size: 22),
                const SizedBox(width: 8),
                const Text('Harmonia Conjugal',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            centerTitle: true,
          ),
          bottomNavigationBar: !isDesktop
              ? AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    // Hide button if we have a result and are on the Result tab (index 1)
                    if (_result != null && _tabController.index == 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _calculate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                          elevation: 4,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Calcular compatibilidade',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    );
                  },
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildModalContent(context, isDesktop: false),
            ),
          ),
        );
      }
    });
  }

  Widget _buildModalContent(BuildContext context, {required bool isDesktop}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header (Only for Desktop, Mobile uses AppBar)
        if (isDesktop) ...[
          SizedBox(
            width: double.infinity,
            height: 44, // Standardized height
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Harmonia Conjugal',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.favorite, color: Colors.pink.shade400, size: 24),
                  ],
                ),
                // Close Button (Right Aligned) - Using standardized button
                Positioned(
                  right: 0,
                  child: AIModalTheme.closeButton(
                      onPressed: () => Navigator.pop(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
        ],

        // Tabs
        if (_result == null) ...[
          // Only Input View if no result yet
          Flexible(fit: FlexFit.loose, child: _buildInputForm(isDesktop)),
        ] else ...[
          // Tabs if result exists
          // Mobile usually prefers no tabs if content is short? But here result is long.
          // We keep tabs for consistency.
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.harmonyPink,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            splashBorderRadius: BorderRadius.circular(16),
            indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.harmonyPink.withOpacity(0.2),
                border: Border.all(color: AppColors.harmonyPink)),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [
              Tab(text: 'Dados'),
              Tab(text: 'Resultado'),
            ],
          ),
          const SizedBox(height: 32),
          Flexible(
            fit: FlexFit.loose,
            child: _tabController.index == 0
                ? _buildInputForm(isDesktop)
                : _buildResultView(context, isDesktop),
          ),
        ],
      ],
    );
  }

  void _openUserSelection() async {
    if (_selectedUser != null) {
      // Clear selection
      setState(() {
        _selectedUser = null;
        _nameController.clear();
        _birthDateController.clear();
      });
      return;
    }

    final result = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SelectUserModal(),
    );

    if (result != null) {
      setState(() {
        _selectedUser = result;
        // Puxar o nome de análise (com acentos) se houver, senão monta nome completo
        if (result.nomeAnalise.isNotEmpty) {
          _nameController.text = result.nomeAnalise;
        } else {
          _nameController.text =
              '${result.primeiroNome} ${result.sobrenome}'.trim();
        }

        _birthDateController.text = result.dataNasc;
      });
    }
  }

  Widget _buildInputForm(bool isDesktop) {
    // Keep SingleChildScrollView but wrap in Flexible in parent
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.harmonyPink, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: const TextStyle(color: Colors.white70),
    );

    final hasManualInput =
        _nameController.text.isNotEmpty || _birthDateController.text.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Adaptive height
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Com quem você quer verificar a compatibilidade?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            enabled: _selectedUser == null,
            autofillHints: const [AutofillHints.name], // Tip for browser
            textInputAction: TextInputAction.next,
            decoration: inputDecoration.copyWith(
              labelText: 'Nome Completo da Pessoa',
              helperText:
                  'Use acentos se houver, pois pode interferir no resultado.',
              helperStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child:
                      Icon(Icons.person_outline, color: AppColors.harmonyPink)),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _birthDateController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.datetime,
            enabled: _selectedUser == null,
            autofillHints: const [AutofillHints.birthday], // Tip for browser
            textInputAction: TextInputAction.done,
            decoration: inputDecoration.copyWith(
              labelText: 'Data de Nascimento (dd/mm/aaaa)',
              hintText: 'ex: 25/12/1990',
              prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child:
                      Icon(Icons.cake_outlined, color: AppColors.harmonyPink)),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('OU',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            ],
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: hasManualInput && _selectedUser == null ? 0.5 : 1.0,
            child: OutlinedButton.icon(
              onPressed: (hasManualInput && _selectedUser == null)
                  ? null
                  : _openUserSelection,
              icon: Icon(_selectedUser != null ? Icons.close : Icons.contacts,
                  size: 18,
                  color: _selectedUser != null ? Colors.redAccent : null),
              label: Text(
                _selectedUser != null
                    ? 'Remover ${_selectedUser!.username} (X)'
                    : 'Selecionar dos Contatos (@username)',
                style: TextStyle(
                    color: _selectedUser != null
                        ? Colors.redAccent
                        : Colors.white70),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    _selectedUser != null ? Colors.redAccent : Colors.white70,
                side: BorderSide(
                    color: _selectedUser != null
                        ? Colors.redAccent.withOpacity(0.5)
                        : Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (isDesktop)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _calculate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.favorite, size: 20),
              label: Text(
                  _isLoading ? 'Calculando...' : 'Calcular compatibilidade',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.harmonyPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, bool isDesktop) {
    if (_result == null) return const SizedBox.shrink();

    final score = _result!['score'] as int;
    final status = _result!['status'] as String;
    final description = _result!['description'] as String;
    final detailedDescription =
        _result!['details']['detailedDescription'] as String?;
    final harmoniaA = _result!['details']['numA'] as int?;
    final rules = _result!['details']['rules'] as Map<String, dynamic>?;

    Color scoreColor;
    if (score >= 80) {
      scoreColor = Colors.greenAccent;
    } else if (score >= 60)
      scoreColor = Colors.amberAccent;
    else
      scoreColor = Colors.redAccent;

    // Check if premium to show/hide sections
    final isPremium =
        widget.currentUser.subscription.plan == SubscriptionPlan.premium;

    return Stack(
      children: [
        // 1. Scrollable Content (Behind)
        SingleChildScrollView(
          // Less padding if AI content is shown, otherwise adjust for footer type. INCREASED for mobile scrolling.
          padding: EdgeInsets.only(
              bottom: _aiAnalysis != null ? 32 : (isPremium ? 150 : 250)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gauge Section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 16,
                        color: scoreColor,
                        backgroundColor: Colors.white10,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score%',
                          style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: scoreColor),
                        ),
                        const Text('Sinergia',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),

              Text(
                status.toUpperCase(),
                style: TextStyle(
                    color: scoreColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      description.replaceFirst(
                          'entre os números', 'entre os Números de Harmonia'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16, height: 1.4),
                    ),
                    if (detailedDescription != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          detailedDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.6,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              // --- STATIC ANALYSIS SECTION ---
              if (rules != null) ...[
                _buildStaticAnalysisSection(rules),
                const SizedBox(height: 24),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text('Entenda os Números (Detalhes Técnicos)',
                        style: TextStyle(color: Colors.white60, fontSize: 13)),
                    iconColor: Colors.white60,
                    collapsedIconColor: Colors.white60,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                                'Você',
                                widget.currentUser.primeiroNome,
                                _result!['details']['destinyA'],
                                _result!['details']['expressionA'],
                                _result!['details']['numA']),
                            const Divider(color: Colors.white10),
                            _buildDetailRow(
                                'Parceiro(a)',
                                _nameController.text,
                                _result!['details']['destinyB'],
                                _result!['details']['expressionB'],
                                _result!['details']['numB']),
                            const SizedBox(height: 8),
                            const Text(
                              '* Harmonia Conjugal = (Destino + Expressão) reduzido a 1-9.',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],

              // --- AI ANALYSIS CONTENT (If available) ---
              if (_aiAnalysis != null) ...[
                const SizedBox(height: 24),

                // Gradient Header (same style as Professional Modal)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.harmonyPink.withOpacity(0.9),
                        AppColors.harmonyPink.withOpacity(0.6)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.robot,
                          size: 24, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Análise do Sincro AI',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 18)),
                            const SizedBox(height: 4),
                            Text(
                                'Casal: ${widget.currentUser.primeiroNome} e ${_nameController.text.isNotEmpty ? _nameController.text : _selectedUser?.primeiroNome ?? "Parceiro(a)"}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // AI Analysis Content
                MarkdownBody(
                  data: _aiAnalysis!,
                  builders: {
                    'blockquote': MantraBuilder(),
                    'strong': MantraEmphasisBuilder(),
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        color: Colors.white, height: 1.6, fontSize: 15),
                    h1: const TextStyle(
                        color: AppColors.harmonyPink,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    h2: const TextStyle(
                        color: AppColors.harmonyPink,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                    h3: const TextStyle(
                        color: AppColors.harmonyPink,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 2),
                    listBullet: const TextStyle(color: AppColors.harmonyPink),
                    blockquote: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                    blockquoteDecoration: BoxDecoration(
                      color: AppColors.harmonyPink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.harmonyPink.withOpacity(0.3)),
                    ),
                    blockquotePadding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    blockSpacing: 20,
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Fixed Animated Footer (Overlay)
        if (_aiAnalysis == null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            bottom: _showResultFooter ? 0 : -200, // Slide up animation
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _showResultFooter ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: isPremium ? EdgeInsets.zero : const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    // Opaque background to hide scrolling content
                    color: isPremium
                        ? Colors.transparent
                        : const Color(0xFF1E1E1E), // Solid dark grey/black
                    borderRadius: BorderRadius.circular(24),
                    border: isPremium
                        ? null
                        : Border.all(
                            color: const Color(0xFFD4AF37), // Gold border
                            width: 2 // Thicker border for non-premium
                            ),
                    boxShadow: isPremium
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFFD4AF37)
                                  .withOpacity(0.2), // Gold glow
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                            const BoxShadow(
                                color: Colors.black54,
                                blurRadius: 15,
                                offset: Offset(0, 10))
                          ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isPremium) ...[
                      const Text(
                        'Quer saber a dinâmica profunda da relação e dicas de como conviver melhor?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFFFFE082), // Gold text
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: _buildAiButton(), // The button itself
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAiButton() {
    final isPremium =
        widget.currentUser.subscription.plan == SubscriptionPlan.premium;

    // Customize styling based on context
    return ElevatedButton.icon(
      onPressed: () {
        if (isPremium) {
          if (!_isAnalyzingAI) _requestAIAnalysis();
        } else {
          _openPlansPage();
        }
      },
      icon: _isAnalyzingAI
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : isPremium
              ? const FaIcon(FontAwesomeIcons.magic, size: 16)
              : const Icon(Icons.lock_open, size: 16),
      label: Text(
        _isAnalyzingAI
            ? 'Analisando...'
            : isPremium
                ? 'VER ANÁLISE DETALHADA (IA)'
                : 'DESBLOQUEAR ANÁLISE COMPLETA', // More direct CTA
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPremium
            ? AppColors.harmonyPink
            : const Color(0xFFD4AF37), // Gold button for upsell
        foregroundColor: isPremium
            ? Colors.white
            : Colors.black, // High contrast black on gold
        disabledForegroundColor: Colors.white38,
        disabledBackgroundColor: Colors.grey.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: isPremium
            ? AppColors.primary.withOpacity(0.5)
            : const Color(0xFFD4AF37).withOpacity(0.5),
      ),
    );
  }

  void _openPlansPage() async {
    final Uri url = Uri.parse(kDebugMode
        ? 'http://localhost:3000/planos-e-precos'
        : 'https://sincroapp.com.br/planos-e-precos');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível abrir a página de planos.')));
      }
    }
  }

  Widget _buildStaticAnalysisSection(Map<String, dynamic> rules) {
    final vibra = (rules['vibra'] as List?)?.cast<int>() ?? [];
    final atrai = (rules['atrai'] as List?)?.cast<int>() ?? [];
    final oposto = (rules['oposto'] as List?)?.cast<int>() ?? [];
    final passivo = (rules['passivo'] as List?)?.cast<int>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vibra.isNotEmpty)
          _buildStaticCard('Vibram Juntos', vibra,
              _staticExplanations['vibra']!, Colors.greenAccent),
        if (atrai.isNotEmpty)
          _buildStaticCard('Atração', atrai, _staticExplanations['atrai']!,
              Colors.blueAccent),
        if (oposto.isNotEmpty)
          _buildStaticCard('Opostos', oposto, _staticExplanations['oposto']!,
              Colors.orangeAccent),
        if (passivo.isNotEmpty)
          _buildStaticCard(
              'Passivo', passivo, _staticExplanations['passivo']!, Colors.grey),
      ],
    );
  }

  Widget _buildStaticCard(
      String title, List<int> numbers, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: color, size: 18),
              const SizedBox(width: 8),
              Text('$title: ${numbers.join(", ")}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String name, int dest, int exp, int harm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $name',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 4),
        Text('Destino ($dest) + Expressão ($exp) = Harmonia ($harm)',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  static const Map<String, String> _staticExplanations = {
    'vibra':
        'Excelente compatibilidade! Vocês vibram na mesma sintonia, facilitando a compreensão mútua e o fluxo natural da relação.',
    'atrai':
        'Existe uma forte atração magnética entre vocês. Perfis que estimulam o crescimento, a admiração e o desejo de estar junto.',
    'oposto':
        'São opostos que podem se atrair ou repelir. A relação exige negociação consciente, paciência e respeito às diferenças de ritmo.',
    'passivo':
        'Relação mais neutra ou passiva. A dinâmica é suave, mas pode cair na rotina se não houver esforço mútuo para manter a chama acesa.',
    'monotonia':
        'A relação pode se tornar monótona se não houver esforço para inovar e buscar novas experiências juntos.',
  };

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Funcionalidade Premium ⭐',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'A análise de Harmonia Conjugal está disponível apenas para assinantes Desperta ou Sinergia.\n\nFaça o upgrade para desbloquear!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Voltar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to subscription page
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Redirecionando para planos...')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Conhecer Planos',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class MantraBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElement(
      md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    // Extract text content from the blockquote (usually wrapped in <p>)
    final text = element.textContent;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const FaIcon(FontAwesomeIcons.quoteLeft,
              size: 20, color: Color(0xFFB388FF)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          const FaIcon(FontAwesomeIcons.quoteRight,
              size: 20, color: Color(0xFFB388FF)),
        ],
      ),
    );
  }
}

class MantraEmphasisBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // Check if text is a quote/mantra (starts and ends with quotes)
    final content = text.textContent;
    final isMantra = content.startsWith('"') ||
        content.startsWith('"') ||
        content.startsWith('«');

    if (isMantra) {
      // Mantra/Quote style: Block with rounded background
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.2),
                Colors.cyanAccent.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ]),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
      );
    } else {
      // Regular bold: Inline cyan text (no block)
      return RichText(
        text: TextSpan(
          text: content,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      );
    }
  }
}

class RoundedHeaderBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        text.text,
        style: preferredStyle?.copyWith(
            color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

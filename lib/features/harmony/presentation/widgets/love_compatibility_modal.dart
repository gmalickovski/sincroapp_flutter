import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
// import 'package:sincro_app_flutter/common/widgets/custom_text_field.dart'; // Removed missing import
import 'package:sincro_app_flutter/features/harmony/services/love_compatibility_service.dart';
import 'package:sincro_app_flutter/services/harmony_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  
  // State
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _aiAnalysis;
  bool _isAnalyzingAI = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        const SnackBar(content: Text('Preencha o nome e a data de nascimento corretamente.')),
      );
      return;
    }

    if (widget.currentUser.subscription.plan == SubscriptionPlan.free) {
      _showUpgradeDialog();
      return;
    }

    setState(() => _isLoading = true);

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
      profileA: profileA, 
      profileB: profileB
    );

    // 3. Show Result
    setState(() {
      _result = synastry;
      _isLoading = false;
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
        }
      );

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;
        final width = isDesktop ? 600.0 : constraints.maxWidth;
        final height = isDesktop ? 700.0 : constraints.maxHeight;

        return Dialog(
          backgroundColor: isDesktop ? AppColors.cardBackground : AppColors.background,
          insetPadding: isDesktop 
              ? const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0) 
              : EdgeInsets.zero, // Fullscreen on mobile
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: isDesktop ? 700.0 : constraints.maxHeight,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Adaptive Height
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Harmonia Conjugal ❤️',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Tabs
                if (_result == null) ...[
                     // Only Input View if no result yet
                     Expanded(child: _buildInputForm(isDesktop)),
                ] else ...[
                     // Tabs if result exists
                     TabBar(
                       controller: _tabController,
                       indicatorColor: AppColors.primary,
                       dividerColor: Colors.transparent,
                       indicatorSize: TabBarIndicatorSize.tab,
                       // Pill indicator style
                       splashBorderRadius: BorderRadius.circular(50),
                       indicator: BoxDecoration(
                           borderRadius: BorderRadius.circular(50),
                           color: AppColors.primary.withOpacity(0.2), 
                           border: Border.all(color: AppColors.primary)
                       ),
                       labelColor: Colors.white,
                       unselectedLabelColor: Colors.white70,
                       tabs: const [
                         Tab(text: 'Dados'),
                         Tab(text: 'Resultado'),
                       ],
                     ),
                     const SizedBox(height: 24),
                     const SizedBox(height: 24),
                     Flexible(
                       fit: FlexFit.loose,
                       child: _tabController.index == 0 
                          ? _buildInputForm(isDesktop)
                          : _buildResultView(context), // Pass context for Theme lookup if needed
                     ),
                ],
              ],
            ),

          ),
        );
      }
    );
  }

  Widget _buildInputForm(bool isDesktop) {
    // Keep SingleChildScrollView but wrap in Flexible in parent
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      labelStyle: const TextStyle(color: Colors.white70),
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Adaptive height
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Com quem você quer verificar a compatibilidade?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration.copyWith(
              labelText: 'Nome Completo da Pessoa',
              helperText: 'Use acentos se houver, pois pode interferir no resultado.',
              helperStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              prefixIcon: const Padding(padding: EdgeInsets.only(left: 16, right: 8), child: Icon(Icons.person_outline, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _birthDateController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.datetime,
            decoration: inputDecoration.copyWith(
              labelText: 'Data de Nascimento (dd/mm/aaaa)',
              hintText: 'ex: 25/12/1990',
              prefixIcon: const Padding(padding: EdgeInsets.only(left: 16, right: 8), child: Icon(Icons.cake_outlined, color: AppColors.primary)),
            ),
          ),
          
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seletor de contatos em breve!')));
            },
            icon: const Icon(Icons.contacts, size: 18),
            label: const Text('Selecionar dos Contatos (@username)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 32),
          
          ElevatedButton(
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('CALCULAR COMPATIBILIDADE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context) {
    if (_result == null) return const SizedBox.shrink();

    final score = _result!['score'] as int;
    final status = _result!['status'] as String;
    final description = _result!['description'] as String;
    final detailedDescription = _result!['details']['detailedDescription'] as String?;
    final harmoniaA = _result!['details']['numA'] as int?;
    final rules = _result!['details']['rules'] as Map<String, dynamic>?;

    Color scoreColor;
    if (score >= 80) scoreColor = Colors.greenAccent;
    else if (score >= 60) scoreColor = Colors.amberAccent;
    else scoreColor = Colors.redAccent;

    // Check if premium to show/hide sections
    final isPremium = widget.currentUser.subscription.plan == SubscriptionPlan.premium;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scrollable Content
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Adaptive height inside scrollView
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
                            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: scoreColor),
                          ),
                          const Text('Sinergia', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Text(
                  status.toUpperCase(),
                  style: TextStyle(color: scoreColor, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        description.replaceFirst('entre os números', 'entre os Números de Harmonia'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
                      ),
                      if (detailedDescription != null) ...[
                         const SizedBox(height: 24),
                         Container(
                           padding: const EdgeInsets.all(24),
                           decoration: BoxDecoration(
                             color: AppColors.primary.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                           ),
                           child: Text(
                             detailedDescription,
                             textAlign: TextAlign.center,
                             style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6, fontStyle: FontStyle.italic),
                           ),
                         ),
                      ]
                    ],
                  ),
                ),

                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Divider(color: Colors.white12),
                ),

                // --- STATIC ANALYSIS SECTION ---
                if (rules != null) ...[
                   _buildStaticAnalysisSection(rules),
                   const SizedBox(height: 24),
                   
                   Theme(
                     data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                     child: ExpansionTile(
                       title: const Text('Entenda os Números (Detalhes Técnicos)', style: TextStyle(color: Colors.white60, fontSize: 13)),
                       iconColor: Colors.white60,
                       collapsedIconColor: Colors.white60,
                       children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Você', widget.currentUser.primeiroNome, _result!['details']['destinyA'], _result!['details']['expressionA'], _result!['details']['numA']),
                                const Divider(color: Colors.white10),
                                _buildDetailRow('Parceiro(a)', _nameController.text, _result!['details']['destinyB'], _result!['details']['expressionB'], _result!['details']['numB']),
                                const SizedBox(height: 8),
                                const Text(
                                  '* Harmonia Conjugal = (Destino + Expressão) reduzido a 1-9.',
                                  style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                          children: [
                             const FaIcon(FontAwesomeIcons.robot, size: 18, color: AppColors.primary),
                             const SizedBox(width: 8),
                             const Text('Análise do Sincro AI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        MarkdownBody(
                          data: _aiAnalysis!,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white, height: 1.5, fontSize: 15),
                            strong: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                            h1: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            h2: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            h3: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            listBullet: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32), // Spacer end of content
                ] else ...[
                   // Spacer for fixed footer
                   const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),

        // --- FIXED FOOTER (CTA) ---
        // Only show CTA if AI Analysis is NOT showing or if it's the trigger button
        if (_aiAnalysis == null) ...[
            Container(
              padding: const EdgeInsets.only(top: 24, bottom: 8), // Padding above CTA
              decoration: BoxDecoration(
                color: isDesktop ? AppColors.cardBackground : AppColors.background, // Match background to cover scroll
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  )
                ]
              ),
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    Text(
                      'Quer saber a dinâmica profunda da relação e dicas de como conviver melhor?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, // Full width button
                      child: _buildAiButton(),
                    ),
                 ],
              ),
            ),
        ]
      ],
    );
  }
  Widget _buildAiButton() {
    final isPremium = widget.currentUser.subscription.plan == SubscriptionPlan.premium;

    return ElevatedButton.icon(
      onPressed: (isPremium && !_isAnalyzingAI) ? _requestAIAnalysis : null,
      icon: _isAnalyzingAI 
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
        : isPremium 
            ? const FaIcon(FontAwesomeIcons.magic, size: 16)
            : const Icon(Icons.lock, size: 16),
      label: Text(
        _isAnalyzingAI 
            ? 'Analisando...' 
            : isPremium 
                ? 'VER ANÁLISE DETALHADA (IA)' 
                : 'DISPONÍVEL NO PLANO SINERGIA',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPremium ? Colors.deepPurple : Colors.grey.withOpacity(0.3),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        disabledBackgroundColor: Colors.grey.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: const StadiumBorder(),
        elevation: isPremium ? 4 : 0,
      ),
    );
  }

  Widget _buildStaticAnalysisSection(Map<String, dynamic> rules) {
    final vibra = (rules['vibra'] as List?)?.cast<int>() ?? [];
    final atrai = (rules['atrai'] as List?)?.cast<int>() ?? [];
    final oposto = (rules['oposto'] as List?)?.cast<int>() ?? [];
    final passivo = (rules['passivo'] as List?)?.cast<int>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vibra.isNotEmpty) _buildStaticCard('Vibram Juntos', vibra, _staticExplanations['vibra']!, Colors.greenAccent),
        if (atrai.isNotEmpty) _buildStaticCard('Atração', atrai, _staticExplanations['atrai']!, Colors.blueAccent),
        if (oposto.isNotEmpty) _buildStaticCard('Opostos', oposto, _staticExplanations['oposto']!, Colors.orangeAccent),
        if (passivo.isNotEmpty) _buildStaticCard('Passivo', passivo, _staticExplanations['passivo']!, Colors.grey),
      ],
    );
  }

  Widget _buildStaticCard(String title, List<int> numbers, String text, Color color) {
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
              Text('$title: ${numbers.join(", ")}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white70,  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String name, int dest, int exp, int harm) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text('$label: $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
         const SizedBox(height: 4),
         Text('Destino ($dest) + Expressão ($exp) = Harmonia ($harm)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
       ],
     );
  }

  static const Map<String, String> _staticExplanations = {
    'vibra': 'Excelente compatibilidade! Vocês vibram na mesma sintonia, facilitando a compreensão mútua e o fluxo natural da relação.',
    'atrai': 'Existe uma forte atração magnética entre vocês. Perfis que estimulam o crescimento, a admiração e o desejo de estar junto.',
    'oposto': 'São opostos que podem se atrair ou repelir. A relação exige negociação consciente, paciência e respeito às diferenças de ritmo.',
    'passivo': 'Relação mais neutra ou passiva. A dinâmica é suave, mas pode cair na rotina se não houver esforço mútuo para manter a chama acesa.',
    'monotonia': 'A relação pode se tornar monótona se não houver esforço para inovar e buscar novas experiências juntos.',
  };

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Funcionalidade Premium ⭐', style: TextStyle(color: Colors.white)),
        content: const Text(
          'A análise de Harmonia Conjugal está disponível apenas para assinantes Desperta ou Sinergia.\n\nFaça o upgrade para desbloquear!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to subscription page
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redirecionando para planos...')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Conhecer Planos', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

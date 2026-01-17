import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/strategy/services/strategy_n8n_service.dart';
import 'package:sincro_app_flutter/features/harmony/presentation/widgets/love_compatibility_modal.dart'; // Reuse builders
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfessionalAptitudeModal extends StatefulWidget {
  final UserModel currentUser;

  const ProfessionalAptitudeModal({super.key, required this.currentUser});

  @override
  State<ProfessionalAptitudeModal> createState() =>
      _ProfessionalAptitudeModalState();
}

class _ProfessionalAptitudeModalState extends State<ProfessionalAptitudeModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _professionController = TextEditingController();

  // State
  bool _isLoading = false;
  String? _aiAnalysis;
  NumerologyProfile? _userProfile;
  VibrationContent? _staticContent;
  int? _expressionNumber;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateNumerology();
  }

  void _calculateNumerology() {
    final engine = NumerologyEngine(
      nomeCompleto: widget.currentUser.nomeAnalise,
      dataNascimento: widget.currentUser.dataNasc,
    );
    _userProfile = engine.calculateProfile();
    _expressionNumber = _userProfile?.expressionNumber;

    if (_expressionNumber != null) {
      _staticContent =
          ContentData.textosAptidoesProfissionais[_expressionNumber];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _analyzeProfession() async {
    if (_professionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite uma profissão.')),
      );
      return;
    }

    // Check Plan: Sinergia Only
    if (widget.currentUser.subscription.plan != SubscriptionPlan.premium) {
      _showUpgradeDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _aiAnalysis = null;
    });

    try {
      final result = await StrategyN8NService.analyzeProfessionCompatibility(
        user: widget.currentUser,
        profile: _userProfile!,
        professionName: _professionController.text,
      );

      setState(() {
        _aiAnalysis = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na análise: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUpgradeDialog() {
    // Show simple dialog or redirect
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Recurso Premium', style: TextStyle(color: Color(0xFFFFD700))),
        content: const Text(
          'A análise específica de profissões com IA é exclusiva do plano Sinergia.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openPlansPage();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  void _openPlansPage() async {
    const url = 'https://sincroapp.com.br/planos-e-precos';
    if (!await launchUrl(Uri.parse(url))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir a página.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return LayoutBuilder(builder: (context, constraints) {
      if (isDesktop) {
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: _buildModalContent(context, isDesktop: true),
          ),
        );
      } else {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Aptidão Profissional',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
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
      children: [
        if (isDesktop) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Aptidão Profissional',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Aptidão Geral'),
            Tab(text: 'Analisar Profissão'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneralTab(),
              _buildSpecificTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    // Check Desperta Plan (Plus)
    final isFree = widget.currentUser.subscription.plan == SubscriptionPlan.free;

    if (isFree) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.lock, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Conteúdo Exclusivo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'A análise geral de aptidão profissional está disponível a partir do plano Desperta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openPlansPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Conhecer Planos'),
            ),
          ],
        ),
      );
    }

    if (_staticContent == null) {
      return const Center(child: Text('Dados não encontrados.', style: TextStyle(color: Colors.white70)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: Text(
                '$_expressionNumber',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Número de Expressão',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _staticContent!.titulo,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _staticContent!.descricaoCurta,
              style: const TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _staticContent!.descricaoCompleta,
            style: const TextStyle(
                fontSize: 15, height: 1.6, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.lightbulb,
                    color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _staticContent!.inspiracao,
                    style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFFFFE082),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _staticContent!.tags
                .map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white10,
                      labelStyle: const TextStyle(color: Colors.white),
                      padding: EdgeInsets.zero,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Descubra sua compatibilidade com uma profissão específica usando I.A.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _professionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Digite uma profissão (ex: Advogado, Designer)',
            labelStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.work_outline, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _analyzeProfession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Analisar Compatibilidade'),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: _aiAnalysis != null
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: MarkdownBody(
                      data: _aiAnalysis!,
                      builders: {
                        'blockquote': MantraBuilder(),
                        'strong': MantraEmphasisBuilder(),
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white, height: 1.5),
                        h1: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                        h2: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  )
                : const Center(
                    child: FaIcon(FontAwesomeIcons.briefcase,
                        size: 48, color: Colors.white10),
                  ),
          ),
        ),
      ],
    );
  }
}

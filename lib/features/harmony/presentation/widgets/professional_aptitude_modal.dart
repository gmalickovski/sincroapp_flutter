import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/core/theme/ai_modal_theme.dart';
import 'package:sincro_app_flutter/features/strategy/services/strategy_n8n_service.dart';
import 'package:sincro_app_flutter/features/harmony/presentation/widgets/love_compatibility_modal.dart'; // Reuse MantraBuilder, MantraEmphasisBuilder
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal for analyzing profession compatibility with AI
/// Opens from the "Analisar Profissão com IA" button on the Dashboard
class ProfessionalAptitudeModal extends StatefulWidget {
  final UserModel currentUser;

  const ProfessionalAptitudeModal({super.key, required this.currentUser});

  @override
  State<ProfessionalAptitudeModal> createState() => _ProfessionalAptitudeModalState();
}

class _ProfessionalAptitudeModalState extends State<ProfessionalAptitudeModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _professionController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = false;
  String? _aiAnalysis;
  NumerologyResult? _userProfile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateNumerology();
  }

  void _calculateNumerology() {
    if (widget.currentUser.nomeAnalise.isNotEmpty && widget.currentUser.dataNasc.isNotEmpty) {
      _userProfile = NumerologyEngine(
        nomeCompleto: widget.currentUser.nomeAnalise,
        dataNascimento: widget.currentUser.dataNasc,
      ).calculateProfile();
    }
  }

  @override
  void dispose() {
    _professionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _analyzeProfession() async {
    if (_professionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite uma profissão ou área de interesse.')),
      );
      return;
    }

    // Check Plan: Sinergia Only
    if (widget.currentUser.subscription.plan != SubscriptionPlan.premium) {
      _showUpgradeDialog();
      return;
    }

    if (_userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível calcular seu perfil numerológico.')),
      );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.stars, color: Colors.cyan.shade300),
            const SizedBox(width: 12),
            const Text('Recurso Premium', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'A análise de compatibilidade profissional com IA está disponível exclusivamente para assinantes do plano Sinergia.',
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
              _openPlansPage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.shade400,
              shape: const StadiumBorder(),
            ),
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  void _openPlansPage() {
    const url = 'https://www.sincroapp.com.br/planos';
    launchUrl(Uri.parse(url));
  }

  void _resetAnalysis() {
    setState(() {
      _aiAnalysis = null;
      _professionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isDesktop) {
      return Dialog(
        backgroundColor: AppColors.cardBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: screenHeight * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildContent(context, isDesktop: true),
          ),
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              _aiAnalysis != null ? Icons.arrow_back_ios_rounded : Icons.close,
              color: Colors.white,
            ),
            onPressed: () {
              if (_aiAnalysis != null) {
                _resetAnalysis();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text('Analisar Profissão',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildContent(context, isDesktop: false),
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context, {required bool isDesktop}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Desktop Header with back button when showing result
        if (isDesktop) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Back button (left) - only when result is showing
                if (_aiAnalysis != null)
                  Positioned(
                    left: 0,
                    child: AIModalTheme.backButton(onPressed: _resetAnalysis),
                  ),
                // Centered Title + Icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology, size: 28, color: Colors.cyan.shade300),
                    const SizedBox(width: 12),
                    const Text('Analisar Profissão com IA',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                // Close button (right)
                Positioned(
                  right: 0,
                  child: AIModalTheme.closeButton(onPressed: () => Navigator.pop(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
        ],

        // Body
        _aiAnalysis != null
            ? _buildResultView()
            : _buildInputView(isDesktop),
      ],
    );
  }

  Widget _buildInputView(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Subtitle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyan.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.cyan.shade300, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Descubra se uma profissão ou área de atuação é compatível com seu perfil numerológico.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Input Field
          TextField(
            controller: _professionController,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Qual profissão você quer analisar?',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Ex: Advogado, Designer, Engenheiro...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.cyan.shade300, width: 2),
              ),
              prefixIcon: Icon(Icons.work_outline, color: Colors.cyan.shade300),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onSubmitted: (_) => _analyzeProfession(),
          ),
          
          const SizedBox(height: 24),
          
          // Helper Text
          Text(
            '💡 Dica: Você pode digitar uma profissão específica (ex: "Arquiteto") ou uma área de atuação (ex: "Tecnologia", "Saúde").',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
          
          const SizedBox(height: 32),
          
          // Analyze Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeProfession,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.psychology, size: 20),
              label: Text(_isLoading ? 'Analisando...' : 'Analisar Compatibilidade',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    // Parse score from AI analysis
    final score = _parseScoreFromAnalysis(_aiAnalysis!);
    final scoreColor = _getScoreColor(score);
    final scoreLabel = _getScoreLabel(score);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan.shade700, Colors.cyan.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.robot, size: 24, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Análise do Sincro AI',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('Profissão: ${_professionController.text}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Score Circle Section (MOVED TO TOP)
          if (score > 0) ...[
            // Score Title
            Text(
              'Score de Compatibilidade',
              style: TextStyle(color: Colors.cyan.shade300, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 24),
            
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 14,
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
                      style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: scoreColor),
                    ),
                    const Text('Compatibilidade', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Score Label
            Text(
              scoreLabel.toUpperCase(),
              style: TextStyle(color: scoreColor, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            
            const SizedBox(height: 32),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),
          ],
          
          // AI Response Text
          Align(
            alignment: Alignment.centerLeft,
            child: MarkdownBody(
              data: _aiAnalysis!,
              builders: {
                'blockquote': ProfessionalMantraBuilder(),
                'strong': NumerologyTermBuilder(),
              },
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, height: 1.6, fontSize: 15),
                h1: TextStyle(color: Colors.cyan.shade300, fontSize: 24, fontWeight: FontWeight.bold),
                h2: TextStyle(color: Colors.cyan.shade300, fontSize: 22, fontWeight: FontWeight.bold),
                h3: TextStyle(color: Colors.cyan.shade300, fontSize: 20, fontWeight: FontWeight.bold, height: 2),
                listBullet: TextStyle(color: Colors.cyan.shade300),
                blockSpacing: 20,
                // Reset blockquote decoration to let custom builder handle it
                blockquote: const TextStyle(color: Colors.transparent),
                blockquoteDecoration: const BoxDecoration(),
                blockquotePadding: EdgeInsets.zero,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetAnalysis,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nova Análise'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyan.shade300,
                    side: BorderSide(color: Colors.cyan.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
        ],
      );
  }
  

  /// Parse score percentage from AI analysis text (searches for patterns like "80%")
  int _parseScoreFromAnalysis(String text) {
    // 1. Try to find explicit "compatibilidade é de XX%" pattern
    final specificRegex = RegExp(r'compatibilidade.*?(\d{1,3})\s*%', caseSensitive: false);
    final specificMatch = specificRegex.firstMatch(text);
    if (specificMatch != null) {
      final value = int.tryParse(specificMatch.group(1)!) ?? 0;
      return value.clamp(0, 100);
    }

    // 2. Fallback: Find ALL percentage matches and use the LAST one
    // (Usually the final score is stated at the end or in the summary)
    final regex = RegExp(r'(\d{1,3})\s*%');
    final matches = regex.allMatches(text);
    if (matches.isNotEmpty) {
      // Filter out small percentages unlikely to be the score (e.g. 5%, 10% adjustments) 
      // if we have multiple. But simplest is trust the last one which is the total.
      final lastMatch = matches.last;
      final value = int.tryParse(lastMatch.group(1)!) ?? 0;
      return value.clamp(0, 100);
    }
    
    return 0;
  }
  
  /// Get color based on score
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 60) return Colors.cyan.shade300;
    if (score >= 40) return Colors.amber;
    return Colors.redAccent;
  }
  
  /// Get label based on score
  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excelente';
    if (score >= 60) return 'Bom';
    if (score >= 40) return 'Moderado';
    if (score >= 20) return 'Baixo';
    return 'Desafiador';
  }
}

/// Builder for numerology terms (e.g., "Expressão 6", "Destino 8")
/// Highlights ALL bold terms to ensure visibility
class NumerologyTermBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // Apply Amber color to ALL bold text to ensure it stands out from white body text
    return Text(
      text.text,
      style: const TextStyle(
        color: Colors.amber, 
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }
}

/// Builder for blockquotes (mantras/citations) in the professional aptitude modal
/// Uses a dark, rounded background with readable text
class ProfessionalMantraBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B21), // Very dark teal/navy background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, size: 20, color: Colors.cyan.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.cyan.shade100,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

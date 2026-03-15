// lib/features/admin/presentation/tabs/admin_ai_config_tab.dart
//
// Aba de configuração de IA no painel Admin.
// Permite escolher provedor (Groq/OpenAI), modelo, temperatura e max tokens.
// As configurações são salvas no Supabase (tabela admin_settings)
// e recarregadas ao abrir o app.

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/ai/ai_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

/// Definição de um modelo disponível para uso.
class _AiModelOption {
  final String id;
  final String displayName;
  final String badge; // Ex: "Recomendado", "Melhor custo-benefício"
  final String provider;
  final String description;

  const _AiModelOption({
    required this.id,
    required this.displayName,
    required this.badge,
    required this.provider,
    required this.description,
  });
}

class AdminAiConfigTab extends StatefulWidget {
  const AdminAiConfigTab({super.key});

  @override
  State<AdminAiConfigTab> createState() => _AdminAiConfigTabState();
}

class _AdminAiConfigTabState extends State<AdminAiConfigTab> {
  // ── Estado ──────────────────────────────────────────────────────────────
  late String _selectedProvider;
  late String _selectedModel;
  late double _temperature;
  late int _maxTokens;
  late int _maxIterations;
  bool _hasChanges = false;
  bool _isSaving = false;

  // ── Modelos disponíveis ────────────────────────────────────────────────
  static const List<_AiModelOption> _groqModels = [
    _AiModelOption(
      id: 'llama-3.3-70b-versatile',
      displayName: 'Llama 3.3 70B',
      badge: '🏆 Recomendado',
      provider: 'groq',
      description: 'Modelo mais equilibrado — excelente raciocínio e velocidade. Ideal para produção no Groq.',
    ),
    _AiModelOption(
      id: 'llama-3.1-8b-instant',
      displayName: 'Llama 3.1 8B Instant',
      badge: '💰 Mais econômico',
      provider: 'groq',
      description: 'Ultra-rápido e barato. Ideal para respostas simples. Menor qualidade em raciocínio complexo.',
    ),
    _AiModelOption(
      id: 'mixtral-8x7b-32768',
      displayName: 'Mixtral 8x7B',
      badge: 'Alternativa',
      provider: 'groq',
      description: 'Bom equilíbrio entre custo e performance. Contexto longo (32k tokens).',
    ),
  ];

  static const List<_AiModelOption> _openAiModels = [
    _AiModelOption(
      id: 'gpt-4o-mini',
      displayName: 'GPT-4o Mini',
      badge: '🏆 Melhor custo-benefício',
      provider: 'openai',
      description: 'Rápido, barato e inteligente. Ideal para a maioria dos casos. Recomendado para produção.',
    ),
    _AiModelOption(
      id: 'gpt-4o',
      displayName: 'GPT-4o',
      badge: '🧠 Mais inteligente',
      provider: 'openai',
      description: 'Modelo flagship da OpenAI. Melhor raciocínio e análise, porém mais caro (~10x o mini).',
    ),
    _AiModelOption(
      id: 'gpt-4.1-mini',
      displayName: 'GPT-4.1 Mini',
      badge: '🆕 Mais recente',
      provider: 'openai',
      description: 'Versão mais recente do modelo mini. Melhor performance em function calling e instruções longas.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    _selectedProvider = AiConfig.provider == AiProviderType.openai ? 'openai' : 'groq';
    _selectedModel = AiConfig.activeModel;
    _temperature = AiConfig.temperature;
    _maxTokens = AiConfig.maxTokens;
    _maxIterations = AiConfig.maxIterations;
  }

  List<_AiModelOption> get _currentModels =>
      _selectedProvider == 'openai' ? _openAiModels : _groqModels;

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      // Atualiza as variáveis de ambiente em runtime
      dotenv.env['AI_PROVIDER'] = _selectedProvider;
      dotenv.env['AI_TEMPERATURE'] = _temperature.toStringAsFixed(2);
      dotenv.env['AI_MAX_TOKENS'] = _maxTokens.toString();
      dotenv.env['AI_MAX_ITERATIONS'] = _maxIterations.toString();

      if (_selectedProvider == 'openai') {
        dotenv.env['OPENAI_MODEL'] = _selectedModel;
      } else {
        dotenv.env['GROQ_MODEL'] = _selectedModel;
      }

      // Persiste no Supabase
      try {
        final settingsToSave = {
          'AI_PROVIDER': _selectedProvider,
          'AI_TEMPERATURE': _temperature.toStringAsFixed(2),
          'AI_MAX_TOKENS': _maxTokens.toString(),
          'AI_MAX_ITERATIONS': _maxIterations.toString(),
          if (_selectedProvider == 'openai') 'OPENAI_MODEL': _selectedModel,
          if (_selectedProvider != 'openai') 'GROQ_MODEL': _selectedModel,
        };
        await SupabaseService().updateAdminAiSettings(settingsToSave);
      } catch (dbError) {
        debugPrint('Erro ao salvar AI Config no Supabase: $dbError');
        // Continua mesmo se der erro, pois já aplicou em memória
      }

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configurações de IA atualizadas com sucesso!'),
            backgroundColor: Color(0xff10b981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configurações de IA',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gerencie provedor, modelo e parâmetros do assistente Sincro IA',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasChanges)
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveConfig,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSaving ? 'Salvando...' : 'Salvar Alterações'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Provedor ────────────────────────────────────────────
          _buildSectionCard(
            title: 'Provedor de IA',
            icon: Icons.cloud_outlined,
            child: Row(
              children: [
                Expanded(
                  child: _buildProviderCard(
                    provider: 'groq',
                    name: 'Groq',
                    icon: Icons.flash_on,
                    description: 'Ultra-rápido (LPU). Ideal para testes e apps que priorizam velocidade.',
                    badge: '⚡ Mais rápido',
                    color: const Color(0xfff97316),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProviderCard(
                    provider: 'openai',
                    name: 'OpenAI',
                    icon: Icons.auto_awesome,
                    description: 'GPT-4o family. Melhor raciocínio e function calling. Ideal para produção.',
                    badge: '🏆 Produção',
                    color: const Color(0xff10b981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Modelo ──────────────────────────────────────────────
          _buildSectionCard(
            title: 'Modelo',
            icon: Icons.memory,
            child: Column(
              children: _currentModels.map((model) => _buildModelTile(model)).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // ── Parâmetros ──────────────────────────────────────────
          _buildSectionCard(
            title: 'Parâmetros',
            icon: Icons.tune,
            child: Column(
              children: [
                // Temperatura
                _buildSliderRow(
                  label: 'Temperatura',
                  tooltip: 'Controla a criatividade das respostas.\n'
                      '0.0 = Respostas focadas e determinísticas.\n'
                      '1.0 = Respostas criativas e variadas.',
                  value: _temperature,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  displayValue: _temperature.toStringAsFixed(2),
                  recommended: 0.7,
                  onChanged: (v) {
                    setState(() {
                      _temperature = v;
                      _markChanged();
                    });
                  },
                ),
                const Divider(color: AppColors.border, height: 32),

                // Max Tokens
                _buildSliderRow(
                  label: 'Máximo de Tokens (resposta)',
                  tooltip: 'Limita o tamanho da resposta da IA.\n'
                      '~750 tokens ≈ 1 parágrafo.\n'
                      '~1500 tokens ≈ resposta média.\n'
                      '~3000 tokens ≈ resposta longa.',
                  value: _maxTokens.toDouble(),
                  min: 500,
                  max: 4000,
                  divisions: 14,
                  displayValue: '$_maxTokens tokens',
                  recommended: 1500,
                  onChanged: (v) {
                    setState(() {
                      _maxTokens = v.round();
                      _markChanged();
                    });
                  },
                ),
                const Divider(color: AppColors.border, height: 32),

                // Max Iterations (Anti-Loop)
                _buildSliderRow(
                  label: 'Máx. Iterações de Ferramentas (Anti-Loop)',
                  tooltip: 'Quantas ferramentas a IA pode chamar por pergunta.\n'
                      'Proteção contra loops infinitos.\n'
                      '3 = Conservador (mais seguro).\n'
                      '5 = Recomendado.\n'
                      '8 = Liberado (mais risco de custo alto).',
                  value: _maxIterations.toDouble(),
                  min: 2,
                  max: 10,
                  divisions: 8,
                  displayValue: '$_maxIterations iterações',
                  recommended: 5,
                  onChanged: (v) {
                    setState(() {
                      _maxIterations = v.round();
                      _markChanged();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Info ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff1e293b),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary.withValues(alpha: 0.7), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'As alterações são aplicadas em tempo real para novas mensagens. '
                    'Para alterações permanentes entre reinicializações do app, edite o arquivo .env.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGETS HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16), // era 24 — ganho de 16dp horizontais
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.secondaryText, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // era 20
          child,
        ],
      ),
    );
  }

  Widget _buildProviderCard({
    required String provider,
    required String name,
    required IconData icon,
    required String description,
    required String badge,
    required Color color,
  }) {
    final isSelected = _selectedProvider == provider;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProvider = provider;
          _selectedModel = _currentModels.first.id;
          _markChanged();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12), // era 20 — reduz consumo horizontal
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xff1e293b),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha: ícone + nome + badge ATIVO
            // Flexible no nome evita overflow quando badge está visível
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? color : AppColors.secondaryText, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.primaryText,
                      fontSize: 16, // era 18
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ATIVO',
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Badge de categoria (ex: "⚡ Mais rápido")
            Text(badge, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            // Descrição com softWrap para quebrar corretamente
            Text(
              description,
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelTile(_AiModelOption model) {
    final isSelected = _selectedModel == model.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = model.id;
          _markChanged();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // era all(16)
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xff1e293b),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // radio alinha ao topo quando texto quebra
          children: [
            // Radio — alinhado ao topo da linha de conteúdo
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.secondaryText,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12), // era 16
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + Badge em Wrap: badge vai para próxima linha se não couber
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        model.displayName,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.primaryText,
                          fontSize: 14, // era 15
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : const Color(0xff374151),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          model.badge,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.secondaryText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.description,
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                  ),
                  // ID técnico só no desktop
                  if (MediaQuery.of(context).size.width > 800) ...[
                    const SizedBox(height: 4),
                    Text(
                      model.id,
                      style: TextStyle(
                        color: AppColors.secondaryText.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String tooltip,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required double recommended,
    required ValueChanged<double> onChanged,
  }) {
    final isRecommended = (value - recommended).abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + Badge em Row com crossAxisAlignment.start:
        // quando label quebra para 2+ linhas, badge fica alinhado ao topo (não ao centro)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label com ícone de ajuda — ocupa espaço restante
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  // Ícone de ajuda: padding top para alinhar com a primeira linha do label
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Tooltip(
                      message: tooltip,
                      child: Icon(
                        Icons.help_outline,
                        size: 14,
                        color: AppColors.secondaryText.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badge de valor — sempre no topo graças ao crossAxisAlignment.start
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isRecommended ? const Color(0xff064e3b) : const Color(0xff1e293b),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isRecommended ? const Color(0xff10b981) : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayValue,
                    style: TextStyle(
                      color: isRecommended ? const Color(0xff34d399) : AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isRecommended) ...[
                    const SizedBox(width: 4),
                    const Text('✓', style: TextStyle(color: Color(0xff34d399), fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: const Color(0xff374151),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

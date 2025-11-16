import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/services/assistant_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class AssistantInsightsCard extends StatefulWidget {
  final UserModel user;

  const AssistantInsightsCard({super.key, required this.user});

  @override
  State<AssistantInsightsCard> createState() => _AssistantInsightsCardState();
}

class _AssistantInsightsCardState extends State<AssistantInsightsCard> {
  final _fs = FirestoreService();
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadInsight();
  }

  Future<String> _loadInsight() async {
    final user = widget.user;
    NumerologyResult numerology;
    if (user.nomeAnalise.isNotEmpty && user.dataNasc.isNotEmpty) {
      numerology = NumerologyEngine(
        nomeCompleto: user.nomeAnalise,
        dataNascimento: user.dataNasc,
      ).calcular()!;
    } else {
      numerology = NumerologyEngine(
        nomeCompleto: 'Indefinido',
        dataNascimento: '01/01/1900',
      ).calcular()!;
    }

    final tasks = await _fs.getRecentTasks(user.uid, limit: 20);
    final goals = await _fs.getActiveGoals(user.uid);
    final journal =
        await _fs.getJournalEntriesForMonth(user.uid, DateTime.now());

    final ans = await AssistantService.ask(
      question:
          'Gere um insight inspirador e motivacional (2-3 frases) para o dia de hoje, usando a numerologia cabalística (Dia Pessoal ${numerology.numeros['diaPessoal']}, vibrações, energia). Seja humano e caloroso. Apenas JSON, answer curto e sem actions.',
      user: user,
      numerology: numerology,
      tasks: tasks,
      goals: goals,
      recentJournal: journal,
      chatHistory: const [],
    );

    return ans.answer.trim().isEmpty
        ? 'Seja bem-vindo(a) ao Sincro! 🌟'
        : ans.answer.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Row(
              children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(
                    child: Text('Gerando insight do dia...',
                        style: TextStyle(color: AppColors.secondaryText))),
              ],
            );
          }
          if (snapshot.hasError) {
            return const Text('Não foi possível gerar o insight hoje.',
                style: TextStyle(color: Colors.redAccent));
          }
          final text = snapshot.data ?? 'Sem insights no momento.';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primaryAccent),
                  SizedBox(width: 8),
                  Text('Insight do dia',
                      style: TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Text(text,
                  style: const TextStyle(color: AppColors.secondaryText)),
            ],
          );
        },
      ),
    );
  }
}

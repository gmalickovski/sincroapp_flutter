import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class CompatibilitySuggestionModal extends StatefulWidget {
  final DateTime targetDate;
  final String userAName;
  final DateTime userABirth;
  final String userBName;
  final DateTime userBBirth;

  const CompatibilitySuggestionModal({
    super.key,
    required this.targetDate,
    required this.userAName,
    required this.userABirth,
    required this.userBName,
    required this.userBBirth,
  });

  @override
  State<CompatibilitySuggestionModal> createState() => _CompatibilitySuggestionModalState();
}

class _CompatibilitySuggestionModalState extends State<CompatibilitySuggestionModal> {
  late double compatibilityScore;
  late List<DateTime> suggestions;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateLogic();
  }

  void _calculateLogic() async {
    // Simula pequeno delay para UX
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final score = NumerologyEngine.calculateCompatibilityScore(
      date: widget.targetDate,
      birthDateA: widget.userABirth,
      birthDateB: widget.userBBirth,
    );

    final nextDates = NumerologyEngine.findNextCompatibleDates(
      startDate: DateTime.now(),
      birthDateA: widget.userABirth,
      birthDateB: widget.userBBirth,
      limit: 3,
    );

    setState(() {
      compatibilityScore = score;
      suggestions = nextDates;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Row(
              children: [
                 const Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
                 const SizedBox(width: 12),
                 const Text(
                   'Análise Sincro',
                   style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                 ),
                 const Spacer(),
                 IconButton(
                   icon: const Icon(Icons.close, color: Colors.grey),
                   onPressed: () => Navigator.pop(context),
                 ),
              ],
            ),
            const SizedBox(height: 24),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Resultado Principal
              _buildResultCard(),
              const SizedBox(height: 24),

              // Explicação
              Text(
                'Esta data é favorável para ${compatibilityScore > 0.9 ? 'ambos!' : (compatibilityScore > 0.4 ? 'um de vocês.' : 'nenhum de vocês.')}',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              
              if (compatibilityScore < 0.9) ...[
                const SizedBox(height: 24),
                const Text(
                  'Melhores datas para ambos:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...suggestions.map((d) => _buildSuggestionTile(d)),
              ]
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    Color color;
    String label;
    IconData icon;

    if (compatibilityScore > 0.9) {
      color = Colors.greenAccent;
      label = 'Sinergia Total';
      icon = Icons.check_circle;
    } else if (compatibilityScore > 0.4) {
      color = Colors.amberAccent;
      label = 'Sinergia Parcial';
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.redAccent;
      label = 'Baixa Sinergia';
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd/MM/yyyy').format(widget.targetDate),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(DateTime date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xff1f2937),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.pop(context, date), // Retorna a data escolhida
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd/MM/yyyy (EEE)', 'pt_BR').format(date),
                  style: const TextStyle(color: Colors.white),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

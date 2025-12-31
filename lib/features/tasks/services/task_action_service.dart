import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class TaskActionService {
  final SupabaseService _supabaseService = SupabaseService();

  /// Reagenda uma tarefa para o próximo dia lógico, baseando-se em 3 cenários:
  /// 1. Sem data: Define para Amanhã.
  /// 2. Atrasada (Data < Hoje): Define para Hoje.
  /// 3. Futura ou Hoje (Data >= Hoje): Define para (Data Atual da Tarefa + 1 Dia).
  ///
  /// Retorna a nova data definida ou null em caso de erro.
  Future<DateTime?> rescheduleTask(
    BuildContext context,
    TaskModel task,
    UserModel userData,
  ) async {
    try {
      final now = DateTime.now().toLocal();
      final today = DateTime(now.year, now.month, now.day);
      
      DateTime targetDate;
      String message;

      if (task.dueDate == null) {
        // Cenário 1: Sem data -> Vai para Amanhã
        targetDate = today.add(const Duration(days: 1));
        message = 'Agendada para amanhã! 📅';
      } else {
        final taskDateLocal = task.dueDate!.toLocal();
        final taskDateOnly = DateTime(taskDateLocal.year, taskDateLocal.month, taskDateLocal.day);

        if (taskDateOnly.isBefore(today)) {
          // Cenário 3: Atrasada -> Vai para Hoje
          targetDate = today;
          message = 'Trazida para hoje! 🚀';
        } else {
          // Cenário 2: Hoje ou Futuro -> Vai para o dia seguinte da data atual da tarefa
          targetDate = taskDateOnly.add(const Duration(days: 1));
          message = 'Adiada para ${targetDate.day}/${targetDate.month}! 🗓️';
        }
      }

      // Calcula o novo Dia Pessoal
      int? newPersonalDay;
      if (userData.nomeAnalise.isNotEmpty && userData.dataNasc.isNotEmpty) {
        final engine = NumerologyEngine(
          nomeCompleto: userData.nomeAnalise,
          dataNascimento: userData.dataNasc,
        );
        // O cálculo do dia pessoal exige data em UTC (meia-noite)
        final targetDateUtc = DateTime.utc(targetDate.year, targetDate.month, targetDate.day);
        try {
          final day = engine.calculatePersonalDayForDate(targetDateUtc);
          if (day > 0) newPersonalDay = day;
        } catch (e) {
          debugPrint('Erro ao calcular dia pessoal no reschedule: $e');
        }
      }

      // Prepara os campos para atualização
      final updates = <String, dynamic>{
        // Usa .toUtc() para preservar o instante exato da meia-noite local
        // Isso evita que a data volte um dia ao ser convertida de volta para local em fusos negativos (ex: Brasil)
        'dueDate': targetDate.toUtc(),
      };
      
      // Atualiza o personalDay se foi calculado (ou remove se não conseguiu)
      if (newPersonalDay != null) {
        updates['personalDay'] = newPersonalDay;
      } else {
        updates['personalDay'] = null;
      }

      // Executa a atualização
      await _supabaseService.updateTaskFields(
        userData.uid,
        task.id,
        updates,
      );

      // Feedback visual
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return targetDate;
    } catch (e) {
      debugPrint("Erro ao reagendar tarefa (Service): $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reagendar tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}

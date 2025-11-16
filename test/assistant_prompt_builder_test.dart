import 'package:flutter_test/flutter_test.dart';
import 'package:sincro_app_flutter/features/assistant/services/assistant_prompt_builder.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';

void main() {
  group('AssistantPromptBuilder.build', () {
    test('includes personalDaysNext30 and scheduling guidance', () {
      final user = UserModel(
        uid: 'u1',
        email: 'x@example.com',
        primeiroNome: 'Fulano',
        sobrenome: 'Silva',
        nomeAnalise: 'Fulano da Silva',
        dataNasc: '01/01/1990',
        plano: 'gratuito',
        isAdmin: false,
        dashboardCardOrder: const [],
        dashboardHiddenCards: const [],
        subscription: SubscriptionModel.free(),
      );

      final numerology = NumerologyEngine(
        nomeCompleto: user.nomeAnalise,
        dataNascimento: user.dataNasc,
      ).calcular()!;

      final prompt = AssistantPromptBuilder.build(
        question: 'Agendar reunião 12/11 às 14h',
        user: user,
        numerology: numerology,
        tasks: const <TaskModel>[],
        goals: const <Goal>[],
        recentJournal: const <JournalEntry>[],
        chatHistory: const [],
        isFirstMessageOfDay: false,
      );

      // Deve conter a lista de dias pessoais futuros
      expect(prompt.contains('personalDaysNext30'), isTrue);
      // Deve conter o fluxo de agendamento com alternativa sugerida
      expect(prompt.contains('FLUXO PARA AGENDAMENTOS'), isTrue);
      expect(prompt.contains('DUAS actions "schedule"'), isTrue);
      // Instrução de JSON-only
      expect(prompt.contains('Sempre retorne SOMENTE o JSON'), isTrue);
    });
  });
}

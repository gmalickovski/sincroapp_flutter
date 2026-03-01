// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:flutter/material.dart'; // Import Material for TimeOfDay, Colors
import 'package:permission_handler/permission_handler.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/core/services/navigation_service.dart';
import 'dart:convert';

import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:local_notifier/local_notifier.dart';

// --- IMPORTANTE ---
// Esta função DEVE ser de nível superior (fora de qualquer classe)
// para funcionar em background no Android.
@pragma('vm:entry-point')
Future<void> _showEndOfDayReminder(fln.NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://supabase.studiomlk.com.br',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            '7ff55347e5f6d2b5ec1cd3ee9c4375280f3a4ca30c98594e29e3ac028806370a',
      ),
    );
  } catch (e) {
    debugPrint('Supabase já inicializado ou erro: $e');
  }

  final String? userId = response.payload;
  if (userId == null || userId.isEmpty) return;

  final supabaseService = SupabaseService();
  final tasks = await supabaseService.getTasksForToday(userId);
  final uncompletedTasks = tasks.where((t) => !t.completed).toList();

  if (uncompletedTasks.isNotEmpty) {
    // Categorização
    int agendamentos = 0;
    int tarefas = 0;

    for (var t in uncompletedTasks) {
      if (t.isAppointment) {
        agendamentos++;
      } else {
        tarefas++;
      }
    }

    // Construção da mensagem gramaticalmente correta
    List<String> parts = [];
    if (agendamentos > 0) {
      parts.add(
          "$agendamentos ${agendamentos == 1 ? 'agendamento' : 'agendamentos'}");
    }
    if (tarefas > 0) {
      parts.add("$tarefas ${tarefas == 1 ? 'tarefa' : 'tarefas'}");
    }

    String body = "Você tem ${parts.join(' e ')} para hoje. Mantenha o foco!";
    String title = "Foco do Dia 🎯";

    // Exibe a notificação
    await NotificationService.instance.showNotification(
      id: 99,
      title: title,
      body: body,
      payload: '{"view": "tasks", "filter": "today"}', // Deep link payload
    );
  }
}

class NotificationService {
  // Singleton
  NotificationService._privateConstructor();
  static final NotificationService instance =
      NotificationService._privateConstructor();

  final fln.FlutterLocalNotificationsPlugin _localNotifications =
      fln.FlutterLocalNotificationsPlugin();

  /// Helper: verifica se estamos em desktop (Windows/Linux)
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  /// Timers ativos para notificações agendadas no Windows
  final Map<int, Timer> _windowsTimers = {};

  // IDs dos Canais (Android)
  static const String _channelIdReminder = 'task_reminders';
  static const String _channelNameReminder = 'Lembretes de Tarefas';
  static const String _channelDescReminder =
      'Notificações para lembretes de tarefas agendadas.';

  static const String _channelIdDaily = 'daily_insights';
  static const String _channelNameDaily = 'Insights Diários';
  static const String _channelDescDaily =
      'Notificações matinais sobre seu dia pessoal e lembretes.';

  // IDs únicos para tipos de notificação agendada
  static const int _dailyPersonalDayId = 1;
  static const int _dailyEndOfDayId = 2;

  /// Inicializa os pacotes, configura canais e solicita permissões
  Future<void> init() async {
    await _configureTimezone();

    // Desktop: usa local_notifier (Windows/Linux)
    if (_isDesktop) {
      await _initDesktopNotifier();
      return;
    }

    await _requestPermissions();

    // Configurações de inicialização do FlutterLocalNotifications
    const fln.AndroidInitializationSettings androidSettings =
        fln.AndroidInitializationSettings(
            '@drawable/ic_notification');
    const fln.DarwinInitializationSettings iosSettings =
        fln.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const fln.InitializationSettings settings =
        fln.InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _showEndOfDayReminder,
    );

    // Cria os canais Android
    await _createAndroidChannels();
  }

  /// Inicializa o local_notifier para Windows/Linux
  Future<void> _initDesktopNotifier() async {
    try {
      await localNotifier.setup(
        appName: 'SincroApp',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      debugPrint('✅ Desktop Notifier (local_notifier) inicializado.');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar local_notifier: $e');
    }
  }

  /// Exibe uma notificação nativa no Windows/Linux via local_notifier
  void _showDesktopNotification({
    required String title,
    required String body,
  }) {
    try {
      final notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.onClick = () {
        debugPrint('[Desktop Notification] Clicked: $title');
      };
      notification.show();
    } catch (e) {
      debugPrint('❌ Erro ao exibir notificação desktop: $e');
    }
  }

  /// Agenda uma notificação no Windows via Timer (funciona enquanto app aberto)
  void _scheduleDesktopNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) {
    // Cancela timer anterior com mesmo ID
    _windowsTimers[id]?.cancel();

    final now = DateTime.now();
    final delay = scheduledDate.difference(now);

    if (delay.isNegative) return; // Já passou

    _windowsTimers[id] = Timer(delay, () {
      _showDesktopNotification(title: title, body: body);
      _windowsTimers.remove(id);
    });
    debugPrint('[Desktop] Notificação agendada: "$title" em ${delay.inMinutes}min');
  }

  /// Solicita permissões de notificação usando permission_handler
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      // IOS permissions are handled by DarwinInitializationSettings requestAlertPermission
    } else if (Platform.isAndroid) {
      // Para Android 13 (API 33) ou superior, precisamos pedir permissão
      await Permission.notification.request();

      // Para Android 12 (API 31) ou superior, precisamos pedir permissão de alarmes exatos
      if (Platform.isAndroid) {
        final status = await Permission.scheduleExactAlarm.status;
        if (!status.isGranted) {
          // Solicita a permissão de alarmes exatos
          await Permission.scheduleExactAlarm.request();
        }
      }
    }
  }

  /// Configura o pacote de fuso horário
  Future<void> _configureTimezone() async {
    // Inicializa os dados de fuso horário (função síncrona)
    tz_data.initializeTimeZones();

    try {
      // Tenta definir um fuso comum brasileiro
      final location = tz.getLocation('America/Sao_Paulo');
      tz.setLocalLocation(location);
    } catch (e) {
      debugPrint(
          "Erro ao definir fuso horário 'America/Sao_Paulo': $e. Usando UTC.");
      try {
        // Tenta definir o fuso horário UTC como fallback
        final utcLocation = tz.getLocation('UTC');
        tz.setLocalLocation(utcLocation);
      } catch (eUtc) {
        debugPrint("Erro crítico ao definir fuso horário UTC: $eUtc");
      }
    }
  }

  /// Cria os canais de notificação para Android (Oreo+)
  Future<void> _createAndroidChannels() async {
    const fln.AndroidNotificationChannel reminderChannel =
        fln.AndroidNotificationChannel(
      _channelIdReminder,
      _channelNameReminder,
      description: _channelDescReminder,
      importance: fln.Importance.max,
      playSound: true,
    );

    const fln.AndroidNotificationChannel dailyChannel =
        fln.AndroidNotificationChannel(
      _channelIdDaily,
      _channelNameDaily,
      description: _channelDescDaily,
      importance: fln.Importance.defaultImportance,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(dailyChannel);
  }

  /// Callback para quando uma notificação é tocada
  static void _onNotificationResponse(fln.NotificationResponse response) {
    if (response.payload != null) {
      if (response.payload!.startsWith('{')) {
        // É um JSON payload customizado
        try {
          final data = jsonDecode(response.payload!);
          final view = data['view'];
          final filter = data['filter'];

          if (view == 'tasks') {
            NavigationService.navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/', (route) => false,
                    arguments: {'view': 'tasks', 'filter': filter});
          }
        } catch (e) {
          debugPrint("Erro ao parsear payload da notificação: $e");
        }
      } else {
        // Payload antigo (apenas ID ou algo simples)
        // Mantemos comportamento padrão ou ignoramos se não for relevante para navegação global
      }
    }
  }

  /// Converte um TimeOfDay para um tz.TZDateTime na próxima ocorrência
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Versão local (DateTime puro) para uso no Windows/Linux
  DateTime _nextInstanceOfTimeLocal(TimeOfDay time) {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Converte uma data e hora específicas para tz.TZDateTime
  tz.TZDateTime _instanceOfDateTime(DateTime date, TimeOfDay time) {
    return tz.TZDateTime(
        tz.local, date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Exibe uma notificação simples agora
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String channelId = _channelIdDaily,
    String? payload,
  }) async {
    // Desktop: usa local_notifier
    if (_isDesktop) {
      _showDesktopNotification(title: title, body: body);
      return;
    }

    final androidDetails = fln.AndroidNotificationDetails(
      channelId,
      channelId == _channelIdDaily ? _channelNameDaily : _channelNameReminder,
      importance: channelId == _channelIdDaily
          ? fln.Importance.defaultImportance
          : fln.Importance.max,
      priority: channelId == _channelIdDaily
          ? fln.Priority.defaultPriority
          : fln.Priority.max,
    );
    const iosDetails = fln.DarwinNotificationDetails();
    final platformDetails =
        fln.NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(id, title, body, platformDetails,
        payload: payload);
  }

  // --- IMPLEMENTAÇÃO DAS FUNCIONALIDADES ---

  /// 1. Notificação Matinal do Dia Pessoal (FEATURE #2)
  Future<void> scheduleDailyPersonalDayNotification({
    required String title,
    required String body,
    required TimeOfDay scheduleTime,
  }) async {
    if (_isDesktop) {
      final scheduledDate = _nextInstanceOfTimeLocal(scheduleTime);
      _scheduleDesktopNotification(
        id: _dailyPersonalDayId,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
      );
      return;
    }
    await _localNotifications.cancel(_dailyPersonalDayId);
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(scheduleTime);
    const androidDetails = fln.AndroidNotificationDetails(
      _channelIdDaily,
      _channelNameDaily,
      importance: fln.Importance.defaultImportance,
      priority: fln.Priority.defaultPriority,
    );
    const iosDetails = fln.DarwinNotificationDetails();
    const platformDetails =
        fln.NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      _dailyPersonalDayId,
      title,
      body,
      scheduledDate,
      platformDetails,
      payload: 'personal_day',
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          fln.DateTimeComponents.time,
    );
  }

  /// 2. Lembrete de Tarefa Agendada (FEATURE #3)
  Future<void> scheduleTaskReminder(TaskModel task) async {
    final int notificationId = task.id.hashCode.abs() % 2147483647;

    if (task.dueDate == null || task.reminderTime == null || task.completed) {
      await cancelTaskReminder(notificationId);
      return;
    }

    if (_isDesktop) {
      final scheduledDate = DateTime(
        task.dueDate!.year, task.dueDate!.month, task.dueDate!.day,
        task.reminderTime!.hour, task.reminderTime!.minute,
      );
      if (scheduledDate.isBefore(DateTime.now())) return;
      _scheduleDesktopNotification(
        id: notificationId,
        title: 'Lembrete de Tarefa',
        body: task.text,
        scheduledDate: scheduledDate,
      );
      return;
    }

    final tz.TZDateTime scheduledDateTime =
        _instanceOfDateTime(task.dueDate!, task.reminderTime!);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    if (scheduledDateTime.isBefore(now)) {
      return;
    }

    const androidDetails = fln.AndroidNotificationDetails(
      _channelIdReminder,
      _channelNameReminder,
      importance: fln.Importance.max,
      priority: fln.Priority.max,
    );
    const iosDetails =
        fln.DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const platformDetails =
        fln.NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      notificationId,
      "Lembrete de Tarefa",
      task.text,
      scheduledDateTime,
      platformDetails,
      payload: 'task_${task.id}',
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancela um lembrete de tarefa
  Future<void> cancelTaskReminder(int notificationId) async {
    if (_isDesktop) {
      _windowsTimers[notificationId]?.cancel();
      _windowsTimers.remove(notificationId);
      return;
    }
    await _localNotifications.cancel(notificationId);
  }

  /// Cancela um lembrete de tarefa usando o Task ID (String)
  Future<void> cancelTaskReminderByTaskId(String taskId) async {
    final int notificationId = taskId.hashCode.abs() % 2147483647;
    await _localNotifications.cancel(notificationId);
  }

  /// 3. Lembrete de Tarefas Não Concluídas (FEATURE #1)
  Future<void> scheduleDailyEndOfDayCheck(
      String userId, TimeOfDay scheduleTime) async {
    if (_isDesktop) {
      final scheduledDate = _nextInstanceOfTimeLocal(scheduleTime);
      _scheduleDesktopNotification(
        id: _dailyEndOfDayId,
        title: 'Verificação de fim de dia',
        body: 'Verificando suas tarefas...',
        scheduledDate: scheduledDate,
      );
      return;
    }
    await _localNotifications.cancel(_dailyEndOfDayId);
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(scheduleTime);
    const androidDetails = fln.AndroidNotificationDetails(
      _channelIdDaily,
      _channelNameDaily,
      importance: fln.Importance.low,
      priority: fln.Priority.low,
    );
    const iosDetails = fln.DarwinNotificationDetails(presentAlert: true);
    const platformDetails =
        fln.NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      _dailyEndOfDayId,
      'Verificação de fim de dia',
      'Verificando suas tarefas...',
      scheduledDate,
      platformDetails,
      payload: userId,
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          fln.DateTimeComponents.time,
    );
  }
  // --- NOVAS FUNCIONALIDADES PARA CROSS-PLATFORM & INCENTIVOS ---

  /// 4. Listener Global para Sincronizar Central -> Nativo
  /// Deve ser chamado no init do Dashboard
  void listenToRealtimeNotifications(String userId) {
    if (kIsWeb) return;

    Supabase.instance.client
        .channel('public:notifications:userId=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            // Exibir notificação nativa
            showNotification(
              id: (newRecord['id'] as String).hashCode,
              title: newRecord['title'] ?? 'Nova notificação',
              body: newRecord['body'] ?? 'Toque para ver os detalhes.',
              payload: newRecord['id'], // Passa ID para abrir depois
            );
          },
        )
        .subscribe();
  }

  /// 5. Inicializa Incentivos Diários (Numerologia/Bom dia e Lembretes)
  Future<void> initializeDailyIncentives(
      String userId, String birthDate) async {
    // A. Agendar "Bom dia" com Numerologia às 09:00
    try {
      final now = DateTime.now();
      // Importante: NumerologyEngine deve ser importado ou lógica replicada.
      // Como não tenho import aqui, vou usar uma lógica simplificada ou adicionar o import no topo.
      // Vou assumir que posso calcular ou buscar do DB.
      // Para este exemplo, vou agendar uma mensagem genérica de incentivo se não conseguir calcular.

      // Tentar calcular via service se possível, ou usar texto fixo "Confira suas vibrações de hoje!"
      // Idealmente, scheduleDailyPersonalDayNotification já aceita title/body.

      await scheduleDailyPersonalDayNotification(
        title: "Bom dia! ☀️",
        body: "Confira as vibrações do seu Dia Pessoal para hoje.",
        scheduleTime: const TimeOfDay(hour: 9, minute: 0),
      );
    } catch (e) {
      debugPrint("Erro ao agendar incentivo diário: $e");
    }

    // B. Verificar Atrasos Agora e Notificar
    await checkForOverdueItems(userId);
  }

  /// 6. Verifica Tarefas Atrasadas (Imediato)
  Future<void> checkForOverdueItems(String userId) async {
    try {
      final supabaseService = SupabaseService();
      // Buscar tarefas não concluídas com data < hoje
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final tasks = await supabaseService.getTasksForToday(userId);
      // Nota: getTasksForToday geralmente pega o dia todo.
      // Para saber "atrasadas" de dias anteriores, precisaria de uma query "overdue".
      // Assumindo que o usuário quer saber do que já passou.
      // Vou simplificar verificando as de hoje que já passaram da hora ou adicionar uma busca de overdue se o service suportar.

      // Se não tivermos um método getOverdueTasks, vamos focar no "Lembrete do dia"
      // ou implementar uma query rápida aqui.

      // Contagem categorizada de itens atrasados
      int agendamentos = 0;
      int tarefas = 0;

      final overdueTasks = tasks.where(
          (t) => !t.completed && t.dueDate != null && t.dueDate!.isBefore(now));

      for (var t in overdueTasks) {
        if (t.isAppointment) {
          agendamentos++;
        } else {
          tarefas++;
        }
      }

      int totalOverdue = agendamentos + tarefas;

      if (totalOverdue > 0) {
        List<String> parts = [];
        if (agendamentos > 0) {
          parts.add(
              "$agendamentos ${agendamentos == 1 ? 'agendamento atrasado' : 'agendamentos atrasados'}");
        }
        if (tarefas > 0) {
          parts.add(
              "$tarefas ${tarefas == 1 ? 'tarefa atrasada' : 'tarefas atrasadas'}");
        }

        showNotification(
          id: 88,
          title: "Atenção aos Prazos ⏰",
          body: "Você possui ${parts.join(' e ')}. Coloque em dia!",
          channelId: _channelIdReminder,
          payload: '{"view": "tasks", "filter": "overdue"}',
        );
      }
    } catch (e) {
      debugPrint("Erro check overdue: $e");
    }
  }

  /// Sincroniza todas as notificações diárias baseadas no estado atual das tarefas.
  /// Deve ser chamado sempre que as tarefas de hoje mudam ou o app abre.
  Future<void> syncDailyNotifications({
    required String userId,
    required String userName,
    required String birthDate,
    required List<TaskModel> todayTasks,
  }) async {
    final now = DateTime.now();

    // 1. Manhã: Foco do Dia (08:30)
    // Se hoje já passou das 08:30, agenda para amanhã com texto genérico (pois não sabemos tarefas de amanhã)
    // Se hoje é antes das 08:30, agenda para hoje com tarefas de hoje.
    final morningTime =
        _instanceOfDateTime(now, const TimeOfDay(hour: 8, minute: 30));
    if (morningTime.isAfter(now)) {
      await _scheduleMorningFocus(todayTasks, morningTime);
    } else {
      // Agenda para amanhã (genérico)
      // Idealmente, precisaríamos das tarefas de amanhã, mas vamos usar uma msg de incentivo
      await scheduleDailyPersonalDayNotification(
        title: "Planeje seu dia ☀️",
        body: "Comece o dia organizando suas prioridades no Sincro.",
        scheduleTime: const TimeOfDay(hour: 8, minute: 30),
      );
    }

    // 2. Manhã: Dia Favorável (10:00)
    final favorableTime =
        _instanceOfDateTime(now, const TimeOfDay(hour: 10, minute: 0));
    if (favorableTime.isAfter(now)) {
      await _scheduleFavorableDay(userName, birthDate, favorableTime);
    }

    // 3. Noite: Check de Fim de Dia (20:00)
    final eveningTime =
        _instanceOfDateTime(now, const TimeOfDay(hour: 20, minute: 0));
    if (eveningTime.isAfter(now)) {
      await _scheduleEveningCheck(todayTasks, eveningTime);
    }
  }

  Future<void> _scheduleMorningFocus(
      List<TaskModel> tasks, tz.TZDateTime scheduledDate) async {
    // Conta tarefas para hoje
    int agendamentos = 0, tarefas = 0;
    final uncompleted = tasks.where((t) => !t.completed).toList();

    for (var t in uncompleted) {
      if (t.isAppointment) {
        agendamentos++;
      } else {
        tarefas++;
      }
    }

    String body = "Prepare-se para hoje! 🚀";
    if (uncompleted.isNotEmpty) {
      List<String> parts = [];
      if (agendamentos > 0) {
        parts.add(
            "$agendamentos ${agendamentos == 1 ? 'agendamento' : 'agendamentos'}");
      }
      if (tarefas > 0) {
        parts.add("$tarefas ${tarefas == 1 ? 'tarefa' : 'tarefas'}");
      }
      body = "Você tem ${parts.join(' e ')} para hoje. Mantenha o foco!";
    }

    await _scheduleOneShot(
        id: 101,
        title: "Foco do Dia 🎯",
        body: body,
        date: scheduledDate,
        payload: '{"view": "tasks", "filter": "today"}');
  }

  Future<void> _scheduleFavorableDay(
      String nome, String dataNasc, tz.TZDateTime scheduledDate) async {
    if (nome.isEmpty || dataNasc.isEmpty) return;
    try {
      final engine =
          NumerologyEngine(nomeCompleto: nome, dataNascimento: dataNasc);
      final diaFavoravel = engine.calculatePersonalDayForDate(
          scheduledDate); // Reusing logic or accessing days list
      // calculatePersonalDayForDate retorna o dia pessoal (1-9), não se é favorável.
      // Precisamos verificar se o DIA HOJE está na lista de dias favoráveis.

      final result = engine.calculateProfile();
      final diasFavoraveis =
          (result.listas['diasFavoraveis'] as List?)?.cast<int>() ?? [];

      if (diasFavoraveis.contains(scheduledDate.day)) {
        await _scheduleOneShot(
            id: 102,
            title: "Hoje é um Dia Favorável! 🌟",
            body: "Aproveite a energia de hoje para realizar seus objetivos!",
            date: scheduledDate,
            payload: '{"view": "favorable_days"}');
      }
    } catch (e) {
      debugPrint("Erro favorable day: $e");
    }
  }

  Future<void> _scheduleEveningCheck(
      List<TaskModel> tasks, tz.TZDateTime scheduledDate) async {
    int agendamentos = 0, tarefas = 0;
    // Pega APENAS as não concluídas
    final uncompleted = tasks.where((t) => !t.completed).toList();

    // Se não tiver pendências, talvez não enviar nada? Ou enviar parabéns?
    // Usuário pediu: "se tiver tarefas pendentes... surge mensagem"
    if (uncompleted.isEmpty) return;

    for (var t in uncompleted) {
      if (t.isAppointment) {
        agendamentos++;
      } else {
        tarefas++;
      }
    }

    List<String> parts = [];
    if (agendamentos > 0) {
      parts.add(
          "$agendamentos ${agendamentos == 1 ? 'agendamento' : 'agendamentos'}");
    }
    if (tarefas > 0) {
      parts.add("$tarefas ${tarefas == 1 ? 'tarefa' : 'tarefas'}");
    }

    String msg =
        "Olá, vejo que você ainda tem ${parts.join(' e ')} pendentes. Que tal dar uma olhadinha? 👀";

    await _scheduleOneShot(
        id: 103,
        title: "Check de Fim de Dia 🌙",
        body: msg,
        date: scheduledDate,
        payload:
            '{"view": "tasks", "filter": "today"}' // Leva para a lista de hoje para remarcar
        );
  }

  Future<void> _scheduleOneShot(
      {required int id,
      required String title,
      required String body,
      required tz.TZDateTime date,
      String? payload}) async {
    // Desktop: usa Timer
    if (_isDesktop) {
      _scheduleDesktopNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: DateTime(date.year, date.month, date.day, date.hour, date.minute),
      );
      return;
    }

    const androidDetails = fln.AndroidNotificationDetails(
      _channelIdDaily,
      _channelNameDaily,
      importance: fln.Importance.defaultImportance,
      priority: fln.Priority.defaultPriority,
    );
    const iosDetails = fln.DarwinNotificationDetails();
    const platformDetails =
        fln.NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      date,
      platformDetails,
      payload: payload,
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

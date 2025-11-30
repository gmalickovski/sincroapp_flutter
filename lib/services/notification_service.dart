// lib/services/notification_service.dart
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:permission_handler/permission_handler.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/firebase_options.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:flutter/material.dart'; // Para TimeOfDay

// Importa os DADOS de fuso horário (do arquivo 'latest.dart') com um apelido ÚNICO
import 'package:timezone/data/latest.dart' as tz_data;
// Importa as FUNÇÕES de fuso horário (do arquivo 'timezone.dart') com outro apelido ÚNICO
import 'package:timezone/timezone.dart' as tz;

// --- IMPORTANTE ---
// Esta função DEVE ser de nível superior (fora de qualquer classe)
// para funcionar em background no Android.
@pragma('vm:entry-point')
Future<void> _showEndOfDayReminder(fln.NotificationResponse response) async {
  // Precisamos inicializar o Firebase aqui para acesso em background
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final String? userId = response.payload;
  if (userId == null || userId.isEmpty) return;

  final firestoreService = FirestoreService();
  final tasks = await firestoreService.getTasksForToday(userId);
  final uncompletedCount = tasks.where((t) => !t.completed).length;

  if (uncompletedCount > 0) {
    String title = "Você tem $uncompletedCount tarefas pendentes";
    String body = "Não se esqueça de concluir seu foco do dia!";
    if (uncompletedCount == 1) {
      title = "Você tem 1 tarefa pendente";
      body = "Não se esqueça de concluir seu foco do dia!";
    }

    // Exibe a notificação final com a contagem
    await NotificationService.instance.showNotification(
      id: 99, // ID diferente para a notificação de resultado
      title: title,
      body: body,
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
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

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
    await _requestPermissions();

    // Configurações de inicialização do FlutterLocalNotifications
    const fln.AndroidInitializationSettings androidSettings =
        fln.AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Usando o ícone padrão do app
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

    // Inicializa o Firebase Messaging
    await _fcm.requestPermission();
  }

  /// Solicita permissões de notificação usando permission_handler
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
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

    const fln.AndroidNotificationChannel dailyChannel = fln.AndroidNotificationChannel(
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
    // Handle notification tap
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
      matchDateTimeComponents: fln.DateTimeComponents.time, // Repete diariamente
    );
  }

  /// 2. Lembrete de Tarefa Agendada (FEATURE #3)
  Future<void> scheduleTaskReminder(TaskModel task) async {
    final int notificationId = task.id.hashCode.abs() % 2147483647;

    if (task.dueDate == null || task.reminderTime == null || task.completed) {
      await cancelTaskReminder(notificationId);
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
      matchDateTimeComponents: fln.DateTimeComponents.time, // Repete diariamente
    );
  }
}

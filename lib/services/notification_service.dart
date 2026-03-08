// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:flutter/material.dart'; // Import Material for TimeOfDay, Colors
import 'package:permission_handler/permission_handler.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:sincro_app_flutter/features/notifications/presentation/widgets/notification_detail_modal.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/features/settings/presentation/settings_screen.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/core/services/navigation_service.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:local_notifier/local_notifier.dart';

// --- ARQUITETURA DE NOTIFICAÇÕES (V2) ---
// O Aplicativo é agora um Receptor Passivo.
// Ele não "agenda" (schedule) nativamente nenhum alarme futuro ou lembrete.
// Tudo é orquestrado via Node.js Server disparando pelo Firebase Cloud Messaging (FCM).


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
    );

    // Cria os canais Android
    await _createAndroidChannels();

    // Inicia ouvintes do Firebase Cloud Messaging (Push Notifications Reais)
    _setupFirebaseMessaging();
  }

  /// Adiciona ouvintes para FCM (App Aberto) e gerencia toques no push nativo
  void _setupFirebaseMessaging() {
    if (kIsWeb || _isDesktop) return;

    // Quando o app está totalmente fechado e você clica na notificação do Android:
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("Push FCM clicado com o app morto: ${message.data}");
        _handlePushNotificationTap(message.data);
      }
    });

    // Quando o app está aberto na tela (Foreground) e chega push FCM
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Exibe nossa local_notification para mostrar na barra mesmo com o app aberto
        showNotification(
          id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title: message.notification!.title ?? 'Sincro',
          body: message.notification!.body ?? '',
          payload: jsonEncode(message.data),
        );
      }
    });

    // Quando o app tá rodando minimizado (em background) e você clica na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Push FCM clicado no background: ${message.data}");
      _handlePushNotificationTap(message.data);
    });
  }

  /// Trata o toque em uma notificação push: rota baseada no tipo
  Future<void> _handlePushNotificationTap(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final notificationId = data['notificationId'] as String?;

    // Task reminders → abrir foco do dia com filtro de atrasadas
    if (type == 'TASK_REMINDER' || type == 'reminder') {
      _navigateToOverdueTasks();
      return;
    }

    // Para outros tipos, abrir modal de detalhes da notificação
    if (notificationId == null || notificationId.isEmpty) return;

    try {
      final notification = await SupabaseService().getNotificationById(notificationId);
      if (notification == null) return;

      // Marcar como lida
      await SupabaseService().markNotificationAsRead(notificationId);

      // Abrir modal flutuante de detalhes
      _openNotificationDetailModal(notification);
    } catch (e) {
      debugPrint('❌ Erro ao abrir notificação push: $e');
    }
  }

  /// Abre o NotificationDetailModal usando o NavigatorKey global
  void _openNotificationDetailModal(NotificationModel notification) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationDetailModal(notification: notification),
    );
  }

  /// Navega para FocoDoDia com filtro de tarefas atrasadas
  void _navigateToOverdueTasks() {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
      arguments: {'view': 'tasks', 'filter': 'overdue'},
    );
  }

  /// Navega para Settings → About tab
  void _navigateToSettingsAbout() {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;

    // Get current user data for settings screen
    final userId = AuthRepository().currentUser?.id;
    if (userId == null) return;

    SupabaseService().getUserData(userId).then((userData) {
      if (userData == null) return;
      final ctx = NavigationService.navigatorKey.currentContext;
      if (ctx == null) return;

      final isDesktop = MediaQuery.of(ctx).size.width >= 720;
      if (isDesktop) {
        showDialog(
          context: ctx,
          builder: (context) => SettingsScreen(userData: userData, initialTab: 5),
        );
      } else {
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (context) => SettingsScreen(userData: userData, initialTab: 5),
          ),
        );
      }
    }).catchError((e) {
      debugPrint('❌ Erro ao navegar para Settings About: $e');
    });
  }

  /// Verifica se há atualização disponível do app (1x por dia)
  Future<void> checkForAppUpdate() async {
    if (kIsWeb) return;

    try {
      final latestVersion = await SupabaseService().getLatestAppVersion();
      if (latestVersion == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (currentVersion != latestVersion) {
        debugPrint('📦 Atualização disponível: $currentVersion → $latestVersion');
        showNotification(
          id: 999999,
          title: '🔄 Atualização Disponível',
          body: 'Uma nova versão do Sincro App ($latestVersion) está disponível.',
          payload: jsonEncode({'view': 'settings_about'}),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar atualização do app: $e');
    }
  }

  /// Salva o Token do Firebase no Supabase para podermos enviar push pra esse celular
  Future<void> saveDeviceFCMToken(String userId) async {
    if (kIsWeb || _isDesktop) return;

    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client.schema('sincroapp').from('user_push_tokens').upsert({
          'user_id': userId,
          'fcm_token': token,
          'platform': Platform.operatingSystem,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'fcm_token');
        debugPrint("FCM Token Salvo com Sucesso!");
      }
    } catch (e) {
      debugPrint("Erro ao salvar FCM Token no Supabase: $e");
    }
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

  /// Callback para quando uma notificação local é tocada
  static void _onNotificationResponse(fln.NotificationResponse response) {
    if (response.payload != null) {
      if (response.payload!.startsWith('{')) {
        // É um JSON payload customizado
        try {
          final data = jsonDecode(response.payload!);
          final view = data['view'];
          final filter = data['filter'];
          final type = data['type'];
          final notificationId = data['notificationId'];

          // Task reminder → navegar para tarefas atrasadas
          if (type == 'TASK_REMINDER' || type == 'reminder') {
            NotificationService.instance._navigateToOverdueTasks();
            return;
          }

          // Settings about (app update notification)
          if (view == 'settings_about') {
            NotificationService.instance._navigateToSettingsAbout();
            return;
          }

          // Se tiver notificationId, abre o modal de detalhes da notificação
          if (notificationId != null && notificationId.toString().isNotEmpty) {
            NotificationService.instance._handlePushNotificationTap(
              Map<String, dynamic>.from(data),
            );
            return;
          }

          if (view == 'tasks') {
            NavigationService.navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/', (route) => false,
                    arguments: {'view': 'tasks', 'filter': filter});
          }
        } catch (e) {
          debugPrint("Erro ao parsear payload da notificação: $e");
        }
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

  // --- IMPLEMENTAÇÃO DAS FUNCIONALIDADES DE CANCELAMENTO ---

  /// Cancela um lembrete de tarefa ativo localmente (mantido para fallback se houver notificações antigas instaladas)
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
    final int baseId = taskId.hashCode.abs() % 2147483647;
    final int overdueId = (taskId.hashCode.abs() + 100000) % 2147483647;
    await cancelTaskReminder(baseId);
    await cancelTaskReminder(overdueId);
  }

  // Nota: Todas as funcões de "scheduleX" foram removidas.
  // O app agora depende inteiramente de receber pushes Firebase originados no Servidor NodeJS.
  // --- LISTENER GLOBAL (PAINEL IN-APP) ---

  /// 4. Listener Global para Sincronizar Central -> Nativo
  /// Observa a tabela `notifications` apenas para garantir que as telas do App
  /// reajam à novidades (como alterar o contador de não lidas), mas NÃO 
  /// chama `showNotification` pra poluir o Android/iOS.
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
            // O app recebe em tempo real o aviso que houve um INSERT na tabela.
            // Para atualizar o badget de notificações in-app, podemos usar Controllers
            // ou Provider. Mas removemos o `showNotification` nativo para 
            // confiar exclusivamente no Backend (NodeJS via FCM).
            debugPrint("Nova notificação para Painel In-App recebida em tempo real: \${payload.newRecord['title']}");
          },
        )
        .subscribe();
  }

}

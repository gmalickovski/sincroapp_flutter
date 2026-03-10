// lib/main.dart
import 'dart:async';
import 'dart:ui'; // For PointerDeviceKind
import 'dart:io'; // For Platform check
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 Import dotenv
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart'; // 🚀 Import Workmanager
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/login/login_screen.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/user_details/user_details_screen.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sincro_app_flutter/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Restore Supabase import
import 'package:sincro_app_flutter/services/supabase_service.dart'; // Restore Service import
import 'package:sincro_app_flutter/core/theme/app_theme.dart';
import 'package:sincro_app_flutter/core/services/navigation_service.dart'; // 🚀 Navigation Service
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: \${message.messageId}");
}

// ... other imports

// --- WORKMANAGER CALLBACK (Must be top-level or static) ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 1. Initialize Flutter Bindings
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Initialize Supabase (Hardcoded for background reliability or pass via inputData if possible)
    // Using hardcoded fallback ensures it works even if .env fails in isolate
    try {
      await Supabase.initialize(
        url: 'https://supabase.studiomlk.com.br',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY3MTYzMTYyLCJleHAiOjIwODI1MjMxNjIsInJlZiI6InNpbmNyb2FwcF9hbm9uIn0.fxAcgzxGZe3ybA1-Ocu2AhvlNPuM2-ysE05IAcgfBaA',
      );
    } catch (e) {
      debugPrint(
          'Workmanager: Supabase init error (might be already init): $e');
    }

    // 3. Perform Background Check
    // We need the User ID. Since we can't easily access Auth State in background isolate without persisting it securely to SharedPrefs or SecureStorage and reading it here.
    // For now, we will assume we can check general updates or if inputs provided userId.
    // NOTE: In a real "Robust" app, you'd save UserId to SharedPreferences and read it here.
    // implemented below as a simulated check or strictly for timed notifications.

    try {
      await NotificationService.instance.init();
      
      // Restaura a sessão do Supabase (supabase_flutter cuida do SharedPreferences por padrão)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final prefs = await SharedPreferences.getInstance();
        final lastResetStr = prefs.getString('lastFocusResetDate');
        final now = DateTime.now();
        // String de hoje
        final todayStr = "${now.year}-${now.month}-${now.day}";

        if (lastResetStr != todayStr) {
           final userId = session.user.id;
           try {
             await Supabase.instance.client
                .schema('sincroapp')
                .from('tasks')
                .update({'is_focus': false})
                .eq('user_id', userId)
                .eq('is_focus', true);
             
             await prefs.setString('lastFocusResetDate', todayStr);
             debugPrint("Workmanager: Foco do dia resetado com sucesso para o usuário $userId");
           } catch (dbError) {
             debugPrint("Workmanager: Falha ao resetar foo do dia: $dbError");
           }
        }
      }

      debugPrint("Workmanager: Background Sync Executed!");

      // Verifica se há atualização disponível do app
      await NotificationService.instance.checkForAppUpdate();
    } catch (e) {
      debugPrint("Workmanager: Output error: $e");
    }

    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o Firebase (necessário para o Push Notification FCM funcionar)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permission (mostly impacts iOS, but good practice)
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar Firebase: $e');
    }
  }

  // 🚀 Carrega o arquivo .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('⚠️ Erro ao carregar .env: $e');
  }

  // Window Manager Setup (Desktop)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility:
          false, // We will draw our own buttons or use window_manager's caption
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize Workmanager
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      Workmanager().initialize(callbackDispatcher,
          isInDebugMode: kDebugMode // Set to false in production
          );
      // Register Periodic Task (15 min minimum on Android)
      Workmanager().registerPeriodicTask(
        "1",
        "simplePeriodicTask",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Workmanager init failed: $e');
    }
  }

  // ========================================
  // INICIALIZAÇÃO SUPABASE (USANDO .ENV)
  // ========================================
  // 1. Definição das chaves (Hardcoded para garantir funcionamento em Prod se .env falhar)
  const String kSupabaseUrl = 'https://supabase.studiomlk.com.br';
  const String kSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY3MTYzMTYyLCJleHAiOjIwODI1MjMxNjIsInJlZiI6InNpbmNyb2FwcF9hbm9uIn0.fxAcgzxGZe3ybA1-Ocu2AhvlNPuM2-ysE05IAcgfBaA';

  try {
    // Tenta pegar do .env carregado anteriormente, se disponível
    final envUrl = dotenv.env['SUPABASE_URL'];
    final envKey = dotenv.env['ANON_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];

    // Usa env variables se existirem e não forem vazias, senão usa as constantes
    final String finalUrl =
        (envUrl != null && envUrl.isNotEmpty) ? envUrl : kSupabaseUrl;
    final String finalKey =
        (envKey != null && envKey.isNotEmpty) ? envKey : kSupabaseAnonKey;

    await Supabase.initialize(
      url: finalUrl,
      anonKey: finalKey,
    );
    debugPrint('🚀 Supabase inicializado com sucesso! ($finalUrl)');
  } catch (e) {
    debugPrint('❌ Erro principal na inicialização do Supabase: $e');
    // Tentativa final desesperada com constantes puras se a lógica acima falhou
    try {
      await Supabase.initialize(
        url: kSupabaseUrl,
        anonKey: kSupabaseAnonKey,
      );
      debugPrint('✅ Supabase inicializado via Failover Hardcoded.');
    } catch (e2) {
      debugPrint('💀 Falha catastrófica ao inicializar Supabase: $e2');
    }
  }

  // Inicializa notificações sem Firebase
  if (!kIsWeb) {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('❌ Erro ao inicializar Notification Service: $e');
    }
  }

  // ========================================
  // CARREGA CONFIGURAÇÕES DA IA DO SUPABASE
  // ========================================
  try {
    final aiSettings = await SupabaseService().getAdminAiSettings();
    if (aiSettings.isNotEmpty) {
      aiSettings.forEach((key, value) {
        dotenv.env[key] = value.toString();
      });
      debugPrint('🧠 AI Config carregada do Supabase com sucesso ($aiSettings).');
    } else {
      debugPrint('🧠 Nenhuma configuração de IA customizada encontrada no Supabase. Usando .env padrão.');
    }
  } catch (e) {
    debugPrint('⚠️ Não foi possível carregar AI Config do Supabase: $e');
  }

  runApp(const SincroApp());
}

class SincroApp extends StatelessWidget {
  const SincroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: const SincroGlobalScrollBehavior(),
      navigatorKey: NavigationService.navigatorKey,
      title: 'SincroApp',
      debugShowCheckedModeBanner: false,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      navigatorObservers: [
        NavigationService.routeObserver,
      ],
      theme: AppTheme.darkTheme,
      home: const AuthCheck(),
      builder: (context, child) {
        return child ?? const SizedBox();
      },
    );
  }
}

class SincroGlobalScrollBehavior extends MaterialScrollBehavior {
  const SincroGlobalScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad, // Fix for Windows touchpad scroll
        PointerDeviceKind.unknown,
      };
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  late final StreamSubscription<User?> _authSubscription;
  final AuthRepository _authRepository = AuthRepository();
  User? _user;
  bool _isLoading = true;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
          _hasNavigated = false; // Reset ao mudar usuário
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // Remove _navigateToScreen as we will build the screen directly

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    if (_isLoading) {
      return const Scaffold(
        key: ValueKey('loading'),
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_user == null) {
      return const LoginScreen(key: ValueKey('login'));
    }

    return FutureBuilder<UserModel?>(
      key: ValueKey(_user!.id),
      future: supabaseService.getUserData(_user!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            key: ValueKey('loading-user'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }
        if (snapshot.hasError) {
          return const DashboardScreen(key: ValueKey('dashboard-error'));
        }

        final userModel = snapshot.data;
        if (userModel == null) {
          return UserDetailsScreen(key: const ValueKey('user-details-null'), user: _user!);
        }

        final String nomeAnalise = (userModel.nomeAnalise).trim();
        final String dataNasc = (userModel.dataNasc).trim();
        final bool dataValida =
            RegExp(r'^\d{2}/\d{2}/\d{4} ?$').hasMatch(dataNasc) ||
                RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dataNasc);

        if (nomeAnalise.isEmpty || dataNasc.isEmpty || !dataValida) {
          return UserDetailsScreen(key: const ValueKey('user-details-invalid'), user: _user!);
        }

        return const DashboardScreen(key: ValueKey('dashboard'));
      },
    );
  }
}

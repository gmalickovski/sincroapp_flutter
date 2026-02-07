// lib/main.dart
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 Import dotenv
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:intl/date_symbol_data_local.dart';

import 'package:sincro_app_flutter/services/notification_service.dart';
import 'package:sincro_app_flutter/services/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Restore Supabase import
import 'package:sincro_app_flutter/services/supabase_service.dart'; // Restore Service import
import 'package:sincro_app_flutter/core/theme/app_theme.dart';
import 'package:sincro_app_flutter/core/services/navigation_service.dart'; // 🚀 Navigation Service
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
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY3MTYzMTYyLCJleHAiOjIwODI1MjMxNjIsInJlZiI6InNpbmNyb2FwcF9hbm9uIn0.fxAcgzxGZe3ybA1-Ocu2AhvlNPuM2-ysE05IAcgfBaA',
      );
    } catch (e) {
      debugPrint('Workmanager: Supabase init error (might be already init): $e');
    }

    // 3. Perform Background Check
    // We need the User ID. Since we can't easily access Auth State in background isolate without persisting it securely to SharedPrefs or SecureStorage and reading it here.
    // For now, we will assume we can check general updates or if inputs provided userId.
    // NOTE: In a real "Robust" app, you'd save UserId to SharedPreferences and read it here.
    // implemented below as a simulated check or strictly for timed notifications.
    
    try {
      await NotificationService.instance.init();
      // Example: Check for unread notifications if we had the User ID
      // For now, let's just log or perform a simple "Alive" check.
      // Ideally: 
      // final prefs = await SharedPreferences.getInstance();
      // final userId = prefs.getString('userId');
      // if (userId != null) await NotificationService.instance.checkForUnread(userId);
      
      debugPrint("Workmanager: Background Sync Executed!");
    } catch (e) {
      debugPrint("Workmanager: Output error: $e");
    }

    return Future.value(true);
  });
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // 🚀 Carrega o arquivo .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('⚠️ Erro ao carregar .env: $e');
  }
  
  // Initialize Workmanager
  if (!kIsWeb) {
    try {
      Workmanager().initialize(
        callbackDispatcher, 
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


  // ========================================
  // INICIALIZAÇÃO SUPABASE (USANDO .ENV)
  // ========================================
  try {
    // Tenta pegar do .env
    final envUrl = dotenv.env['SUPABASE_URL'];
    final envKey = dotenv.env['ANON_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY']; // Tenta os dois nomes

    // debugPrint('🔍 DEBUG ENV: URL found? ${envUrl != null}');
    // debugPrint('🔍 DEBUG ENV: KEY found? ${envKey != null}');
    // if (envKey != null) debugPrint('🔍 DEBUG KEY Start: ${envKey.substring(0, 10)}...');
    
    // Fallback
    final fallbackUrl = const String.fromEnvironment('SUPABASE_URL');
    final fallbackKey = const String.fromEnvironment('SUPABASE_ANON_KEY'); 
    
    final finalUrl = envUrl ?? fallbackUrl;
    // Hardcoded fallback for SAFETY if all else fails (Localhost Dev)
    final finalKey = envKey ?? (fallbackKey.isNotEmpty ? fallbackKey : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY3MTYzMTYyLCJleHAiOjIwODI1MjMxNjIsInJlZiI6InNpbmNyb2FwcF9hbm9uIn0.fxAcgzxGZe3ybA1-Ocu2AhvlNPuM2-ysE05IAcgfBaA');

    // debugPrint('🚀 Initializing Supabase with:');
    // debugPrint('   URL: $finalUrl');
    // debugPrint('   KEY: ${finalKey.substring(0, 10)}... (Length: ${finalKey.length})');

    await Supabase.initialize(
      url: finalUrl.isNotEmpty ? finalUrl : 'https://supabase.studiomlk.com.br', 
      anonKey: finalKey,
    );
    // debugPrint('🚀 Supabase inicializado com sucesso usando .env!');
  } catch (e) {
    debugPrint('❌ Erro ao inicializar Supabase: $e');
  }

  // Inicializa notificações sem Firebase
  if (!kIsWeb) {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('❌ Erro ao inicializar Notification Service: $e');
    }
  }

  runApp(const SincroApp());
}

class SincroApp extends StatelessWidget {
  const SincroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      navigatorObservers: [
        NavigationService.routeObserver,
      ],
      theme: AppTheme.darkTheme,
      home: const AuthCheck(),
    );
  }
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

  void _navigateToScreen(Widget screen, String screenName) {
    if (_hasNavigated) {
      return;
    }

    _hasNavigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => screen),
        );
      }
    });
  }

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
          _navigateToScreen(const DashboardScreen(), 'DashboardScreen (error)');
          return const Scaffold(
            key: ValueKey('navigating'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }

        final userModel = snapshot.data;
        if (userModel == null) {
          _navigateToScreen(
            UserDetailsScreen(user: _user!),
            'UserDetailsScreen (null)',
          );
          return const Scaffold(
            key: ValueKey('navigating'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }

        final String nomeAnalise = (userModel.nomeAnalise).trim();
        final String dataNasc = (userModel.dataNasc).trim();
        final bool dataValida =
            RegExp(r'^\d{2}/\d{2}/\d{4} ?$').hasMatch(dataNasc) ||
                RegExp(r'^\d{2}/\d{2}/\d{4}$')
                    .hasMatch(dataNasc); 

        if (nomeAnalise.isEmpty || dataNasc.isEmpty || !dataValida) {
          _navigateToScreen(
            UserDetailsScreen(user: _user!),
            'UserDetailsScreen (missing-or-invalid)',
          );
          return const Scaffold(
            key: ValueKey('navigating'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }

        _navigateToScreen(const DashboardScreen(), 'DashboardScreen');

        return const Scaffold(
          key: ValueKey('navigating'),
          backgroundColor: AppColors.background,
          body: Center(
            child: CustomLoadingSpinner(),
          ),
        );
      },
    );
  }
}

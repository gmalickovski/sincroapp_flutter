// lib/main.dart
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 Import dotenv
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

// --- INÍCIO DAS NOVAS IMPORTAÇÕES ---
import 'package:sincro_app_flutter/services/notification_service.dart';
import 'package:sincro_app_flutter/services/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import completo (User vem daqui)
import 'package:sincro_app_flutter/services/supabase_service.dart';
// --- FIM DAS NOVAS IMPORTAÇÕES ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // 🚀 Carrega o arquivo .env
  try {
    await dotenv.load(fileName: ".env");
    // debugPrint('📄 Arquivo .env carregado com sucesso.');
  } catch (e) {
    debugPrint('⚠️ Erro ao carregar .env: $e');
  }

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryAccent,
        fontFamily: 'Poppins',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textTheme: const TextTheme().apply(
          bodyColor: AppColors.primaryText,
          displayColor: AppColors.primaryText,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAccent,
            foregroundColor: AppColors.primaryText,
            shape: const StadiumBorder(),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF2a2141),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            color: AppColors.primaryText,
            fontFamily: 'Poppins',
            fontSize: 16,
          ),
          elevation: 4,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          space: 1,
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.primary),
          titleTextStyle: TextStyle(
            color: AppColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ),
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

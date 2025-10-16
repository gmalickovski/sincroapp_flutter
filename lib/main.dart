// lib/main.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sincro_app_flutter/firebase_options.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/login/login_screen.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/user_details/user_details_screen.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SincroApp());
}

class SincroApp extends StatelessWidget {
  const SincroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SincroApp',
      debugShowCheckedModeBanner: false,
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
        fontFamily: 'Inter',

        // ATUALIZAÇÃO DE UI/UX: Remove o efeito de splash/highlight globalmente
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
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF2a2141),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            color: AppColors.primaryText,
            fontFamily: 'Inter',
            fontSize: 16,
          ),
          elevation: 4,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          space: 1,
          thickness: 1,
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
  // ... (código do AuthCheck sem alterações)
  late final StreamSubscription<User?> _authSubscription;
  final AuthRepository _authRepository = AuthRepository();
  User? _firebaseUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()));
    }
    if (_firebaseUser != null) {
      return FutureBuilder<UserModel?>(
        future: firestoreService.getUserData(_firebaseUser!.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(child: CircularProgressIndicator()));
          }
          if (userSnapshot.hasData &&
              userSnapshot.data != null &&
              userSnapshot.data!.nomeAnalise.isNotEmpty) {
            return const DashboardScreen();
          }
          return UserDetailsScreen(firebaseUser: _firebaseUser!);
        },
      );
    }
    return const LoginScreen();
  }
}

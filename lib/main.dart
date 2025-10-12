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

// --- ALTERAÇÃO 1: Adicione esta importação ---
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- ALTERAÇÃO 2: Adicione esta linha para inicializar a localização ---
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryAccent,
        fontFamily: 'Inter',
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
      ),
      home: const AuthCheck(),
      debugShowCheckedModeBanner:
          false, // Adicionado para remover o banner de debug
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
  User? _firebaseUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      if (mounted) {
        // Garante que o widget ainda está na árvore
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_firebaseUser != null) {
      return FutureBuilder<UserModel?>(
        future: firestoreService.getUserData(_firebaseUser!.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          // Se o utilizador tem dados no Firestore, vai para o Dashboard
          if (userSnapshot.hasData &&
              userSnapshot.data != null &&
              userSnapshot.data!.nomeAnalise.isNotEmpty) {
            return const DashboardScreen();
          }
          // Caso contrário, vai para a tela de preenchimento de dados
          return UserDetailsScreen(firebaseUser: _firebaseUser!);
        },
      );
    }

    // Se não há utilizador, vai para o Login
    return const LoginScreen();
  }
}

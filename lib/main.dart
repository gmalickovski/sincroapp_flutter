import 'dart:async'; // Importar para usar o StreamSubscription
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    );
  }
}

// 1. Convertido para StatefulWidget
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
    // 2. Ouvimos o stream de autenticação e atualizamos o estado
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      setState(() {
        _firebaseUser = user;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    // 3. Cancelamos a subscrição para evitar fugas de memória
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    // Enquanto o estado inicial de autenticação está a ser verificado
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Se o utilizador está logado
    if (_firebaseUser != null) {
      // Usamos o FutureBuilder como antes para verificar os dados no Firestore
      return FutureBuilder<UserModel?>(
        future: firestoreService.getUserData(_firebaseUser!.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (userSnapshot.hasData && userSnapshot.data != null) {
            return const DashboardScreen();
          }
          return UserDetailsScreen(firebaseUser: _firebaseUser!);
        },
      );
    }

    // Se o utilizador não está logado
    return const LoginScreen();
  }
}

// lib/app/routs/app_router.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:sincro_app_flutter/features/authentication/presentation/login/login_screen.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/register/register_screen.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/user_details/user_details_screen.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:sincro_app_flutter/features/subscription/presentation/subscription_screen.dart';
import 'package:sincro_app_flutter/features/subscription/presentation/thank_you_screen.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String userDetails = '/user-details';
  static const String dashboard = '/dashboard';
  static const String subscription = '/subscription';
  static const String thankYou = '/thank-you';
}

class AppRouter {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.dashboard: (_) => const DashboardScreen(),
        AppRoutes.thankYou: (_) => const ThankYouScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.userDetails:
        final args = settings.arguments;
        if (args is User) {
          return MaterialPageRoute(
            builder: (_) => UserDetailsScreen(firebaseUser: args),
            settings: settings,
          );
        }
        // Suporta também Map com chave 'user' para flexibilidade
        if (args is Map && args['user'] is User) {
          return MaterialPageRoute(
            builder: (_) =>
                UserDetailsScreen(firebaseUser: args['user'] as User),
            settings: settings,
          );
        }
        return _unknown(settings,
            reason: 'Argumento inválido para /user-details');
      case AppRoutes.subscription:
        final args = settings.arguments;
        if (args is Map && args['user'] is UserModel) {
          return MaterialPageRoute(
            builder: (_) => SubscriptionScreen(user: args['user'] as UserModel),
            settings: settings,
          );
        }
        return _unknown(settings,
            reason:
                'Argumentos inválidos para /subscription (esperado: {user: UserModel})');
      default:
        return null; // deixa para routes/unknownRoute tratarem
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _unknown(settings, reason: 'Rota não registrada');
  }

  static Route<dynamic> _unknown(RouteSettings settings, {String? reason}) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Rota não encontrada')),
        body: Center(
          child: Text(
              'Nenhum gerador para a rota "${settings.name}". ${reason ?? ''}'),
        ),
      ),
      settings: settings,
    );
  }
}

// lib/services/payment_service.dart
// ignore_for_file: todo

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/common/constants/stripe_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço centralizado de pagamentos com Stripe
class PaymentService {
  final SupabaseService _supabaseService = SupabaseService();

  /// Inicializa o Stripe (deve ser chamado no main ou splash)
  static Future<void> initialize() async {
    // TODO: Substituir pela sua Publishable Key do Stripe
    Stripe.publishableKey = 'pk_test_51SYoC3PxUnpVpxqmeShfUQCAev2DIsGD2X4JMJLJHGMF6nXXzIoN3orUh9ptYZgQTV6nAOHpOVv9k5a9IpFV0xUh0007i5ifDi'; 
    if (!kIsWeb) {
      await Stripe.instance.applySettings();
    }
  }

  /// Retorna o Link de Pagamento baseado no plano e ciclo
  String? getPaymentLink(SubscriptionPlan plan, BillingCycle cycle) {
    if (plan == SubscriptionPlan.plus) { // Desperta
      return cycle == BillingCycle.monthly 
          ? StripeConstants.linkDespertaMonthly 
          : StripeConstants.linkDespertaAnnual;
    } else if (plan == SubscriptionPlan.premium) { // Sinergia
      return cycle == BillingCycle.monthly 
          ? StripeConstants.linkSinergiaMonthly 
          : StripeConstants.linkSinergiaAnnual;
    }
    return null;
  }

  /// Verifica status da assinatura atual
  Future<SubscriptionModel> getSubscriptionStatus(String userId) async {
    final userData = await _supabaseService.getUserData(userId);
    return userData?.subscription ?? SubscriptionModel.free();
  }

  Future<void> openCustomerPortal() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Usuário não autenticado';

      const returnUrl = 'https://sincroapp.com.br'; 
      // Use local server or production URL
      const String baseUrl = kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
      final url = Uri.parse('$baseUrl/api/stripe/portal-session');

      debugPrint('SincroApp: Solicitando portal: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user.id,
          'email': user.email,
          'returnUrl': returnUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final portalUrl = data['url'] as String;
        
        // Abre a URL no navegador
        final uri = Uri.parse(portalUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri, 
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_self',
          );
        } else {
          throw 'Não foi possível abrir a URL: $portalUrl';
        }
        debugPrint('Portal URL: $portalUrl');
      } else {
         throw 'Erro ao abrir portal (${response.statusCode}): ${response.body}';
      }

    } catch (e) {
      debugPrint('Erro ao abrir portal: $e');
      rethrow;
    }
  }

  /// Abre o Link de Pagamento no navegador
  Future<void> launchPaymentLink(SubscriptionPlan plan, BillingCycle cycle, String userId) async {
    final url = getPaymentLink(plan, cycle);
    if (url != null) {
      // Adiciona client_reference_id para identificar o usuário no webhook
      // Verifica se a URL já tem query params (Links do Stripe geralmente não têm, mas por garantia)
      final separator = url.contains('?') ? '&' : '?';
      final finalUrl = '$url${separator}client_reference_id=$userId';

      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );
      } else {
        throw 'Não foi possível abrir a URL: $url';
      }
    } else {
      throw 'Link de pagamento não encontrado para este plano.';
    }
  }
}

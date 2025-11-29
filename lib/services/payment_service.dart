// lib/services/payment_service.dart
// ignore_for_file: todo

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sincro_app_flutter/common/constants/stripe_constants.dart';

/// Serviço centralizado de pagamentos com Stripe
class PaymentService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Inicializa o Stripe (deve ser chamado no main ou splash)
  static Future<void> initialize() async {
    // TODO: Substituir pela sua Publishable Key do Stripe
    Stripe.publishableKey = 'pk_test_51SYoC3PxUnpVpxqmeShfUQCAev2DIsGD2X4JMJLJHGMF6nXXzIoN3orUh9ptYZgQTV6nAOHpOVv9k5a9IpFV0xUh0007i5ifDi'; 
    await Stripe.instance.applySettings();
  }

  /// Inicia processo de assinatura via Stripe
  Future<bool> purchaseSubscription({
    required String userId,
    required SubscriptionPlan plan,
    BillingCycle cycle = BillingCycle.monthly,
  }) async {
    if (plan == SubscriptionPlan.free) {
      throw ArgumentError('Plano free não requer compra');
    }

    try {
      // 1. Determinar o Price ID correto
      final priceId = _getPriceId(plan, cycle);
      if (priceId == null) {
        throw UnimplementedError('Plano/Ciclo não configurado no StripeConstants');
      }

      // 2. Criar Assinatura no backend (retorna clientSecret do PaymentIntent da fatura)
      final paymentData = await _createSubscription(
        priceId: priceId,
      );

      // 3. Inicializar Payment Sheet
      if (paymentData['clientSecret'] == null) {
        debugPrint('Client Secret é nulo. Assinatura pode não requerer pagamento imediato ou falhou.');
        // Se não houver clientSecret, talvez seja um trial ou erro. 
        // Por enquanto, vamos retornar true se houver subscriptionId, assumindo sucesso sem pagamento imediato.
        if (paymentData['subscriptionId'] != null) {
             return true;
        }
        throw Exception('Falha ao obter segredo de pagamento do Stripe.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          customFlow: false,
          merchantDisplayName: 'Sincro App',
          paymentIntentClientSecret: paymentData['clientSecret'],
          customerEphemeralKeySecret: paymentData['ephemeralKey'],
          customerId: paymentData['customer'],
          style: ThemeMode.system,
        ),
      );

      // 4. Apresentar Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 5. Sucesso!
      debugPrint('Assinatura realizada com sucesso!');
      return true;

    } on StripeException catch (e) {
      debugPrint('Erro do Stripe: ${e.error.localizedMessage}');
      if (e.error.code == FailureCode.Canceled) {
        return false; // Usuário cancelou
      }
      rethrow;
    } catch (e) {
      debugPrint('Erro ao processar assinatura: $e');
      rethrow;
    }
  }

  /// Retorna o Price ID baseado no plano e ciclo
  String? _getPriceId(SubscriptionPlan plan, BillingCycle cycle) {
    if (plan == SubscriptionPlan.plus) { // Desperta
      return cycle == BillingCycle.monthly 
          ? StripeConstants.priceDespertaMonthly 
          : StripeConstants.priceDespertaAnnual;
    } else if (plan == SubscriptionPlan.premium) { // Sinergia
      return cycle == BillingCycle.monthly 
          ? StripeConstants.priceSinergiaMonthly 
          : StripeConstants.priceSinergiaAnnual;
    }
    return null;
  }

  /// Cria Subscription via Firebase Function
  Future<Map<String, dynamic>> _createSubscription({
    required String priceId,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createSubscription');
      
      final result = await callable.call<Map<String, dynamic>>({
        'priceId': priceId,
      });

      return result.data;
    } catch (e) {
      debugPrint('Erro ao chamar createSubscription: $e');
      rethrow;
    }
  }

  /// Verifica status da assinatura atual
  Future<SubscriptionModel> getSubscriptionStatus(String userId) async {
    final userData = await _firestoreService.getUserData(userId);
    return userData?.subscription ?? SubscriptionModel.free();
  }

  Future<void> openCustomerPortal() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createPortalSession');
      
      // Define a URL de retorno baseada na plataforma
      // Para mobile, idealmente seria um Deep Link (ex: sincroapp://profile)
      // Por enquanto, vamos usar o site oficial como fallback
      const returnUrl = 'https://sincroapp.com.br'; 

      final result = await callable.call({
        'returnUrl': returnUrl,
      });

      final url = result.data['url'] as String;
      
      // Abre a URL no navegador
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );
      } else {
        throw 'Não foi possível abrir a URL: $url';
      }
      debugPrint('Portal URL: $url');
    } catch (e) {
      debugPrint('Erro ao abrir portal: $e');
      rethrow;
    }
  }
}

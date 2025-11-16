# 🔐 Guia Completo de Configuração de Pagamentos

## 📋 Visão Geral

Este documento detalha como configurar pagamentos multiplataforma para o Sincro App usando:
- **Web**: PagBank (gateway brasileiro)
- **iOS**: Apple In-App Purchase
- **Android**: Google Play Billing

---

## 🌐 PARTE 1: Web - PagBank

### 1.1 Configuração da Conta PagBank

#### Passo 1: Habilitar API PagBank
1. Acesse https://pagseguro.uol.com.br
2. Faça login com sua conta (CPF já cadastrado)
3. Vá em **Integrações** > **Credenciais de Produção**
4. Anote seu **Token de Produção**

#### Passo 2: Configurar Ambiente de Testes (Sandbox)
1. Acesse https://sandbox.pagseguro.uol.com.br
2. Crie credenciais de teste
3. Anote **Email** e **Token de Sandbox**

#### Passo 3: Criar Produtos/Planos no PagBank
```
Plano Desperta:
- Nome: Sincro Desperta
- Valor: R$ 19,90/mês
- Recorrência: Mensal
- ID: sincro_desperta_monthly

Plano Sinergia:
- Nome: Sincro Sinergia
- Valor: R$ 39,90/mês
- Recorrência: Mensal
- ID: sincro_sinergia_monthly
```

### 1.2 Configuração Firebase Functions

Crie arquivo `functions/pagbank.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Configurar credenciais PagBank (usar Firebase Config ou Secrets)
const PAGBANK_TOKEN = functions.config().pagbank.token;
const PAGBANK_EMAIL = functions.config().pagbank.email;
const PAGBANK_SANDBOX = functions.config().pagbank.sandbox === 'true';

const PAGBANK_API = PAGBANK_SANDBOX 
  ? 'https://ws.sandbox.pagseguro.uol.com.br'
  : 'https://ws.pagseguro.uol.com.br';

/**
 * Cria sessão de checkout no PagBank
 */
exports.createPagBankCheckout = functions.https.onCall(async (data, context) => {
  // Verificar autenticação
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado');
  }

  const { userId, plan, productId, price } = data;

  try {
    // Criar checkout session no PagBank
    const response = await axios.post(
      `${PAGBANK_API}/v2/checkout`,
      {
        email: PAGBANK_EMAIL,
        token: PAGBANK_TOKEN,
        currency: 'BRL',
        itemId1: productId,
        itemDescription1: `Assinatura ${plan}`,
        itemAmount1: price.toFixed(2),
        itemQuantity1: 1,
        reference: userId, // Identificar usuário
        redirectURL: `https://seuapp.com/payment/callback`,
        notificationURL: `https://us-central1-SEU_PROJECT.cloudfunctions.net/pagbankWebhook`,
      }
    );

    const checkoutCode = response.data.code;
    const checkoutUrl = PAGBANK_SANDBOX
      ? `https://sandbox.pagseguro.uol.com.br/v2/checkout/payment.html?code=${checkoutCode}`
      : `https://pagseguro.uol.com.br/v2/checkout/payment.html?code=${checkoutCode}`;

    return { checkoutUrl, checkoutCode };
  } catch (error) {
    console.error('Erro ao criar checkout PagBank:', error);
    throw new functions.https.HttpsError('internal', 'Erro ao processar pagamento');
  }
});

/**
 * Webhook para notificações do PagBank
 */
exports.pagbankWebhook = functions.https.onRequest(async (req, res) => {
  const notificationCode = req.body.notificationCode;

  try {
    // Buscar detalhes da transação
    const response = await axios.get(
      `${PAGBANK_API}/v3/transactions/notifications/${notificationCode}`,
      {
        params: {
          email: PAGBANK_EMAIL,
          token: PAGBANK_TOKEN,
        }
      }
    );

    const transaction = response.data.transaction;
    const userId = transaction.reference; // ID do usuário
    const status = transaction.status;

    // Status do PagBank:
    // 1: Aguardando pagamento
    // 2: Em análise
    // 3: Paga
    // 4: Disponível
    // 5: Em disputa
    // 6: Devolvida
    // 7: Cancelada

    if (status === 3 || status === 4) {
      // Pagamento confirmado - ativar assinatura
      await admin.firestore().collection('users').doc(userId).update({
        'subscription.isActive': true,
        'subscription.plan': transaction.items[0].id.includes('sinergia') 
          ? 'sinergia' 
          : 'desperta',
        'subscription.startDate': admin.firestore.Timestamp.now(),
        'subscription.endDate': admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // +30 dias
        ),
        'subscription.paymentMethod': 'pagbank',
        'subscription.transactionId': transaction.code,
      });

      console.log(`Assinatura ativada para usuário ${userId}`);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Erro ao processar webhook PagBank:', error);
    res.status(500).send('Error');
  }
});
```

### 1.3 Configurar Secrets no Firebase

```bash
# Definir credenciais PagBank
firebase functions:config:set \
  pagbank.token="SEU_TOKEN_PRODUCAO" \
  pagbank.email="SEU_EMAIL_PAGSEGURO" \
  pagbank.sandbox="false"

# Para ambiente de testes, use:
firebase functions:config:set \
  pagbank.token="SEU_TOKEN_SANDBOX" \
  pagbank.sandbox="true"

# Deploy das functions
firebase deploy --only functions
```

---

## 📱 PARTE 2: iOS - Apple In-App Purchase

### 2.1 Configuração App Store Connect

#### Passo 1: Criar App no App Store Connect
1. Acesse https://appstoreconnect.apple.com
2. Crie novo app ou selecione existente
3. Anote o **Bundle ID** (ex: `com.seuapp.sincro`)

#### Passo 2: Criar Produtos de Assinatura
1. Em **App Store Connect** > **Seu App** > **Assinaturas**
2. Criar **Grupo de Assinatura**: "Sincro Premium"
3. Adicionar produtos:

```
Produto 1:
- ID: sincro_desperta_monthly
- Tipo: Auto-renewable subscription
- Duração: 1 mês
- Preço: R$ 19,90 (Tier 10)

Produto 2:
- ID: sincro_sinergia_monthly
- Tipo: Auto-renewable subscription
- Duração: 1 mês
- Preço: R$ 39,90 (Tier 20)
```

#### Passo 3: Configurar Sandbox Testers
1. **Users and Access** > **Sandbox Testers**
2. Criar contas de teste (use emails fictícios)
3. Anotar credenciais para testes

### 2.2 Configuração no Flutter

#### Adicionar dependência
```yaml
# pubspec.yaml
dependencies:
  in_app_purchase: ^3.1.13
  in_app_purchase_storekit: ^0.3.6  # Para iOS
```

#### Configurar iOS
```bash
# ios/Runner/Info.plist
# Não precisa adicionar nada especial para IAP
```

### 2.3 Implementar iOS IAP

Crie `lib/services/ios_iap_service.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class IOSIAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  final Set<String> _productIds = {
    'sincro_desperta_monthly',
    'sincro_sinergia_monthly',
  };

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception('App Store não disponível');
    }

    // Escutar atualizações de compra
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) => print('Erro no purchase stream: $error'),
    );
  }

  Future<List<ProductDetails>> getProducts() async {
    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) {
      throw Exception('Erro ao buscar produtos: ${response.error}');
    }
    return response.productDetails;
  }

  Future<void> purchaseProduct(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        _verifyPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        print('Erro na compra: ${purchase.error}');
      }
      
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    // Enviar receipt para backend validar
    final receiptData = purchase.verificationData.serverVerificationData;
    
    // TODO: Chamar Firebase Function para validar
    // await validateAppleReceipt(receiptData);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
```

---

## 🤖 PARTE 3: Android - Google Play Billing

### 3.1 Configuração Google Play Console

#### Passo 1: Criar App no Google Play Console
1. Acesse https://play.google.com/console
2. Crie novo app ou selecione existente
3. Anote o **Package Name** (ex: `com.seuapp.sincro`)

#### Passo 2: Criar Produtos de Assinatura
1. **Monetização** > **Produtos** > **Assinaturas**
2. Criar produtos:

```
Produto 1:
- ID: sincro_desperta_monthly
- Nome: Sincro Desperta
- Preço: R$ 19,90
- Período: Mensal

Produto 2:
- ID: sincro_sinergia_monthly
- Nome: Sincro Sinergia
- Preço: R$ 39,90
- Período: Mensal
```

#### Passo 3: Configurar Contas de Teste
1. **Configurações** > **Contas de Teste**
2. Adicionar emails de teste
3. Criar **Lista de Teste Interna/Fechado**

### 3.2 Configuração no Flutter

```yaml
# pubspec.yaml
dependencies:
  in_app_purchase: ^3.1.13
  in_app_purchase_android: ^0.3.0  # Para Android
```

### 3.3 Implementar Android Billing

Similar ao iOS, usar `in_app_purchase` package.

---

## 🔄 PARTE 4: Sincronização Cross-Platform

### 4.1 Estrutura Firestore

```javascript
users/{userId}/
  └── subscription: {
        isActive: boolean,
        plan: 'free' | 'desperta' | 'sinergia',
        startDate: Timestamp,
        endDate: Timestamp,
        paymentMethod: 'pagbank' | 'apple' | 'google',
        transactionId: string,
        cancelAtPeriodEnd: boolean,
        originalTransactionId: string, // Para iOS
        purchaseToken: string, // Para Android
      }
```

### 4.2 Firebase Functions - Validação de Receipts

```javascript
// functions/validatePurchase.js

/**
 * Valida receipt da Apple
 */
exports.validateAppleReceipt = functions.https.onCall(async (data, context) => {
  const { receiptData, userId } = data;
  
  // Validar com Apple
  const response = await axios.post(
    'https://buy.itunes.apple.com/verifyReceipt',
    {
      'receipt-data': receiptData,
      'password': 'SEU_SHARED_SECRET', // Do App Store Connect
    }
  );

  if (response.data.status === 0) {
    // Receipt válido - atualizar Firestore
    const receipt = response.data.latest_receipt_info[0];
    await admin.firestore().collection('users').doc(userId).update({
      'subscription.isActive': true,
      'subscription.plan': receipt.product_id.includes('sinergia') ? 'sinergia' : 'desperta',
      'subscription.paymentMethod': 'apple',
      'subscription.originalTransactionId': receipt.original_transaction_id,
    });
  }
  
  return { valid: response.data.status === 0 };
});

/**
 * Valida purchase do Google
 */
exports.validateGooglePurchase = functions.https.onCall(async (data, context) => {
  const { purchaseToken, productId, userId } = data;
  
  // Validar com Google Play Developer API
  const { google } = require('googleapis');
  const androidpublisher = google.androidpublisher('v3');
  
  const auth = new google.auth.GoogleAuth({
    keyFile: 'service-account-key.json',
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const response = await androidpublisher.purchases.subscriptions.get({
    auth: auth,
    packageName: 'com.seuapp.sincro',
    subscriptionId: productId,
    token: purchaseToken,
  });

  if (response.data.paymentState === 1) {
    // Pago - atualizar Firestore
    await admin.firestore().collection('users').doc(userId).update({
      'subscription.isActive': true,
      'subscription.plan': productId.includes('sinergia') ? 'sinergia' : 'desperta',
      'subscription.paymentMethod': 'google',
      'subscription.purchaseToken': purchaseToken,
    });
  }
  
  return { valid: response.data.paymentState === 1 };
});
```

---

## 📊 PARTE 5: Tela de Assinatura no App

Exemplo de tela de compra (já adaptada ao seu design):

```dart
// lib/features/subscription/subscription_screen.dart
class SubscriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Escolha seu Plano')),
      body: Column(
        children: [
          // Card Desperta
          PlanCard(
            plan: 'Desperta',
            price: 'R\$ 19,90/mês',
            features: ['Todos os números', 'Insights AI', 'Sem anúncios'],
            onTap: () => _purchase(context, SubscriptionPlan.desperta),
          ),
          // Card Sinergia
          PlanCard(
            plan: 'Sinergia',
            price: 'R\$ 39,90/mês',
            features: ['Tudo do Desperta', 'Análises avançadas', 'Suporte prioritário'],
            onTap: () => _purchase(context, SubscriptionPlan.sinergia),
          ),
        ],
      ),
    );
  }

  void _purchase(BuildContext context, SubscriptionPlan plan) async {
    final paymentService = PaymentService();
    final userId = FirebaseAuth.instance.currentUser!.uid;
    
    try {
      await paymentService.purchaseSubscription(
        userId: userId,
        plan: plan,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }
}
```

---

## ✅ CHECKLIST de Implementação

### Web (PagBank)
- [ ] Criar conta PagBank e obter credenciais
- [ ] Criar produtos no PagBank
- [ ] Implementar Firebase Functions (checkout + webhook)
- [ ] Configurar secrets no Firebase
- [ ] Testar em sandbox
- [ ] Testar em produção

### iOS
- [ ] Criar app no App Store Connect
- [ ] Criar produtos de assinatura
- [ ] Adicionar `in_app_purchase` ao pubspec
- [ ] Implementar IOSIAPService
- [ ] Criar Firebase Function de validação
- [ ] Testar com sandbox accounts
- [ ] Submeter app para review

### Android
- [ ] Criar app no Google Play Console
- [ ] Criar produtos de assinatura
- [ ] Configurar service account para API
- [ ] Implementar AndroidIAPService
- [ ] Criar Firebase Function de validação
- [ ] Testar com contas de teste
- [ ] Publicar app

### Backend/Firestore
- [ ] Atualizar modelo de subscription
- [ ] Implementar webhooks
- [ ] Implementar validação de receipts
- [ ] Configurar regras de segurança

---

## 💰 Comparação de Taxas

| Plataforma | Taxa de Transação | Taxa Recorrente | Observações |
|------------|-------------------|-----------------|-------------|
| **PagBank** | ~4-5% + R$0,40 | Mesma | Sem taxa de setup |
| **Apple** | 15-30% (primeiro ano) | 15% (após 1 ano) | Obrigatório para iOS |
| **Google** | 15-30% (primeiro ano) | 15% (após 1 ano) | Obrigatório para Android |

**Importante**: As lojas de app (Apple/Google) **exigem** uso de IAP para assinaturas em apps nativos. Você **não pode** usar PagBank diretamente no iOS/Android para assinaturas.

---

## 🚀 Próximos Passos Recomendados

1. **Começar pelo Web** (PagBank) - mais simples e você já tem conta
2. **Implementar estrutura base** no Firestore
3. **Testar fluxo completo** no web
4. **Preparar apps mobile** para as lojas
5. **Implementar IAP** para iOS e Android
6. **Sincronizar tudo** via Firestore

Quer que eu implemente alguma parte específica primeiro? Posso criar:
- Tela de assinatura completa
- Firebase Functions prontas
- Integração PagBank web
- Configuração iOS/Android

Me diga por onde prefere começar! 🎯

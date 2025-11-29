// lib/common/constants/stripe_constants.dart

class StripeConstants {
  // TODO: Substitua pelos seus Price IDs reais (começam com 'price_')
  // Você pode encontrá-los no Dashboard do Stripe > Produtos > [Seu Produto] > Preços
  
  // Sincro Desperta (Product ID: prod_TVrgkFsoNVzi6i)
  static const String priceDespertaMonthly = 'price_1SYpx9PxUnpVpxqmTvBn8QJa';
  static const String priceDespertaAnnual = 'price_1SYpx9PxUnpVpxqmjbYUm8CT';

  // Sincro Sinergia (Product ID: prod_TVrkizVYiXQ2Ue)
  static const String priceSinergiaMonthly = 'price_1SYq1DPxUnpVpxqmb8ezCEMD';
  static const String priceSinergiaAnnual = 'price_1SYq1DPxUnpVpxqmpeKOcBYb';

  // Payment Links
  static const String linkDespertaMonthly = 'https://buy.stripe.com/test_cNidRbb0xdxBcLT10x5c402';
  static const String linkDespertaAnnual = 'https://buy.stripe.com/test_5kQ00l9WtdxB4fngZv5c403';
  static const String linkSinergiaMonthly = 'https://buy.stripe.com/test_eVq7sN3y5alp4fndNj5c400';
  static const String linkSinergiaAnnual = 'https://buy.stripe.com/test_9B614p2u19hl4fn5gN5c401';
}

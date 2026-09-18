import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_service.dart';
import 'supabase_service.dart';

/// Google Play Billing — product IDs must match Play Console.
class BillingService {
  BillingService._();
  static final instance = BillingService._();

  static const productPro = 'pro_monthly';
  static const productElite = 'elite_monthly';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool available = false;
  List<ProductDetails> products = [];

  Future<void> init() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      available = false;
      return;
    }
    available = await _iap.isAvailable();
    if (!available) return;

    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (_) {},
    );

    await queryProducts();
  }

  Future<void> queryProducts() async {
    if (!available) return;
    final resp = await _iap.queryProductDetails({productPro, productElite});
    products = resp.productDetails.toList();
  }

  ProductDetails? productForPlan(String planId) {
    final id = planId == 'elite' ? productElite : productPro;
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> buy(String planId) async {
    await init();
    final product = productForPlan(planId);
    if (product == null) return false;
    final param = PurchaseParam(productDetails: product);
    // Subscriptions use buyNonConsumable on Play for subs in this plugin
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    await init();
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == productElite) {
          await PremiumService.setLocalTier(PlanTier.elite);
          await _syncProfilePremium(true, 'elite');
        } else if (p.productID == productPro) {
          await PremiumService.setLocalTier(PlanTier.pro);
          await _syncProfilePremium(true, 'pro');
        }
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  Future<void> _syncProfilePremium(bool isPremium, String plan) async {
    try {
      final svc = SupabaseService.instance;
      if (!svc.isReady || !svc.isAuthenticated) return;
      final uid = svc.currentUser?.id;
      if (uid == null) return;
      await svc.client.from('profiles').upsert({
        'id': uid,
        'is_premium': isPremium,
        'premium_until': DateTime.now()
            .add(const Duration(days: 32))
            .toIso8601String(),
      });
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
  }
}

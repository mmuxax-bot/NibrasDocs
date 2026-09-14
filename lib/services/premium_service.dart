import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

enum PlanTier { free, pro, elite }

/// Limits: all features free. Caps are on document count & page length.
class PremiumService {
  static const maxDocsFree = 5;
  static const maxPagesFree = 15;
  static const maxPagesPro = 150;
  /// Elite: effectively unlimited for UI checks
  static const maxPagesElite = 999999;

  static const _prefPlan = 'nibras_plan_tier';

  /// Local override for testing (null = use profile/prefs)
  static PlanTier? debugForceTier;

  static Future<PlanTier> currentTier() async {
    if (debugForceTier != null) return debugForceTier!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString(_prefPlan);
      if (local == 'elite') return PlanTier.elite;
      if (local == 'pro') return PlanTier.pro;

      final svc = SupabaseService.instance;
      if (svc.isReady && svc.isAuthenticated) {
        final user = svc.currentUser;
        if (user != null) {
          final row = await svc.client
              .from('profiles')
              .select('is_premium, premium_until')
              .eq('id', user.id)
              .maybeSingle();
          if (row != null) {
            final until = row['premium_until'] as String?;
            if (until != null) {
              final d = DateTime.tryParse(until);
              if (d != null && d.isBefore(DateTime.now())) {
                return PlanTier.free;
              }
            }
            // is_premium without plan column → treat as Pro
            if (row['is_premium'] == true) {
              return PlanTier.pro;
            }
          }
        }
      }
    } catch (_) {}
    return PlanTier.free;
  }

  static Future<void> setLocalTier(PlanTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefPlan,
      tier == PlanTier.elite
          ? 'elite'
          : tier == PlanTier.pro
              ? 'pro'
              : 'free',
    );
  }

  static Future<bool> isPremium() async {
    final t = await currentTier();
    return t != PlanTier.free;
  }

  static Future<int> maxDocuments() async {
    final t = await currentTier();
    if (t == PlanTier.free) return maxDocsFree;
    return 999999;
  }

  static Future<int> maxPages() async {
    final t = await currentTier();
    switch (t) {
      case PlanTier.free:
        return maxPagesFree;
      case PlanTier.pro:
        return maxPagesPro;
      case PlanTier.elite:
        return maxPagesElite;
    }
  }

  static Future<bool> canCreateDocument(int currentCount) async {
    final max = await maxDocuments();
    return currentCount < max;
  }

  static Future<bool> canUsePageCount(int pages) async {
    final max = await maxPages();
    return pages <= max;
  }

  /// Soft warning when past 80% of page quota
  static Future<bool> isNearPageLimit(int pages) async {
    final max = await maxPages();
    if (max >= maxPagesElite) return false;
    return pages >= (max * 0.8).floor();
  }

  /// All editor features are free (image, link, table, …).
  /// Only document count & page length are gated.
  static const premiumFeatures = <String>{};
}

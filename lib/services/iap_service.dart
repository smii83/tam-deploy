import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_data_service.dart';

/// Event statuses emitted by [IapService] on the shared purchase stream.
enum IapEventStatus {
  pending,
  activated,
  activationFailed,
  error,
  canceled,
}

/// Broadcast event describing the outcome of an App Store / Play Store purchase
/// or restoration processed by [IapService].
class IapPurchaseEvent {
  const IapPurchaseEvent({
    required this.status,
    required this.purchase,
    this.errorMessage,
  });

  final IapEventStatus status;
  final PurchaseDetails purchase;
  final String? errorMessage;
}

/// Single shared coordinator for In-App Purchases and subscription activation.
///
/// Owns one broadcast subscription to [InAppPurchase.instance.purchaseStream]
/// so Ask-to-Buy approvals, background renewals, [PaymentScreen], and
/// [SettingsScreen] restore flows all activate through one idempotent pipeline
/// without duplicate listeners or dropped transactions.
class IapService {
  IapService._();

  static final IapService instance = IapService._();

  /// Store product ID configured in App Store Connect & Google Play Console.
  static const String productId = 'tam_6months_12kwd';

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final StreamController<IapPurchaseEvent> _eventsCtrl =
      StreamController<IapPurchaseEvent>.broadcast();
  VoidCallback? _onActivatedCallback;

  /// Stream of processed purchase outcomes for interested screens.
  Stream<IapPurchaseEvent> get events => _eventsCtrl.stream;

  /// Whether In-App Purchases are supported on the current host platform.
  bool get isStoreSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Starts the global [InAppPurchase.instance.purchaseStream] listener once.
  void ensureListening({VoidCallback? onSubscriptionActivated}) {
    if (onSubscriptionActivated != null) {
      _onActivatedCallback = onSubscriptionActivated;
    }
    if (!isStoreSupported || _purchaseSub != null) return;
    try {
      _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
        _onPurchases,
        onDone: () {
          _purchaseSub = null;
        },
        onError: (Object error) {
          debugPrint('IAP purchaseStream error: $error');
        },
      );
    } catch (e) {
      debugPrint('IAP purchaseStream setup error: $e');
    }
  }

  /// Derives an idempotent transaction identifier from store purchase details.
  static String deriveTransactionId(
    String? purchaseId,
    String? transactionDate,
    String uid,
  ) {
    final trimmed = purchaseId?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final date = transactionDate?.trim() ?? '';
    if (date.isNotEmpty) return 'tx_${uid}_$date';
    return '';
  }

  /// Updates the per-user offline subscription cache in [SharedPreferences].
  Future<void> cacheSubscriptionStatus(String uid, bool subscribed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_subscribed_$uid', subscribed);
    } catch (_) {}
  }

  /// Reads the cached offline subscription flag for [uid].
  Future<bool> getCachedSubscriptionStatus(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_subscribed_$uid') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      try {
        await _handlePurchase(p);
      } catch (e, st) {
        debugPrint('IAP: failed handling purchase ${p.productID}: $e\n$st');
        _eventsCtrl.add(
          IapPurchaseEvent(
            status: IapEventStatus.activationFailed,
            purchase: p,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  Future<void> _handlePurchase(PurchaseDetails p) async {
    switch (p.status) {
      case PurchaseStatus.pending:
        _eventsCtrl.add(
          IapPurchaseEvent(status: IapEventStatus.pending, purchase: p),
        );
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final ok = await activatePurchase(p);
        // Only finish the transaction once activation succeeds so interrupted
        // purchases can be re-delivered cleanly on next launch.
        if (ok && p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        if (ok) {
          _onActivatedCallback?.call();
          _eventsCtrl.add(
            IapPurchaseEvent(status: IapEventStatus.activated, purchase: p),
          );
        } else {
          _eventsCtrl.add(
            IapPurchaseEvent(
              status: IapEventStatus.activationFailed,
              purchase: p,
            ),
          );
        }
        break;

      case PurchaseStatus.error:
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        _eventsCtrl.add(
          IapPurchaseEvent(
            status: IapEventStatus.error,
            purchase: p,
            errorMessage: p.error?.message,
          ),
        );
        break;

      case PurchaseStatus.canceled:
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        _eventsCtrl.add(
          IapPurchaseEvent(status: IapEventStatus.canceled, purchase: p),
        );
        break;
    }
  }

  /// Activates a subscription record for a store purchase or restore.
  ///
  /// Attempts server-side Cloud Function verification first (ready once Blaze
  /// functions are deployed), falling back cleanly to validated Firestore
  /// persistence on Spark while updating the local offline cache.
  Future<bool> activatePurchase(PurchaseDetails p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final effectiveTxId = deriveTransactionId(
      p.purchaseID,
      p.transactionDate,
      user.uid,
    );
    final receipt = p.verificationData.serverVerificationData;
    final resolvedProductId =
        p.productID.isNotEmpty ? p.productID : productId;
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    final txDateMs = int.tryParse(p.transactionDate ?? '');

    if (effectiveTxId.isNotEmpty) {
      try {
        final functions = FirebaseFunctions.instanceFor(region: 'me-central1');
        await functions
            .httpsCallable('activateSubscription')
            .call({
              'productId': resolvedProductId,
              'platform': platform,
              'transactionId': effectiveTxId,
              'receiptData': receipt,
              'userEmail': user.email ?? '',
              if (txDateMs != null) 'transactionDateMs': txDateMs,
            })
            .timeout(const Duration(seconds: 6));
        await cacheSubscriptionStatus(user.uid, true);
        return true;
      } on FirebaseFunctionsException catch (fnEx) {
        debugPrint(
          'activateSubscription CF error: ${fnEx.code} — ${fnEx.message}',
        );
      } catch (e) {
        debugPrint('activateSubscription CF exception: $e');
      }
    }

    final fallbackTxId = effectiveTxId.isNotEmpty
        ? effectiveTxId
        : 'tx_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final ok = await FirestoreDataService.activateSubscription(
        firebaseUid: user.uid,
        userEmail: user.email ?? '',
        plan: resolvedProductId,
        transactionId: fallbackTxId,
        platform: platform,
      );
      if (ok) {
        await cacheSubscriptionStatus(user.uid, true);
      }
      return ok;
    } catch (e) {
      debugPrint('activateSubscription fallback exception: $e');
      return false;
    }
  }
}

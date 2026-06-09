import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// iOS AdMob App Open Ad 서비스.
/// 흐름: ATT 권한 요청 → 광고 로드 → 노출 → onComplete 콜백.
///
/// 광고 ID는 빌드 시 dart-define으로 주입:
///   개발: flutter run  (defaultValue = 테스트 ID 자동 사용)
///   배포: flutter build ios --dart-define-from-file=config/prod.json
class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  // dart-define 미지정 시 Google 공식 테스트 ID를 기본값으로 사용
  static const _adUnitId = String.fromEnvironment(
    'ADMOB_APP_OPEN_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5575463023',
  );

  AppOpenAd? _ad;
  bool _isShowing = false;

  /// ATT 권한 요청 후 광고 로드.
  /// iOS 14+ 전용. 미결정 상태일 때만 다이얼로그 표시.
  Future<void> requestAttAndLoad() async {
    if (kIsWeb || !Platform.isIOS) return;

    final status = await AppTrackingTransparency.trackingAuthorizationStatus;

    // 아직 사용자에게 묻지 않은 상태일 때만 요청
    if (status == TrackingStatus.notDetermined) {
      // iOS가 다이얼로그를 표시할 준비가 될 때까지 짧게 대기
      await Future.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }

    // 허용 여부와 무관하게 광고 로드 (거부 시 비개인화 광고 제공)
    await _loadAd();
  }

  Future<void> _loadAd() async {
    // ignore: avoid_print
    print('[AdMob] 광고 로드 시작 (unit: $_adUnitId)');
    final completer = Completer<void>();
    await AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          // ignore: avoid_print
          print('[AdMob] 광고 로드 성공');
          _ad = ad;
          completer.complete();
        },
        onAdFailedToLoad: (err) {
          // ignore: avoid_print
          print('[AdMob] 광고 로드 실패: ${err.message} (code: ${err.code})');
          _ad = null;
          completer.complete();
        },
      ),
    );
    await completer.future;
  }

  /// 광고가 준비됐으면 노출하고 [onComplete] 호출.
  /// 광고 없거나 iOS 아니면 즉시 [onComplete] 호출.
  Future<void> showIfAvailable({required void Function() onComplete}) async {
    // ignore: avoid_print
    print('[AdMob] showIfAvailable — ad: $_ad, isShowing: $_isShowing');
    if (kIsWeb || !Platform.isIOS || _isShowing || _ad == null) {
      onComplete();
      return;
    }

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _isShowing = true,
      onAdDismissedFullScreenContent: (ad) {
        _isShowing = false;
        ad.dispose();
        _ad = null;
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _isShowing = false;
        ad.dispose();
        _ad = null;
        onComplete();
      },
    );

    await _ad!.show();
  }
}

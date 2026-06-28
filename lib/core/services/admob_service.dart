import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// dart-define 미지정 시 Google 공식 테스트 ID 사용
const _androidBannerId = String.fromEnvironment(
  'ADMOB_BANNER_ID_ANDROID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);
const _iosBannerId = String.fromEnvironment(
  'ADMOB_BANNER_ID_IOS',
  defaultValue: 'ca-app-pub-8560405440054672/6964347258',
);

String get _bannerAdUnitId {
  if (Platform.isAndroid) return _androidBannerId;
  if (Platform.isIOS) return _iosBannerId;
  return '';
}

/// iOS ATT 권한 요청 후 AdMob 초기화. 스플래시에서 await 호출.
/// ATT 응답(허용/거부 무관)을 받은 뒤 MobileAds를 초기화하므로
/// 추적 데이터 수집이 항상 ATT 이후에 시작된다.
Future<void> requestAttThenInitAds() async {
  if (kIsWeb) return;
  if (Platform.isIOS) {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // 스플래시 화면이 완전히 표시된 뒤 다이얼로그가 뜨도록 짧게 대기
      await Future.delayed(const Duration(milliseconds: 300));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }
  await MobileAds.instance.initialize();
}

/// 배너 광고를 미리 로드해 보관하는 컨트롤러.
/// 스플래시에서 [preload]를 호출해 두면, 홈의 [BannerAdWidget]은 이미 로드된
/// 광고를 즉시 표시한다(홈 진입 후 로딩 대기·팝업 없음).
/// no-fill 등 일시 실패 시 짧은 백오프로 재시도한다.
class BannerAdController extends Notifier<BannerAd?> {
  static const _maxAttempts = 3;
  bool _started = false;

  @override
  BannerAd? build() {
    ref.onDispose(() => state?.dispose());
    return null;
  }

  /// 광고를 로드하고 성공/실패가 확정될 때까지 대기.
  /// 최초 1회만 실행되며, 성공 시 [state]에 광고를 보관한다.
  Future<void> preload() async {
    if (kIsWeb || _started || state != null) return;
    _started = true;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final ad = await _loadOnce();
      if (ad != null) {
        state = ad;
        return;
      }
      // no-fill 대비: 1초, 2초 백오프 후 재시도
      if (attempt < _maxAttempts) {
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  Future<BannerAd?> _loadOnce() {
    final completer = Completer<BannerAd?>();
    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] 배너 로드 실패: ${error.message}');
          ad.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    ad.load();
    return completer.future;
  }
}

final bannerAdProvider = NotifierProvider<BannerAdController, BannerAd?>(
  BannerAdController.new,
);

/// 홈 화면 하단에 삽입하는 AdMob 배너 위젯.
/// 프리로드된 광고가 있으면 즉시 표시하고, 없으면 SizedBox.shrink()로 축소.
/// 광고 로드 자체는 [BannerAdController]가 소유하므로 이 위젯은 표시만 담당한다.
class BannerAdWidget extends ConsumerWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(bannerAdProvider);
    if (ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

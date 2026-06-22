import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// dart-define 미지정 시 Google 공식 테스트 ID 사용
const _androidBannerId = String.fromEnvironment(
  'ADMOB_BANNER_ID_ANDROID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);
const _iosBannerId = String.fromEnvironment(
  'ADMOB_BANNER_ID_IOS',
  defaultValue: 'ca-app-pub-3940256099942544/2934735716',
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

/// 홈 화면 하단에 삽입하는 AdMob 배너 위젯.
/// 로드 성공 시 광고 높이만큼 공간을 차지하고, 실패 시 SizedBox.shrink()로 축소.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb) return;
    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] 배너 로드 실패: ${error.message}');
          ad.dispose();
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}

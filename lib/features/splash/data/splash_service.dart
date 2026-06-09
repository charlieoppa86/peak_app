import 'dart:io';

import 'package:flutter/foundation.dart';

enum VersionStatus { upToDate, optionalUpdate, forceUpdate }

abstract final class SplashService {
  // 현재 앱 버전. 실제로는 package_info_plus로 읽어온다.
  static const _current = (major: 1, minor: 0, patch: 0);

  /// 기기 인터넷 연결 여부. web은 항상 true 반환.
  static Future<bool> checkNetwork() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 서버에서 최소 요구 버전·최신 버전을 받아 현재 버전과 비교.
  /// 프로덕션: Firebase Remote Config 또는 자체 API 사용.
  static Future<VersionStatus> checkVersion() async {
    // Mock: 실제 구현 시 Firebase Remote Config 또는 자체 API로 교체
    const serverMin = (major: 1, minor: 0, patch: 0);
    const serverLatest = (major: 1, minor: 0, patch: 0);

    if (_olderThan(_current, serverMin)) return VersionStatus.forceUpdate;
    if (_olderThan(_current, serverLatest)) return VersionStatus.optionalUpdate;
    return VersionStatus.upToDate;
  }

  /// 홈 화면에 필요한 데이터 프리패치. 실패 시 호출부가 무시(skip).
  /// 프로덕션: 날씨 API·유저 설정 등을 앱 전역 캐시에 저장.
  static Future<void> prefetchHomeData() async {
    // 프로덕션: 날씨 API·유저 설정 등을 앱 전역 캐시에 저장
  }

  static bool _olderThan(
    ({int major, int minor, int patch}) a,
    ({int major, int minor, int patch}) b,
  ) {
    if (a.major != b.major) return a.major < b.major;
    if (a.minor != b.minor) return a.minor < b.minor;
    return a.patch < b.patch;
  }
}

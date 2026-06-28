import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

/// 소셜 로그인(카카오·애플) → Supabase 세션 승격 담당.
///
/// 앱은 익명 세션으로 시작하고(US-002), 함께 달리기·공유 게이트에서만 이 서비스를
/// 호출해 실제 사용자로 세션을 승격한다. 승격 후에는 [SupabaseService.isSignedIn]이
/// true가 되어 게이트를 통과한다.
class AuthService {
  /// 카카오로 로그인하고 Supabase 세션을 카카오 사용자로 승격한다.
  /// 성공 시 완료, 설정 누락·OIDC 비활성화는 [SocialLoginException]을 던진다.
  /// 사용자가 로그인을 취소하면 카카오 SDK가 예외를 던지므로 호출부에서 catch 한다.
  static Future<void> signInWithKakao() async {
    if (AppConfig.kakaoNativeAppKey.isEmpty) {
      throw const SocialLoginException(
        '카카오 네이티브 앱 키가 설정되지 않았어요 (.env의 KAKAO_NATIVE_APP_KEY).',
      );
    }

    // 카카오톡이 깔려 있으면 앱으로 로그인, 아니면(또는 전환 실패 시) 카카오계정 웹 로그인.
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }

    final idToken = token.idToken;
    if (idToken == null) {
      throw const SocialLoginException(
        '카카오 OpenID Connect가 비활성화되어 있어요. 카카오 디벨로퍼스에서 OpenID Connect를 켠 뒤 다시 시도해 주세요.',
      );
    }

    // ID 토큰으로 Supabase 세션 발급 — 기존 익명 세션을 카카오 사용자로 대체한다.
    await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: idToken,
      accessToken: token.accessToken,
    );
  }

  /// 애플로 로그인하고 Supabase 세션을 애플 사용자로 승격한다 (iOS 13+).
  /// 리플레이 공격 방지를 위해 nonce를 생성해 해시는 애플에, 원본은 Supabase에 전달한다.
  /// 사용자가 취소하면 [SignInWithApple]이 예외를 던지므로 호출부에서 catch 한다.
  static Future<void> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const SocialLoginException('애플 ID 토큰을 받지 못했어요. 다시 시도해 주세요.');
    }

    // 원본 nonce를 함께 보내 애플 idToken의 nonce(해시)와 대조 검증한다.
    await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  /// 암호학적으로 안전한 난수 nonce 생성 (애플 로그인 리플레이 방지용).
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// 로그아웃 — 카카오·Supabase 세션을 해제하고 다시 익명 세션으로 복귀한다.
  /// (앱은 로그인 없이도 동작해야 하므로 로그아웃 후에도 익명 세션을 유지한다.)
  static Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오 로그아웃 실패는 무시 — Supabase 세션 정리가 우선.
    }
    await SupabaseService.client.auth.signOut();
    await SupabaseService.ensureSession();
  }
}

/// 소셜 로그인 설정·환경 오류. 사용자에게 보여줄 메시지를 담는다.
class SocialLoginException implements Exception {
  const SocialLoginException(this.message);
  final String message;

  @override
  String toString() => message;
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/services/auth_service.dart';

/// 함께 달리기·공유 게이트에서 뜨는 로그인 Bottom Sheet (애플·카카오).
/// 로그인 성공 시 `Navigator.pop(context, true)`, 취소 시 false로 닫힌다.
/// 애플 버튼은 iOS에서만 노출한다 (App Store 제3자 로그인 제공 시 애플 로그인 의무).
class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key, this.reason});

  /// 로그인이 필요한 이유 한 줄 설명 (예: "같이 달리기를 만들려면 로그인이 필요해요").
  final String? reason;

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  bool _loading = false;

  bool get _appleAvailable => !kIsWeb && Platform.isIOS;

  /// 공통 로그인 실행기 — 성공 시 시트를 true로 닫고, 실패/취소는 부드럽게 안내한다.
  Future<void> _run(Future<void> Function() login) async {
    setState(() => _loading = true);
    try {
      await login();
      if (mounted) Navigator.pop(context, true);
    } on SocialLoginException catch (e) {
      _showError(e.message);
    } catch (_) {
      // 사용자 취소·일시 오류 — 시트는 유지하고 부드럽게 안내만 한다.
      _showError('로그인을 완료하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.groups_outlined, size: 40, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              '로그인이 필요해요',
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              widget.reason ?? '함께 달리기와 일정 공유는 로그인 후 이용할 수 있어요.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (_appleAvailable) ...[
              SignInWithAppleButton(
                onPressed:
                    _loading ? null : () => _run(AuthService.signInWithApple),
                text: '애플로 로그인',
                height: 52,
                style: isDark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 10),
            ],
            _KakaoButton(
              loading: _loading,
              onPressed:
                  _loading ? null : () => _run(AuthService.signInWithKakao),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context, false),
              child: const Text('다음에 할게요'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KakaoButton extends StatelessWidget {
  const _KakaoButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  // 카카오 브랜드 가이드: 배경 #FEE500, 라벨 불투명 검정.
  static const _kakaoYellow = Color(0xFFFEE500);
  static const _kakaoLabel = Color(0xFF191600);

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _kakaoYellow,
        foregroundColor: _kakaoLabel,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: _kakaoLabel),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble, size: 20),
                const SizedBox(width: 8),
                Text(
                  '카카오로 로그인',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _kakaoLabel,
                      ),
                ),
              ],
            ),
    );
  }
}

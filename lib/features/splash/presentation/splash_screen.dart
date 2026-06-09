import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/admob_service.dart';
import '../data/splash_service.dart';

/// 스플래시 — 앱 진입 직후 버전 체크·네트워크 체크·데이터 프리패치를 병렬 처리.
/// 모두 완료되면 홈으로 이동. 문제 발생 시 적절한 다이얼로그를 노출하고 블록.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  String _statusText = '준비 중...';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _runStartup();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ─── Startup flow ──────────────────────────────────────────────────────────

  Future<void> _runStartup() async {
    while (true) {
      // ATT 권한 요청 + 광고 프리로드를 startup과 병렬로 시작 (iOS 전용, 실패해도 무시)
      final adFuture = AdMobService.instance.requestAttAndLoad();

      // 3가지를 동시에 시작
      final networkFuture = SplashService.checkNetwork();
      final versionFuture = SplashService.checkVersion();
      final prefetchFuture = _safePrefetch();

      // 네트워크 결과를 먼저 확인 (나머지는 백그라운드에서 계속 실행 중)
      final hasNetwork = await networkFuture;
      if (!mounted) return;

      if (!hasNetwork) {
        final retry = await _showNetworkDialog();
        if (!mounted) return;
        if (retry) {
          _setStatus('재연결 확인 중...');
          continue; // 전체 루프 재시작 (3가지 모두 재실행)
        }
        return;
      }

      _setStatus('버전 확인 중...');

      // 네트워크 OK — version·prefetch는 이미 실행 중이므로 결과만 수거
      final versionStatus = await versionFuture;
      await prefetchFuture; // 실패는 _safePrefetch 내부에서 흡수됨
      if (!mounted) return;

      switch (versionStatus) {
        case VersionStatus.forceUpdate:
          await _showForceUpdateDialog(); // 탈출 불가, 여기서 앱 흐름 멈춤
          return;

        case VersionStatus.optionalUpdate:
          final shouldUpdate = await _showOptionalUpdateDialog();
          if (!mounted) return;
          if (shouldUpdate) {
            _openStore();
            return;
          }

        case VersionStatus.upToDate:
          break;
      }

      if (!mounted) return;

      // 광고 로드가 아직 진행 중이면 최대 6초 대기 후 노출 시도
      await adFuture.timeout(const Duration(seconds: 6), onTimeout: () {});
      if (!mounted) return;

      // 광고 노출 후 홈 이동 (광고 없으면 즉시 이동)
      AdMobService.instance.showIfAvailable(
        onComplete: () { if (mounted) context.go('/home'); },
      );
      return;
    }
  }

  // prefetch 실패는 로그만 남기고 skip
  Future<void> _safePrefetch() async {
    try {
      await SplashService.prefetchHomeData();
    } catch (_) {}
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  Future<bool> _showNetworkDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.wifi_off_rounded, size: 44),
        title: const Text('인터넷 연결 없음'),
        content: const Text(
          '인터넷에 연결되어 있지 않아요.\n네트워크 연결 후 다시 시도해 주세요.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 강제 업데이트: 닫기 불가. "지금 업데이트" 탭 시 스토어 이동.
  Future<void> _showForceUpdateDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // 뒤로가기로 닫기 방지
        child: AlertDialog(
          icon: const Icon(Icons.system_update_rounded, size: 44),
          title: const Text('업데이트 필요'),
          content: const Text(
            '현재 버전은 더 이상 지원되지 않아요.\n계속 사용하려면 최신 버전으로 업데이트해 주세요.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openStore();
              },
              child: const Text('지금 업데이트'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showOptionalUpdateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.new_releases_rounded, size: 44, color: Theme.of(ctx).colorScheme.primary),
        title: const Text('새 버전이 있어요'),
        content: const Text(
          '더 나은 경험을 위해 업데이트를 추천해요.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지금 업데이트'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _openStore() {
    // TODO: url_launcher 연동 후 App Store / Play Store URL 열기
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스토어 연결은 출시 시 연동 예정이에요')),
      );
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 로고 영역 (2/3)
            Expanded(
              flex: 2,
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: const _LogoArea(),
                ),
              ),
            ),
            // 로딩 영역 (1/3)
            Expanded(
              child: _LoadingArea(statusText: _statusText),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoArea extends StatelessWidget {
  const _LogoArea();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(color: primary.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Icon(Icons.filter_hdr_rounded, size: 44, color: primary),
        ),
        const SizedBox(height: 20),
        Text(
          'Peak',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '날씨 보고 라이딩 잡는 앱',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }
}

class _LoadingArea extends StatelessWidget {
  const _LoadingArea({required this.statusText});

  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            statusText,
            key: ValueKey(statusText),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

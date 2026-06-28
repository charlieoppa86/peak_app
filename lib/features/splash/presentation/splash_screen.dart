import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/services/admob_service.dart'
    show requestAttThenInitAds, bannerAdProvider;
import '../data/splash_service.dart';

/// 스플래시 — 앱 진입 직후 버전 체크·네트워크 체크·데이터 프리패치를 병렬 처리.
/// 모두 완료되면 홈으로 이동. 문제 발생 시 적절한 다이얼로그를 노출하고 블록.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  String _statusText = '준비 중...';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    // 첫 프레임이 렌더링된 뒤 실행해야 ATT 다이얼로그가 화면 위에 올바르게 표시됨
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartup());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ─── Startup flow ──────────────────────────────────────────────────────────

  Future<void> _runStartup() async {
    while (true) {
      // ATT 다이얼로그가 완전히 닫힌 뒤 AdMob이 초기화되도록 먼저 await
      await requestAttThenInitAds();
      if (!mounted) return;

      // AdMob 초기화 직후 배너를 미리 로드 시작 → 홈 진입 시 즉시 표시.
      // best-effort라 결과를 끝까지 기다리지 않고 아래에서 짧게만 대기한다.
      final adFuture = ref.read(bannerAdProvider.notifier).preload();

      final networkFuture = SplashService.checkNetwork();
      final versionFuture = SplashService.checkVersion();

      final hasNetwork = await networkFuture;
      if (!mounted) return;

      if (!hasNetwork) {
        final retry = await _showNetworkDialog();
        if (!mounted) return;
        if (retry) {
          _setStatus('재연결 확인 중...');
          continue;
        }
        return;
      }

      _setStatus('버전 확인 중...');

      final versionStatus = await versionFuture;
      if (!mounted) return;

      // 오늘의 날씨가 실제 로드될 때까지 스플래시 유지(실패/지연 시 타임아웃 후 진행).
      _setStatus('날씨 정보 불러오는 중...');
      await _prefetchWeather();
      if (!mounted) return;

      // 배너 광고가 준비될 때까지 잠깐 더 대기(준비되면 홈에서 곧바로 노출).
      await adFuture.timeout(const Duration(seconds: 2), onTimeout: () {});
      if (!mounted) return;

      switch (versionStatus) {
        case VersionStatus.forceUpdate:
          await _showForceUpdateDialog();
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
      context.go('/home');
      return;
    }
  }

  // 오늘의 날씨(weatherRecommendationProvider)를 실제로 로드해 캐시에 채운다.
  // 비-autoDispose provider라 여기서 한 번 로드하면 홈에서 스켈레톤 없이 즉시 표시된다.
  // 실패/지연 시에는 홈으로 넘어가 홈의 에러 카드·재시도 UI가 처리한다.
  Future<void> _prefetchWeather() async {
    try {
      await ref
          .read(weatherRecommendationProvider.future)
          .timeout(const Duration(seconds: 10));
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.18,
            child: Image.asset(
              'assets/images/splash_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
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
        ],
      ),
    );
  }
}

class _LogoArea extends StatelessWidget {
  const _LogoArea();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          '라이더를 위한 단 하나의 앱',
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

import 'package:flutter/material.dart';

import '../../shared/widgets/login_sheet.dart';
import '../services/supabase_service.dart';

/// 로그인 게이트 (US-002).
///
/// 이미 로그인(비익명)된 상태면 즉시 true를 반환한다.
/// 아니면 카카오 로그인 Bottom Sheet를 띄우고, 로그인 성공 시 true / 취소 시 false.
///
/// 사용 예:
/// ```dart
/// if (!await ensureSignedIn(context, reason: '같이 달리기를 만들려면 로그인이 필요해요')) return;
/// if (!context.mounted) return;
/// // ... 로그인 필요한 동작 진행
/// ```
Future<bool> ensureSignedIn(BuildContext context, {String? reason}) async {
  if (SupabaseService.isSignedIn) return true;
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => LoginSheet(reason: reason),
  );
  return result ?? false;
}

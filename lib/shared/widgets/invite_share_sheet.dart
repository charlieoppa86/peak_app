import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 시스템 공유 시트를 통한 초대 링크 공유 (US-005 AC1).
/// - 문자/카카오톡/더보기: 모두 iOS 네이티브 공유 시트 호출
/// - 링크 복사: 클립보드 저장
/// - weatherScore 전달 시 공유 메시지에 날씨 점수 포함
class InviteShareSheet extends StatelessWidget {
  const InviteShareSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.link,
    this.weatherScore,
  });

  final String title;
  final String subtitle;
  final String link;
  final int? weatherScore;

  String get _shareText {
    final scoreLine = weatherScore != null ? '\n날씨 점수: $weatherScore점' : '';
    return '[Peak] 같이 달려요! 🚴\n'
        '코스: $title\n'
        '$subtitle'
        '$scoreLine\n\n'
        '참석 여부 알려줘 →\n$link';
  }

  Future<void> _openShareSheet(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      _shareText,
      subject: '[Peak] $title 라이딩 초대',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '초대 공유',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$title · $subtitle',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ShareOption(
                icon: Icons.sms_outlined,
                label: '문자',
                onTap: () => _openShareSheet(context),
              ),
              _ShareOption(
                icon: Icons.chat_bubble_outline,
                label: '카카오톡',
                onTap: () => _openShareSheet(context),
              ),
              _ShareOption(
                icon: Icons.more_horiz,
                label: '더보기',
                onTap: () => _openShareSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('링크를 복사했어요')),
                    );
                  },
                  child: const Text('복사'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(icon),
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

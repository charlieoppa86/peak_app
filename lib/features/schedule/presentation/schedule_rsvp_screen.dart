import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// peak://home/schedule/:id/rsvp 딥링크로 진입하는 참석 응답 화면.
/// 앱이 설치된 사용자는 자신의 이름과 참석 버튼을 볼 수 있다.
class ScheduleRsvpScreen extends ConsumerStatefulWidget {
  const ScheduleRsvpScreen({
    super.key,
    required this.scheduleId,
    required this.course,
    required this.date,
    required this.time,
  });

  final String scheduleId;
  final String course;
  final String date;
  final String time;

  @override
  ConsumerState<ScheduleRsvpScreen> createState() => _ScheduleRsvpScreenState();
}

enum _RsvpStatus { none, attending, maybe, declined }

class _ScheduleRsvpScreenState extends ConsumerState<ScheduleRsvpScreen> {
  String _userName = '';
  _RsvpStatus _status = _RsvpStatus.none;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    if (mounted) setState(() => _userName = name);
  }

  Future<void> _respond(_RsvpStatus status) async {
    if (_userName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }
    setState(() => _status = status);

    try {
      await Supabase.instance.client.from('schedule_rsvps').upsert({
        'riding_schedule_id': widget.scheduleId,
        'name': _userName.trim(),
        'status': status.name,
      }, onConflict: 'riding_schedule_id,name');
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        setState(() => _status = _RsvpStatus.none);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('라이딩 초대'),
        centerTitle: false,
      ),
      body: _submitted ? _buildDone(colors, text) : _buildForm(colors, text),
    );
  }

  Widget _buildForm(ColorScheme colors, TextTheme text) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // 초대 헤더
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('라이딩 초대', style: text.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.course.isNotEmpty) ...[
                Text('코스', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(widget.course, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
              ],
              if (widget.date.isNotEmpty) ...[
                Text('날짜', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(widget.date, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
              ],
              if (widget.time.isNotEmpty) ...[
                Text('시간', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(widget.time, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 이름 표시 / 입력
        Text('참석자 이름', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: _userName,
          onChanged: (v) => setState(() => _userName = v),
          decoration: InputDecoration(
            hintText: '이름을 입력해주세요',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // 참석 버튼들
        Text('참석 여부', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _RsvpButton(label: '참석 ✓', status: _RsvpStatus.attending, selected: _status == _RsvpStatus.attending, onTap: () => _respond(_RsvpStatus.attending))),
            const SizedBox(width: 8),
            Expanded(child: _RsvpButton(label: '미정', status: _RsvpStatus.maybe, selected: _status == _RsvpStatus.maybe, onTap: () => _respond(_RsvpStatus.maybe))),
            const SizedBox(width: 8),
            Expanded(child: _RsvpButton(label: '불참', status: _RsvpStatus.declined, selected: _status == _RsvpStatus.declined, onTap: () => _respond(_RsvpStatus.declined))),
          ],
        ),
      ],
    );
  }

  Widget _buildDone(ColorScheme colors, TextTheme text) {
    final message = switch (_status) {
      _RsvpStatus.attending => '참석으로 응답했어요 🎉',
      _RsvpStatus.maybe => '미정으로 응답했어요',
      _RsvpStatus.declined => '불참으로 응답했어요',
      _RsvpStatus.none => '',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _status == _RsvpStatus.attending ? Icons.check_circle_outline : Icons.info_outline,
              size: 64,
              color: _status == _RsvpStatus.attending ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(message, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '$_userName 님의 응답이 전달되었어요.',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('홈으로'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({required this.label, required this.status, required this.selected, required this.onTap});

  final String label;
  final _RsvpStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAttending = status == _RsvpStatus.attending;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? (isAttending ? colors.primary : colors.surfaceContainerHighest)
              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: isAttending ? colors.primary : colors.outline, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected && isAttending ? colors.onPrimary : colors.onSurface,
              ),
        ),
      ),
    );
  }
}

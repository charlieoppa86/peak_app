import 'package:flutter/material.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
const _triggerOptions = [30, 50, 70];

/// 알림 설정 — 주간 요약 요일·시각, 날씨 악화 트리거 기준, ON/OFF (US-011).
/// 변경 사항은 다음 알림 발송 시점부터 즉시 적용된다 (US-011 AC3).
class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  bool _enabled = true;
  String _summaryDay = '월';
  TimeOfDay _summaryTime = const TimeOfDay(hour: 8, minute: 0);
  int _trigger = 50;

  void _toggleEnabled(bool value) {
    setState(() => _enabled = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? '알림을 켰어요' : '알림을 껐어요. 다음 발송부터 적용돼요')),
    );
  }

  Future<void> _pickSummaryTime() async {
    final picked = await showTimePicker(context: context, initialTime: _summaryTime);
    if (picked != null) {
      setState(() => _summaryTime = picked);
      _notifyApplied();
    }
  }

  void _notifyApplied() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('변경 사항을 저장했어요. 다음 알림부터 적용돼요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('알림 받기'),
            subtitle: const Text('날씨 악화 · 주간 요약 · 그룹 일정 변경 알림'),
            value: _enabled,
            onChanged: _toggleEnabled,
          ),
          const Divider(height: 32),
          Opacity(
            opacity: _enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !_enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('주간 요약 알림', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '이번 주 라이딩 최적 시간대 TOP 3를 골라 알려드려요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _summaryDay,
                          decoration: const InputDecoration(labelText: '요일', border: OutlineInputBorder()),
                          items: [for (final d in _weekdays) DropdownMenuItem(value: d, child: Text('$d요일'))],
                          onChanged: (day) {
                            if (day == null) return;
                            setState(() => _summaryDay = day);
                            _notifyApplied();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickSummaryTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: '시각', border: OutlineInputBorder()),
                            child: Text(_summaryTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('날씨 악화 알림', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '예정 일정의 강수확률이 아래 기준 이상으로 올라가면 알려드려요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<int>(
                    groupValue: _trigger,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _trigger = value);
                      _notifyApplied();
                    },
                    child: Column(
                      children: [
                        for (final option in _triggerOptions)
                          RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            value: option,
                            title: Text('강수확률 $option%p 이상 상승 시'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

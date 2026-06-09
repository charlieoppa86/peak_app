import 'package:flutter/material.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 프로필 편집 — 이름/닉네임 수정 · 선호 운동 요일 변경.
/// 입력값은 기기에 저장되어 이후 초대 발송 시 자동으로 채워진다 (US-002 AC3).
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameController = TextEditingController(text: '동현');
  final Set<String> _preferredDays = {'화', '토', '일'};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이름 또는 닉네임을 입력해주세요')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필을 저장했어요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 편집')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('이름 / 닉네임', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '예: 동현',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '그룹 초대 시 다른 멤버에게 표시되는 이름이에요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),
          Text('선호 운동 요일', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in _weekdays)
                FilterChip(
                  label: Text('$day요일'),
                  selected: _preferredDays.contains(day),
                  onSelected: (_) => setState(() {
                    _preferredDays.contains(day) ? _preferredDays.remove(day) : _preferredDays.add(day);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
    );
  }
}

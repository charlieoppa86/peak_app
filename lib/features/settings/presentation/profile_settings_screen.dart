import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late final TextEditingController _nameController;
  final Set<String> _preferredDays = {'화', '토', '일'};

  @override
  void initState() {
    super.initState();
    final savedName = ref.read(userNameProvider);
    _nameController = TextEditingController(text: savedName.isEmpty ? '피크' : savedName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이름 또는 닉네임을 입력해주세요')));
      return;
    }
    await ref.read(userNameProvider.notifier).update(name);
    if (!mounted) return;
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

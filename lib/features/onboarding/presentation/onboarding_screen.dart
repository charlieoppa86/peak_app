import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/data/region_mock_data.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 온보딩 — 이름 · 지역(시/구) · 선호 요일을 3스텝 이내로 설정 (US-001, US-002).
/// 로그인 없이 즉시 메인 화면 진입 (US-002 AC1). 완료 후에는 다시 노출되지 않아야 한다 (US-001 AC3).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();

  int _step = 0;
  String? _city = '서울특별시';
  String? _district;
  final Set<String> _preferredDays = {};

  static const _stepCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _nameController.text.trim().isNotEmpty;
      case 1:
        return _city != null && _district != null;
      case 2:
        return _preferredDays.isNotEmpty;
      default:
        return false;
    }
  }

  void _next() {
    if (_step == _stepCount - 1) {
      context.go('/home');
      return;
    }
    setState(() => _step += 1);
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text('${_step + 1} / $_stepCount'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  for (var i = 0; i < _stepCount; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: i <= _step ? 1 : 0,
                          minHeight: 4,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _NameStep(controller: _nameController, onChanged: () => setState(() {})),
                  _RegionStep(
                    city: _city,
                    district: _district,
                    onCityChanged: (city) => setState(() {
                      _city = city;
                      _district = null;
                    }),
                    onDistrictChanged: (district) => setState(() => _district = district),
                  ),
                  _WeekdayStep(
                    selected: _preferredDays,
                    onToggle: (day) => setState(() {
                      _preferredDays.contains(day) ? _preferredDays.remove(day) : _preferredDays.add(day);
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canProceed ? _next : null,
                  child: Text(_step == _stepCount - 1 ? '시작하기' : '다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: '어떻게 불러드릴까요?',
      subtitle: '로그인 없이 바로 시작해요. 그룹 초대 시 다른 멤버에게 표시되는 이름이에요.',
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(
          labelText: '이름 또는 닉네임',
          hintText: '예: 동현',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _RegionStep extends StatelessWidget {
  const _RegionStep({
    required this.city,
    required this.district,
    required this.onCityChanged,
    required this.onDistrictChanged,
  });

  final String? city;
  final String? district;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;

  @override
  Widget build(BuildContext context) {
    final districts = city == null ? const <String>[] : mockRegions[city]!;
    return _StepScaffold(
      title: '어느 지역에서 라이딩하세요?',
      subtitle: '시/구 단위로 설정하면 해당 지역 2주 날씨 캘린더를 바로 보여드려요.',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: city,
            decoration: const InputDecoration(labelText: '시/도', border: OutlineInputBorder()),
            items: [for (final c in mockRegions.keys) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: onCityChanged,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: district,
            decoration: const InputDecoration(labelText: '시/군/구', border: OutlineInputBorder()),
            items: [for (final d in districts) DropdownMenuItem(value: d, child: Text(d))],
            onChanged: districts.isEmpty ? null : onDistrictChanged,
          ),
        ],
      ),
    );
  }
}

class _WeekdayStep extends StatelessWidget {
  const _WeekdayStep({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: '주로 언제 라이딩하세요?',
      subtitle: '선호하는 운동 요일을 골라주세요. 여러 개 선택할 수 있어요.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final day in _weekdays)
            FilterChip(
              label: Text('$day요일'),
              selected: selected.contains(day),
              onSelected: (_) => onToggle(day),
            ),
        ],
      ),
    );
  }
}

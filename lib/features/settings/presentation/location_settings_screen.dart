import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/data/region_mock_data.dart';

/// 지역 설정 — 시/구 단위 지역 변경, 변경 즉시 날씨 캘린더 갱신.
class LocationSettingsScreen extends ConsumerStatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  ConsumerState<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState
    extends ConsumerState<LocationSettingsScreen> {
  late String? _city;
  late String? _district;

  @override
  void initState() {
    super.initState();
    final loc = ref.read(selectedLocationProvider);
    _city = loc.city;
    _district = loc.district;
  }

  Future<void> _save() async {
    if (_city == null || _district == null) return;
    await ref.read(selectedLocationProvider.notifier).update(_city!, _district!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_city $_district(으)로 변경했어요. 날씨 캘린더를 갱신했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final districts = _city == null ? const <String>[] : mockRegions[_city]!;

    return Scaffold(
      appBar: AppBar(title: const Text('지역 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            '시/구 단위로 지역을 설정하면 해당 지역의 2주 날씨 캘린더로 즉시 갱신돼요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: const InputDecoration(
                labelText: '시/도', border: OutlineInputBorder()),
            items: [
              for (final c in mockRegions.keys)
                DropdownMenuItem(value: c, child: Text(c))
            ],
            onChanged: (city) => setState(() {
              _city = city;
              _district = null;
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _district,
            decoration: const InputDecoration(
                labelText: '시/군/구', border: OutlineInputBorder()),
            items: [
              for (final d in districts)
                DropdownMenuItem(value: d, child: Text(d))
            ],
            onChanged:
                districts.isEmpty ? null : (d) => setState(() => _district = d),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: (_city != null && _district != null) ? _save : null,
            child: const Text('저장하고 캘린더 갱신'),
          ),
        ],
      ),
    );
  }
}

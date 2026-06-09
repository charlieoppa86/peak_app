import 'package:flutter/material.dart';

import '../../../shared/data/region_mock_data.dart';

/// 지역 설정 — 시/구 단위 지역 변경, 변경 즉시 날씨 캘린더 갱신.
class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  String? _city = '서울특별시';
  String? _district = '마포구';

  void _save() {
    if (_city == null || _district == null) return;
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: const InputDecoration(labelText: '시/도', border: OutlineInputBorder()),
            items: [for (final c in mockRegions.keys) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (city) => setState(() {
              _city = city;
              _district = null;
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _district,
            decoration: const InputDecoration(labelText: '시/군/구', border: OutlineInputBorder()),
            items: [for (final d in districts) DropdownMenuItem(value: d, child: Text(d))],
            onChanged: districts.isEmpty ? null : (district) => setState(() => _district = district),
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

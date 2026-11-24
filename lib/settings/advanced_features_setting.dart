import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class AdvancedFeaturesSetting extends StatelessWidget {
  final AppSettings settings;

  const AdvancedFeaturesSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          '上級機能を表示',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: const Text(
          '統合ツリーや局面検索などの機能を表示します',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        value: settings.showAdvancedFeatures,
        onChanged: (value) => settings.set('showAdvancedFeatures', value),
      ),
    );
  }
}

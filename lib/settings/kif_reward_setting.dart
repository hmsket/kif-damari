import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/reward_ad_manager.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/constants.dart';

class KifRewardSetting extends StatelessWidget {
  final AppSettings settings;

  const KifRewardSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final rawValue = settings.get('kifLimit');
    final kifLimit = (rawValue ?? defaultKifLimit) as int;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          '追加できる棋譜の上限数を増やす',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          '現在の設定: 最大 $kifLimit 個',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          RewardAdManager().loadAd();
          
          showConfirmationDialog(context);
        },
      ),
    );
  }

  void 
  showConfirmationDialog(BuildContext context) {
    final adManager = RewardAdManager();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isReady = adManager.isAdReady;

            Timer? timer;
            if (!isReady) {
              timer = Timer(const Duration(seconds: 1), () {
                if (context.mounted) {
                  setDialogState(() {});
                }
              });
            }

            return AlertDialog(
              title: const Text('棋譜上限数の拡張'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('動画広告を最後まで視聴すると、追加できる棋譜の上限数が1つ増えます。'),
                  if (!isReady) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isReady
                      ? () {
                          timer?.cancel();
                          Navigator.pop(context);
                          _showAdAndGrantReward(context);
                        }
                      : null,
                  child: Text(isReady ? '視聴して増やす' : '広告を準備中...'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdAndGrantReward(BuildContext context) {
    final adManager = RewardAdManager();

    adManager.showAd(
      onRewardEarned: () {
        final rawValue = settings.get('kifLimit');
        final currentLimit = (rawValue ?? defaultKifLimit) as int;
        final newLimit = currentLimit + 1;
        
        settings.set('kifLimit', newLimit);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('棋譜の上限数が $newLimit に増えました！')),
        );
      },
      onFailed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('広告の表示に失敗しました。しばらく経ってから再度お試しください。')),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardAdManager {
  // シングルトンパターンの設定（アプリ内で常に単一のインスタンスを使う）
  static final RewardAdManager _instance = RewardAdManager._internal();
  factory RewardAdManager() => _instance;
  RewardAdManager._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  // 🚨 テスト用のリワード広告ユニットID（Android用）
  final String _adUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // 外部から広告が準備できているか確認するためのゲッター
  bool get isAdReady => _rewardedAd != null;

  // ① 広告のロード
  void loadAd() {
    if (_isAdLoading || _rewardedAd != null) return;

    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          _setAdCallbacks(ad);
          debugPrint('リワード広告の読み込みに成功しました');
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('リワード広告の読み込みに失敗しました: $error');
          _rewardedAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  // 広告のイベントコールバック設定
  void _setAdCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        loadAd(); // 閉じられたら次の広告を自動で事前ロード
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        loadAd(); // 表示失敗時も再ロード
      },
    );
  }

  // ② 広告の表示（引数で「成功した時の処理」と「失敗した時の処理」を関数として受け取る）
  void showAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onFailed,
  }) {
    if (_rewardedAd == null) {
      onFailed();
      loadAd(); // 念のため再ロード
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // 動画を最後まで見終わったので、渡された報酬付与処理を実行
        onRewardEarned();
      },
    );
  }

  // アプリ終了時などに明示的に破棄したい場合
  void dispose() {
    _rewardedAd?.dispose();
  }
}

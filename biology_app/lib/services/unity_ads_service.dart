import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../ads_config.dart';

class UnityAdsService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) {
      return;
    }

    if (kUnityGameIdAndroid.isEmpty ||
        kUnityGameIdAndroid == 'YOUR_UNITY_GAME_ID_ANDROID') {
      debugPrint('⚠️ Unity Ads: не задан kUnityGameIdAndroid');
      return;
    }

    _initialized = true;

    UnityAds.init(
      gameId: kUnityGameIdAndroid,
      testMode: kUnityTestMode,
      onComplete: () {
        debugPrint('✅ Unity Ads initialized');
      },
      onFailed: (error, message) {
        debugPrint('❌ Unity Ads init failed: $error, $message');
        _initialized = false;
      },
    );
  }
}


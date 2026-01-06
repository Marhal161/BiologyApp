import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../ads_config.dart';

/// Сервис для управления межстраничной рекламой Яндекса
class YandexInterstitialAdService {
  static InterstitialAdLoader? _adLoader;
  static Future<InterstitialAdLoader>? _adLoaderFuture;
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoading = false;
  static Completer<bool>? _loadCompleter;

  static Future<InterstitialAdLoader> _getOrCreateLoader() async {
    if (_adLoader != null) return _adLoader!;
    _adLoaderFuture ??= InterstitialAdLoader.create(
      onAdLoaded: (InterstitialAd interstitialAd) {
        _interstitialAd = interstitialAd;
        _isAdLoading = false;
        _loadCompleter?.complete(true);
        _loadCompleter = null;
        debugPrint('✅ Межстраничная реклама Яндекса загружена');

        // Устанавливаем обработчики событий для загруженной рекламы
        _interstitialAd?.setAdEventListener(
          eventListener: InterstitialAdEventListener(
            onAdShown: () {
              debugPrint('👁️ Межстраничная реклама показана');
            },
            onAdFailedToShow: (error) {
              debugPrint('❌ Ошибка показа рекламы: ${error.description}');
              _interstitialAd = null;
              // Попробуем загрузить новую
              loadAd();
            },
            onAdDismissed: () {
              debugPrint('👋 Межстраничная реклама закрыта');
              _interstitialAd = null;
              // Предзагружаем следующую рекламу
              loadAd();
            },
            onAdClicked: () {
              debugPrint('👆 Клик по межстраничной рекламе');
            },
            onAdImpression: (impressionData) {
              debugPrint('📊 Impression: ${impressionData?.getRawData()}');
            },
          ),
        );
      },
      onAdFailedToLoad: (error) {
        _isAdLoading = false;
        _loadCompleter?.complete(false);
        _loadCompleter = null;
        debugPrint(
          '❌ Ошибка загрузки межстраничной рекламы: ${error.description}',
        );
      },
    ).then((loader) {
      _adLoader = loader;
      return loader;
    });

    return _adLoaderFuture!;
  }

  /// Загружает межстраничную рекламу
  static Future<void> loadAd() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('⚠️ Межстраничная реклама доступна только на Android и iOS');
      return;
    }

    if (_isAdLoading) {
      debugPrint('⏳ Реклама уже загружается...');
      return;
    }

    // Определяем какой ID использовать (для тестирования или продакшн)
    String adUnitId;
    if (Platform.isAndroid && kTestYandexOnAndroid) {
      adUnitId = 'demo-interstitial-yandex'; // Демо для тестирования
    } else if (Platform.isIOS) {
      adUnitId = kYandexInterstitialAdUnitId; // Реальный для iOS
    } else {
      // На Android в продакшене пока не показываем (используется VK)
      debugPrint('⚠️ Межстраничная реклама Яндекса на Android только в тестовом режиме');
      return;
    }

    _isAdLoading = true;
    _loadCompleter ??= Completer<bool>();
    debugPrint('🔄 Загрузка межстраничной рекламы...');

    final loader = await _getOrCreateLoader();
    await loader.loadAd(
      adRequestConfiguration: AdRequestConfiguration(adUnitId: adUnitId),
    );
  }

  /// Показывает межстраничную рекламу, если она загружена
  static Future<bool> showAd() async {
    if (_interstitialAd == null) {
      debugPrint('⚠️ Межстраничная реклама еще не загружена');
      return false;
    }

    try {
      await _interstitialAd!.show();
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка показа межстраничной рекламы: $e');
      return false;
    }
  }

  /// Пытается показать межстраничную рекламу, а если она не загружена —
  /// запускает загрузку и ждёт до [timeout].
  static Future<bool> showAfterLoad({Duration timeout = const Duration(seconds: 5)}) async {
    if (_interstitialAd != null) {
      return showAd();
    }

    if (!_isAdLoading) {
      await loadAd();
    }

    final completer = _loadCompleter;
    if (completer == null) {
      return false;
    }

    final loaded = await completer.future.timeout(timeout, onTimeout: () => false);
    if (!loaded || _interstitialAd == null) {
      return false;
    }

    return showAd();
  }

  /// Проверяет, загружена ли реклама
  static bool isAdLoaded() {
    return _interstitialAd != null;
  }

  /// Уничтожает рекламу
  static void dispose() {
    _interstitialAd?.destroy();
    _interstitialAd = null;
    _adLoader?.destroy();
    _adLoader = null;
    _adLoaderFuture = null;
    _isAdLoading = false;
    _loadCompleter = null;
  }
}

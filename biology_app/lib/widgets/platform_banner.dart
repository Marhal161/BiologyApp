import 'dart:io';
import 'package:flutter/material.dart';
import 'vk_banner.dart';
import 'yandex_banner.dart';
import '../ads_config.dart';

/// Виджет для показа рекламы в зависимости от платформы:
/// - Android (RuStore) → VK (myTarget) реклама
/// - iOS (App Store) → Яндекс реклама
class PlatformBanner extends StatelessWidget {
  const PlatformBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      // Android → VK (myTarget) реклама для RuStore
      return const VkBanner(
        slotId: kVkMyTargetSlotId,
        adSize: '320x50',
      );
    } else if (Platform.isIOS) {
      // iOS → Яндекс реклама для App Store
      return const YandexBanner(
        adUnitId: kYandexBannerAdUnitId,
        width: 320,
      );
    } else {
      // Для других платформ (web, desktop) не показываем рекламу
      return const SizedBox.shrink();
    }
  }
}


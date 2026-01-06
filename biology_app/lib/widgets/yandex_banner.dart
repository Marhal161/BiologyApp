import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

class YandexBanner extends StatefulWidget {
  final String adUnitId;
  final int width;

  const YandexBanner({
    super.key,
    required this.adUnitId,
    this.width = 320,
  });

  @override
  State<YandexBanner> createState() => _YandexBannerState();
}

class _YandexBannerState extends State<YandexBanner> {
  BannerAd? _bannerAd;
  int? _calculatedHeight;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    final adSize = BannerAdSize.sticky(width: widget.width);

    // Для sticky размер по высоте вычисляется нативно — без этого виджет часто "режется" снизу.
    try {
      _calculatedHeight = await adSize.getCalculatedHeight();
    } catch (_) {
      _calculatedHeight = 50;
    }

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      adSize: adSize,
      adRequest: const AdRequest(),
      onAdLoaded: () {
        debugPrint('✅ Yandex Banner Ad loaded successfully');
        if (mounted) {
          setState(() {});
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ Yandex Banner Ad failed to load: ${error.description}');
        if (mounted) {
          setState(() {});
        }
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _bannerAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const SizedBox.shrink();
    }

    final height = (_calculatedHeight ?? 50).toDouble();

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: height,
      child: _bannerAd == null
          ? const SizedBox.shrink()
          : AdWidget(bannerAd: _bannerAd!),
    );
  }
}

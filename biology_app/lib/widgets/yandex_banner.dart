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
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      adSize: BannerAdSize.sticky(width: widget.width),
      adRequest: const AdRequest(),
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('Yandex Banner Ad failed to load: ${error.description}');
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
          });
        }
      },
    );
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

    if (!_isAdLoaded || _bannerAd == null) {
      // Показываем placeholder пока реклама загружается
      return Container(
        height: 50,
        color: Colors.transparent,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: 50,
      child: AdWidget(bannerAd: _bannerAd!),
    );
  }
}

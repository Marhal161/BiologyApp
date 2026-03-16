import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../services/unity_ads_service.dart';

class UnityBanner extends StatefulWidget {
  final String placementId;

  const UnityBanner({
    super.key,
    required this.placementId,
  });

  @override
  State<UnityBanner> createState() => _UnityBannerState();
}

class _UnityBannerState extends State<UnityBanner> {
  @override
  void initState() {
    super.initState();
    UnityAdsService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    if (widget.placementId.isEmpty ||
        widget.placementId == 'YOUR_UNITY_BANNER_PLACEMENT_ID') {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: UnityBannerAd(
        placementId: widget.placementId,
        onLoad: (placementId) {
          debugPrint('✅ Unity Banner loaded: $placementId');
        },
        onClick: (placementId) {
          debugPrint('✅ Unity Banner clicked: $placementId');
        },
        onFailed: (placementId, error, message) {
          debugPrint(
            '❌ Unity Banner failed: $placementId, $error, $message',
          );
        },
      ),
    );
  }
}


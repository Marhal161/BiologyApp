import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VkBanner extends StatelessWidget {
  final int slotId;
  final String? adSize; // '320x50', '300x250', '728x90' or null for adaptive
  final bool debug;
  final bool testMode;
  final double? height;
  final double extraHeight; // safety margin to avoid clipping (labels like "18+" may need extra space)

  const VkBanner({
    super.key,
    required this.slotId,
    this.adSize,
    this.debug = false,
    this.testMode = false,
    this.height,
    this.extraHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    final bannerHeight = (height ?? _getHeight(adSize)) + extraHeight;

    // Используем явную высоту, иначе AndroidView может быть обрезан снизу на устройствах с жестами.
    return SizedBox(
      width: double.infinity,
      height: bannerHeight,
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: height ?? _getHeight(adSize),
          child: AndroidView(
            viewType: 'vk_mytarget_banner',
            layoutDirection: TextDirection.ltr,
            creationParams: <String, dynamic>{
              'slotId': slotId,
              if (adSize != null) 'adSize': adSize,
              // Allow forcing debug/test even in release builds during diagnostics.
              'debug': debug || kDebugMode,
              'testMode': testMode,
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
      ),
    );
  }

  double _getHeight(String? size) {
    switch (size) {
      case '300x250':
        return 250;
      case '728x90':
        return 90;
      case '320x50':
        return 50;
      default:
        return 50;
    }
  }
}

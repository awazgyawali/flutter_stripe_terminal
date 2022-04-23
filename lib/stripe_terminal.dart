
import 'dart:async';

import 'package:flutter/services.dart';

class StripeTerminal {
  static const MethodChannel _channel = MethodChannel('stripe_terminal');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}

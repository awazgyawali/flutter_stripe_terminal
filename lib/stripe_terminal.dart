library stripe_terminal;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

part "models/log.dart";
part "utils/strings.dart";
part "models/reader.dart";
part "models/payment_intent.dart";
part 'models/payment_method.dart';
part "models/discover_config.dart";
part "models/collect_configuration.dart";

class StripeTerminal {
  static const MethodChannel _channel = MethodChannel('stripe_terminal');
  Future<String> Function() fetchToken;

  /// Initializes the terminal SDK
  StripeTerminal({
    /// A callback function that returns a Future which resolves to a connection token from your backend
    /// Check out more at https://stripe.com/docs/terminal/payments/setup-integration#connection-token
    required this.fetchToken,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "requestConnectionToken":
          return fetchToken();
        case "onNativeLog":
          _logsStreamController.add(StripeLog(
            code: call.arguments["code"] as String,
            message: call.arguments["message"] as String,
          ));
          break;
        case "onReadersFound":
          List readers = call.arguments;
          _readerStreamController.add(
            readers.map<StripeReader>((e) => StripeReader.fromJson(e)).toList(),
          );
          return fetchToken();
        default:
          return null;
      }
    });
    _channel.invokeMethod("init");
  }

  final StreamController<StripeLog> _logsStreamController =
      StreamController<StripeLog>();

  /// Gives you the native logs of this plugin. If some features are not working for you,
  /// you can listen to the native logs to understand whats going wrong.
  Stream<StripeLog> get onNativeLogs => _logsStreamController.stream;

  /// Connects to a bluetooth reader, only works if you have scanned devices within this session.
  ///
  /// Always run `discoverReaders` before calling this function
  @Deprecated(
    "Please use `connectBluetoothReader` function instead to connect to the bluetooth reader",
  )
  Future<bool> connectToReader(
    String readerSerialNumber, {
    String? locationId,
  }) async {
    bool? connected =
        await _channel.invokeMethod<bool?>("connectBluetoothReader", {
      "locationId": locationId,
      "readerSerialNumber": readerSerialNumber,
    });
    if (connected == null) {
      throw Exception("Unable to connect to the reader");
    } else {
      return connected;
    }
  }

  /// Connects to a bluetooth reader, only works if you have scanned devices within this session.
  ///
  /// Always run `discoverReaders` before calling this function
  Future<bool> connectBluetoothReader(
    String readerSerialNumber, {
    String? locationId,
  }) async {
    bool? connected =
        await _channel.invokeMethod<bool?>("connectBluetoothReader", {
      "locationId": locationId,
      "readerSerialNumber": readerSerialNumber,
    });
    if (connected == null) {
      throw Exception("Unable to connect to the reader");
    } else {
      return connected;
    }
  }

  /// Connects to a internet reader, only works if you have scanned devices within this session.
  ///
  /// Always run `discoverReaders` before calling this function
  Future<bool> connectToInternetReader(
    String readerSerialNumber, {
    bool failIfInUse = false,
  }) async {
    bool? connected =
        await _channel.invokeMethod<bool?>("connectToInternetReader", {
      "failIfInUse": failIfInUse,
      "readerSerialNumber": readerSerialNumber,
    });
    if (connected == null) {
      throw Exception("Unable to connect to the reader");
    } else {
      return connected;
    }
  }

  /// Disconnects from a reader, only works if you are connected to a device
  ///
  /// Always run `connectToReader` before calling this function
  Future<bool> disconnectFromReader() async {
    bool? disconnected =
        await _channel.invokeMethod<bool?>("disconnectFromReader");
    if (disconnected == null) {
      throw Exception("Unable to disconnect from the reader");
    } else {
      return disconnected;
    }
  }

  /// Checks the connection status of the SDK
  Future<ConnectionStatus> connectionStatus() async {
    int? statusId = await _channel.invokeMethod<int>("connectionStatus");
    if (statusId == null) {
      throw Exception("Unable to get connection status");
    } else {
      return ConnectionStatus.values[statusId];
    }
  }

  /// Fetches the connected reader from the SDK. `null` if not connected
  Future<StripeReader?> fetchConnectedReader() async {
    Map? reader = await _channel.invokeMethod<Map>("fetchConnectedReader");
    if (reader == null) {
      return null;
    } else {
      return StripeReader.fromJson(reader);
    }
  }

  /// Extracts payment method from the reader
  ///
  /// Only support `insert` operation on the reader
  Future<StripePaymentMethod> readReusableCardDetail() async {
    Map cardDetail = await _channel.invokeMethod("readReusableCardDetail");
    return StripePaymentMethod.fromJson(cardDetail);
  }

  late StreamController<List<StripeReader>> _readerStreamController;

  /// Starts scanning readers in the vicinity. This will return a list of readers.
  ///
  /// Can contain an empty array if no readers are found.
  ///
  /// [simulated] se to `true` will simulate readers which can be connected and tested.
  Stream<List<StripeReader>> discoverReaders(DiscoverConfig config) {
    _readerStreamController = StreamController<List<StripeReader>>();

    _channel.invokeMethod("discoverReaders#start", {
      "config": config.toMap(),
    });
    _readerStreamController.onCancel = () {
      _channel.invokeMethod("discoverReaders#stop");
      _readerStreamController.close();
    };
    return _readerStreamController.stream;
  }

  /// Starts reading payment method based on payment intent.
  ///
  /// Payment intent is supposed to be generated on your backend and the `clientSecret` of the payment intent
  /// should be passed to this function.
  ///
  /// Once passed, the payment intent will be fetched and the payment method is captured. A sucessful function call
  /// should return an instance of `StripePaymentIntent` with status `requiresPaymentMethod`;
  ///
  /// Only supports `swipe`, `tap` and `insert` method
  Future<StripePaymentIntent> collectPaymentMethod(
    String clientSecret, {
    CollectConfiguration? collectConfiguration = const CollectConfiguration(
      skipTipping: true,
    ),
  }) async {
    Map paymentIntent = await _channel.invokeMethod("collectPaymentMethod", {
      "paymentIntentClientSecret": clientSecret,
      "collectConfiguration": collectConfiguration?.toMap(),
    });

    return StripePaymentIntent.fromMap(paymentIntent);
  }
}

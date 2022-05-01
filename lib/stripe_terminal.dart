library stripe_terminal;

import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';

part "utils/strings.dart";
part "models/reader.dart";
part 'models/payment_method.dart';

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

  /// Connects to a reader, only works if you have scanned devices within this session.
  ///
  /// Always run `discoverReaders` before calling this function
  Future<bool> connectToReader(
    StripeReader reader, {
    String? locationId,
  }) async {
    bool? connected = await _channel.invokeMethod<bool?>("connectToReader", {
      "locationId": locationId,
      "readerSerialNumber": reader.serialNumber,
    });
    if (connected == null) {
      throw Exception("Unable to connect to the reader");
    } else {
      return connected;
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
  Future<StripePaymentMethod> readPaymentMethod() async {
    Map cardDetail = await _channel.invokeMethod("readPaymentMethod");
    return StripePaymentMethod.fromJson(cardDetail);
  }

  final StreamController<List<StripeReader>> _readerStreamController =
      StreamController<List<StripeReader>>();

  /// Starts scanning readers in the vicinity. This will return a list of readers.
  ///
  /// Can contain an empty array if no readers are found.
  ///
  /// [simulated] se to `true` will simulate readers which can be connected and tested.
  Stream<List<StripeReader>> discoverReaders({
    bool simulated = false,
  }) {
    _channel.invokeMethod("discoverReaders#start", {
      "simulated": simulated,
    });
    _readerStreamController.onCancel = () {
      _channel.invokeMethod("discoverReaders#stop");
      _readerStreamController.close();
    };
    return _readerStreamController.stream;
  }
}

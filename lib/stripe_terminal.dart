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
          print("StripeTerminal: onReadersFound $readers");
          _readerStreamController.add(
            readers.map<StripeReader>((e) => StripeReader.fromJson(e)).toList(),
          );

          return fetchToken();
        case "onRequestReaderInput":
          if (call.arguments is String) {
            String requestReaderInput = call.arguments;
            _onRequestReaderInputController.add(requestReaderInput);
          }
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
    String readerSerialNumber, {
    String? locationId,
  }) async {
    bool? connected = await _channel.invokeMethod<bool?>("connectToReader", {
      "locationId": locationId,
      "readerSerialNumber": readerSerialNumber,
    });
    if (connected == null) {
      throw Exception("Unable to connect to the reader");
    } else {
      return connected;
    }
  }

  /// Disconnects from a connected card reader
  Future<bool> disconnectReader() async {
    bool? isDisconnected =
        await _channel.invokeMethod<bool?>("disconnectReader");
    if (isDisconnected != null && isDisconnected) {
      return isDisconnected;
    } else {
      throw Exception("Unable to disconnect from Card Reader");
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

  StreamController<List<StripeReader>> _readerStreamController =
      StreamController<List<StripeReader>>();

  StreamController<String> _onRequestReaderInputController =
      StreamController<String>();

  /// Starts scanning readers in the vicinity. This will return a list of readers.
  ///
  /// Can contain an empty array if no readers are found.
  ///
  /// [simulated] se to `true` will simulate readers which can be connected and tested.
  Stream<List<StripeReader>> discoverReaders({
    bool simulated = false,
  }) {
    print("StripeTerminal: discoverReaders#start");
    _channel.invokeMethod("discoverReaders#start", {
      "simulated": simulated,
    });
    _readerStreamController.onCancel = () {
      print("StripeTerminal: discoverReaders#stop");
      _channel.invokeMethod("discoverReaders#stop");
      _readerStreamController.close();
      _readerStreamController = StreamController<List<StripeReader>>();
    };
    return _readerStreamController.stream;
  }

  /// Starts the whole payment process.
  /// Sends a request to the connected Stripe card reader to swipe card
  Future<Map?> startPaymentProcess(String amount,
      {String? clientSecret}) async {
    Map? response;
    if (clientSecret != null && clientSecret.isNotEmpty) {
      // if clientSecret is passed,
      // start payment process without creating a new paymentIntent from app side
      response = await _channel.invokeMethod<Map>(
          "startPayment", {"amount": amount, "clientSecret": clientSecret});
    } else {
      // Create paymentIntent from app side. Then continue to process the payment
      response = await _channel.invokeMethod<Map>("startPayment", {
        "amount": amount,
      });
    }

    if (response != null &&
        response['isSuccess'] != null &&
        response['isSuccess']) {
      return response;
    } else {
      throw Exception("Payment process failed!");
    }
  }

  /// Starts listening for 'onRequestReaderInput' events.
  ///
  /// e.g. Swipe, Insert, Tap.
  Stream<String> onRequestReaderInputStream({
    bool simulated = false,
  }) {
    _onRequestReaderInputController.onCancel = () {
      _onRequestReaderInputController.close();
      _onRequestReaderInputController = StreamController<String>();
    };
    return _onRequestReaderInputController.stream;
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:stripe_terminal/stripe_terminal.dart';

void main() {
  runApp(
    const MaterialApp(home: MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://localhost:8080/",
    ),
  );

  Future<String> getConnectionString() async {
    // get api call using _dio to get connection token
    Response response = await _dio.get("/connectionToken");
    if (!response.data["success"]) {
      throw Exception(
        "Failed to get connection token because ${response.data["message"]}",
      );
    }

    return response.data["data"];
  }

  late StripeTerminal stripeTerminal;
  @override
  void initState() {
    super.initState();
    stripeTerminal = StripeTerminal(
      fetchToken: getConnectionString,
    );
    stripeTerminal.discoverReaders(simulated: true).listen((readers) {
      setState(() {
        this.readers = readers;
      });
    });
  }

  List<StripeReader>? readers;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Center(
        child: Column(
          children: [
            TextButton(
              child: const Text("Init Stripe"),
              onPressed: () async {
                stripeTerminal = StripeTerminal(
                  fetchToken: getConnectionString,
                );
              },
            ),
            TextButton(
              child: const Text("Get Connection Token"),
              onPressed: () async {
                String connectionToken = await getConnectionString();
                _showSnackbar(connectionToken);
              },
            ),
            TextButton(
              child: const Text("Scan Devices"),
              onPressed: () async {
                stripeTerminal
                    .discoverReaders(simulated: true)
                    .listen((readers) {
                  setState(() {
                    this.readers = readers;
                  });
                });
              },
            ),
            TextButton(
              child: const Text("Connection Status"),
              onPressed: () async {
                stripeTerminal.connectionStatus().then((status) {
                  _showSnackbar("Connection status: ${status.toString()}");
                });
              },
            ),
            TextButton(
              child: const Text("Connected Device"),
              onPressed: () async {
                stripeTerminal
                    .fetchConnectedReader()
                    .then((StripeReader? reader) {
                  _showSnackbar("Connection Device: ${reader?.toJson()}");
                });
              },
            ),
            if (readers != null)
              ...readers!.map(
                (e) => ListTile(
                  title: Text(e.serialNumber),
                  trailing: Text(describeEnum(e.batteryStatus)),
                  leading: Text(e.locationId),
                  onTap: () async {
                    await stripeTerminal.connectToReader(e.serialNumber);
                    _showSnackbar("Connected to a device");
                  },
                  subtitle: Text(describeEnum(e.deviceType)),
                ),
              ),
            TextButton(
              child: const Text("Read Card Detail"),
              onPressed: () async {
                stripeTerminal
                    .readPaymentMethod()
                    .then((StripePaymentMethod paymentMethod) {
                  _showSnackbar(
                    "A card was read: ${paymentMethod.card?.toJson()}",
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        content: Text(
          message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

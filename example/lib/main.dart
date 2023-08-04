import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      // TODO: THIS URL does not work
      baseUrl: "https://deb8-103-163-182-241.in.ngrok.io",
    ),
  );

  Future<String> getConnectionString() async {
    // get api call using _dio to get connection token
    Response response = await _dio.get("/connectionToken");
    if (!(response.data)["success"]) {
      throw Exception(
        "Failed to get connection token because ${response.data["message"]}",
      );
    }

    return (response.data)["data"];
  }

  Future<void> _pushLogs(StripeLog log) async {
    debugPrint(log.code);
    debugPrint(log.message);
  }

  Future<String> createPaymentIntent() async {
    Response invoice = await _dio.post("/createPaymentIntent", data: {
      "email": "awazgyawali@gmail.com",
      "order": {"test": "1"},
      "ticketCount": 3,
      "price": 5,
    });
    return jsonDecode(invoice.data)["paymentIntent"]["client_secret"];
  }

  late StripeTerminal stripeTerminal;
  @override
  void initState() {
    super.initState();
    _initStripe();
  }

  _initStripe() async {
    stripeTerminal = await StripeTerminal.getInstance(
      fetchToken: getConnectionString,
    );
    stripeTerminal.onNativeLogs.listen(_pushLogs);
  }

  bool simulated = true;

  StreamSubscription? _sub;
  List<StripeReader>? readers;
  String? paymentIntentId;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Center(
        child: Column(
          children: [
            ListTile(
              onTap: () {
                setState(() {
                  simulated = !simulated;
                  _initStripe();
                });
              },
              title: const Text("Scanning mode"),
              trailing: Text(simulated ? "Simulator" : "Real"),
            ),
            TextButton(
              child: const Text("Init Stripe"),
              onPressed: () async {
                _initStripe();
              },
            ),
            TextButton(
              child: const Text("Get Connection Token"),
              onPressed: () async {
                String connectionToken = await getConnectionString();
                _showSnackbar(connectionToken);
              },
            ),
            if (_sub == null)
              TextButton(
                child: const Text("Scan Devices"),
                onPressed: () async {
                  setState(() {
                    readers = [];
                  });
                  _sub = stripeTerminal
                      .discoverReaders(
                    DiscoverConfig(
                      discoveryMethod: DiscoveryMethod.bluetooth,
                      simulated: simulated,
                    ),
                  )
                      .listen((readers) {
                    setState(() {
                      this.readers = readers;
                    });
                  });
                },
              ),
            if (_sub != null)
              TextButton(
                child: const Text("Stop Scanning"),
                onPressed: () async {
                  setState(() {
                    _sub?.cancel();
                    _sub = null;
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
                  leading: Text(e.locationId ?? "No Location Id"),
                  onTap: () async {
                    await stripeTerminal
                        .connectToReader(
                      e.serialNumber,
                      locationId: "tml_EoMcZwfY6g8btZ",
                    )
                        .then((value) {
                      _showSnackbar("Connected to a device");
                    }).catchError((e) {
                      if (e is PlatformException) {
                        _showSnackbar(e.message ?? e.code);
                      }
                    });
                  },
                  subtitle: Text(describeEnum(e.deviceType)),
                ),
              ),
            TextButton(
              child: const Text("Read Reusable Card Detail"),
              onPressed: () async {
                stripeTerminal
                    .readReusableCardDetail()
                    .then((StripePaymentMethod paymentMethod) {
                  _showSnackbar(
                    "A card was read: ${paymentMethod.card?.toJson()}",
                  );
                });
              },
            ),
            TextButton(
              child: const Text("Set reader display"),
              onPressed: () async {
                stripeTerminal.setReaderDisplay(
                  ReaderDisplay(
                    type: DisplayType.cart,
                    cart: DisplayCart(
                      currency: "USD",
                      tax: 130,
                      total: 1000,
                      lineItems: [
                        DisplayLineItem(
                          description: "hello 1",
                          quantity: 1,
                          amount: 500,
                        ),
                        DisplayLineItem(
                          description: "hello 2",
                          quantity: 1,
                          amount: 500,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            TextButton(
              child: const Text("Collect Payment Method"),
              onPressed: () async {
                paymentIntentId = await createPaymentIntent();
                stripeTerminal
                    .collectPaymentMethod(paymentIntentId!)
                    .then((StripePaymentIntent paymentIntent) async {
                  _dio.post("/confirmPaymentIntent", data: {
                    "paymentIntentId": paymentIntent.id,
                  });
                  _showSnackbar(
                    "A payment method was captured",
                  );
                });
              },
            ),
            TextButton(
              child: const Text("Misc Button"),
              onPressed: () async {
                StripeReader.fromJson(
                  {
                    "locationStatus": 2,
                    "deviceType": 3,
                    "serialNumber": "STRM26138003393",
                    "batteryStatus": 0,
                    "simulated": false,
                    "availableUpdate": false
                  },
                );
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
        content: Text(
          message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

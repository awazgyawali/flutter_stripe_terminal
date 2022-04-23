import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:stripe_terminal/stripe_terminal.dart';

void main() {
  runApp(const MyApp());
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [
              TextButton(
                child: const Text("Get Connection Token"),
                onPressed: () async {
                  String connectionToken = await getConnectionString();
                },
              ),
              TextButton(
                child: const Text("Test communcation"),
                onPressed: () async {
                  String testMessage = await stripeTerminal.test();
                  print(testMessage);
                },
              ),
              TextButton(
                child: const Text("Scan Devices"),
                onPressed: () async {
                  stripeTerminal.discoverReaders().listen((readers) {
                    print(readers.length);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripe_terminal/stripe_terminal.dart';

void main() {
  const MethodChannel channel = MethodChannel('stripe_terminal');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await StripeTerminal.platformVersion, '42');
  });
}

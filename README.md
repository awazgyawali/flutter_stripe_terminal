# stripe_terminal
[![pub package](https://img.shields.io/pub/v/stripe_terminal.svg)](https://pub.dartlang.org/packages/stripe_terminal)

A flutter plugin to scan stripe readers and connect to the them and get the payment methods.
# Installation

## Android
No Configuration needed, workes  out of the box.

## iOS
You need to provide permission request strings to your `Info.plist` file. A sample content can be

```
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Location access is required in order to accept payments.</string>
	<key>NSBluetoothPeripheralUsageDescription</key>
	<string>Bluetooth access is required in order to connect to supported bluetooth card readers.</string>
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>This app uses Bluetooth to connect to supported card readers.</string>
```
You also need to authorize backround modes authorization for `bluetooth-central`. Paste the following to your `Info.plist` file
```
	<key>UIBackgroundModes</key>
	<array>
		<string>bluetooth-central</string>
	</array>
```

# Usage

- **First initilize the SDK**
```
    stripeTerminal = StripeTerminal(
      fetchToken: () async {
        // Call your backend to get the connection token and return to this function
        // Example token can be.
        const token = "pst_test_XXXXXXXXXX...."; 

        return token;
      },
    );
```

- Example backend code to get the connection token written on node.js:
```
    import Stripe from "stripe";
    import express from "express"

    const stripe = new Stripe("sk_test_XXXXXXXXXXXXXXXXXX", {
        apiVersion: "2020-08-27"
    })

    const app = express();

    app.get("/connectionToken", async (req, res) => {
        const token = await stripe.terminal.connectionTokens.create();
        res.send({
            success: true,
            data: token.secret
        });
    });

    app.post("/createPaymentIntent", async (req, res) => {
        const pi = await stripe.paymentIntents.create({
            amount: 1000,
            currency: "USD",
            capture_method: "manual",
            payment_method_types: ["card_present"]
        })

        res.send({
            success: true,
            paymentIntent: pi
        })
    })

    app.listen(8000, () => {
        console.log("Server started")
    });
```

- **Discover the devices nearby and show it to the user**
```
    stripeTerminal
        .discoverReaders(simulated: true)
        .listen((List<StripeReader> readers) {
            setState(() {
                this.readers = readers;
            });
        });
```

- **Connect to a bluetooth reader**
```
    bool connected = await stripeTerminal.connectBluetoothReader(readers[0].serialNumber);
    if(connected) {
        print("Connected to a device");
    }
``` 

- **Scan a card from the reader**
```
    stripeTerminal
        .readReusableCardDetail()
        .then((StripePaymentMethod paymentMethod) {
            print("A card was read, the last four digit is ${paymentMethod.card?.last4}");
        });
```

- **Scan payment method from the reader using tap, swipe, insert method**
```
    // Get this from your backend by creating a new payment intent
    
    Future<String> createPaymentIntent() async {
        Response invoice = await _dio.post("/createPaymentIntent");
        return invoice.data["paymentIntent"]["client_secret"];
    }

    String payment_intent_client_secret = await createPaymentIntent();

    stripeTerminal
        .collectPaymentMethod(payment_intent_client_secret)
        .then((StripePaymentIntent paymentIntent) {
            print("A payment intent has captured a payment method, send this payment intent to you backend to capture the payment");
        });
```

And you are done!!!!

# Currently supported features:
- Initializing terminal SDK
- Scanning the readers
- Connecting to a device (Only bluetooth devices on android)
- Checking connection status
- Checking connected device
- Read payment method from the device
# Missing Features
- Create payment intent
- Process payment
- Capture payment

# Future Plan
Please feel free to send a PR for further feature as you need or just create an issue on the repo with the feature request. 

I have no plans to maintain this package in the long future thus the package will be deprecated as soon as [flutter_stripe](https://pub.dev/packages/flutter_stripe) adds support to their SDK as mentioned [here](https://github.com/flutter-stripe/flutter_stripe/issues/39#issuecomment-1084191165) 

# Support the creator
Creating software for free takes time and effort thus please consider buying me a cup of coffee. This we definitely put a smile on my face and motivate me to contribute more.

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/aawaz)

[:heart: Sponsor](https://github.com/sponsors/awazgyawali)
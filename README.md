# stripe_terminal

A flutter plugin to scan stripe readers and connect to the devices and get the payment methods.

## Getting Started

### Installation

#### Android
No Configuration needed, workes  out of the box.

#### iOS
You need to provide permission request strings to your `Info.plist` file. A sample content can be

```
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Location access is required in order to accept payments.</string>
	<key>UIBackgroundModes</key>
	<key>NSBluetoothPeripheralUsageDescription</key>
	<string>Bluetooth access is required in order to connect to supported bluetooth card readers.</string>
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>This app uses Bluetooth to connect to supported card readers.</string>
```


You also need to authorize backround modes authorization for `bluetooth-central`. Paste the following to your `Info.plist` file
```
	<array>
		<string>bluetooth-central</string>
	</array>
```


### Usage

- First initilize the SDK
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

- Discover the devices nearby and show it to the user
```
    stripeTerminal
        .discoverReaders(simulated: true)
        .listen((List<StripeReader> readers) {
            setState(() {
                this.readers = readers;
            });
        });
```

- Connect to a reader
```
    bool connected = await stripeTerminal.connectToReader(readers[0]);
    if(connected) {
        print("Connected to a device");
    }
``` 

- Scan a card from the reader
```
    stripeTerminal
        .readPaymentMethod()
        .then((StripePaymentMethod paymentMethod) {
            print("A card was read, the last four digit is ${paymentMethod.card?.last4}");
        });
```

And you are done!!!!
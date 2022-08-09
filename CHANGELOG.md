## 1.4.0
Added `connectToInternetReader` function and deprecated `connecttoReader` instead use `connectToBluetoothReader`
## 1.3.4
`disconnectFromReader` function has been added

## 1.3.3
Once the 'collectPaymentMethod' is called, you need to call `processPayment` with same client_secret to make the payment ready.
Removed `processPayment` function, `collectPaymentMethod` will call it internally.

## 1.3.2
Added support to skipTipping on `collectPaymentMethod` function.
## 1.3.1
**Breaking Change**
Once the 'collectPaymentMethod' is called, you need to call `processPayment` with same client_secret to make the payment ready.
## 1.2.0
**Breaking Change**
Refactored readReusableCardDetail function to only collect card detail using insert method.
Tested with real M2 reader
Added collectPaymentMethod function to collect payment method using NFC and swipe reader
## 1.1.0

Added support for flutter 3.0.0
## 1.0.0+4

Fixed Initilization Issue
## 1.0.0+3

Fixed Stream issue
## 1.0.0+1

Fixed readme and license

## 1.0.0

Inital Release

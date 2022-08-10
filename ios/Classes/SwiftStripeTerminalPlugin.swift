import Flutter
import UIKit
import Foundation
import StripeTerminal

public class SwiftStripeTerminalPlugin: NSObject, FlutterPlugin, DiscoveryDelegate, BluetoothReaderDelegate {
    
    
    let stripeAPIClient: StripeAPIClient
    let methodChannel: FlutterMethodChannel
    var discoverCancelable: Cancelable?
    var readers: [Reader] = []
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "stripe_terminal", binaryMessenger: registrar.messenger())
        let instance = SwiftStripeTerminalPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    
    public init(channel: FlutterMethodChannel) {
        self.methodChannel = channel
        stripeAPIClient = StripeAPIClient(methodChannel: channel)
        Terminal.initialize()
    }
    
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        self.discoverCancelable?.cancel({ error in
            
        })
        
        self.discoverCancelable = nil
        if (Terminal.shared.connectedReader != nil){
            Terminal.shared.disconnectReader { error in
                
            }
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            if(!Terminal.hasTokenProvider()){
                Terminal.setTokenProvider(stripeAPIClient)
            }
            result(nil)
            break;
            
        case "clearReaderDisplay":
            Terminal.shared.clearReaderDisplay { error in
                if(error == nil){
                    result(true)
                } else {
                    result(
                        FlutterError(
                            code: "stripeTerminal#unableToClearDisplay",
                            message: error!.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        case "setReaderDisplay":
            do {
                let arguments = call.arguments as! Dictionary<String, Any>
                let rawReaderDisplay = arguments["readerDisplay"] as! Dictionary<String, Any>
                let dataReaderDisplay = try JSONSerialization.data(withJSONObject: rawReaderDisplay, options: .prettyPrinted)
                let readerDisplay = try? JSONDecoder().decode(ReaderDisplay.self, from: dataReaderDisplay)
                if(readerDisplay == nil) {
                    return result(
                        FlutterError(
                            code: "stripeTerminal#unableToDisplay",
                            message: "Invalid `readerDisplay` value provided",
                            details: nil
                        )
                    )
                }
                
                    
                let cart = Cart(
                    currency: readerDisplay!.cart.currency,
                    tax: readerDisplay!.cart.tax,
                    total: readerDisplay!.cart.total
                )
                    
                readerDisplay?.cart.lineItems.forEach({ item in
                    cart.lineItems.add(CartLineItem(displayName: item.description, quantity: item.quantity, amount: item.amount))
                })

                Terminal.shared.setReaderDisplay(cart) { (error) in
                    if(error == nil){
                        result(true)
                    } else {
                        result(
                            FlutterError(
                                code: "stripeTerminal#unableToDisplay",
                                message: error!.localizedDescription,
                                details: nil
                            )
                        )
                    }
                }
                
            } catch {
                result(
                    FlutterError(
                        code: "stripeTerminal#unableToDisplay",
                        message: "Invalid `readerDisplay` value provided",
                        details: nil
                    )
                )
            }
            break;
        case "discoverReaders#start":
            let arguments = call.arguments as! Dictionary<String, Any>
            let configData = arguments["config"] as! Dictionary<String, Any>
            let simulated = configData["simulated"] as! Bool
            let locationId = configData["locationId"] as? String
            let discoveryMethodString = configData["discoveryMethod"] as! String
            let discoveryMethod = StripeTerminalParser.getScanMethod(discoveryMethod: discoveryMethodString)
            
            if(discoveryMethod == nil){
                return result(
                    FlutterError(
                        code: "stripeTerminal#invalidRequest",
                        message: "`discoveryMethod` is not provided on discoverReaders function",
                        details: nil
                    )
                )
            }
            
            let config = DiscoveryConfiguration(
                discoveryMethod: discoveryMethod!,
                locationId: locationId,
                simulated: simulated
            )
            
            self.discoverCancelable = Terminal.shared.discoverReaders(config, delegate: self) { error in
                if let error = error {
                    result(
                        FlutterError(
                            code: "stripeTerminal#unabelToDiscover",
                            message: "Unable to discover readers because \(error.localizedDescription) ",
                            details: nil
                        )
                    )
                } else {
                    result(true)
                }
            }
            break;
        case "discoverReaders#stop":
            if(self.discoverCancelable == nil){
                result(
                    FlutterError(
                        code: "stripeTerminal#unabelToCancelDiscover",
                        message: "There is no discover action running to stop.",
                        details: nil
                    )
                )
            } else {
                self.discoverCancelable?.cancel({ error in
                    if let error = error {
                        result(
                            FlutterError(
                                code: "stripeTerminal#unabelToCancelDiscover",
                                message: "Unable to stop the discover action because \(error.localizedDescription) ",
                                details: nil
                            )
                        )
                    } else {
                        result(true)
                    }
                })
            }
            self.discoverCancelable = nil;
            break;
        case "fetchConnectedReader":
            result(Terminal.shared.connectedReader?.toDict())
            break;
        case "connectionStatus":
            result(Terminal.shared.connectionStatus.rawValue)
            break;
        case "disconnectFromReader":
            Terminal.shared.disconnectReader { err in
                if(err != nil) {
                    result(
                        FlutterError(
                            code: "stripeTerminal#unableToDisconnect",
                            message: "Unable to disconnect from device because \(err?.localizedDescription)",
                            details: nil
                        )
                    )
                } else {
                    result(true)
                }
                
            }
            break;
            
        case "connectBluetoothReader":
            if(Terminal.shared.connectionStatus == ConnectionStatus.notConnected){
                let arguments = call.arguments as! Dictionary<String, Any>?
                
                let readerSerialNumber = arguments!["readerSerialNumber"] as! String?
                
                let reader = readers.first { reader in
                    return reader.serialNumber == readerSerialNumber
                }
                
                if(reader == nil) {
                    result(
                        FlutterError(
                            code: "stripeTerminal#readerNotFound",
                            message: "Reader with provided serial number no longer exists",
                            details: nil
                        )
                    )
                    return
                }
                
                let locationId = arguments!["locationId"] as? String? ?? reader?.locationId
                
                if(locationId == nil) {
                    result(
                        FlutterError(
                            code: "stripeTerminal#locationNotProvided",
                            message: "Either you have to provide the location id or device should be attached to a location",
                            details: nil
                        )
                    )
                    return
                }
                
                let connectionConfig = BluetoothConnectionConfiguration(
                    locationId: locationId!
                )
                
                Terminal.shared.connectBluetoothReader(reader!, delegate: self, connectionConfig: connectionConfig) { reader, error in
                    if reader != nil {
                        result(true)
                    } else {
                        result(
                            FlutterError(
                                code: "stripeTerminal#unableToConnect",
                                message: error?.localizedDescription,
                                details: nil
                            )
                        )
                    }
                }
                
            } else if(Terminal.shared.connectionStatus == .connecting) {
                result(
                    FlutterError(
                        code: "stripeTerminal#deviceConnecting",
                        message: "A new connection is being established with a device thus you cannot request a new connection at the moment.",
                        details: nil
                    )
                )
            } else {
                result(
                    FlutterError(
                        code: "stripeTerminal#deviceAlreadyConnected",
                        message: "A device with serial number \(Terminal.shared.connectedReader!.serialNumber) is already connected",
                        details: nil
                    )
                )
            }
            break;
        case "connectToInternetReader":
            if(Terminal.shared.connectionStatus == ConnectionStatus.notConnected){
                let arguments = call.arguments as! Dictionary<String, Any>?
                
                let readerSerialNumber = arguments!["readerSerialNumber"] as! String?
                let failIfInUse = arguments!["failIfInUse"] as! Bool?
                
                let reader = readers.first { reader in
                    return reader.serialNumber == readerSerialNumber
                }
                
                if(reader == nil) {
                    result(
                        FlutterError(
                            code: "stripeTerminal#readerNotFound",
                            message: "Reader with provided serial number no longer exists",
                            details: nil
                        )
                    )
                    return
                }
                
                let connectionConfig = InternetConnectionConfiguration(
                    failIfInUse: failIfInUse!
                )
                
                Terminal.shared.connectInternetReader(reader!, connectionConfig: connectionConfig) { reader, error in
                    if reader != nil {
                        result(true)
                    } else {
                        result(
                            FlutterError(
                                code: "stripeTerminal#unableToConnect",
                                message: error?.localizedDescription,
                                details: nil
                            )
                        )
                    }
                }
                
            } else if(Terminal.shared.connectionStatus == .connecting) {
                result(
                    FlutterError(
                        code: "stripeTerminal#deviceConnecting",
                        message: "A new connection is being established with a device thus you cannot request a new connection at the moment.",
                        details: nil
                    )
                )
            } else {
                result(
                    FlutterError(
                        code: "stripeTerminal#deviceAlreadyConnected",
                        message: "A device with serial number \(Terminal.shared.connectedReader!.serialNumber) is already connected",
                        details: nil
                    )
                )
            }
            break;
        case "readReusableCardDetail":
            if(Terminal.shared.connectedReader == nil){
                result(
                    FlutterError(
                        code: "stripeTerminal#deviceNotConnected",
                        message: "You must connect to a device before you can use it.",
                        details: nil
                    )
                )
            } else {
                let params =  ReadReusableCardParameters()
                Terminal.shared.readReusableCard(params) { paymentMethod, error in
                    if(paymentMethod != nil){
                        result(paymentMethod?.originalJSON)
                    } else {
                        result(
                            FlutterError(
                                code: "stripeTerminal#unabletToReadCardDetail",
                                message: "Device was not able to read payment method details.",
                                details: nil
                            )
                        )
                    }
                }
            }
            break;
        case "collectPaymentMethod":
            if(Terminal.shared.connectedReader == nil){
                result(
                    FlutterError(
                        code: "stripeTerminal#deviceNotConnected",
                        message: "You must connect to a device before you can use it.",
                        details: nil
                    )
                )
                return
            }
            
            let arguments = call.arguments as! Dictionary<String, Any>?
            
            let paymentIntentClientSecret = arguments!["paymentIntentClientSecret"] as! String?
            
            if (paymentIntentClientSecret == nil) {
                result(
                    FlutterError(
                        code:   "stripeTerminal#invalidPaymentIntentClientSecret",
                        message:  "The payment intent client_secret seems to be invalid or missing.",
                        details:   nil
                    )
                )
                return
            }
            
            let collectConfiguration = arguments!["collectConfiguration"] as! Dictionary<String, Any>?
            let collectConfig = CollectConfiguration(skipTipping: collectConfiguration!["skipTipping"] as! Bool)
            Terminal.shared.retrievePaymentIntent(clientSecret: paymentIntentClientSecret!) { paymentIntent, error in
                if let error = error {
                    result(
                        FlutterError(
                            code: "stripeTerminal#unableToRetrivePaymentIntent",
                            message: "Stripe was not able to fetch the payment intent with the provided client secret. \(error.localizedDescription)",
                            details: nil
                        )
                    )
                } else {
                    Terminal.shared.collectPaymentMethod(paymentIntent!, collectConfig: collectConfig) { paymentIntent, error in
                        if let error = error {
                            result(
                                FlutterError(
                                    code: "stripeTerminal#unableToCollectPaymentMethod",
                                    message: "Stripe reader was not able to collect the payment method for the provided payment intent.  \(error.localizedDescription)",
                                    details: nil
                                )
                            )
                        } else {
                            self.generateLog(code: "collectPaymentMethod", message: paymentIntent!.originalJSON.description)
                            Terminal.shared.processPayment(paymentIntent!) { paymentIntent, error in
                                if let error = error {
                                    result(
                                        FlutterError(
                                            code: "stripeTerminal#unableToProcessPayment",
                                            message: "Stripe reader was not able to process the payment for the provided payment intent.  \(error.localizedDescription)",
                                            details: nil
                                        )
                                    )
                                } else {
                                    self.generateLog(code: "processPayment", message: paymentIntent!.originalJSON.description)
                                    result(paymentIntent?.originalJSON)
                                }
                            }
                        }
                    }
                }
            }
            break;
        default:
            result(
                FlutterError(
                    code: "stripeTerminal#unsupportedFunctionCall",
                    message: "A method call of name \(call.method) is not supported by the plugin.",
                    details: nil
                )
            )
        }
    }
    
    public func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        self.readers = readers;
        let parsedReaders = readers.map { reader -> Dictionary<String, Any> in
            return reader.toDict()
        }
        
        methodChannel.invokeMethod("onReadersFound", arguments: parsedReaders)
    }
    
    public func reader(_ reader: Reader, didReportAvailableUpdate update: ReaderSoftwareUpdate) {
        
    }
    
    public func reader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {
        
    }
    
    public func reader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {
        
    }
    
    public func reader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: Error?) {
        
    }
    
    public func reader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions = []) {
        
    }
    
    public func reader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {
        
    }
    
    private func generateLog(code: String, message: String) {
        var log: Dictionary<String, String> = Dictionary<String, String>()
        
        log["code"] = code
        log["message"] = message
        
        methodChannel.invokeMethod("onNativeLog", arguments: log)
    }
}


extension Reader{
    func toDict()-> Dictionary<String, Any>{
        var dict =  Dictionary<String, Any>()
        dict["serialNumber"] = self.serialNumber
        dict["originalJSON"] = self.originalJSON
        dict["availableUpdate"] = self.availableUpdate != nil
        dict["batteryLevel"] = self.batteryLevel
        dict["batteryStatus"] = self.batteryStatus.rawValue
        dict["deviceSoftwareVersion"] = self.deviceSoftwareVersion
        dict["deviceType"] = self.deviceType.rawValue
        dict["locationId"] = self.locationId
        dict["ipAddress"] = self.ipAddress
        dict["isCharging"] = self.isCharging
        dict["label"] = self.label
        dict["locationStatus"] = self.locationStatus.rawValue
        dict["stripeId"] = self.stripeId
        dict["simulated"] = self.simulated
        return dict;
    }
}

extension PaymentMethod {
    func toDict()->Dictionary<String, Any> {
        var dict =  Dictionary<String, Any>()
        dict["card"] = card?.toDict()
        dict["id"] = stripeId
        return dict;
    }
}

extension CardDetails {
    func toDict() ->Dictionary<String, Any>{
        var dict =  Dictionary<String, Any>()
        dict["brand"] = self.brand
        dict["country"] = self.country
        dict["expMonth"] = self.expMonth
        dict["expYear"] = self.expYear
        dict["fingerprint"] = self.fingerprint
        dict["last4"] = self.last4
        dict["funding"] = self.funding.rawValue
        return dict;
    }
}

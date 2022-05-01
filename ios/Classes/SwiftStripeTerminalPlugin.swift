import Flutter
import UIKit
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
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            Terminal.setTokenProvider(stripeAPIClient)
            result(nil)
            break;
        case "discoverReaders#start":
            let arguments = call.arguments as! Dictionary<String, Any>
            let simulated = arguments["simulated"] as! Bool
            let config = DiscoveryConfiguration(
                discoveryMethod: .bluetoothScan,
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
            
        case "connectToReader":
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
        case "readPaymentMethod":
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

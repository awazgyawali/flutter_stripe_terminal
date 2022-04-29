import Flutter
import UIKit
import StripeTerminal

public class SwiftStripeTerminalPlugin: NSObject, FlutterPlugin, DiscoveryDelegate, BluetoothReaderDelegate {
    
    
    let stripeAPIClient: StripeAPIClient
    let methodChannel: FlutterMethodChannel
    var discoverCancelable: Cancelable?
    
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
            let config = DiscoveryConfiguration(
                discoveryMethod: .bluetoothScan,
                simulated: true
            )
            
            self.discoverCancelable = Terminal.shared.discoverReaders(config, delegate: self) { error in
                if let error = error {
                    result("Unable to discover readers because \(error.localizedDescription)")
                } else {
                    result(nil)
                }
            }
            break;
        case "discoverReaders#stop":
            self.discoverCancelable?.cancel({ error in
                if let error = error {
                    result("Unable to stop discovering readers because \(error.localizedDescription)")
                } else {
                    result(nil)
                }
            })
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
                
                let locationId = arguments!["locationId"] as? String?
                let readerJson = arguments!["reader"] as! Dictionary<String, Any>?
                
                let reader = Reader.decodedObject(fromJSON: readerJson)
                
                let connectionConfig = BluetoothConnectionConfiguration(
                    locationId: locationId ?? reader!.locationId!
                )
                
                Terminal.shared.connectBluetoothReader(reader!, delegate: self, connectionConfig: connectionConfig) { reader, error in
                    if reader != nil {
                        result(true)
                    } else {
                        result(false)
                    }
                }
                
            } else {
                result(false)
            }
            
            break;
            
        case "readCardDetail":
            let params =  ReadReusableCardParameters()
            
            Terminal.shared.readReusableCard(params) { paymentMethod, error in
                if(paymentMethod != nil){
                    result(paymentMethod?.card?.toDict())
                } else {
                    result("Unable to read card detail.")
                }
            }
            break;
        default:
            print("Unsupported function called")
        }
    }
    
    public func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
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

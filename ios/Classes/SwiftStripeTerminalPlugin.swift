import Flutter
import UIKit
import StripeTerminal

public class SwiftStripeTerminalPlugin: NSObject, FlutterPlugin, DiscoveryDelegate {
    
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
        default:
            print("Unsupported function called")
        }
    }
    
    public func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        let parsedReaders = readers.map { reader -> Dictionary<String, Any> in
            var dict =  Dictionary<String, Any>()
            dict["serialNumber"] = reader.serialNumber
            dict["originalJSON"] = reader.originalJSON
            dict["availableUpdate"] = reader.availableUpdate
            dict["batteryLevel"] = reader.batteryLevel
            dict["batteryStatus"] = reader.batteryStatus
            dict["deviceSoftwareVersion"] = reader.deviceSoftwareVersion
            dict["deviceType"] = reader.deviceType
            dict["locationId"] = reader.locationId
            dict["ipAddress"] = reader.ipAddress
            dict["isCharging"] = reader.isCharging
            dict["label"] = reader.label
            dict["locationStatus"] = reader.locationStatus
            dict["stripeId"] = reader.stripeId
            dict["simulated"] = reader.simulated
            return dict
            
        }
        methodChannel.invokeMethod("onReadersFound", arguments: parsedReaders)
    }
}

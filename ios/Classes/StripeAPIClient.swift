import Foundation
import StripeTerminal

class StripeAPIClient: ConnectionTokenProvider {
    let methodChannel: FlutterMethodChannel
    
    init(methodChannel: FlutterMethodChannel){
        self.methodChannel = methodChannel
    }

    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        methodChannel.invokeMethod("requestConnectionToken", arguments: nil) { secret in
            completion(secret as! String?, nil)
        };
    }
}

import Foundation
import StripeTerminal

class APIClient: ConnectionTokenProvider {

    // For simplicity, this example class is a singleton
    static let shared = APIClient()

    static let backendUrl = URL(string: "http://localhost:4242")!

    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let url = URL(string: "/connection_token", relativeTo: APIClient.backendUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let task = session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                do {
                    // Warning: casting using 'as? [String: String]' looks simpler, but isn't safe:
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let secret = json?["secret"] as? String {
                        completion(secret, nil)
                    } else {
                        let error = NSError(domain: "com.stripe-terminal-ios.example",
                                            code: 2000,
                                            userInfo: [NSLocalizedDescriptionKey: "Missing 'secret' in ConnectionToken JSON response"])
                        completion(nil, error)
                    }
                } catch {
                    completion(nil, error)
                }
            } else {
                let error = NSError(domain: "com.stripe-terminal-ios.example",
                                    code: 1000,
                                    userInfo: [NSLocalizedDescriptionKey: "No data in response from ConnectionToken endpoint"])
                completion(nil, error)
            }
        }

        task.resume()
    }
    func capturePaymentIntent(_ paymentIntentId: String, completion: @escaping ErrorCompletionBlock) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: OperationQueue.main)
        let url = URL(string: "/capture_payment_intent", relativeTo: APIClient.backendUrl)!

        let parameters = "{\"payment_intent_id\": \"\(paymentIntentId)\"}"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = parameters.data(using: .utf8)

        let task = session.dataTask(with: request) {(data, response, error) in
            if let response = response as? HTTPURLResponse, let data = data {
                switch response.statusCode {
                case 200..<300:
                    completion(nil)
                case 402:
                    let description = String(data: data, encoding: .utf8) ?? "Failed to capture payment intent"
                    completion(NSError(domain: "com.stripe-terminal-ios.example", code: 2, userInfo: [NSLocalizedDescriptionKey: description]))
                default:
                    completion(error ?? NSError(domain: "com.stripe-terminal-ios.example", code: 0, userInfo: [NSLocalizedDescriptionKey: "Other networking error encountered."]))
                }
            } else {
                completion(error)
            }
        }
        task.resume()
    }
}

//
//  StripeTerminalParser.swift
//  stripe_terminal
//
//  Created by Aawaz Gyawali on 08/08/2022.
//

import Foundation
import StripeTerminal

class StripeTerminalParser {
    
    static func getScanMethod(discoveryMethod: String) -> DiscoveryMethod? {
        switch(discoveryMethod){
        case "bluetooth":
            return DiscoveryMethod.bluetoothScan;
        case "internet":
            return DiscoveryMethod.internet;
        default:
            return nil;
        }
    }
}

//
//  ContentView.swift
//  swiftyapp
//
//  Created by Jonathan McKenzie on 7/9/24.
//

import SwiftUI
import RustyLib

private let sampleTransactionHex = """
01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022100f16703104aab4e4088317c862daec83440242411b039d14280e03dd33b487ab802201318a7be236672c5c56083eb7a5a195bc57a40af7923ff8545016cd3b571e2a601232103c40e5d339df3f30bf753e7e04450ae4ef76c9e45587d1d993bdc4cd06f0651c7acffffffff0000000000
"""

private let sampleBlockHex = """
010000006fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d6190000000000982051fd1e4ba744bbbe680e1fee14677ba1a3c3540bf7b1cdb606e857233e0e61bc6649ffff001d01e362990101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff0704ffff001d0104ffffffff0100f2052a0100000043410496b538e853519c726a2c91e61ec11600ae1390813a627c66fb8be7947be63c52da7589379515d4e0a604f8141781e62294721166bf621e73a82cbf2342c858eeac00000000
"""

struct ContentView: View {
    var body: some View {
        print("ContentView: body property accessed.")
        let helloMessage = rustHello()
        let sum = rustAdd(a: 10, b: 32)
        let transactionSummary = transactionSummaryHex(rawHex: sampleTransactionHex)
        let blockSummary = blockSummaryHex(rawHex: sampleBlockHex)
        print("ContentView: rustHello() returned \(helloMessage)")
        print("ContentView: rustAdd(a: 10, b: 32) returned \(sum)")
        return VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(helloMessage)
            Text(String(sum))
            Text(transactionSummary.map { "tx \($0.txid) (\($0.inputCount) in, \($0.outputCount) out)" } ?? "tx summary unavailable")
            Text(blockSummary.map { "block \($0.blockHash) (\($0.transactionCount) txs)" } ?? "block summary unavailable")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

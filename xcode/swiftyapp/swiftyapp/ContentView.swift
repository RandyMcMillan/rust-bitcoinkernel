import Foundation
import SwiftUI
import RustyLib

private enum MempoolNetwork: String, CaseIterable, Identifiable {
    case mainnet
    case testnet
    case testnet4
    case signet
    case regtest

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var recentTransactionsURL: URL? {
        switch self {
        case .mainnet:
            URL(string: "https://mempool.space/api/mempool/recent")
        case .testnet:
            URL(string: "https://mempool.space/testnet/api/mempool/recent")
        case .testnet4:
            URL(string: "https://mempool.space/testnet4/api/mempool/recent")
        case .signet:
            URL(string: "https://mempool.space/signet/api/mempool/recent")
        case .regtest:
            nil
        }
    }
}

private struct RecentMempoolTransaction: Codable, Identifiable {
    let txid: String
    let fee: Int
    let vsize: Int
    let value: Int

    var id: String { txid }
}

private enum RecentMempoolStorage {
    static func key(for network: MempoolNetwork) -> String {
        "mempool.recent.\(network.rawValue)"
    }

    static func load(for network: MempoolNetwork) -> [RecentMempoolTransaction] {
        guard let data = UserDefaults.standard.data(forKey: key(for: network)) else {
            return []
        }

        return (try? JSONDecoder().decode([RecentMempoolTransaction].self, from: data)) ?? []
    }

    static func save(_ transactions: [RecentMempoolTransaction], for network: MempoolNetwork) {
        guard let data = try? JSONEncoder().encode(transactions) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(for: network))
    }
}

struct ContentView: View {
    @State private var selectedNetwork = MempoolNetwork.mainnet
    @State private var recentTransactions: [RecentMempoolTransaction] = []
    @State private var loadingRecentTransactions = false
    @State private var recentTransactionsError: String?

    var body: some View {
        let helloMessage = rustHello()
        let sum = rustAdd(a: 10, b: 32)
        return VStack(alignment: .leading, spacing: 12) {
            Picker("Network", selection: $selectedNetwork) {
                ForEach(MempoolNetwork.allCases) { network in
                    Text(network.displayName).tag(network)
                }
            }
            .pickerStyle(.segmented)
            Text("Selected: \(selectedNetwork.displayName)")
            Text(helloMessage)
            Text(String(sum))
            Group {
                if loadingRecentTransactions {
                    Text("Loading recent mempool transactions...")
                } else if let recentTransactionsError {
                    Text(recentTransactionsError)
                } else if recentTransactions.isEmpty {
                    Text("No recent transactions loaded.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(recentTransactions) { transaction in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.txid)
                                        .font(.caption.monospaced())
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("fee \(transaction.fee) sat/vB  vsize \(transaction.vsize)  value \(transaction.value)")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .task(id: selectedNetwork) {
            await loadRecentTransactions()
        }
    }

    @MainActor
    private func loadRecentTransactions() async {
        guard let url = selectedNetwork.recentTransactionsURL else {
            loadingRecentTransactions = false
            recentTransactions = []
            recentTransactionsError = "No public mempool feed for \(selectedNetwork.displayName)."
            return
        }

        loadingRecentTransactions = true
        recentTransactionsError = nil
        recentTransactions = RecentMempoolStorage.load(for: selectedNetwork)

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let transactions = try JSONDecoder().decode([RecentMempoolTransaction].self, from: data)
            recentTransactions = transactions
            RecentMempoolStorage.save(transactions, for: selectedNetwork)
        } catch {
            if recentTransactions.isEmpty {
                recentTransactionsError = "Failed to load recent transactions: \(error.localizedDescription)"
            } else {
                recentTransactionsError = "Showing cached data: \(error.localizedDescription)"
            }
        }

        loadingRecentTransactions = false
    }
}

#Preview {
    ContentView()
}

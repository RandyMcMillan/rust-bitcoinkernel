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

private struct TransactionDetailView: View {
    let transaction: RecentMempoolTransaction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailRow(title: "Txid", value: transaction.txid)
                detailRow(title: "Fee", value: "\(transaction.fee) sat/vB")
                detailRow(title: "Virtual size", value: "\(transaction.vsize) vB")
                detailRow(title: "Value", value: "\(transaction.value) sats")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Transaction")
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
        return NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("bitcoinkernal")
                            .font(.title.bold())
                            .foregroundStyle(.primary)
                        Text("Live Bitcoin data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Network", selection: $selectedNetwork) {
                        ForEach(MempoolNetwork.allCases) { network in
                            Text(network.displayName).tag(network)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Selected network")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selectedNetwork.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(helloMessage)
                            .foregroundStyle(.primary)
                        Text(String(sum))
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        if loadingRecentTransactions {
                            Text("Loading recent mempool transactions...")
                                .foregroundStyle(.secondary)
                        } else if let recentTransactionsError {
                            Text(recentTransactionsError)
                                .foregroundStyle(.secondary)
                        } else if recentTransactions.isEmpty {
                            Text("No recent transactions loaded.")
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 12) {
                                    ForEach(recentTransactions) { transaction in
                                        NavigationLink {
                                            TransactionDetailView(transaction: transaction)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(transaction.txid)
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(.primary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                Text("fee \(transaction.fee) sat/vB  vsize \(transaction.vsize)  value \(transaction.value)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("Tap for details")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color(.secondarySystemGroupedBackground))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .scrollIndicators(.hidden)
                            }
                        }
                    }
                }
                .padding()
                .navigationTitle("Mempool")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: selectedNetwork) {
            await loadRecentTransactions()
        }
    }

    @MainActor
    private func loadRecentTransactions() async {
        guard let url = selectedNetwork.recentTransactionsURL else {
            loadingRecentTransactions = false
            recentTransactions = []
            recentTransactionsError = "No public bitcoinkernal feed for \(selectedNetwork.displayName)."
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

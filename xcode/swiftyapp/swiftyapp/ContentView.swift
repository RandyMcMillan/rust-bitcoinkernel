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

    var recentTransactionsURLs: [URL] {
        switch self {
        case .mainnet:
            return [
                URL(string: "https://mempool.space/api/mempool/recent"),
                URL(string: "https://bitcoin.gob.sv/api/mempool/recent"),
                URL(string: "https://blockstream.info/api/mempool/recent"),
            ].compactMap { $0 }
        case .testnet:
            return [
                URL(string: "https://mempool.space/testnet/api/mempool/recent"),
                URL(string: "https://blockstream.info/testnet/api/mempool/recent"),
            ].compactMap { $0 }
        case .testnet4:
            return [
                URL(string: "https://mempool.space/testnet4/api/mempool/recent"),
            ].compactMap { $0 }
        case .signet:
            return [
                URL(string: "https://mempool.space/signet/api/mempool/recent"),
                URL(string: "https://blockstream.info/signet/api/mempool/recent"),
            ].compactMap { $0 }
        case .regtest:
            return []
        }
    }

    func transactionDetailURLs(txid: String) -> [URL] {
        switch self {
        case .mainnet:
            return [
                URL(string: "https://mempool.space/api/tx/\(txid)"),
                URL(string: "https://bitcoin.gob.sv/api/tx/\(txid)"),
                URL(string: "https://blockstream.info/api/tx/\(txid)"),
            ].compactMap { $0 }
        case .testnet:
            return [
                URL(string: "https://mempool.space/testnet/api/tx/\(txid)"),
                URL(string: "https://blockstream.info/testnet/api/tx/\(txid)"),
            ].compactMap { $0 }
        case .testnet4:
            return [
                URL(string: "https://mempool.space/testnet4/api/tx/\(txid)"),
            ].compactMap { $0 }
        case .signet:
            return [
                URL(string: "https://mempool.space/signet/api/tx/\(txid)"),
                URL(string: "https://blockstream.info/signet/api/tx/\(txid)"),
            ].compactMap { $0 }
        case .regtest:
            return []
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

private struct TransactionDetail: Decodable {
    struct Prevout: Decodable {
        let value: Int
        let scriptpubkeyAddress: String?

        private enum CodingKeys: String, CodingKey {
            case value
            case scriptpubkeyAddress = "scriptpubkey_address"
        }
    }

    struct Input: Decodable {
        let txid: String
        let vout: Int
        let prevout: Prevout?
    }

    struct Output: Decodable, Identifiable {
        let value: Int
        let scriptpubkeyAddress: String?

        var id: String { "\(value)-\(scriptpubkeyAddress ?? "unknown")" }

        private enum CodingKeys: String, CodingKey {
            case value
            case scriptpubkeyAddress = "scriptpubkey_address"
        }
    }

    struct Status: Decodable {
        let confirmed: Bool
        let blockHeight: Int?
        let blockHash: String?
        let blockTime: Int?

        private enum CodingKeys: String, CodingKey {
            case confirmed
            case blockHeight = "block_height"
            case blockHash = "block_hash"
            case blockTime = "block_time"
        }
    }

    let txid: String
    let version: Int
    let locktime: Int
    let vin: [Input]
    let vout: [Output]
    let size: Int
    let weight: Int
    let sigops: Int?
    let fee: Int
    let status: Status
}

private struct TransactionDetailView: View {
    let transaction: RecentMempoolTransaction
    let network: MempoolNetwork
    @State private var detail: TransactionDetail?
    @State private var detailError: String?
    @State private var loadingDetail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard(title: "Transaction", subtitle: "Live mempool entry") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transaction.txid)
                            .font(.body.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        if loadingDetail {
                            Text("Loading more transaction data...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let detailError {
                            Text(detailError)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                sectionCard(title: "Metrics", subtitle: "What matters at a glance") {
                    VStack(alignment: .leading, spacing: 10) {
                        detailRow(title: "Fee rate", value: "\(transaction.fee) sat/vB")
                        detailRow(title: "Virtual size", value: "\(transaction.vsize) vB")
                        detailRow(title: "Value", value: "\(transaction.value) sats")
                        if let detail {
                            detailRow(title: "Version", value: "\(detail.version)")
                            detailRow(title: "Locktime", value: "\(detail.locktime)")
                            detailRow(title: "Size", value: "\(detail.size) bytes")
                            detailRow(title: "Weight", value: "\(detail.weight)")
                            detailRow(title: "Inputs", value: "\(detail.vin.count)")
                            detailRow(title: "Outputs", value: "\(detail.vout.count)")
                            if let sigops = detail.sigops {
                                detailRow(title: "Sigops", value: "\(sigops)")
                            }
                        }
                    }
                }

                if let detail {
                    sectionCard(title: "Status", subtitle: "Confirmation and chain data") {
                        VStack(alignment: .leading, spacing: 10) {
                            detailRow(title: "Confirmed", value: detail.status.confirmed ? "Yes" : "No")
                            if let blockHeight = detail.status.blockHeight {
                                detailRow(title: "Block height", value: "\(blockHeight)")
                            }
                            if let blockHash = detail.status.blockHash {
                                detailRow(title: "Block hash", value: blockHash)
                            }
                            if let blockTime = detail.status.blockTime {
                                detailRow(title: "Block time", value: "\(blockTime)")
                            }
                        }
                    }
                }

                if let detail {
                    sectionCard(title: "Inputs & outputs", subtitle: "Expanded transaction flow") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Inputs")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                ForEach(detail.vin.indices, id: \.self) { index in
                                    let input = detail.vin[index]
                                    Text("\(index + 1). \(input.txid):\(input.vout) \(input.prevout?.scriptpubkeyAddress ?? "unknown")")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Outputs")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                ForEach(detail.vout) { output in
                                    Text("\(output.value) sats \(output.scriptpubkeyAddress ?? "no address")")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Transaction")
        .task(id: transaction.txid) {
            await pollTransactionDetail()
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func pollTransactionDetail() async {
        let urls = network.transactionDetailURLs(txid: transaction.txid)
        guard !urls.isEmpty else {
            detailError = "No public transaction detail feed for \(network.displayName)."
            return
        }

        loadingDetail = true

        while !Task.isCancelled {
            await refreshTransactionDetail(urls: urls)

            do {
                try await Task.sleep(nanoseconds: recentTransactionsPollIntervalSeconds * 1_000_000_000)
            } catch {
                break
            }
        }
    }

    @MainActor
    private func refreshTransactionDetail(urls: [URL]) async {
        var lastError: Error?

        for url in urls {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                detail = try JSONDecoder().decode(TransactionDetail.self, from: data)
                detailError = nil
                lastError = nil
                loadingDetail = false
                return
            } catch {
                lastError = error
            }
        }

        if let lastError {
            if detail == nil {
                detailError = "Failed to load transaction details: \(lastError.localizedDescription)"
            } else {
                detailError = "Showing cached detail while retrying: \(lastError.localizedDescription)"
            }
        }

        loadingDetail = false
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

private enum RecentMempoolSourceStorage {
    static func key(for network: MempoolNetwork) -> String {
        "mempool.source.index.\(network.rawValue)"
    }

    static func loadIndex(for network: MempoolNetwork, sourceCount: Int) -> Int {
        guard sourceCount > 0 else { return 0 }
        return UserDefaults.standard.integer(forKey: key(for: network)).clamped(to: 0..<(sourceCount))
    }

    static func saveIndex(_ index: Int, for network: MempoolNetwork) {
        UserDefaults.standard.set(index, forKey: key(for: network))
    }
}

private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound - 1)
    }
}

private let recentTransactionsPollIntervalSeconds: UInt64 = 20

struct ContentView: View {
    @State private var selectedNetwork = MempoolNetwork.mainnet
    @State private var recentTransactions: [RecentMempoolTransaction] = []
    @State private var loadingRecentTransactions = false
    @State private var recentTransactionsError: String?
    @State private var recentTransactionsSourceLabel: String?

    var body: some View {
        let helloMessage = rustHello()
        let sum = rustAdd(a: 10, b: 32)
        return NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        Section {
                            VStack(alignment: .leading, spacing: 16) {
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
                                        LazyVStack(alignment: .leading, spacing: 12) {
                                            ForEach(recentTransactions) { transaction in
                                                NavigationLink {
                                                    TransactionDetailView(transaction: transaction, network: selectedNetwork)
                                                } label: {
                                                    VStack(alignment: .leading, spacing: 10) {
                                                        HStack(alignment: .firstTextBaseline) {
                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text("Transaction")
                                                                    .font(.headline)
                                                                    .foregroundStyle(.primary)
                                                                Text(transaction.txid)
                                                                    .font(.caption.monospaced())
                                                                    .foregroundStyle(.secondary)
                                                                    .fixedSize(horizontal: false, vertical: true)
                                                            }
                                                            Spacer(minLength: 12)
                                                            Text("Open")
                                                                .font(.caption.bold())
                                                                .foregroundStyle(.white)
                                                                .padding(.horizontal, 10)
                                                                .padding(.vertical, 6)
                                                                .background(
                                                                    Capsule(style: .continuous)
                                                                        .fill(Color.accentColor)
                                                                )
                                                        }

                                                        HStack(spacing: 12) {
                                                            infoPill(title: "Fee", value: "\(transaction.fee) sat/vB")
                                                            infoPill(title: "Size", value: "\(transaction.vsize) vB")
                                                            infoPill(title: "Value", value: "\(transaction.value) sats")
                                                        }
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
                                    }
                                }
                            }
                        } header: {
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
                                    Text("Live data with rotating fallback sources")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if let recentTransactionsSourceLabel {
                                        Text(recentTransactionsSourceLabel)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )

                                Divider()
                            }
                            .padding()
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                    .padding()
                }
                .navigationTitle("Mempool")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: selectedNetwork) {
            await pollRecentTransactions()
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    @MainActor
    private func pollRecentTransactions() async {
        let urls = selectedNetwork.recentTransactionsURLs
        guard !urls.isEmpty else {
            loadingRecentTransactions = false
            recentTransactions = []
            recentTransactionsError = "No public bitcoinkernal feed for \(selectedNetwork.displayName)."
            return
        }

        recentTransactions = RecentMempoolStorage.load(for: selectedNetwork)

        while !Task.isCancelled {
            await refreshRecentTransactions(urls: urls)

            do {
                try await Task.sleep(nanoseconds: recentTransactionsPollIntervalSeconds * 1_000_000_000)
            } catch {
                break
            }
        }
    }

    @MainActor
    private func refreshRecentTransactions(urls: [URL]) async {
        loadingRecentTransactions = true
        recentTransactionsError = nil
        recentTransactionsSourceLabel = nil

        let startIndex = RecentMempoolSourceStorage.loadIndex(for: selectedNetwork, sourceCount: urls.count)
        var lastError: Error?

        for offset in 0..<urls.count {
            let index = (startIndex + offset) % urls.count
            let url = urls[index]

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let transactions = try JSONDecoder().decode([RecentMempoolTransaction].self, from: data)
                recentTransactions = transactions
                RecentMempoolStorage.save(transactions, for: selectedNetwork)
                RecentMempoolSourceStorage.saveIndex((index + 1) % urls.count, for: selectedNetwork)
                recentTransactionsSourceLabel = "Loaded from \(url.host ?? "mempool source")."
                lastError = nil
                break
            } catch {
                lastError = error
            }
        }

        if let lastError, recentTransactions.isEmpty {
            recentTransactionsError = "Failed to load recent transactions: \(lastError.localizedDescription)"
            recentTransactionsSourceLabel = nil
        } else if let lastError {
            recentTransactionsError = "Showing cached data: \(lastError.localizedDescription)"
            recentTransactionsSourceLabel = "Cached data while fallback sources retry."
        } else if recentTransactions.isEmpty == false {
            recentTransactionsError = nil
        }

        loadingRecentTransactions = false
    }
}

#Preview {
    ContentView()
}

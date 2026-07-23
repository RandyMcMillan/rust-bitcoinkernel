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

    func transactionHexURLs(txid: String) -> [URL] {
        switch self {
        case .mainnet:
            return [
                URL(string: "https://mempool.space/api/tx/\(txid)/hex"),
                URL(string: "https://bitcoin.gob.sv/api/tx/\(txid)/hex"),
                URL(string: "https://blockstream.info/api/tx/\(txid)/hex"),
            ].compactMap { $0 }
        case .testnet:
            return [
                URL(string: "https://mempool.space/testnet/api/tx/\(txid)/hex"),
                URL(string: "https://blockstream.info/testnet/api/tx/\(txid)/hex"),
            ].compactMap { $0 }
        case .testnet4:
            return [
                URL(string: "https://mempool.space/testnet4/api/tx/\(txid)/hex"),
            ].compactMap { $0 }
        case .signet:
            return [
                URL(string: "https://mempool.space/signet/api/tx/\(txid)/hex"),
                URL(string: "https://blockstream.info/signet/api/tx/\(txid)/hex"),
            ].compactMap { $0 }
        case .regtest:
            return []
        }
    }

    func transactionPageURL(txid: String) -> URL? {
        switch self {
        case .mainnet:
            return URL(string: "https://mempool.space/tx/\(txid)")
                ?? URL(string: "https://blockstream.info/tx/\(txid)")
        case .testnet:
            return URL(string: "https://mempool.space/testnet/tx/\(txid)")
                ?? URL(string: "https://blockstream.info/testnet/tx/\(txid)")
        case .testnet4:
            return URL(string: "https://mempool.space/testnet4/tx/\(txid)")
        case .signet:
            return URL(string: "https://mempool.space/signet/tx/\(txid)")
                ?? URL(string: "https://blockstream.info/signet/tx/\(txid)")
        case .regtest:
            return nil
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
    let network: MempoolNetwork
    @State private var detail: TransactionRelations?
    @State private var detailError: String?
    @State private var loadingDetail = false
    @State private var selectedInputDetail: InputSelection?
    @State private var selectedOutputDetail: OutputSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard(title: "Transaction", subtitle: "Live mempool entry") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transaction.txid)
                            .font(.headline.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        if loadingDetail {
                            Text("Loading more transaction data from Rust...")
                                .font(.body)
                                .foregroundStyle(.primary)
                        } else if let detailError {
                            Text(detailError)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                sectionCard(title: "Metrics", subtitle: "") {
                    VStack(alignment: .leading, spacing: 10) {
                        detailRow(title: "Fee rate", value: "\(transaction.fee) sat/vB")
                        detailRow(title: "Virtual size", value: "\(transaction.vsize) vB")
                        detailRow(title: "Value", value: "\(transaction.value) sats")
                        if let detail {
                            detailRow(title: "Inputs", value: "\(detail.inputCount)")
                            detailRow(title: "Outputs", value: "\(detail.outputCount)")
                            detailRow(title: "Serialized size", value: "\(detail.serializedLen) bytes")
                        }
                    }
                }

                if let detail {
                    sectionCard(title: "Inputs", subtitle: "Outpoints this transaction spends") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(detail.inputs.enumerated()), id: \.offset) { _, input in
                                Button {
                                    selectedInputDetail = InputSelection(input: input)
                                } label: {
                                    if input.isCoinbase {
                                        inputCard(title: "Coinbase input", sequence: input.sequence) {
                                            Text("No previous output")
                                                .font(.body.monospaced())
                                                .foregroundStyle(.primary)
                                        }
                                    } else {
                                        inputCard(title: "Input", sequence: input.sequence) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(input.txid):\(input.vout)")
                                                    .font(.body.monospaced())
                                                    .foregroundStyle(.primary)
                                                Text("Tap to load related data")
                                                    .font(.body)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    sectionCard(title: "Outputs", subtitle: "Resulting value flow") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(detail.outputs.enumerated()), id: \.offset) { _, output in
                                Button {
                                    selectedOutputDetail = OutputSelection(output: output)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("#\(output.index) \(output.value) sats")
                                            .font(.body.monospaced())
                                            .foregroundStyle(.primary)
                                        Text(output.scriptPubkeyHex)
                                            .font(.body.monospaced())
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                        Text("Tap for output details")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.systemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
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
        .sheet(item: $selectedInputDetail) { selection in
            NavigationStack {
                InputTransactionDetailView(input: selection.input, network: network)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                selectedInputDetail = nil
                            }
                        }
                    }
            }
        }
        .sheet(item: $selectedOutputDetail) { selection in
            NavigationStack {
                OutputTransactionDetailView(output: selection.output, txid: transaction.txid)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                selectedOutputDetail = nil
                            }
                        }
                    }
            }
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
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.body)
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
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inputCard<Content: View>(
        title: String,
        sequence: UInt64,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text("sequence \(sequence)")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    @MainActor
    private func pollTransactionDetail() async {
        let urls = network.transactionHexURLs(txid: transaction.txid)
        guard !urls.isEmpty else {
            detailError = "No public transaction hex feed for \(network.displayName)."
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
                let hex = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                detail = transactionRelationsHex(rawHex: hex)
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
                detailError = "Failed to load transaction hex: \(lastError.localizedDescription)"
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

private struct InputSelection: Identifiable {
    let id = UUID()
    let input: TransactionInputSummary
}

private struct OutputSelection: Identifiable {
    let id = UUID()
    let output: TransactionOutputSummary
}

private struct InputTransactionDetailView: View {
    let input: TransactionInputSummary
    let network: MempoolNetwork
    @State private var detail: TransactionRelations?
    @State private var detailError: String?
    @State private var loadingDetail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard(
                    title: input.isCoinbase ? "Coinbase input" : "Input",
                    subtitle: "Referenced transaction data"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(input.isCoinbase ? "No previous transaction" : "\(input.txid):\(input.vout)")
                            .font(.headline.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        Text("sequence \(input.sequence)")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)

                        if loadingDetail {
                            Text("Loading related transaction data...")
                                .font(.body)
                                .foregroundStyle(.primary)
                        } else if let detailError {
                            Text(detailError)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                if let detail {
                    sectionCard(title: "Related inputs", subtitle: "Inputs from the referenced transaction") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(detail.inputs.enumerated()), id: \.offset) { _, relatedInput in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(relatedInput.isCoinbase ? "Coinbase input" : "\(relatedInput.txid):\(relatedInput.vout)")
                                        .font(.body.monospaced())
                                        .foregroundStyle(.primary)
                                    Text("sequence \(relatedInput.sequence)")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.systemBackground))
                                )
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
        .navigationTitle("Input Detail")
        .task(id: input.txid) {
            await pollRelatedTransaction()
        }
    }

    @MainActor
    private func pollRelatedTransaction() async {
        guard !input.isCoinbase else {
            loadingDetail = false
            detail = nil
            detailError = "Coinbase inputs do not reference a previous transaction."
            return
        }

        let urls = network.transactionHexURLs(txid: input.txid)
        guard !urls.isEmpty else {
            detailError = "No public transaction hex feed for \(network.displayName)."
            return
        }

        loadingDetail = true

        while !Task.isCancelled {
            await refreshRelatedTransaction(urls: urls)

            do {
                try await Task.sleep(nanoseconds: recentTransactionsPollIntervalSeconds * 1_000_000_000)
            } catch {
                break
            }
        }
    }

    @MainActor
    private func refreshRelatedTransaction(urls: [URL]) async {
        var lastError: Error?

        for url in urls {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let hex = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                detail = transactionRelationsHex(rawHex: hex)
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
                detailError = "Failed to load related transaction data: \(lastError.localizedDescription)"
            } else {
                detailError = "Showing cached detail while retrying: \(lastError.localizedDescription)"
            }
        }

        loadingDetail = false
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.body)
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
}

private struct OutputTransactionDetailView: View {
    let output: TransactionOutputSummary
    let txid: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard(title: "Output", subtitle: "Transaction result") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction \(txid)")
                            .font(.headline.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        Text("#\(output.index)")
                            .font(.body.monospaced())
                            .foregroundStyle(.primary)
                        Text("\(output.value) sats")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(output.scriptPubkeyHex)
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Output Detail")
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.body)
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
                                Group {
                                    if loadingRecentTransactions {
                                        Text("Loading recent mempool transactions...")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                    } else if let recentTransactionsError {
                                        Text(recentTransactionsError)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                    } else if recentTransactions.isEmpty {
                                        Text("No recent transactions loaded.")
                                            .font(.body)
                                            .foregroundStyle(.primary)
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
                                                                    .font(.title3.bold())
                                                                    .foregroundStyle(.primary)
                                                                Text(transaction.txid)
                                                                    .font(.body.monospaced())
                                                                    .foregroundStyle(.primary)
                                                                    .fixedSize(horizontal: false, vertical: true)
                                                            }
                                                            Spacer(minLength: 12)
                                                            //Text("Open")
                                                            //    .font(.body.bold())
                                                            //    .foregroundStyle(.white)
                                                            //    .padding(.horizontal, 10)
                                                            //    .padding(.vertical, 6)
                                                            //    .background(
                                                            //        Capsule(style: .continuous)
                                                            //            .fill(Color.accentColor)
                                                            //    )
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
                                    Text("rust-bitcoinkernal/xcode: swift ffi")
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
                .font(.body)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
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
                recentTransactionsSourceLabel = nil //"Loaded from \(url.host ?? "mempool source")."
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

import OSLog
import UnadlyCore
import WebKit

/// Loads the bundled ad-server list and compiles it into WebKit content rule lists.
/// WebKit then blocks matching requests inside the engine, for every page and frame,
/// before they leave the Mac. Compiled lists are cached by WebKit across launches, so
/// only the first launch (or a new list) pays the compile cost.
@MainActor
final class AdBlocker {
    static let shared = AdBlocker()

    enum State: Equatable {
        case loading
        case ready(hostCount: Int)
        case failed
    }

    private(set) var state: State = .loading
    private(set) var ruleLists: [WKContentRuleList] = []
    private var waiters: [@MainActor () -> Void] = []

    private static let identifierPrefix = "unadly."
    private let logger = Logger(subsystem: "com.salahu01.unadly", category: "AdBlocker")

    private init() {}

    var hostCount: Int {
        if case let .ready(count) = state { return count }
        return 0
    }

    /// Runs `body` once rule lists are ready (or failed). Runs immediately if already done.
    func whenReady(_ body: @escaping @MainActor () -> Void) {
        if state == .loading { waiters.append(body) } else { body() }
    }

    func load() {
        Task { await loadRuleLists() }
    }

    private func loadRuleLists() async {
        guard let store = WKContentRuleListStore.default() else {
            logger.error("Content rule list store unavailable")
            return finish(.failed, lists: [])
        }

        let list: HostList
        do {
            list = try await Task.detached(priority: .userInitiated) { try Self.bundledHostList() }.value
        } catch {
            logger.error("Could not read bundled ad list: \(error.localizedDescription, privacy: .public)")
            return finish(.failed, lists: [])
        }

        let version = list.fingerprint
        let chunks = ContentRules.chunks(of: list.hosts)
        var wanted: [(id: String, json: @Sendable () throws -> String)] = chunks.enumerated().map { index, hosts in
            ("\(Self.identifierPrefix)hosts.\(version).\(index)", { try ContentRules.blockingRules(for: hosts) })
        }
        wanted.append(("\(Self.identifierPrefix)cosmetic.\(version)", { try ContentRules.cosmeticRules() }))

        var compiled: [WKContentRuleList] = []
        for item in wanted {
            if let list = try? await store.contentRuleList(forIdentifier: item.id) {
                compiled.append(list)
                continue
            }
            do {
                let json = try await Task.detached(priority: .userInitiated) { try item.json() }.value
                if let list = try await store.compileContentRuleList(forIdentifier: item.id, encodedContentRuleList: json) {
                    compiled.append(list)
                }
            } catch {
                logger.error("Compiling \(item.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        await removeStaleLists(in: store, keeping: Set(wanted.map(\.id)))
        finish(compiled.isEmpty ? .failed : .ready(hostCount: list.hosts.count), lists: compiled)
        logger.info("Ad blocking ready: \(list.hosts.count) hosts in \(compiled.count) rule lists")
    }

    /// Deletes rule lists compiled from older versions of the ad list.
    private func removeStaleLists(in store: WKContentRuleListStore, keeping current: Set<String>) async {
        let existing = await store.availableIdentifiers() ?? []
        for id in existing where id.hasPrefix(Self.identifierPrefix) && !current.contains(id) {
            try? await store.removeContentRuleList(forIdentifier: id)
        }
    }

    private func finish(_ state: State, lists: [WKContentRuleList]) {
        self.state = state
        ruleLists = lists
        let pending = waiters
        waiters = []
        pending.forEach { $0() }
    }

    private nonisolated static func bundledHostList() throws -> HostList {
        guard let url = Bundle.main.url(forResource: "adhosts", withExtension: "txt") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return HostList(parsing: try String(contentsOf: url, encoding: .utf8))
    }
}

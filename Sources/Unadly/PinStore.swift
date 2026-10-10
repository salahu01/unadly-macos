import Combine
import Foundation
import UnadlyCore

/// Pinned sites, shared by every window and saved in the app's preferences.
@MainActor
final class PinStore: ObservableObject {
    static let shared = PinStore()

    @Published private(set) var list: PinList

    private let defaults: UserDefaults
    private let key = "pins.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(PinList.self, from: data) {
            list = saved
        } else {
            list = PinList()
        }
    }

    var pins: [Pin] { list.pins }

    func contains(_ url: URL) -> Bool { list.contains(url) }
    func add(_ url: URL) { update { $0.add(url) } }
    func remove(_ url: URL) { update { $0.remove(url) } }
    func toggle(_ url: URL) { update { $0.toggle(url) } }

    private func update(_ change: (inout PinList) -> Void) {
        change(&list)
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: key) }
    }
}

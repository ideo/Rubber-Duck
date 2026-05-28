// DuckMap — Chip MAC → DuckID assignment, loaded from JSON.
//
// Real Bambu Duck firmware opens <relay>/ws/duck with an `X-Duck-Id: <MAC>`
// header (see bambu/firmware/main/agent.c). Stage maps that MAC to one of
// the four boy-band slots via a config file. See
// boyband/docs/duck-id-mapping.md for the rationale and venue workflow.
//
// File format (boyband/duck-map.local.json):
//   {
//     "A0B7657ECC10": "D1",
//     "A0B7657ECCE4": "D2",
//     "A0B7657FA38C": "D3",
//     "A0B7657FB504": "D4"
//   }
//
// Lookups are case-insensitive; MACs are normalized to UPPERCASE on load.

import Foundation

struct DuckMap: Sendable {
    private let macToDuck: [String: DuckID]

    init(macToDuck: [String: DuckID]) {
        // Normalize keys to uppercase, no separators.
        var normalized: [String: DuckID] = [:]
        for (k, v) in macToDuck {
            normalized[Self.normalize(k)] = v
        }
        self.macToDuck = normalized
    }

    /// Load from a JSON file at `path`. Returns nil if the file doesn't
    /// exist or is unparseable. Errors are logged to stderr.
    static func load(from path: String) -> DuckMap? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            fputs("[duck-map] \(path): expected JSON object of MAC → slot strings\n", stderr)
            return nil
        }
        var parsed: [String: DuckID] = [:]
        for (mac, slot) in raw {
            guard let duck = DuckID.parse(slot) else {
                fputs("[duck-map] \(path): \(mac) → \"\(slot)\" is not a valid DuckID (D1..D4)\n", stderr)
                continue
            }
            parsed[mac] = duck
        }
        return DuckMap(macToDuck: parsed)
    }

    /// Resolve a chip MAC to a slot, or nil if unmapped.
    func lookup(mac: String) -> DuckID? {
        macToDuck[Self.normalize(mac)]
    }

    /// All mapped MACs (for diagnostics).
    var allEntries: [(mac: String, duck: DuckID)] {
        macToDuck.map { ($0.key, $0.value) }
            .sorted { $0.1.rawValue < $1.1.rawValue }
    }

    /// Strip non-hex chars, uppercase. "a0:b7:65:7e:cc:10" → "A0B7657ECC10".
    private static func normalize(_ mac: String) -> String {
        mac.uppercased().filter { $0.isHexDigit }
    }
}

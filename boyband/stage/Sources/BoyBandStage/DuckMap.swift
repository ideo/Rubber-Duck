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
    /// Optional friendly name per slot (e.g. D1 → "Mallard"). Shown in logs.
    private let duckToName: [DuckID: String]

    init(macToDuck: [String: DuckID], names: [DuckID: String] = [:]) {
        // Normalize keys to uppercase, no separators.
        var normalized: [String: DuckID] = [:]
        for (k, v) in macToDuck {
            normalized[Self.normalize(k)] = v
        }
        self.macToDuck = normalized
        self.duckToName = names
    }

    /// Load from a JSON file at `path`. Returns nil if the file doesn't
    /// exist or is unparseable. Errors are logged to stderr.
    ///
    /// Each value may be EITHER a bare slot string ("D1") or an object
    /// {"slot": "D1", "name": "Mallard"}. Both forms can be mixed. Keys
    /// starting with "_" are ignored (so you can keep _comment fields).
    static func load(from path: String) -> DuckMap? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fputs("[duck-map] \(path): expected a JSON object keyed by MAC\n", stderr)
            return nil
        }
        var parsed: [String: DuckID] = [:]
        var names: [DuckID: String] = [:]
        for (mac, value) in raw {
            if mac.hasPrefix("_") { continue }
            var slotStr: String?
            var nameStr: String?
            if let s = value as? String {
                slotStr = s
            } else if let obj = value as? [String: Any] {
                slotStr = obj["slot"] as? String
                nameStr = obj["name"] as? String
            }
            guard let slotStr, let duck = DuckID.parse(slotStr) else {
                fputs("[duck-map] \(path): \(mac) has no valid slot (D1..D4) — skipped\n", stderr)
                continue
            }
            parsed[mac] = duck
            if let nameStr { names[duck] = nameStr }
        }
        return DuckMap(macToDuck: parsed, names: names)
    }

    /// Resolve a chip MAC to a slot, or nil if unmapped.
    func lookup(mac: String) -> DuckID? {
        macToDuck[Self.normalize(mac)]
    }

    /// Friendly name for a slot, if one was configured.
    func name(for duck: DuckID) -> String? {
        duckToName[duck]
    }

    /// All mapped MACs (for diagnostics).
    var allEntries: [(mac: String, duck: DuckID, name: String?)] {
        macToDuck.map { ($0.key, $0.value, duckToName[$0.value]) }
            .sorted { $0.1.rawValue < $1.1.rawValue }
    }

    /// Strip non-hex chars, uppercase. "a0:b7:65:7e:cc:10" → "A0B7657ECC10".
    private static func normalize(_ mac: String) -> String {
        mac.uppercased().filter { $0.isHexDigit }
    }
}

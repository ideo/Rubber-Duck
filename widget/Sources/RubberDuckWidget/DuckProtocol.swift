// Duck Protocol — Typed message definitions for all cross-boundary communication.
//
// Every message that flows between widget ↔ service (WebSocket) or
// widget → Teensy (serial) is defined here as a Codable struct.
// This is the single source of truth for the wire protocol.

import Foundation

// MARK: - Eval Scores (shared across all layers)

struct EvalScores: Codable, Equatable {
    let creativity: Double
    let soundness: Double
    let ambition: Double
    let elegance: Double
    let risk: Double
    let reaction: String?
    let summary: String?      // Factual summary (relay mode)
    var voice: String?        // Wildcard voice key (AI-picked, Haiku only for now)

    /// Weighted sentiment score combining all dimensions.
    /// Positive = good code, negative = concerning code.
    var sentiment: Double {
        soundness * 0.3 + elegance * 0.25 + creativity * 0.2 + ambition * 0.15 - risk * 0.1
    }
}

// MARK: - Enums

enum EvalSource: String, Codable {
    case user
    case claude
}

enum PermissionStatus: String, Codable {
    case pending
    case allow
    case deny
    case timeout
}

/// Top-level duck mode. Mutually exclusive — only one runs at a time.
/// Behavior nuance (chattiness, mic) lives in `DuckEnergy` and the mic toggle,
/// not here. Selecting `.walkieTalkie` auto-launches the tmux'd CLI session.
enum DuckMode: String, CaseIterable {
    case companion       // Normal floating-duck experience
    case walkieTalkie    // Experimental: launches CLI in tmux for voice control

    /// Human-readable label for menus and TTS.
    var label: String {
        switch self {
        case .companion: return "Companion"
        case .walkieTalkie: return "Walkie-Talkie (Experimental)"
        }
    }

    /// SF Symbol name for this mode.
    var iconName: String {
        switch self {
        case .companion: return "figure.2.left.holdinghands"
        case .walkieTalkie: return "flask.fill"
        }
    }

    /// Full-sentence description for menus, settings, and tooltips.
    /// Used as NSMenuItem.subtitle, Settings caption text, and right-click
    /// menu tooltip (.help).
    var subtitle: String {
        switch self {
        case .companion:
            return "Ducky floats on your desktop, reacts to your work, and alerts you to permission requests."
        case .walkieTalkie:
            return "Talk to Claude CLI by voice in a tmux session. Walkie-talkie style. Experimental."
        }
    }

    /// TTS-friendly label.
    var spokenLabel: String {
        switch self {
        case .companion: return "Companion mode"
        case .walkieTalkie: return "Walkie-talkie mode"
        }
    }
}

/// How talkative + active the duck is. One dial governing speech chattiness
/// today (and motion taper post-v0.10). Independent of mic and mode.
enum DuckEnergy: String, CaseIterable {
    case normal   // Full reactions + full motion
    case shy      // Tapered: less frequent reactions + Bambu motion taper
    case zen      // Permissions only — no reaction chatter; rare motion

    /// Human-readable label for menus and TTS.
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .shy: return "Shy"
        case .zen: return "Zen"
        }
    }

    /// SF Symbol name.
    var iconName: String {
        switch self {
        case .normal: return "bubble.left.and.bubble.right.fill"
        case .shy: return "bubble.left"
        case .zen: return "leaf.fill"
        }
    }

    /// Full-sentence description for menus, settings, and tooltips.
    var subtitle: String {
        switch self {
        case .normal:
            return "Comments and reactions all day. Full motion."
        case .shy:
            return "Tapered reactions with restraint. Calmer motion."
        case .zen:
            return "Permission alerts only — no reaction chatter. Rare motion."
        }
    }

    /// TTS-friendly label.
    var spokenLabel: String {
        switch self {
        case .normal: return "Normal energy"
        case .shy: return "Shy"
        case .zen: return "Zen"
        }
    }

    /// Whether reactions/opinions are spoken at this energy level.
    /// `.zen` silences them entirely; `.shy` lets them through but the
    /// chattiness limiter (Step 2) reduces frequency.
    var speaksReactions: Bool { self != .zen }
}

// MARK: - Inbound Messages (service → widget via WebSocket)

/// Eval result broadcast from the service.
struct EvalResult: Codable {
    let type: String        // "eval"
    let timestamp: String?
    let source: String?     // "user" or "claude"
    let textPreview: String?
    let sessionId: String?
    let scores: EvalScores?

    enum CodingKeys: String, CodingKey {
        case type, timestamp, source, scores
        case textPreview = "text_preview"
        case sessionId = "session_id"
    }
}

/// Permission event broadcast from the service.
struct PermissionEvent: Codable {
    let type: String        // "permission"
    let status: String?
    let toolName: String?
    let toolInput: String?
    let optionLabels: [String]?
    let actionSummary: String?  // TTS-friendly description of what the tool wants to do

    enum CodingKeys: String, CodingKey {
        case type, status
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case optionLabels = "option_labels"
        case actionSummary = "action_summary"
    }
}

/// Discriminated union for all inbound WebSocket messages.
/// Decodes via the "type" field to route to the correct payload.
enum InboundMessage {
    case eval(EvalResult)
    case permission(PermissionEvent)
    case unknown(String)
}

extension InboundMessage {
    /// Decode a raw JSON string into a typed message.
    static func decode(from text: String) -> InboundMessage? {
        guard let data = text.data(using: .utf8) else { return nil }

        // Peek at the "type" field to pick the right variant
        struct TypePeek: Decodable { let type: String? }
        guard let peek = try? JSONDecoder().decode(TypePeek.self, from: data) else {
            return nil
        }

        let decoder = JSONDecoder()
        switch peek.type {
        case "eval":
            guard let msg = try? decoder.decode(EvalResult.self, from: data) else { return nil }
            return .eval(msg)
        case "permission":
            guard let msg = try? decoder.decode(PermissionEvent.self, from: data) else { return nil }
            return .permission(msg)
        default:
            return .unknown(peek.type ?? "nil")
        }
    }
}

// MARK: - Outbound Messages (widget → service via WebSocket)

/// Voice input command — inject text into Claude Code via tmux.
struct VoiceInputCommand: Encodable {
    let command = "voice_input"
    let text: String
}

/// Permission response — approve or deny Claude's action.
struct PermissionResponseCommand: Encodable {
    let command = "permission_response"
    let decision: String          // "allow" or "deny"
    let suggestionIndex: Int?     // 1-based, nil for simple allow/deny

    enum CodingKeys: String, CodingKey {
        case command, decision
        case suggestionIndex = "suggestion_index"
    }
}

/// Helper to encode any outbound command to a JSON string.
enum OutboundMessage {
    case voiceInput(VoiceInputCommand)
    case permissionResponse(PermissionResponseCommand)

    func encode() -> String? {
        let encoder = JSONEncoder()
        let data: Data?
        switch self {
        case .voiceInput(let cmd):
            data = try? encoder.encode(cmd)
        case .permissionResponse(let cmd):
            data = try? encoder.encode(cmd)
        }
        guard let d = data else { return nil }
        return String(data: d, encoding: .utf8)
    }
}

// MARK: - Transport Protocols

/// How the widget talks to the eval service (currently WebSocket, future: MCP).
protocol EvalTransport: AnyObject {
    var isConnected: Bool { get }
    var onMessage: ((InboundMessage) -> Void)? { get set }

    func connect()
    func disconnect()
    func send(_ message: OutboundMessage)
}

/// How the widget talks to the hardware duck (currently serial, future: BLE/network).
protocol DeviceTransport: AnyObject {
    var isConnected: Bool { get }
    var deviceName: String { get }
    var onLineReceived: ((String) -> Void)? { get set }
    /// Fired when the transport connects or disconnects (e.g. USB hot-plug).
    var onConnectionChange: (() -> Void)? { get set }

    func connect()
    func disconnect()
    func sendScores(_ message: SerialScoreMessage)
    func sendCommand(_ command: String)
}

// MARK: - Serial Messages (widget → Teensy)

/// Score message formatted for the Teensy serial protocol.
/// Wire format: "{U|C},creativity,soundness,ambition,elegance,risk\n"
struct SerialScoreMessage {
    let scores: EvalScores
    let source: EvalSource

    /// Encode to the Teensy wire format.
    var wireFormat: String {
        let srcChar = source == .user ? "U" : "C"
        return String(format: "%@,%.2f,%.2f,%.2f,%.2f,%.2f\n",
                      srcChar,
                      scores.creativity,
                      scores.soundness,
                      scores.ambition,
                      scores.elegance,
                      scores.risk)
    }
}

// PreferencesView — Settings window (⌘,) using macOS System Settings pattern.
//
// NavigationSplitView sidebar + grouped Form content area.
// Intelligence picker, API key management, voice preferences, and about info.

import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @EnvironmentObject var speechService: SpeechService

    enum Tab: String, CaseIterable, Identifiable {
        case intelligence = "Intelligence"
        case voice = "Voice"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .intelligence: return "brain.head.profile"
            case .voice: return "waveform"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selectedTab: Tab = .intelligence

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .frame(width: 20)
                            Text(tab.rawValue)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 170)

            Divider()

            // Detail
            Group {
                switch selectedTab {
                case .intelligence:
                    IntelligencePane()
                case .voice:
                    VoicePane(speechService: speechService)
                case .about:
                    AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 420)
    }
}

// MARK: - Intelligence Pane

private struct IntelligencePane: View {
    private let accent = Color(red: 0.925, green: 0.725, blue: 0.278)

    @State private var evalProvider = DuckConfig.evalProvider
    @State private var anthropicKey = DuckConfig.anthropicAPIKey
    @State private var geminiKey = DuckConfig.geminiAPIKey
    @State private var hasAnthropicKey = !DuckConfig.anthropicAPIKey.isEmpty
    @State private var hasGeminiKey = !DuckConfig.geminiAPIKey.isEmpty
    @State private var editingAnthropicKey = false
    @State private var editingGeminiKey = false

    var body: some View {
        Form {
            Section("Provider") {
                providerRow(.foundation, icon: "apple.logo",
                            title: "Apple Foundation Models",
                            subtitle: "On-device, free, sub-second")

                providerRow(.anthropic, icon: "brain.head.profile",
                            title: "Claude Haiku",
                            subtitle: "Anthropic API, higher quality scoring")

                providerRow(.gemini, icon: "sparkles",
                            title: "Gemini",
                            subtitle: "Google API, alternative cloud scoring")
            }

            Section("API Keys") {
                apiKeyRow(label: "Anthropic",
                          hasKey: hasAnthropicKey,
                          isEditing: $editingAnthropicKey,
                          key: $anthropicKey,
                          onSave: {
                              DuckConfig.saveAPIKey(anthropicKey)
                              hasAnthropicKey = true
                              editingAnthropicKey = false
                          },
                          onClear: {
                              DuckConfig.removeAPIKey()
                              anthropicKey = ""
                              hasAnthropicKey = false
                              editingAnthropicKey = false
                          })

                apiKeyRow(label: "Gemini",
                          hasKey: hasGeminiKey,
                          isEditing: $editingGeminiKey,
                          key: $geminiKey,
                          onSave: {
                              DuckConfig.saveGeminiAPIKey(geminiKey)
                              hasGeminiKey = true
                              editingGeminiKey = false
                          },
                          onClear: {
                              DuckConfig.removeGeminiAPIKey()
                              geminiKey = ""
                              hasGeminiKey = false
                              editingGeminiKey = false
                          })
            }

            if hasAnthropicKey || hasGeminiKey {
                Section {
                    Button(role: .destructive) {
                        DuckConfig.removeAPIKey()
                        DuckConfig.removeGeminiAPIKey()
                        anthropicKey = ""; geminiKey = ""
                        hasAnthropicKey = false; hasGeminiKey = false
                        evalProvider = .foundation
                        DuckConfig.evalProvider = .foundation
                    } label: {
                        Label("Clear All Keys", systemImage: "trash")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func providerRow(_ provider: DuckConfig.EvalProvider, icon: String, title: String, subtitle: String) -> some View {
        Button {
            evalProvider = provider
            DuckConfig.evalProvider = provider
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 24)
                    .foregroundStyle(evalProvider == provider ? accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(evalProvider == provider ? .semibold : .regular)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if evalProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func apiKeyRow(label: String, hasKey: Bool, isEditing: Binding<Bool>,
                           key: Binding<String>,
                           onSave: @escaping () -> Void,
                           onClear: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                if hasKey && !isEditing.wrappedValue {
                    Text("••••••••")
                        .foregroundStyle(.secondary)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("Edit") { isEditing.wrappedValue = true }
                        .buttonStyle(.borderless)
                } else if !hasKey && !isEditing.wrappedValue {
                    Text("Not set")
                        .foregroundStyle(.tertiary)
                    Button("Add") { isEditing.wrappedValue = true }
                        .buttonStyle(.borderless)
                }
            }

            if isEditing.wrappedValue {
                HStack(spacing: 6) {
                    SecureField("Paste API key", text: key)
                        .textFieldStyle(.roundedBorder)
                    Button("Save", action: onSave)
                        .disabled(key.wrappedValue.isEmpty)
                    if hasKey {
                        Button(action: onClear) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    Button("Cancel") { isEditing.wrappedValue = false }
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}

// MARK: - Voice Pane

private struct VoicePane: View {
    let speechService: SpeechService

    @State private var selectedVoice: String = UserDefaults.standard.string(forKey: "duck_tts_voice") ?? DuckVoices.wildcardSayName
    @State private var volume: Float = DuckConfig.volume

    var body: some View {
        Form {
            Section("Voice") {
                Picker("Voice", selection: $selectedVoice) {
                    Text("Wildcard (AI picks)").tag(DuckVoices.wildcardSayName)
                    Text("Silent (speech bubbles)").tag(DuckVoices.silentSayName)
                    Divider()
                    ForEach(DuckVoices.main, id: \.sayName) { v in Text(v.label).tag(v.sayName) }
                    Divider()
                    ForEach(DuckVoices.classic, id: \.sayName) { v in Text(v.label).tag(v.sayName) }
                    Divider()
                    ForEach(DuckVoices.specialFX, id: \.sayName) { v in Text(v.label).tag(v.sayName) }
                    Divider()
                    ForEach(DuckVoices.british, id: \.sayName) { v in Text(v.label).tag(v.sayName) }
                }
                .onChange(of: selectedVoice) {
                    speechService.ttsVoice = selectedVoice
                    if selectedVoice == DuckVoices.wildcardSayName {
                        speechService.setVoiceTransient(DuckVoices.wildcardDefault.sayName)
                        speechService.speak("Wildcard mode.", skipChirpWait: true)
                    } else if selectedVoice == DuckVoices.silentSayName {
                        speechService.speak("Silent mode. Speech bubbles only.")
                    } else {
                        let voice = DuckVoices.all.first { $0.sayName == selectedVoice }
                        speechService.speak(voice?.preview ?? "This is how I sound.", skipChirpWait: true)
                    }
                }
            }

            Section("Volume") {
                HStack(spacing: 8) {
                    Image(systemName: volumeIcon)
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Slider(value: $volume, in: 0...1, step: 0.05)
                        .tint(Color(red: 0.925, green: 0.725, blue: 0.278))
                    Text("\(Int(volume * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .onChange(of: volume) {
                    DuckConfig.volume = volume
                    speechService.setVolume(volume)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var volumeIcon: String {
        switch volume {
        case 0:       return "speaker.slash.fill"
        case ..<0.33: return "speaker.wave.1.fill"
        case ..<0.66: return "speaker.wave.2.fill"
        default:      return "speaker.wave.3.fill"
        }
    }
}

// MARK: - About Pane

private struct AboutPane: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Text("Duck Duck Duck")
                        .font(.title2.bold())
                    Text("Built at IDEO by some mighty ducks.")
                        .foregroundStyle(.secondary)
                    Link("GitHub", destination: URL(string: "https://github.com/ideo/Rubber-Duck")!)
                        .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
    }
}

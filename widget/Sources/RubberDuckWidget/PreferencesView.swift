// PreferencesView — Settings window (⌘,) for configuration.
//
// Intelligence picker, API key management, voice preferences, and about info.

import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @EnvironmentObject var speechService: SpeechService
    @State private var evalProvider = DuckConfig.evalProvider
    @State private var anthropicKey = DuckConfig.anthropicAPIKey
    @State private var geminiKey = DuckConfig.geminiAPIKey
    @State private var hasAnthropicKey = !DuckConfig.anthropicAPIKey.isEmpty
    @State private var hasGeminiKey = !DuckConfig.geminiAPIKey.isEmpty
    @State private var volume = DuckConfig.volume

    var body: some View {
        TabView {
            intelligenceTab
                .tabItem { Label("Intelligence", systemImage: "brain") }
            voiceTab
                .tabItem { Label("Voice", systemImage: "waveform") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 360)
    }

    // MARK: - Intelligence

    @State private var editingAnthropicKey = false
    @State private var editingGeminiKey = false

    private var intelligenceTab: some View {
        let accent = Color(red: 0.925, green: 0.725, blue: 0.278)
        return Form {
            Section("Intelligence Provider") {
                // Foundation
                providerRow(provider: .foundation, icon: "apple.logo",
                            title: "Apple Foundation Models",
                            subtitle: "On-device, free, sub-second. ~3B parameter model.",
                            accent: accent)

                // Anthropic + inline key
                providerRow(provider: .anthropic, icon: "brain.head.profile",
                            title: "Claude Haiku",
                            subtitle: "Anthropic API. Higher quality scoring.",
                            accent: accent)
                apiKeyRow(hasKey: hasAnthropicKey, isEditing: $editingAnthropicKey, key: $anthropicKey,
                          onSave: { DuckConfig.saveAPIKey(anthropicKey); hasAnthropicKey = true; editingAnthropicKey = false },
                          onClear: { DuckConfig.removeAPIKey(); anthropicKey = ""; hasAnthropicKey = false; editingAnthropicKey = false })
                    .padding(.leading, 34)

                // Gemini + inline key
                providerRow(provider: .gemini, icon: "sparkles",
                            title: "Gemini",
                            subtitle: "Google API. Alternative cloud scoring.",
                            accent: accent)
                apiKeyRow(hasKey: hasGeminiKey, isEditing: $editingGeminiKey, key: $geminiKey,
                          onSave: { DuckConfig.saveGeminiAPIKey(geminiKey); hasGeminiKey = true; editingGeminiKey = false },
                          onClear: { DuckConfig.removeGeminiAPIKey(); geminiKey = ""; hasGeminiKey = false; editingGeminiKey = false })
                    .padding(.leading, 34)
            }

            if hasAnthropicKey || hasGeminiKey {
                Button {
                    DuckConfig.removeAPIKey()
                    DuckConfig.removeGeminiAPIKey()
                    anthropicKey = ""; geminiKey = ""
                    hasAnthropicKey = false; hasGeminiKey = false
                    evalProvider = .foundation
                    DuckConfig.evalProvider = .foundation
                } label: {
                    Label("Clear All Keys", systemImage: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func providerRow(provider: DuckConfig.EvalProvider, icon: String, title: String, subtitle: String, accent: Color) -> some View {
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
        }
        .buttonStyle(.plain)
    }

    private func apiKeyRow(
        hasKey: Bool,
        isEditing: Binding<Bool>,
        key: Binding<String>,
        onSave: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if hasKey && !isEditing.wrappedValue {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.green)
                    Text("••••••••")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Edit") { isEditing.wrappedValue = true }
                        .buttonStyle(.borderless)
                } else if !hasKey && !isEditing.wrappedValue {
                    Image(systemName: "key")
                        .foregroundStyle(.tertiary)
                    Text("No API key")
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Add Key") { isEditing.wrappedValue = true }
                        .buttonStyle(.borderless)
                }
            }

            if isEditing.wrappedValue {
                HStack {
                    SecureField("Paste API key", text: key)
                        .textFieldStyle(.roundedBorder)
                    Button("Save", action: onSave)
                        .disabled(key.wrappedValue.isEmpty)
                    if hasKey {
                        Button {
                            onClear()
                        } label: {
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

    // MARK: - Voice

    @State private var selectedVoice: String = UserDefaults.standard.string(forKey: "duck_tts_voice") ?? DuckVoices.wildcardSayName

    private var voiceTab: some View {
        Form {
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

            HStack(spacing: 8) {
                Image(systemName: volume <= 0 ? "speaker.slash.fill" : volume < 0.33 ? "speaker.wave.1.fill" : volume < 0.66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")
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
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Text("Duck Duck Duck")
                .font(.title2.bold())
            Text("Built at IDEO by some mighty ducks.")
                .foregroundStyle(.secondary)
            Link("GitHub", destination: URL(string: "https://github.com/ideo/Rubber-Duck")!)
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

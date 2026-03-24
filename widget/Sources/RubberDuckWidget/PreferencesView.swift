// PreferencesView — Settings window (⌘,) for configuration.
//
// Intelligence picker, API key management, voice preferences, and about info.

import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @State private var evalProvider = DuckConfig.evalProvider
    @State private var anthropicKey = DuckConfig.anthropicAPIKey
    @State private var geminiKey = DuckConfig.geminiAPIKey
    @State private var volume = DuckConfig.volume

    var body: some View {
        TabView {
            voiceTab
                .tabItem { Label("Voice", systemImage: "waveform") }
            intelligenceTab
                .tabItem { Label("Intelligence", systemImage: "brain") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 320)
    }

    // MARK: - Voice

    private var voiceTab: some View {
        Form {
            Section("Voice") {
                Text("Change voice via the right-click menu on the duck or the menu bar icon.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Slider(value: $volume, in: 0...1, step: 0.05) {
                Text("Volume: \(Int(volume * 100))%")
            }
            .onChange(of: volume) {
                DuckConfig.volume = volume
            }
        }
        .padding()
    }

    // MARK: - Intelligence

    private var intelligenceTab: some View {
        Form {
            Picker("Eval Provider", selection: $evalProvider) {
                Text("Foundation (on-device, free)").tag(DuckConfig.EvalProvider.foundation)
                Text("Haiku (Anthropic API)").tag(DuckConfig.EvalProvider.anthropic)
                Text("Gemini (Google API)").tag(DuckConfig.EvalProvider.gemini)
            }
            .pickerStyle(.radioGroup)
            .onChange(of: evalProvider) {
                DuckConfig.evalProvider = evalProvider
            }

            Divider()

            Section("API Keys") {
                HStack {
                    SecureField("Anthropic API Key", text: $anthropicKey)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        DuckConfig.saveAPIKey(anthropicKey)
                    }
                    if !anthropicKey.isEmpty {
                        Button("Clear") {
                            DuckConfig.removeAPIKey()
                            anthropicKey = ""
                        }
                    }
                }

                HStack {
                    SecureField("Gemini API Key", text: $geminiKey)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        DuckConfig.saveGeminiAPIKey(geminiKey)
                    }
                    if !geminiKey.isEmpty {
                        Button("Clear") {
                            DuckConfig.removeGeminiAPIKey()
                            geminiKey = ""
                        }
                    }
                }
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

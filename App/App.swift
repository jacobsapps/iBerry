import SwiftUI

@main
struct iBerryApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

struct HomeView: View {
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("Set up keyboard") {
                        OnboardingView()
                    }
                }
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Keyboard test text")
                } header: {
                    Text("Try it here")
                } footer: {
                    Text("Choose iBerry using the globe. Try “teh”: space or punctuation accepts confident corrections. Backspace undoes it.")
                }
            }
            .navigationTitle("iBerry")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


struct OnboardingView: View {
    @Environment(\.openURL) private var openURL
    @State private var settingsUnavailable = false

    var body: some View {
        List {
            Section("1 · Add the keyboard") {
                Text("In Settings, go to General → Keyboard → Keyboards → Add New Keyboard → iBerry.")
            }
            Section("2 · Enable haptics") {
                Text("Select iBerry and enable Allow Full Access for haptic feedback in the extension.")
                Text("This demo never stores or transmits what you type. It has no networking or analytics.")
                    .foregroundStyle(.secondary)
            }
            Section("3 · Try it") {
                Text("Return to the test editor. Hold the globe key and choose iBerry.")
                Text("Use a real iPhone to feel the two heavy impacts. Simulator has no haptic hardware.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url) { accepted in
                            settingsUnavailable = !accepted
                        }
                    }
                }
                Text("Opens this app’s settings. If Keyboards isn’t shown, follow the General → Keyboard path above.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .alert("Open Settings manually", isPresented: $settingsUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Open Settings → General → Keyboard → Keyboards to add iBerry.")
        }
        .navigationTitle("Set up")
        .navigationBarTitleDisplayMode(.inline)
    }
}

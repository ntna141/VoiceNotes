import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceLink.self) private var link
    @Environment(MoodIconStore.self) private var icons
    @State private var newTerm = ""
    @State private var newHint = ""

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(NeoIconButtonStyle(size: 40))
                .accessibilityLabel("Back")
                Text("Settings")
                    .font(.title.weight(.black))
                    .foregroundStyle(Neo.ink)
                Spacer()
            }
            .padding(16)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Soniox") {
                        VStack(alignment: .leading, spacing: 10) {
                            SecureField("API key", text: $settings.apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .neoField()
                            footer("Recordings are uploaded when they finish and transcribed with \(SonioxClient.model).")
                        }
                    }

                    section("Language hints") {
                        languageEditor
                    }

                    section("Custom vocabulary") {
                        tokenEditor(
                            placeholder: "Add a name or term",
                            text: $newTerm,
                            tokens: settings.vocabularyTerms,
                            capitalize: .words,
                            add: addTerm,
                            remove: settings.removeTerm,
                            emptyFooter: "Names and jargon added here are sent as context so they are recognized.",
                            filledFooter: { "\($0) term\($0 == 1 ? "" : "s") sent as context with every transcription." }
                        )
                    }

                    section("Device") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                NeoTag(text: link.isConnected ? "Connected" : "Not connected", fill: link.isConnected ? Neo.green : Neo.redSoft)
                                if let battery = link.battery {
                                    NeoTag(text: "\(battery)%", fill: Neo.card)
                                }
                                if let firmware = link.firmware {
                                    NeoTag(text: "FW \(firmware)", fill: Neo.card)
                                }
                            }
                            if let lastHelloAt = link.lastHelloAt {
                                footer("Last sync \(lastHelloAt.formatted(date: .abbreviated, time: .shortened))")
                            }
                            HStack(spacing: 10) {
                                Button("Pair VoiceNote") {
                                    Task { await link.pair() }
                                }
                                .buttonStyle(NeoButtonStyle(fill: Neo.green))
                                Button("Unpair") {
                                    Task { await link.unpair() }
                                }
                                .buttonStyle(NeoButtonStyle(fill: Neo.red))
                            }
                            Button {
                                link.resetMoodsOnDevice()
                            } label: {
                                HStack {
                                    Text("Reset moods on device")
                                    if link.pendingReset {
                                        NeoTag(text: "Pending", fill: Neo.yellow)
                                    }
                                }
                            }
                            .buttonStyle(NeoButtonStyle(fill: Neo.yellow))
                            footer("Pushes this month from the phone to the device, overriding what the device has.")
                            if let error = link.lastError {
                                Text(error)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Neo.red)
                            }
                        }
                    }

                    section("Mood icons") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(1...MoodIcons.count, id: \.self) { mood in
                                iconRow(mood)
                            }
                            if icons.hasOverrides {
                                Button("Reset all to defaults") {
                                    icons.resetAll()
                                    link.iconsChanged()
                                }
                                .buttonStyle(NeoButtonStyle(fill: Neo.red))
                            }
                            footer(icons.deviceInSync ? "Device has the current icon set." : "Icons will be sent to the device on next connection.")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Neo.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .tint(Neo.ink)
        .scrollDismissesKeyboard(.interactively)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NeoSectionHeader(title: title)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .neoCard()
        }
        .padding(.trailing, Neo.shadow)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Neo.ink)
    }

    private var languageSuggestions: [LanguageHint] {
        LanguageHints.matches(newHint, excluding: settings.languageHintList)
    }

    private var resolvedHint: String? {
        LanguageHints.resolve(newHint)
    }

    private var canAddHint: Bool {
        guard let code = resolvedHint else { return false }
        return !settings.languageHintList.contains(code)
    }

    private var languageEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Add a language", text: $newHint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .neoField()
                    .onSubmit(addHint)
                Button("Add", action: addHint)
                    .buttonStyle(NeoButtonStyle(fill: Neo.red, shadow: 2))
                    .disabled(!canAddHint)
                    .opacity(canAddHint ? 1 : 0.5)
            }
            if !languageSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(languageSuggestions.prefix(8))) { language in
                        Button {
                            pickLanguage(language)
                        } label: {
                            HStack {
                                Text(language.localizedName)
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Text(language.code)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Neo.muted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Neo.ink)
                        .accessibilityLabel("\(language.localizedName), \(language.code)")
                    }
                }
                .neoCard(shadow: 2, radius: Neo.buttonRadius)
            }
            if !settings.languageHintList.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(settings.languageHintList, id: \.self) { token in
                        termChip(LanguageHints.displayName(for: token)) {
                            settings.removeLanguage(token)
                        }
                    }
                }
            }
            footer(settings.languageHintList.isEmpty
                ? "Languages added here are sent as hints so speech is recognized in those languages."
                : "\(settings.languageHintList.count) language\(settings.languageHintList.count == 1 ? "" : "s") sent as hints with every transcription.")
        }
    }

    private func tokenEditor(
        placeholder: String,
        text: Binding<String>,
        tokens: [String],
        capitalize: TextInputAutocapitalization,
        add: @escaping () -> Void,
        remove: @escaping (String) -> Void,
        emptyFooter: String,
        filledFooter: (Int) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(capitalize)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .neoField()
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(NeoButtonStyle(fill: Neo.red, shadow: 2))
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            if !tokens.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tokens, id: \.self) { token in
                        termChip(token) {
                            remove(token)
                        }
                    }
                }
            }
            footer(tokens.isEmpty ? emptyFooter : filledFooter(tokens.count))
        }
    }

    private func addTerm() {
        settings.addTerm(newTerm)
        newTerm = ""
    }

    private func addHint() {
        guard canAddHint else { return }
        settings.addLanguage(newHint)
        newHint = ""
    }

    private func pickLanguage(_ language: LanguageHint) {
        settings.addLanguage(language.code)
        newHint = ""
    }

    private func termChip(_ term: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(term)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    remove()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.black))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Neo.red).overlay(Circle().strokeBorder(Neo.ink, lineWidth: Neo.chipBorder)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(term)")
        }
        .foregroundStyle(Neo.ink)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .neoChip(Neo.greenSoft)
    }

    private func iconRow(_ mood: Int) -> some View {
        HStack(spacing: 12) {
            MoodGlyph(mood: mood, size: 36)
                .padding(4)
                .neoChip()
            VStack(alignment: .leading, spacing: 2) {
                Text("Mood \(mood)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Neo.ink)
                Text(icons.isCustom(mood) ? "Custom" : "Default")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Neo.muted)
            }
            Spacer()
            NavigationLink(value: MoodIconDestination(mood: mood)) {
                Text("Edit")
            }
            .buttonStyle(NeoButtonStyle(fill: Neo.card, shadow: 2))
            if icons.isCustom(mood) {
                Button {
                    icons.setOverride(nil, for: mood)
                    link.iconsChanged()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(NeoIconButtonStyle(fill: Neo.card, size: 36))
            }
        }
    }
}

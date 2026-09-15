import PhotosUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceLink.self) private var link
    @Environment(MoodIconStore.self) private var icons
    @State private var conversionMode = BitmapConverter.Mode.threshold
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickingMood = 0
    @State private var conversionError: String?
    @State private var newTerm = ""

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title.weight(.black))
                    .foregroundStyle(Neo.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(NeoButtonStyle(fill: Neo.green))
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
                            TextField("Language hints (en, vi)", text: $settings.languageHints)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .neoField()
                            footer("Recordings are uploaded when they finish and transcribed with \(SonioxClient.model).")
                        }
                    }

                    section("Custom vocabulary") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                TextField("Add a name or term", text: $newTerm)
                                    .autocorrectionDisabled()
                                    .submitLabel(.done)
                                    .neoField()
                                    .onSubmit(addTerm)
                                Button("Add", action: addTerm)
                                    .buttonStyle(NeoButtonStyle(fill: Neo.red, shadow: 2))
                                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                                    .opacity(newTerm.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                            }
                            let terms = settings.vocabularyTerms
                            if !terms.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(terms, id: \.self) { term in
                                        termChip(term)
                                    }
                                }
                            }
                            footer(terms.isEmpty ? "Names and jargon added here are sent as context so they are recognized." : "\(terms.count) term\(terms.count == 1 ? "" : "s") sent as context with every transcription.")
                        }
                    }

                    section("Device") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                NeoTag(text: link.isConnected ? "CONNECTED" : "NOT CONNECTED", fill: link.isConnected ? Neo.green : Neo.redSoft)
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
                                        NeoTag(text: "PENDING", fill: Neo.yellow)
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
                            Picker("Conversion", selection: $conversionMode) {
                                ForEach(BitmapConverter.Mode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
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
                            if let conversionError {
                                Text(conversionError)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Neo.red)
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
        .tint(Neo.ink)
        .scrollDismissesKeyboard(.interactively)
        .photosPicker(isPresented: Binding(get: { pickingMood != 0 }, set: { if !$0 { pickingMood = 0 } }), selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item, pickingMood != 0 else { return }
            let mood = pickingMood
            Task {
                await importImage(item, mood: mood)
                pickedItem = nil
                pickingMood = 0
            }
        }
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
            .foregroundStyle(Neo.muted)
    }

    private func addTerm() {
        settings.addTerm(newTerm)
        newTerm = ""
    }

    private func termChip(_ term: String) -> some View {
        HStack(spacing: 6) {
            Text(term)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    settings.removeTerm(term)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.black))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Neo.red).overlay(Circle().strokeBorder(Neo.ink, lineWidth: 1.5)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(term)")
        }
        .foregroundStyle(Neo.ink)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Neo.radius)
                .fill(Neo.greenSoft)
                .overlay(RoundedRectangle(cornerRadius: Neo.radius).strokeBorder(Neo.ink, lineWidth: 1.5))
        )
    }

    private func iconRow(_ mood: Int) -> some View {
        HStack(spacing: 12) {
            MoodGlyph(mood: mood, size: 36)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Neo.card)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Neo.ink, lineWidth: 1.5))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Mood \(mood)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Neo.ink)
                Text(icons.isCustom(mood) ? "Custom" : "Default")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Neo.muted)
            }
            Spacer()
            Button("Replace") {
                pickingMood = mood
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

    private func importImage(_ item: PhotosPickerItem, mood: Int) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            conversionError = "Could not load that image"
            return
        }
        guard let bitmap = BitmapConverter.bitmap(from: image, mode: conversionMode) else {
            conversionError = "Could not convert that image"
            return
        }
        conversionError = nil
        icons.setOverride(bitmap, for: mood)
        link.iconsChanged()
    }
}

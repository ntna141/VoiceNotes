import AVFoundation
import SwiftUI

struct CameraSheet: View {
    let onAdd: ([UIImage], String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ready = false
    @State private var unavailable = false
    @State private var capturing = false
    @State private var flash = false
    @State private var flashOn = false
    @State private var choosingDay = false
    @State private var shots: [IdentifiedImage] = []

    private let camera = CameraSession.shared

    var body: some View {
        ZStack {
            if choosingDay {
                DayPickerCard { dayKey in
                    onAdd(shots.map(\.image), dayKey)
                    dismiss()
                } onCancel: {
                    choosingDay = false
                }
            } else {
                cameraContent
            }
        }
        .animation(.easeInOut(duration: 0.2), value: choosingDay)
        .presentationBackground(Neo.paper)
        .interactiveDismissDisabled(!shots.isEmpty)
        .tint(Neo.ink)
        .task {
            if await camera.start() {
                ready = true
            } else {
                unavailable = true
            }
        }
        .onChange(of: flashOn) {
            camera.setFlash(flashOn ? .on : .off)
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var cameraContent: some View {
        VStack(spacing: 16) {
            topBar
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Neo.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Neo.radius, style: .continuous).strokeBorder(Neo.ink, lineWidth: 3))
            if !shots.isEmpty {
                thumbnails
            }
            controls
        }
        .padding(20)
        .padding(.trailing, Neo.shadow)
        .animation(.easeInOut(duration: 0.2), value: shots.isEmpty)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(NeoIconButtonStyle(size: 40))
            .accessibilityLabel("Close")
            if !shots.isEmpty {
                Text("^[\(shots.count) photo](inflect: true)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Neo.ink)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button {
                choosingDay = true
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(NeoIconButtonStyle(fill: Neo.green, size: 40))
            .disabled(shots.isEmpty)
            .opacity(shots.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Done")
        }
    }

    private var preview: some View {
        ZStack {
            Neo.ink
            if ready {
                CameraPreview(session: camera.session)
            } else if unavailable {
                VStack(spacing: 12) {
                    Text(CameraSession.isAuthorized ? "No camera available" : "Camera access is off")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Neo.paper)
                    if !CameraSession.isAuthorized {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(NeoButtonStyle())
                    }
                }
            } else {
                ProgressView()
                    .tint(Neo.paper)
            }
            Color.white
                .opacity(flash ? 0.8 : 0)
                .allowsHitTesting(false)
        }
    }

    private var thumbnails: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(shots.reversed()) { shot in
                    ScrapView(image: shot.image, isCutout: false)
                        .frame(width: 64 * shot.image.size.width / shot.image.size.height, height: 64)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                shots.removeAll { $0.id == shot.id }
                            }
                        }
                }
            }
            .padding(.vertical, 6)
            .padding(.trailing, Neo.shadow)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private var controls: some View {
        HStack {
            Menu {
                Button("Flip camera", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                    camera.flip()
                }
                Toggle("Flash", systemImage: flashOn ? "bolt.fill" : "bolt.slash", isOn: $flashOn)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(NeoIconButtonStyle(size: 48))
            .disabled(!ready)
            .opacity(ready ? 1 : 0.5)
            .accessibilityLabel("Camera options")
            Spacer()
            Button {
                capture()
            } label: {
                Image(systemName: "circle.inset.filled")
                    .font(.largeTitle.weight(.bold))
            }
            .buttonStyle(NeoIconButtonStyle(fill: Neo.red, size: 64))
            .disabled(!ready || capturing)
            .opacity(ready ? 1 : 0.5)
            .accessibilityLabel("Take photo")
            Spacer()
            Color.clear
                .frame(width: 48, height: 48)
        }
    }

    private func capture() {
        capturing = true
        flash = true
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.25)) {
                flash = false
            }
        }
        Task {
            if let image = await camera.capture() {
                shots.append(IdentifiedImage(image: image))
            }
            capturing = false
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

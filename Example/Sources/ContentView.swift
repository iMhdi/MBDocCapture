import SwiftUI
import PhotosUI
import MBDocCapture

/// Playground for MBDocCapture: tweak the configuration, then scan with the camera or from a photo.
struct ContentView: View {
    @State private var configuration = MBDocCaptureConfiguration()
    @State private var isScanning = false
    @State private var sourceImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var pages: [ImageScannerResults] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Scan with Camera", systemImage: "camera.viewfinder") {
                        sourceImage = nil
                        isScanning = true
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Crop a Photo", systemImage: "photo.on.rectangle")
                    }
                }

                if !pages.isEmpty {
                    Section("Result") {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(pages.indices, id: \.self) { index in
                                    Image(uiImage: pages[index].preferredImage)
                                        .resizable().scaledToFit().frame(height: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }

                Section("Appearance") {
                    Toggle("Liquid Glass (iOS 26+)", isOn: $configuration.appearance.usesLiquidGlass)
                    ColorPicker("Tint", selection: color(\.tintColor))
                    ColorPicker("Detection outline", selection: color(\.detectionStrokeColor))
                    ColorPicker("Corner handles", selection: color(\.cornerHandleColor))
                    ColorPicker("Shutter", selection: color(\.shutterButtonColor))
                    Stepper("Outline width: \(configuration.appearance.detectionLineWidth, specifier: "%.0f")", value: $configuration.appearance.detectionLineWidth, in: 1...6)
                }

                Section("Behavior") {
                    Toggle("Front and back", isOn: Binding(
                        get: { configuration.behavior.scanMode == .twoSided },
                        set: { configuration.behavior.scanMode = $0 ? .twoSided : .singlePage }))
                    Toggle("Auto scan", isOn: $configuration.behavior.isAutoScanEnabled)
                    Toggle("Adjust corners step", isOn: $configuration.behavior.showsEditStep)
                    Toggle("Review step", isOn: $configuration.behavior.showsReviewStep)
                    Toggle("Enhancement", isOn: $configuration.behavior.isEnhancementAvailable)
                    Toggle("Enhanced by default", isOn: $configuration.behavior.prefersEnhancedImageByDefault)
                    Toggle("Hints", isOn: $configuration.behavior.showsHints)
                    Toggle("Haptics", isOn: $configuration.behavior.isHapticFeedbackEnabled)
                }

                Section("Detection") {
                    Stepper("Auto scan frames: \(configuration.detection.autoScanStabilityFrames)", value: $configuration.detection.autoScanStabilityFrames, in: 5...80, step: 5)
                }
            }
            .navigationTitle("MBDocCapture")
        }
        .documentScanner(isPresented: $isScanning, image: sourceImage, configuration: configuration) { result in
            switch result {
            case .success(let pages): self.pages = pages
            case .failure(is CancellationError): break
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                sourceImage = image
                photoItem = nil
                isScanning = true
            }
        }
        .alert("Scan failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func color(_ keyPath: WritableKeyPath<MBDocCaptureConfiguration.Appearance, UIColor>) -> Binding<Color> {
        Binding(get: { Color(uiColor: configuration.appearance[keyPath: keyPath]) },
                set: { configuration.appearance[keyPath: keyPath] = UIColor($0) })
    }
}

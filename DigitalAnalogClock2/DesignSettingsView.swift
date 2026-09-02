import SwiftUI
import PhotosUI
import UIKit

struct DesignSettingsView: View {
    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Float
    @Binding var showOuterRing: Bool

    @ObservedObject var settings: ClockDesignSettings

    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "文字を常に上向きにする",
                        isOn: $keepLabelsUpright
                    )
                }

                Section(header: Text("秒針")) {
                    Toggle(
                        "スイープ秒針",
                        isOn: $sweepSecondHand
                    )

                    HStack {
                        Image(systemName: "speaker.fill")

                        Slider(
                            value: Binding(
                                get: {
                                    Double(tickVolume)
                                },
                                set: { value in
                                    tickVolume = Float(value)
                                }
                            ),
                            in: 0...1
                        )

                        Image(systemName: "speaker.wave.3.fill")
                    }

                    Text("ステップ秒針のときに鳴る音の音量")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("表示")) {
                    Toggle(
                        "文字盤の外枠を表示",
                        isOn: $showOuterRing
                    )
                }

                Section(header: Text("枠の設定")) {
                    Picker(
                        "枠の形状",
                        selection: $settings.frameStyle
                    ) {
                        ForEach(ClockFrameStyle.allCases) { style in
                            Text(style.displayName)
                                .tag(style)
                        }
                    }

                    ColorPicker(
                        "枠の色",
                        selection: $settings.frameColor,
                        supportsOpacity: true
                    )
                }

                Section(header: Text("針の色の設定")) {
                    ColorPicker(
                        "時針の色",
                        selection: $settings.hourHandColor,
                        supportsOpacity: true
                    )

                    ColorPicker(
                        "分針の色",
                        selection: $settings.minuteHandColor,
                        supportsOpacity: true
                    )

                    ColorPicker(
                        "秒針の色",
                        selection: $settings.secondHandColor,
                        supportsOpacity: true
                    )
                }

                Section(header: Text("背景")) {
                    ColorPicker(
                        "背景色",
                        selection: $settings.backgroundColor,
                        supportsOpacity: true
                    )

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            "写真を選択",
                            systemImage: "photo"
                        )
                    }

                    if settings.backgroundImage != nil {
                        Button(role: .destructive) {
                            settings.deleteBackgroundImage()
                            selectedPhotoItem = nil
                        } label: {
                            Label(
                                "写真を削除",
                                systemImage: "trash"
                            )
                        }
                    }

                    if let image = settings.backgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 180, height: 180)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 10
                                )
                            )
                    }
                }

                Section(header: Text("プレビュー")) {
                    DesignClockPreview(
                        settings: settings,
                        keepLabelsUpright: keepLabelsUpright
                    )
                    .frame(width: 260, height: 260)
                    .mask {
                        GeometryReader { geo in
                            let size = min(geo.size.width, geo.size.height)
                            switch settings.frameStyle {
                            case .circle:
                                Circle()
                            case .rectangle:
                                Rectangle()
                            case .roundedRectangle:
                                RoundedRectangle(cornerRadius: max(0, size * 0.12 - size * 0.035 - (size * 0.07) / 2))
                            }
                        }
                    }
                    .overlay {
                        GeometryReader { geo in
                            let size = min(geo.size.width, geo.size.height)
                            switch settings.frameStyle {
                            case .circle:
                                Circle().stroke(.secondary.opacity(0.35), lineWidth: 1)
                            case .rectangle:
                                Rectangle().stroke(.secondary.opacity(0.35), lineWidth: 1)
                            case .roundedRectangle:
                                RoundedRectangle(cornerRadius: max(0, size * 0.12 - size * 0.035 - (size * 0.07) / 2))
                                    .stroke(.secondary.opacity(0.35), lineWidth: 1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("時計デザイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            return
        }

        do {
            guard let data = try await selectedPhotoItem
                .loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }

            let squared = squareCropped(image) ?? image
            guard let compressedData = squared.jpegData(
                compressionQuality: 0.85
            ) else {
                return
            }

            settings.backgroundImageData = compressedData
        } catch {
            print(
                "背景写真の読み込みに失敗しました: \(error)"
            )
        }
    }

    private func squareCropped(_ image: UIImage) -> UIImage? {
        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return nil }

        let side = min(width, height)
        let originX = (width - side) / 2.0
        let originY = (height - side) / 2.0

        let scale = image.scale
        let cropRect = CGRect(
            x: originX * scale,
            y: originY * scale,
            width: side * scale,
            height: side * scale
        ).integral

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return nil
        }

        // Preserve original orientation
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

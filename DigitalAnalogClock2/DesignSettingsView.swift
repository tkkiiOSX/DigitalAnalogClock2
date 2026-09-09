import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct DesignSettingsView: View {
    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Float
    @Binding var showOuterRing: Bool

    @ObservedObject var settings: ClockDesignSettings

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage("hourlyChimeEnabled")
    private var hourlyChimeEnabled = false

    // AppStorageはFloatに対応していないためDoubleを使用する
    @AppStorage("hourlyChimeVolume")
    private var hourlyChimeVolume: Double = 1.0

    @AppStorage("hourlyChimeIntervalMinutes")
    private var hourlyChimeIntervalMinutes = 60

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var testHourlyChimePlayer: AVAudioPlayer?
    @State private var showingChimeTimingDialog = false

    private static let chimeTimingOptions: [ChimeTimingOption] = [
        ChimeTimingOption(minutes: 1, title: "1分"),
        ChimeTimingOption(minutes: 30, title: "30分"),
        ChimeTimingOption(minutes: 60, title: "1時間"),
        ChimeTimingOption(minutes: 360, title: "6時間"),
        ChimeTimingOption(minutes: 720, title: "12時間"),
        ChimeTimingOption(minutes: 1440, title: "24時間")
    ]

    private var selectedChimeTimingTitle: String {
        Self.chimeTimingOptions.first {
            $0.minutes == hourlyChimeIntervalMinutes
        }?.title ?? "1時間"
    }

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

                Section(header: Text("時報")) {
                    Toggle(
                        "時報を鳴らす",
                        isOn: $hourlyChimeEnabled
                    )

                    Button {
                        showingChimeTimingDialog = true
                    } label: {
                        HStack {
                            Text("時報のタイミング")
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(selectedChimeTimingTitle)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Text("現在の設定: \(selectedChimeTimingTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "speaker.fill")

                        Slider(
                            value: $hourlyChimeVolume,
                            in: 0...1
                        )

                        Image(systemName: "speaker.wave.3.fill")
                    }

                    Text("時報の音量")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        playTestHourlyChime()
                    } label: {
                        Label(
                            "時報をテスト再生",
                            systemImage: "play.circle.fill"
                        )
                    }

                    Text("時報をテスト再生します。ここで音が鳴れば、正常です。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("選択したタイミングの0秒に合うように、時報を3秒前から再生します。秒針の音とは重ねて再生されます。")
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
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)

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
                            let size = min(
                                geo.size.width,
                                geo.size.height
                            )

                            switch settings.frameStyle {
                            case .circle:
                                Circle()

                            case .rectangle:
                                Rectangle()

                            case .roundedRectangle:
                                RoundedRectangle(
                                    cornerRadius: max(
                                        0,
                                        size * 0.12 - size * 0.035 - (size * 0.07) / 2
                                    )
                                )
                            }
                        }
                    }
                    .overlay {
                        GeometryReader { geo in
                            let size = min(
                                geo.size.width,
                                geo.size.height
                            )

                            switch settings.frameStyle {
                            case .circle:
                                Circle()
                                    .stroke(
                                        .secondary.opacity(0.35),
                                        lineWidth: 1
                                    )

                            case .rectangle:
                                Rectangle()
                                    .stroke(
                                        .secondary.opacity(0.35),
                                        lineWidth: 1
                                    )

                            case .roundedRectangle:
                                RoundedRectangle(
                                    cornerRadius: max(
                                        0,
                                        size * 0.12 - size * 0.035 - (size * 0.07) / 2
                                    )
                                )
                                .stroke(
                                    .secondary.opacity(0.35),
                                    lineWidth: 1
                                )
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
            .confirmationDialog(
                "時報のタイミング",
                isPresented: $showingChimeTimingDialog,
                titleVisibility: .visible
            ) {
                ForEach(Self.chimeTimingOptions) { option in
                    Button {
                        hourlyChimeIntervalMinutes = option.minutes
                        print("時報タイミングを選択しました: \(option.title)")
                    } label: {
                        if option.minutes == hourlyChimeIntervalMinutes {
                            Text("✓ \(option.title)")
                        } else {
                            Text(option.title)
                        }
                    }
                }

                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("時報を鳴らす間隔を選択してください。")
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
        }
    }

    private func playTestHourlyChime() {
        guard hourlyChimeVolume > 0 else {
            print("時報テスト再生: 音量が0のため再生しません")
            return
        }

        guard let soundURL = Bundle.main.url(
            forResource: "jihou",
            withExtension: "mp3"
        ) else {
            print("時報テスト再生: jihou.mp3がBundleに見つかりません")
            print("Target Membership / Copy Bundle Resources を確認してください")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()

            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [
                    .mixWithOthers
                ]
            )

            try audioSession.setActive(true)

            if testHourlyChimePlayer == nil {
                let player = try AVAudioPlayer(
                    contentsOf: soundURL
                )

                player.numberOfLoops = 0
                player.prepareToPlay()

                testHourlyChimePlayer = player
            }

            guard let testHourlyChimePlayer else {
                print("時報テスト再生: プレイヤーを作成できませんでした")
                return
            }

            testHourlyChimePlayer.stop()
            testHourlyChimePlayer.currentTime = 0
            testHourlyChimePlayer.volume = Float(hourlyChimeVolume)

            let didPlay = testHourlyChimePlayer.play()

            if didPlay {
                print("時報テスト再生: jihou.mp3を再生しました")
                print("時報テスト再生: duration \(String(format: "%.2f", testHourlyChimePlayer.duration))秒")
                print("時報テスト再生: volume \(String(format: "%.2f", hourlyChimeVolume))")
                print("時報テスト再生: 現在の時報タイミング \(selectedChimeTimingTitle)")
            } else {
                print("時報テスト再生: jihou.mp3の再生に失敗しました")
            }
        } catch {
            testHourlyChimePlayer = nil
            print("時報テスト再生: 準備または再生に失敗しました: \(error)")
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

        guard width > 0,
              height > 0 else {
            return nil
        }

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

        guard let cgImage = image.cgImage?.cropping(
            to: cropRect
        ) else {
            return nil
        }

        // Preserve original orientation
        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
}

private struct ChimeTimingOption: Identifiable {
    let minutes: Int
    let title: String

    var id: Int {
        minutes
    }
}

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
        ChimeTimingOption(
            minutes: 1,
            title: "1分 (1 Minute)"
        ),
        ChimeTimingOption(
            minutes: 30,
            title: "30分 (30 Minutes)"
        ),
        ChimeTimingOption(
            minutes: 60,
            title: "1時間 (1 Hour)"
        ),
        ChimeTimingOption(
            minutes: 360,
            title: "6時間 (6 Hours)"
        ),
        ChimeTimingOption(
            minutes: 720,
            title: "12時間 (12 Hours)"
        ),
        ChimeTimingOption(
            minutes: 1440,
            title: "24時間 (24 Hours)"
        )
    ]

    private var selectedChimeTimingTitle: String {
        Self.chimeTimingOptions.first {
            $0.minutes == hourlyChimeIntervalMinutes
        }?.title ?? "1時間 (1 Hour)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text(
                        "全ての時計(All Clocks)：文字の上向き (Labels Upright)"
                    )
                ) {
                    Toggle(
                        isOn: $keepLabelsUpright
                    ) {
                        Text(
                            "文字を常に上向きにする\n"
                                + "(Keep Labels Upright)"
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }
                }

                Section(
                    header: Text(
                        "全ての時計(All Clocks)：秒針 (Second Hand)"
                    )
                ) {
                    Toggle(
                        isOn: $sweepSecondHand
                    ) {
                        Text(
                            "スイープ秒針\n"
                                + "(Sweeping Second Hand)"
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }

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

                    Text(
                        "ステップ秒針のときに鳴る音の音量\n"
                            + "(Ticking Sound Volume in Step-Second Mode)"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                Section(
                    header: Text(
                        "全ての時計(All Clocks)：時報 (Hourly Chime)"
                    )
                ) {
                    Toggle(
                        isOn: $hourlyChimeEnabled
                    ) {
                        Text(
                            "時報を鳴らす\n"
                                + "(Enable Hourly Chime)"
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }

                    Button {
                        showingChimeTimingDialog = true
                    } label: {
                        HStack(
                            alignment: .firstTextBaseline
                        ) {
                            Text(
                                "時報のタイミング\n"
                                    + "(Chime Timing)"
                            )
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                            Spacer(minLength: 8)

                            Text(selectedChimeTimingTitle)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )

                            Image(
                                systemName: "chevron.up.chevron.down"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Text(
                        "現在の設定: \(selectedChimeTimingTitle)\n"
                            + "(Current Setting: \(selectedChimeTimingTitle))"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    HStack {
                        Image(systemName: "speaker.fill")

                        Slider(
                            value: $hourlyChimeVolume,
                            in: 0...1
                        )

                        Image(systemName: "speaker.wave.3.fill")
                    }

                    Text(
                        "時報の音量\n"
                            + "(Hourly Chime Volume)"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    Button {
                        playTestHourlyChime()
                    } label: {
                        Label {
                            Text(
                                "時報をテスト再生\n"
                                    + "(Test Hourly Chime)"
                            )
                            .multilineTextAlignment(.leading)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        } icon: {
                            Image(systemName: "play.circle.fill")
                        }
                    }

                    Text(
                        "時報をテスト再生します。ここで音が鳴れば、正常です。\n"
                            + "(Test the hourly chime. If you hear the sound, it is working correctly.)"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    Text(
                        "選択したタイミングの0秒に合うように、時報を3秒前から再生します。秒針の音とは重ねて再生されます。\n"
                            + "(Playback starts 3 seconds before the selected time and overlaps with the second-hand sound.)"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                Section(
                    header: Text(
                        "表示 (Display)"
                    )
                ) {
                    Toggle(
                        isOn: $showOuterRing
                    ) {
                        Text(
                            "文字盤の外枠を表示\n"
                                + "(Show Outer Frame)"
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }
                }

                Section(
                    header: Text(
                        "枠の設定 (Frame Settings)\n丸枠(Circle)\n角枠(Rectangle)\n角丸枠(Rounded Rectangle)"
                    )
                ) {
                    Picker(
                        selection: $settings.frameStyle
                    ) {
                        ForEach(ClockFrameStyle.allCases) { style in
                            Text(style.displayName)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                                .tag(style)
                        }
                    } label: {
                        Text(
                            "枠の形状\n"
                                + "(Frame Shape)"
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)

                    ColorPicker(
                        "枠の色 (Frame Color)",
                        selection: $settings.frameColor,
                        supportsOpacity: true
                    )
                }

                Section(
                    header: Text(
                        "針の色の設定 (Hand Color Settings)"
                    )
                ) {
                    ColorPicker(
                        "時針の色 (Hour Hand Color)",
                        selection: $settings.hourHandColor,
                        supportsOpacity: true
                    )

                    ColorPicker(
                        "分針の色 (Minute Hand Color)",
                        selection: $settings.minuteHandColor,
                        supportsOpacity: true
                    )

                    ColorPicker(
                        "秒針の色 (Second Hand Color)",
                        selection: $settings.secondHandColor,
                        supportsOpacity: true
                    )
                }

                Section(
                    header: Text(
                        "背景 (Background)"
                    )
                ) {
                    ColorPicker(
                        "背景色 (Background Color)",
                        selection: $settings.backgroundColor,
                        supportsOpacity: true
                    )

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label {
                            Text(
                                "写真を選択\n"
                                    + "(Select Photo)"
                            )
                            .multilineTextAlignment(.leading)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        } icon: {
                            Image(systemName: "photo")
                        }
                    }

                    if settings.backgroundImage != nil {
                        Button(role: .destructive) {
                            settings.deleteBackgroundImage()
                            selectedPhotoItem = nil
                        } label: {
                            Label {
                                Text(
                                    "写真を削除\n"
                                        + "(Delete Photo)"
                                )
                                .multilineTextAlignment(.leading)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    if let image = settings.backgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: 180,
                                height: 180
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 10
                                )
                            )
                    }
                }

                Section(
                    header: Text(
                        "プレビュー (Preview)"
                    )
                ) {
                    DesignClockPreview(
                        settings: settings,
                        keepLabelsUpright: keepLabelsUpright
                    )
                    .frame(
                        width: 260,
                        height: 260
                    )
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
                                        size * 0.12
                                            - size * 0.035
                                            - (size * 0.07) / 2
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
                                        size * 0.12
                                            - size * 0.035
                                            - (size * 0.07) / 2
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
            .navigationTitle(
                "時計デザイン (Clock Design)"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button(
                        "完了 (Done)"
                    ) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "時報のタイミング (Chime Timing)",
                isPresented: $showingChimeTimingDialog,
                titleVisibility: .visible
            ) {
                ForEach(Self.chimeTimingOptions) { option in
                    Button {
                        hourlyChimeIntervalMinutes = option.minutes
                        print(
                            "時報タイミングを選択しました: \(option.title)"
                        )
                    } label: {
                        if option.minutes == hourlyChimeIntervalMinutes {
                            Text("✓ \(option.title)")
                        } else {
                            Text(option.title)
                        }
                    }
                }

                Button(
                    "キャンセル (Cancel)",
                    role: .cancel
                ) {}
            } message: {
                Text(
                    "時報を鳴らす間隔を選択してください。\n"
                        + "(Select the hourly chime interval.)"
                )
                .multilineTextAlignment(.leading)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
        }
    }

    private func playTestHourlyChime() {
        guard hourlyChimeVolume > 0 else {
            print(
                "時報テスト再生: 音量が0のため再生しません"
            )
            return
        }

        guard let soundURL = Bundle.main.url(
            forResource: "jihou",
            withExtension: "mp3"
        ) else {
            print(
                "時報テスト再生: jihou.mp3がBundleに見つかりません"
            )
            print(
                "Target Membership / Copy Bundle Resources を確認してください"
            )
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
                print(
                    "時報テスト再生: プレイヤーを作成できませんでした"
                )
                return
            }

            testHourlyChimePlayer.stop()
            testHourlyChimePlayer.currentTime = 0
            testHourlyChimePlayer.volume = Float(
                hourlyChimeVolume
            )

            let didPlay = testHourlyChimePlayer.play()

            if didPlay {
                print(
                    "時報テスト再生: jihou.mp3を再生しました"
                )
                print(
                    "時報テスト再生: duration "
                        + "\(String(format: "%.2f", testHourlyChimePlayer.duration))秒"
                )
                print(
                    "時報テスト再生: volume "
                        + "\(String(format: "%.2f", hourlyChimeVolume))"
                )
                print(
                    "時報テスト再生: 現在の時報タイミング "
                        + "\(selectedChimeTimingTitle)"
                )
            } else {
                print(
                    "時報テスト再生: jihou.mp3の再生に失敗しました"
                )
            }
        } catch {
            testHourlyChimePlayer = nil
            print(
                "時報テスト再生: 準備または再生に失敗しました: \(error)"
            )
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

    private func squareCropped(
        _ image: UIImage
    ) -> UIImage? {
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

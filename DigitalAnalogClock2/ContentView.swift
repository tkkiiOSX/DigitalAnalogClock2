//
//  ContentView.swift
//  DigitalAnalogClock2
//
//  Created by Xcode2021 on 2026/08/28.
//

import SwiftUI
import Combine
import AVFoundation
import UIKit
import CoreMotion

@MainActor
final class ClockInstance: ObservableObject, Identifiable {
    let id = UUID()
    @Published var timeZoneIdentifier: String
    @Published var designSettings: ClockDesignSettings
    @Published var showSettings: Bool = false
    init(timeZoneIdentifier: String, designSettings: ClockDesignSettings? = nil) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.designSettings = designSettings ?? ClockDesignSettings()
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentDate = Date()

    @AppStorage("keepLabelsUpright")
    private var keepLabelsUpright = false

    @AppStorage("sweepSecondHand")
    private var sweepSecondHand = true

    // AppStorageはFloatに対応していないためDoubleを使用する
    @AppStorage("tickVolume")
    private var tickVolume: Double = 0.8

    @AppStorage("showOuterRing")
    private var showOuterRing = true

    // 名前は既存互換のため残しますが、意味は「現在地のタイムゾーンに追従」です
    @AppStorage("followSystemTimeZone")
    private var followSystemTimeZone = false

    @AppStorage("gpsSyncEnabled")
    private var gpsSyncEnabled = false

    @AppStorage("hourlyChimeEnabled")
    private var hourlyChimeEnabled = false

    // AppStorageはFloatに対応していないためDoubleを使用する
    @AppStorage("hourlyChimeVolume")
    private var hourlyChimeVolume: Double = 1.0

    @AppStorage("hourlyChimeIntervalMinutes")
    private var hourlyChimeIntervalMinutes = 60

    @AppStorage("gyroEnabled") private var gyroEnabled = false
    @StateObject private var gyroManager = GyroManager()

    @StateObject private var locationTimeZoneManager =
        LocationTimeZoneManager()

    @State private var tickPlayer: AVAudioPlayer?
    @State private var hourlyChimePlayer: AVAudioPlayer?

    @State private var lastSecondPlayed = -1
    @State private var audioIsPrepared = false
    @State private var hourlyChimeAudioIsPrepared = false

    // 同じ時報タイミングを複数回鳴らさないための記録
    @State private var lastChimeTargetStart: Date?

    // jihou.mp3は3秒目が0秒なので、対象時刻の3秒前から再生する
    private let hourlyChimeLeadTimeSeconds: TimeInterval = 3

    private let timer = Timer.publish(
        every: 1 / 30,
        on: .main,
        in: .common
    ).autoconnect()

    private var allowedChimeIntervalMinutes: [Int] {
        [
            1,
            30,
            60,
            360,
            720,
            1440
        ]
    }

    private var normalizedChimeIntervalMinutes: Int {
        if allowedChimeIntervalMinutes.contains(hourlyChimeIntervalMinutes) {
            return hourlyChimeIntervalMinutes
        }

        return 60
    }

    @State private var clocks: [ClockInstance] = [ClockInstance(timeZoneIdentifier: TimeZone.current.identifier)]

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            if isPortrait {
                VStack {
                    Button(action: {
                        clocks.append(ClockInstance(timeZoneIdentifier: "Asia/Tokyo"))
                    }) {
                        Label("", systemImage: "plus")
                            .font(.headline)
                            .padding(8)
                    }
                    Spacer(minLength: 6)
                    if clocks.count <= 2 {
                        VStack(spacing: 24) {
                            ForEach(clocks) { clock in
                                GeometryReader { geo in
                                    let size = min(geo.size.width, geo.size.height)
                                    let tz = TimeZone(identifier: clock.timeZoneIdentifier) ?? .current
                                    clockContainer(
                                        size: size,
                                        timeZone: tz,
                                        designSettings: clock.designSettings,
                                        showSettings: Binding(
                                            get: {
                                                clock.showSettings
                                            },
                                            set: { value in
                                                if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                                    clocks[idx].showSettings = value
                                                }
                                            }
                                        ),
                                        onSettings: {
                                            if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                                clocks[idx].showSettings = true
                                            }
                                        },
                                        onUpdateTimeZone: { newTimeZone in
                                            if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                                clocks[idx].timeZoneIdentifier = newTimeZone.identifier
                                            }
                                        }
                                    )
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .rotationEffect(gyroEnabled ? Angle(radians: -gyroManager.gravityAngle) : .zero)
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .padding()
                            }
                        }
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 24) {
                                ForEach(clocks) { clock in
                                    GeometryReader { geo in
                                        let size = min(geo.size.width, geo.size.height)
                                        let tz = TimeZone(identifier: clock.timeZoneIdentifier) ?? .current
                                        clockContainer(
                                            size: size,
                                            timeZone: tz,
                                            designSettings: clock.designSettings,
                                            showSettings: Binding(
                                                get: {
                                                    clock.showSettings
                                                },
                                                set: { value in
                                                    if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                                        clocks[idx].showSettings = value
                                                    }
                                                }
                                            ),
                                            onSettings: {
                                                if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                                    clocks[idx].showSettings = true
                                                }
                                            },
                                            onUpdateTimeZone: { newTimeZone in
                                                if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                                    clocks[idx].timeZoneIdentifier = newTimeZone.identifier
                                                }
                                            }
                                        )
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .rotationEffect(gyroEnabled ? Angle(radians: -gyroManager.gravityAngle) : .zero)
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .padding()
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                }
                .padding()
                .onReceive(timer) { newDate in
                    handleTimer(newDate)
                }
                .onAppear {
                    print("ContentView.onAppear が呼ばれました")
                    prepareAudioPlayers()
                    configureLocationTimeZoneTracking()
                    if gyroEnabled {
                        gyroManager.start()
                    }
                }
                .onDisappear {
                    if gyroEnabled {
                        gyroManager.stop()
                    }
                }
                .onChange(of: followSystemTimeZone) { _, enabled in
                    gpsSyncEnabled = enabled
                    locationTimeZoneManager.setEnabled(enabled)
                    if enabled {
                        locationTimeZoneManager.refresh()
                    }
                }
                .onChange(of: gpsSyncEnabled) { _, enabled in
                    if enabled {
                        followSystemTimeZone = true
                        locationTimeZoneManager.setEnabled(true)
                        locationTimeZoneManager.refresh()
                    } else if !followSystemTimeZone {
                        locationTimeZoneManager.setEnabled(false)
                    }
                }
                .onChange(of: locationTimeZoneManager.timeZone) { _, newTimeZone in
                    guard followSystemTimeZone,
                          let newTimeZone else {
                        return
                    }
                    if clocks.indices.contains(0) {
                        clocks[0].timeZoneIdentifier = newTimeZone.identifier
                    }
                    lastChimeTargetStart = nil
                }
                .onChange(of: hourlyChimeEnabled) { _, enabled in
                    lastChimeTargetStart = nil
                    if enabled {
                        prepareHourlyChimePlayer()
                        print("時報がONになりました。時報間隔: \(normalizedChimeIntervalMinutes)分")
                    } else {
                        hourlyChimePlayer?.stop()
                        hourlyChimePlayer?.currentTime = 0
                        print("時報がOFFになりました")
                    }
                }
                .onChange(of: hourlyChimeVolume) { _, volume in
                    hourlyChimePlayer?.volume = Float(hourlyChimeVolume)
                    print("時報音量を変更しました: \(String(format: "%.2f", volume))")
                }
                .onChange(of: hourlyChimeIntervalMinutes) { _, newValue in
                    lastChimeTargetStart = nil
                    print("時報タイミングを変更しました: \(newValue)分")
                }
                .onChange(of: scenePhase) { _, phase in
                    print("scenePhase が変更されました: \(phase)")
                    guard phase == .active else {
                        return
                    }
                    prepareAudioPlayers()
                    lastChimeTargetStart = nil
                    if followSystemTimeZone {
                        gpsSyncEnabled = true
                        locationTimeZoneManager.setEnabled(true)
                        locationTimeZoneManager.refresh()
                    } else {
                        gpsSyncEnabled = false
                        locationTimeZoneManager.setEnabled(false)
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 0) {
                    VStack {
                        Button(action: {
                            clocks.append(ClockInstance(timeZoneIdentifier: "Asia/Tokyo"))
                        }) {
                            Label("", systemImage: "plus")
                                .font(.headline)
                                .padding(8)
                        }
                        Spacer()
                    }
                    .frame(width: 90)
                    Spacer(minLength: 12)

                    let clockCount = clocks.count
                    let spacing: CGFloat = 24
                    let availableHeight = geometry.size.height - 32
                    let clockSize = max(120, availableHeight)
                    let totalContentWidth = CGFloat(clockCount) * clockSize + CGFloat(clockCount - 1) * spacing

                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: spacing) {
                            ForEach(clocks) { clock in
                                clockContainer(
                                    size: clockSize,
                                    timeZone: TimeZone(identifier: clock.timeZoneIdentifier) ?? .current,
                                    designSettings: clock.designSettings,
                                    showSettings: Binding(
                                        get: {
                                            clock.showSettings
                                        },
                                        set: { value in
                                            if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                                clocks[idx].showSettings = value
                                            }
                                        }
                                    ),
                                    onSettings: {
                                        if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                            clocks[idx].showSettings = true
                                        }
                                    },
                                    onUpdateTimeZone: { newTimeZone in
                                        if let idx = clocks.firstIndex(where: { $0.id == clock.id }) {
                                            clocks[idx].timeZoneIdentifier = newTimeZone.identifier
                                        }
                                    }
                                )
                                .frame(width: clockSize, height: clockSize)
                                .rotationEffect(gyroEnabled ? Angle(radians: -gyroManager.gravityAngle) : .zero)
                            }
                        }
                        .frame(width: totalContentWidth, height: availableHeight, alignment: .center)
                        .padding(.vertical, (geometry.size.height - availableHeight) / 2)
                    }
                    .frame(height: availableHeight)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.trailing)
                }
                .padding(.top)
                .onReceive(timer) { newDate in
                    handleTimer(newDate)
                }
                .onAppear {
                    print("ContentView.onAppear が呼ばれました")
                    prepareAudioPlayers()
                    configureLocationTimeZoneTracking()
                    if gyroEnabled {
                        gyroManager.start()
                    }
                }
                .onDisappear {
                    if gyroEnabled {
                        gyroManager.stop()
                    }
                }
                .onChange(of: followSystemTimeZone) { _, enabled in
                    gpsSyncEnabled = enabled
                    locationTimeZoneManager.setEnabled(enabled)
                    if enabled {
                        locationTimeZoneManager.refresh()
                    }
                }
                .onChange(of: gpsSyncEnabled) { _, enabled in
                    if enabled {
                        followSystemTimeZone = true
                        locationTimeZoneManager.setEnabled(true)
                        locationTimeZoneManager.refresh()
                    } else if !followSystemTimeZone {
                        locationTimeZoneManager.setEnabled(false)
                    }
                }
                .onChange(of: locationTimeZoneManager.timeZone) { _, newTimeZone in
                    guard followSystemTimeZone,
                          let newTimeZone else {
                        return
                    }
                    if clocks.indices.contains(0) {
                        clocks[0].timeZoneIdentifier = newTimeZone.identifier
                    }
                    lastChimeTargetStart = nil
                }
                .onChange(of: hourlyChimeEnabled) { _, enabled in
                    lastChimeTargetStart = nil
                    if enabled {
                        prepareHourlyChimePlayer()
                        print("時報がONになりました。時報間隔: \(normalizedChimeIntervalMinutes)分")
                    } else {
                        hourlyChimePlayer?.stop()
                        hourlyChimePlayer?.currentTime = 0
                        print("時報がOFFになりました")
                    }
                }
                .onChange(of: hourlyChimeVolume) { _, volume in
                    hourlyChimePlayer?.volume = Float(hourlyChimeVolume)
                    print("時報音量を変更しました: \(String(format: "%.2f", volume))")
                }
                .onChange(of: hourlyChimeIntervalMinutes) { _, newValue in
                    lastChimeTargetStart = nil
                    print("時報タイミングを変更しました: \(newValue)分")
                }
                .onChange(of: scenePhase) { _, phase in
                    print("scenePhase が変更されました: \(phase)")
                    guard phase == .active else {
                        return
                    }
                    prepareAudioPlayers()
                    lastChimeTargetStart = nil
                    if followSystemTimeZone {
                        gpsSyncEnabled = true
                        locationTimeZoneManager.setEnabled(true)
                        locationTimeZoneManager.refresh()
                    } else {
                        gpsSyncEnabled = false
                        locationTimeZoneManager.setEnabled(false)
                    }
                }
            }
        }
    }

    private func configureLocationTimeZoneTracking() {
        gpsSyncEnabled = followSystemTimeZone
        locationTimeZoneManager.setEnabled(followSystemTimeZone)

        if followSystemTimeZone {
            locationTimeZoneManager.refresh()
        }
    }

    private func prepareAudioPlayers() {
        print("音声プレイヤー準備処理を開始します")
        printBundleMP3Files()

        prepareAudioPlayer()
        prepareHourlyChimePlayer()
    }

    private func printBundleMP3Files() {
        let mp3FileNames = Bundle.main.urls(
            forResourcesWithExtension: "mp3",
            subdirectory: nil
        )?
        .map {
            $0.lastPathComponent
        }
        .sorted() ?? []

        if mp3FileNames.isEmpty {
            print("Bundle内のmp3ファイル: なし")
        } else {
            print("Bundle内のmp3ファイル: \(mp3FileNames.joined(separator: ", "))")
        }
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(
            .playback,
            mode: .default,
            options: [
                .mixWithOthers
            ]
        )

        try audioSession.setActive(true)
    }

    private func prepareAudioPlayer() {
        guard !audioIsPrepared else {
            tickPlayer?.volume = Float(tickVolume)
            return
        }

        guard let soundURL = Bundle.main.url(
            forResource: "CLOCK01",
            withExtension: "mp3"
        ) else {
            print("CLOCK01.mp3がアプリのBundleに見つかりません")
            return
        }

        do {
            try configureAudioSession()

            let player = try AVAudioPlayer(
                contentsOf: soundURL
            )

            player.volume = Float(tickVolume)
            player.numberOfLoops = 0
            player.prepareToPlay()

            tickPlayer = player
            audioIsPrepared = true

            print("CLOCK01.mp3の準備が完了しました")
        } catch {
            tickPlayer = nil
            audioIsPrepared = false

            print("CLOCK01.mp3の準備に失敗しました: \(error)")
        }
    }

    private func prepareHourlyChimePlayer() {
        guard !hourlyChimeAudioIsPrepared else {
            hourlyChimePlayer?.volume = Float(hourlyChimeVolume)
            print("jihou.mp3は既に準備済みです")
            return
        }

        print("jihou.mp3の準備を開始します")

        guard let soundURL = Bundle.main.url(
            forResource: "jihou",
            withExtension: "mp3"
        ) else {
            print("jihou.mp3がアプリのBundleに見つかりません")
            print("ファイル名が jihou.mp3 か、Target Membership / Copy Bundle Resources を確認してください")
            return
        }

        do {
            try configureAudioSession()

            let player = try AVAudioPlayer(
                contentsOf: soundURL
            )

            player.volume = Float(hourlyChimeVolume)
            player.numberOfLoops = 0
            player.prepareToPlay()

            hourlyChimePlayer = player
            hourlyChimeAudioIsPrepared = true

            print("jihou.mp3の準備が完了しました")
            print("jihou.mp3 duration: \(String(format: "%.2f", player.duration))秒")
            print("jihou.mp3 volume: \(String(format: "%.2f", hourlyChimeVolume))")
        } catch {
            hourlyChimePlayer = nil
            hourlyChimeAudioIsPrepared = false

            print("jihou.mp3の準備に失敗しました: \(error)")
        }
    }

    private func playTickSound() {
        if !audioIsPrepared || tickPlayer == nil {
            prepareAudioPlayer()
        }

        guard let tickPlayer else {
            print("再生できる音声プレイヤーがありません")
            return
        }

        tickPlayer.stop()
        tickPlayer.currentTime = 0
        tickPlayer.volume = Float(tickVolume)

        let didPlay = tickPlayer.play()

        if !didPlay {
            print("CLOCK01.mp3の再生に失敗しました")
        }
    }

    private func playHourlyChimeSound(
        elapsedFromIdealStart: TimeInterval
    ) {
        if !hourlyChimeAudioIsPrepared || hourlyChimePlayer == nil {
            prepareHourlyChimePlayer()
        }

        guard let hourlyChimePlayer else {
            print("再生できる時報プレイヤーがありません")
            return
        }

        hourlyChimePlayer.stop()
        hourlyChimePlayer.volume = Float(hourlyChimeVolume)

        // 本来の開始時刻より少し遅れた場合は、その分だけ再生位置を進める
        hourlyChimePlayer.currentTime = min(
            max(0, elapsedFromIdealStart),
            hourlyChimePlayer.duration
        )

        hourlyChimePlayer.prepareToPlay()

        let didPlay = hourlyChimePlayer.play()

        if didPlay {
            print(
                "jihou.mp3を時報再生しました。再生位置: \(String(format: "%.2f", hourlyChimePlayer.currentTime))秒 音量: \(String(format: "%.2f", hourlyChimeVolume))"
            )
        } else {
            print("jihou.mp3の時報再生に失敗しました")
        }
    }

    private func clockContainer(
        size: CGFloat,
        timeZone: TimeZone,
        designSettings: ClockDesignSettings,
        showSettings: Binding<Bool>,
        onSettings: @escaping () -> Void,
        onUpdateTimeZone: @escaping (TimeZone) -> Void
    ) -> some View {
        let clockRadius = size * 0.45
        let secondHandWidth = size * 0.04
        let hourHandWidth = size * 0.09

        return clockFace(
            size: size,
            clockRadius: clockRadius,
            secondHandWidth: secondHandWidth,
            hourHandWidth: hourHandWidth,
            timeZone: timeZone,
            designSettings: designSettings
        )
        .overlay(alignment: .bottomTrailing) {
            timeZoneLabel(size: size, timeZone: timeZone)
        }
        .overlay(alignment: .topTrailing) {
            settingsButton(size: size, onSettings: onSettings)
        }
        .background {
            ZStack {
                // Base background behind the clock (outside the frame remains visible)
                designSettings.backgroundColor
                // Photo only fills the inner face of the frame (outside stays transparent to base)
                clockFaceBackgroundMasked(size: size, designSettings: designSettings)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: size * 0.02)
        )
        .sheet(isPresented: showSettings) {
            settingsView(
                designSettings: designSettings,
                onUpdateTimeZone: onUpdateTimeZone,
                currentTimeZone: timeZone,
                dismiss: {
                    showSettings.wrappedValue = false
                }
            )
        }
    }

    private func clockFace(
        size: CGFloat,
        clockRadius: CGFloat,
        secondHandWidth: CGFloat,
        hourHandWidth: CGFloat,
        timeZone: TimeZone,
        designSettings: ClockDesignSettings
    ) -> some View {
        ZStack {
            outerRing(size: size, designSettings: designSettings)

            ClockHand(
                angle: hourAngle(timeZone: timeZone),
                length: clockRadius * 0.55,
                color: designSettings.hourHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: hourString(timeZone: timeZone),
                labelColor: designSettings.hourHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: minuteAngle(timeZone: timeZone),
                length: clockRadius * 0.80,
                color: designSettings.minuteHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: minuteString(timeZone: timeZone),
                labelColor: designSettings.minuteHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: secondAngle(timeZone: timeZone),
                length: clockRadius * 0.92,
                color: designSettings.secondHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: secondString(timeZone: timeZone),
                labelColor: designSettings.secondHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            centerCircle(size: size)
        }
        .frame(
            width: size,
            height: size
        )
    }

    @ViewBuilder
    private func clockFaceBackgroundMasked(size: CGFloat, designSettings: ClockDesignSettings) -> some View {
        if let image = designSettings.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .mask(innerMask(size: size, designSettings: designSettings))
        }
    }

    @ViewBuilder
    private func innerMask(size: CGFloat, designSettings: ClockDesignSettings) -> some View {
        // Match the visible inner edge of the stroked frame in outerRing():
        let lineWidth = size * 0.03
        let inset = lineWidth / 2

        switch designSettings.frameStyle {
        case .circle:
            Circle()
                .inset(by: inset)

        case .rectangle:
            Rectangle()
                .inset(by: inset)

        case .roundedRectangle:
            RoundedRectangle(cornerRadius: size * 0.12)
                .inset(by: inset)
        }
    }

    @ViewBuilder
    private func outerRing(size: CGFloat, designSettings: ClockDesignSettings) -> some View {
        if showOuterRing {
            let lineWidth = size * 0.03
            let insetAmount = lineWidth / 2

            switch designSettings.frameStyle {
            case .circle:
                Circle()
                    .inset(by: insetAmount)
                    .stroke(
                        designSettings.frameColor,
                        lineWidth: lineWidth
                    )
                    .frame(
                        width: size,
                        height: size
                    )
                    .shadow(radius: 8)

            case .rectangle:
                Rectangle()
                    .inset(by: insetAmount)
                    .stroke(
                        designSettings.frameColor,
                        lineWidth: lineWidth
                    )
                    .frame(
                        width: size,
                        height: size
                    )
                    .shadow(radius: 8)

            case .roundedRectangle:
                RoundedRectangle(
                    cornerRadius: size * 0.12
                )
                .inset(by: insetAmount)
                .stroke(
                    designSettings.frameColor,
                    lineWidth: lineWidth
                )
                .frame(
                    width: size,
                    height: size
                )
                .shadow(radius: 8)
            }
        }
    }

    private func centerCircle(size: CGFloat) -> some View {
        Circle()
            .fill(.yellow)
            .frame(
                width: size * 0.1,
                height: size * 0.1
            )
            .shadow(radius: 2)
    }

    private func timeZoneLabel(size: CGFloat, timeZone: TimeZone) -> some View {
        Text(timeZoneDisplayName(timeZone: timeZone))
            .font(
                .system(
                    size: max(11, size * 0.035),
                    weight: .medium
                )
            )
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .padding(8)
    }

    private func settingsButton(size: CGFloat, onSettings: @escaping () -> Void) -> some View {
        Button {
            onSettings()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(
                    .system(
                        size: max(18, size * 0.05)
                    )
                )
                .foregroundStyle(.primary)
                .padding(12)
                .background(
                    .ultraThinMaterial,
                    in: Circle()
                )
                .shadow(radius: 2)
        }
        .padding(8)
    }

    private func settingsView(
        designSettings: ClockDesignSettings,
        onUpdateTimeZone: @escaping (TimeZone) -> Void,
        currentTimeZone: TimeZone,
        dismiss: @escaping () -> Void
    ) -> some View {
        SettingsView(
            keepLabelsUpright: Binding(
                get: {
                    keepLabelsUpright
                },
                set: { value in
                    keepLabelsUpright = value
                }
            ),
            sweepSecondHand: Binding(
                get: {
                    sweepSecondHand
                },
                set: { value in
                    sweepSecondHand = value
                }
            ),
            tickVolume: Binding(
                get: {
                    Float(tickVolume)
                },
                set: { value in
                    tickVolume = Double(value)

                    if let tickPlayer {
                        tickPlayer.volume = value
                    }
                }
            ),
            showOuterRing: Binding(
                get: {
                    showOuterRing
                },
                set: { value in
                    showOuterRing = value
                }
            ),
            timeZone: Binding(
                get: {
                    currentTimeZone
                },
                set: { newTimeZone in
                    onUpdateTimeZone(newTimeZone)
                }
            ),
            followSystemTimeZone: $followSystemTimeZone,
            gpsSyncEnabled: $gpsSyncEnabled,
            designSettings: designSettings
        ) {
            dismiss()
        }
    }

    private func handleTimer(_ newDate: Date) {
        currentDate = newDate
        handleChime(newDate)

        guard !sweepSecondHand else {
            lastSecondPlayed = -1
            return
        }

        let currentSecond = calendar(timeZone: clocks.firstTimeZone()).component(
            .second,
            from: newDate
        )

        guard currentSecond != lastSecondPlayed else {
            return
        }

        playTickSound()
        lastSecondPlayed = currentSecond
    }

    private func handleChime(_ newDate: Date) {
        guard hourlyChimeEnabled else {
            return
        }

        guard hourlyChimeVolume > 0 else {
            return
        }

        guard let nextTargetStart = nextChimeTargetStart(
            after: newDate
        ) else {
            return
        }

        let secondsUntilTarget = nextTargetStart.timeIntervalSince(
            newDate
        )

        // 対象時刻の3秒前から、対象時刻直前までの間に1回だけ再生する
        guard secondsUntilTarget > 0,
              secondsUntilTarget <= hourlyChimeLeadTimeSeconds else {
            return
        }

        guard lastChimeTargetStart != nextTargetStart else {
            return
        }

        let elapsedFromIdealStart =
            hourlyChimeLeadTimeSeconds - secondsUntilTarget

        print(
            "時報再生条件成立: 間隔 \(normalizedChimeIntervalMinutes)分 / 対象0秒まで \(String(format: "%.2f", secondsUntilTarget))秒 / 再生位置補正 \(String(format: "%.2f", elapsedFromIdealStart))秒"
        )

        playHourlyChimeSound(
            elapsedFromIdealStart: elapsedFromIdealStart
        )

        lastChimeTargetStart = nextTargetStart
    }

    private func nextChimeTargetStart(after date: Date) -> Date? {
        guard let startOfDay = calendar(timeZone: clocks.firstTimeZone()).startOfDay(
            for: date
        ) as Date? else {
            return nil
        }

        let intervalMinutes = normalizedChimeIntervalMinutes
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        let elapsedSeconds = date.timeIntervalSince(startOfDay)

        let currentSlot = floor(elapsedSeconds / intervalSeconds)
        let nextSlot = currentSlot + 1
        let nextElapsedSeconds = nextSlot * intervalSeconds

        return calendar(timeZone: clocks.firstTimeZone()).date(
            byAdding: .second,
            value: Int(nextElapsedSeconds),
            to: startOfDay
        )
    }

    private func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private var hour: Int {
        calendar(timeZone: clocks.firstTimeZone()).component(
            .hour,
            from: currentDate
        )
    }

    private var minute: Int {
        calendar(timeZone: clocks.firstTimeZone()).component(
            .minute,
            from: currentDate
        )
    }

    private var second: Int {
        calendar(timeZone: clocks.firstTimeZone()).component(
            .second,
            from: currentDate
        )
    }

    private var nanosecond: Int {
        calendar(timeZone: clocks.firstTimeZone()).component(
            .nanosecond,
            from: currentDate
        )
    }

    private func hourAngle(timeZone: TimeZone) -> Angle {
        let hourValue = Double(hour(timeZone: timeZone) % 12)
            + Double(minute(timeZone: timeZone)) / 60

        return Angle.degrees(
            (hourValue / 12) * 360
        )
    }

    private func minuteAngle(timeZone: TimeZone) -> Angle {
        let minuteValue = Double(minute(timeZone: timeZone))
            + Double(second(timeZone: timeZone)) / 60

        return Angle.degrees(
            (minuteValue / 60) * 360
        )
    }

    private func secondAngle(timeZone: TimeZone) -> Angle {
        let secondValue: Double

        if sweepSecondHand {
            secondValue = Double(second(timeZone: timeZone))
                + Double(nanosecond(timeZone: timeZone)) / 1_000_000_000
        } else {
            secondValue = Double(second(timeZone: timeZone))
        }

        return Angle.degrees(
            (secondValue / 60) * 360
        )
    }

    private func hourString(timeZone: TimeZone) -> String {
        String(format: "%d", hour(timeZone: timeZone))
    }

    private func minuteString(timeZone: TimeZone) -> String {
        String(format: "%02d", minute(timeZone: timeZone))
    }

    private func secondString(timeZone: TimeZone) -> String {
        String(format: "%02d", second(timeZone: timeZone))
    }

    private func timeZoneDisplayName(timeZone: TimeZone) -> String {
        switch timeZone.identifier {
        case "Asia/Tokyo", "Japan":
            return "日本／東京"

        case "Europe/London":
            return "イギリス／ロンドン"

        case "America/New_York":
            return "アメリカ／ニューヨーク"

        case "America/Los_Angeles":
            return "アメリカ／ロサンゼルス"

        case "Asia/Seoul":
            return "韓国／ソウル"

        case "Asia/Shanghai":
            return "中国／上海"

        case "Europe/Paris":
            return "フランス／パリ"

        case "Europe/Berlin":
            return "ドイツ／ベルリン"

        case "Australia/Sydney":
            return "オーストラリア／シドニー"

        case "Asia/Amman":
            return "ヨルダン／アンマン"

        default:
            return timeZone.identifier
                .replacingOccurrences(
                    of: "_",
                    with: " "
                )
                .replacingOccurrences(
                    of: "/",
                    with: "／"
                )
        }
    }

    // Helper functions for time components with explicit timeZone parameter
    private func hour(timeZone: TimeZone) -> Int {
        calendar(timeZone: timeZone).component(.hour, from: currentDate)
    }
    private func minute(timeZone: TimeZone) -> Int {
        calendar(timeZone: timeZone).component(.minute, from: currentDate)
    }
    private func second(timeZone: TimeZone) -> Int {
        calendar(timeZone: timeZone).component(.second, from: currentDate)
    }
    private func nanosecond(timeZone: TimeZone) -> Int {
        calendar(timeZone: timeZone).component(.nanosecond, from: currentDate)
    }
}

private extension Array where Element == ClockInstance {
    func firstTimeZone() -> TimeZone {
        if let first = self.first {
            return TimeZone(identifier: first.timeZoneIdentifier) ?? .current
        }
        return .current
    }
}

struct ClockHand: View {
    let angle: Angle
    let length: CGFloat
    let color: Color
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let label: String
    let labelColor: Color
    let keepLabelsUpright: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(
                    width: minWidth,
                    height: length
                )
                .cornerRadius(minWidth / 2)
                .offset(y: -length / 2)
                .rotationEffect(angle)

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(
                        width: maxWidth * 1.4,
                        height: maxWidth * 1.4
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                labelColor,
                                lineWidth: maxWidth * 0.1
                            )
                    }
                    .shadow(radius: 1)

                Text(label)
                    .font(
                        .system(
                            size: maxWidth,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(labelColor)
                    .shadow(radius: 1)
                    .rotationEffect(
                        keepLabelsUpright
                            ? -angle
                            : .zero
                    )
            }
            .offset(
                y: -length + maxWidth * 0.2
            )
            .rotationEffect(angle)
        }
    }
}

#Preview {
    ContentView()
}

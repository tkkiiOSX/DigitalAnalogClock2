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

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentDate = Date()
    @State private var showSettings = false

    @AppStorage("keepLabelsUpright")
    private var keepLabelsUpright = false

    @AppStorage("sweepSecondHand")
    private var sweepSecondHand = true

    // AppStorageはFloatに対応していないためDoubleを使用する
    @AppStorage("tickVolume")
    private var tickVolume: Double = 0.8

    @AppStorage("showOuterRing")
    private var showOuterRing = true

    @AppStorage("timeZoneIdentifier")
    private var timeZoneIdentifier = TimeZone.current.identifier

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

    @StateObject private var designSettings =
        ClockDesignSettings()

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

    private var timeZone: TimeZone {
        if followSystemTimeZone,
           let locationTimeZone = locationTimeZoneManager.timeZone {
            return locationTimeZone
        }

        return TimeZone(identifier: timeZoneIdentifier)
            ?? .current
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(
                geometry.size.width,
                geometry.size.height
            )

            clockContainer(size: size)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
        .onReceive(timer) { newDate in
            handleTimer(newDate)
        }
        .onAppear {
            print("ContentView.onAppear が呼ばれました")
            prepareAudioPlayers()
            configureLocationTimeZoneTracking()
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

            timeZoneIdentifier = newTimeZone.identifier
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
            hourlyChimePlayer?.volume = Float(volume)
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

    private func clockContainer(size: CGFloat) -> some View {
        let clockRadius = size * 0.45
        let secondHandWidth = size * 0.04
        let hourHandWidth = size * 0.09

        return clockFace(
            size: size,
            clockRadius: clockRadius,
            secondHandWidth: secondHandWidth,
            hourHandWidth: hourHandWidth
        )
        .overlay(alignment: .bottomTrailing) {
            timeZoneLabel(size: size)
        }
        .overlay(alignment: .topTrailing) {
            settingsButton(size: size)
        }
        .background {
            ZStack {
                // Base background behind the clock (outside the frame remains visible)
                designSettings.backgroundColor
                // Photo only fills the inner face of the frame (outside stays transparent to base)
                clockFaceBackgroundMasked(size: size)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: size * 0.02)
        )
        .sheet(isPresented: $showSettings) {
            settingsView
        }
    }

    private func clockFace(
        size: CGFloat,
        clockRadius: CGFloat,
        secondHandWidth: CGFloat,
        hourHandWidth: CGFloat
    ) -> some View {
        ZStack {
            outerRing(size: size)

            ClockHand(
                angle: hourAngle,
                length: clockRadius * 0.55,
                color: designSettings.hourHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: hourString,
                labelColor: designSettings.hourHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: minuteAngle,
                length: clockRadius * 0.80,
                color: designSettings.minuteHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: minuteString,
                labelColor: designSettings.minuteHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: secondAngle,
                length: clockRadius * 0.92,
                color: designSettings.secondHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: secondString,
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
    private func clockFaceBackgroundMasked(size: CGFloat) -> some View {
        if let image = designSettings.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .mask(innerMask(size: size))
        }
    }

    @ViewBuilder
    private func innerMask(size: CGFloat) -> some View {
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
    private func outerRing(size: CGFloat) -> some View {
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

    private func timeZoneLabel(size: CGFloat) -> some View {
        Text(timeZoneDisplayName)
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

    private func settingsButton(size: CGFloat) -> some View {
        Button {
            showSettings = true
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

    private var settingsView: some View {
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
                    timeZone
                },
                set: { newTimeZone in
                    timeZoneIdentifier = newTimeZone.identifier
                }
            ),
            followSystemTimeZone: $followSystemTimeZone,
            gpsSyncEnabled: $gpsSyncEnabled,
            designSettings: designSettings
        ) {
            showSettings = false
        }
    }

    private func handleTimer(_ newDate: Date) {
        currentDate = newDate
        handleChime(newDate)

        guard !sweepSecondHand else {
            lastSecondPlayed = -1
            return
        }

        let currentSecond = calendar.component(
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
        guard let startOfDay = calendar.startOfDay(
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

        return calendar.date(
            byAdding: .second,
            value: Int(nextElapsedSeconds),
            to: startOfDay
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private var hour: Int {
        calendar.component(
            .hour,
            from: currentDate
        )
    }

    private var minute: Int {
        calendar.component(
            .minute,
            from: currentDate
        )
    }

    private var second: Int {
        calendar.component(
            .second,
            from: currentDate
        )
    }

    private var nanosecond: Int {
        calendar.component(
            .nanosecond,
            from: currentDate
        )
    }

    private var hourAngle: Angle {
        let hourValue = Double(hour % 12)
            + Double(minute) / 60

        return Angle.degrees(
            (hourValue / 12) * 360
        )
    }

    private var minuteAngle: Angle {
        let minuteValue = Double(minute)
            + Double(second) / 60

        return Angle.degrees(
            (minuteValue / 60) * 360
        )
    }

    private var secondAngle: Angle {
        let secondValue: Double

        if sweepSecondHand {
            secondValue = Double(second)
                + Double(nanosecond) / 1_000_000_000
        } else {
            secondValue = Double(second)
        }

        return Angle.degrees(
            (secondValue / 60) * 360
        )
    }

    private var hourString: String {
        String(format: "%d", hour)
    }

    private var minuteString: String {
        String(format: "%02d", minute)
    }

    private var secondString: String {
        String(format: "%02d", second)
    }

    private var timeZoneDisplayName: String {
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

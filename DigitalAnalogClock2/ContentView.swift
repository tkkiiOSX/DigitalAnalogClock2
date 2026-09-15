//
//  ContentView.swift
//  DigitalAnalogClock2
//
//  Created by Xcode2021 on 2026/08/28.
//

import SwiftUI
import Combine
import AVFoundation

struct ClockInfo: Codable, Identifiable {
    let id: UUID
    let timeZoneIdentifier: String
}

@MainActor
final class ClockInstance: ObservableObject, Identifiable {
    let id: UUID

    @Published var timeZoneIdentifier: String
    @Published var designSettings: ClockDesignSettings
    @Published var showSettings = false

    init(
        id: UUID,
        timeZoneIdentifier: String,
        designSettings: ClockDesignSettings? = nil
    ) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
        if let designSettings = designSettings {
            self.designSettings = designSettings
        } else {
            self.designSettings = ClockDesignSettings(keyPrefix: "clockDesign.\(id).")
        }
    }
}

struct ContentView: View {
    @State private var currentDate = Date()

    @AppStorage("keepLabelsUpright")
    private var keepLabelsUpright = false

    @AppStorage("sweepSecondHand")
    private var sweepSecondHand = true

    @AppStorage("tickVolume")
    private var tickVolume: Double = 0.8

    @AppStorage("showOuterRing")
    private var showOuterRing = true

    @AppStorage("hourlyChimeEnabled")
    private var hourlyChimeEnabled = false

    @AppStorage("hourlyChimeVolume")
    private var hourlyChimeVolume: Double = 1.0

    @AppStorage("hourlyChimeIntervalMinutes")
    private var hourlyChimeIntervalMinutes = 60

    @AppStorage("savedClocks")
    private var savedClocksData: Data = {
        let identifiers = [ClockInfo(id: UUID(), timeZoneIdentifier: TimeZone.current.identifier)]
        return (try? JSONEncoder().encode(identifiers)) ?? Data()
    }()

    @State private var clocks: [ClockInstance] = []

    @State private var tickPlayer: AVAudioPlayer?
    @State private var hourlyChimePlayer: AVAudioPlayer?

    @State private var audioIsPrepared = false
    @State private var hourlyChimeAudioIsPrepared = false
    @State private var lastSecondPlayed = -1
    @State private var lastChimeTargetStart: Date?

    @State private var clockToDelete: ClockInstance? = nil
    @State private var showingDeleteAlert = false
    @State private var closeDeleteActionsTrigger = 0

    private let hourlyChimeLeadTimeSeconds: TimeInterval = 3

    private let timer = Timer.publish(
        every: 1.0 / 30.0,
        on: .main,
        in: .common
    )
    .autoconnect()

    private let allowedChimeIntervals = [
        1,
        30,
        60,
        360,
        720,
        1440
    ]

    private var normalizedChimeIntervalMinutes: Int {
        allowedChimeIntervals.contains(hourlyChimeIntervalMinutes)
            ? hourlyChimeIntervalMinutes
            : 60
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.height > geometry.size.width {
                portraitLayout
            } else {
                landscapeLayout(
                    availableHeight: max(120, geometry.size.height - 32)
                )
            }
        }
        .onAppear {
            restoreClocksIfNeeded()
            prepareAudioPlayers()
        }
        .onReceive(timer) { date in
            handleTimer(date)
        }
        .onChange(of: hourlyChimeEnabled) { _, enabled in
            lastChimeTargetStart = nil

            if enabled {
                prepareHourlyChimePlayer()
            } else {
                hourlyChimePlayer?.stop()
                hourlyChimePlayer?.currentTime = 0
            }
        }
        .onChange(of: hourlyChimeVolume) { _, volume in
            hourlyChimePlayer?.volume = Float(volume)
        }
        .onChange(of: hourlyChimeIntervalMinutes) { _, _ in
            lastChimeTargetStart = nil
        }
        .alert("この時計を削除しますか？", isPresented: $showingDeleteAlert) {
            Button("はい", role: .destructive) {
                if let clockToDelete {
                    removeClock(clockToDelete)
                }

                clockToDelete = nil
                closeDeleteActions()
            }

            Button("いいえ", role: .cancel) {
                clockToDelete = nil
                closeDeleteActions()
            }
        } message: {
            Text("この操作は取り消せません。")
        }
    }

    private var portraitLayout: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 24) {
                ForEach(clocks) { clock in
                    deletableClockItem(clock)
                        .aspectRatio(1, contentMode: .fit)
                        .padding()
                }

                addClockButton(size: nil)
                    .aspectRatio(1, contentMode: .fit)
                    .padding()
            }
            .padding()
        }
    }

    private func landscapeLayout(availableHeight: CGFloat) -> some View {
        let spacing: CGFloat = 24
        let clockSize = availableHeight
        let itemCount = CGFloat(clocks.count + 1)
        let contentWidth =
            itemCount * clockSize
            + CGFloat(clocks.count) * spacing

        return ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: spacing) {
                ForEach(clocks) { clock in
                    deletableClockItem(clock)
                        .frame(
                            width: clockSize,
                            height: clockSize
                        )
                }

                addClockButton(size: clockSize)
            }
            .frame(
                width: contentWidth,
                height: availableHeight
            )
            .padding(.horizontal)
        }
        .frame(height: availableHeight)
        .frame(maxHeight: .infinity)
    }

    private func deletableClockItem(_ clock: ClockInstance) -> some View {
        SwipeToRevealDeleteButton(
            canDelete: true,
            closeTrigger: closeDeleteActionsTrigger,
            onDelete: {
                clockToDelete = clock
                showingDeleteAlert = true
            }
        ) {
            clockItem(clock)
        }
    }

    private func clockItem(_ clock: ClockInstance) -> some View {
        let timeZone =
            TimeZone(identifier: clock.timeZoneIdentifier)
            ?? .current

        return ClockView(
            date: currentDate,
            timeZone: timeZone,
            designSettings: clock.designSettings,
            showSettings: binding(
                for: clock,
                keyPath: \.showSettings
            ),
            keepLabelsUpright: $keepLabelsUpright,
            sweepSecondHand: $sweepSecondHand,
            tickVolume: $tickVolume,
            showOuterRing: $showOuterRing,

            // 廃止した自動位置同期用の引数。
            // SettingsView側で使用しないため固定値を渡す。
            followSystemTimeZone: .constant(false),
            gpsSyncEnabled: .constant(false),

            onSettings: {
                setSettingsVisible(true, for: clock)
            },
            onUpdateTimeZone: { newTimeZone in
                updateTimeZone(
                    newTimeZone,
                    for: clock
                )
            },
            onTickVolumeChanged: { newVolume in
                tickVolume = Double(newVolume)
            }
        )
    }

    private func addClockButton(size: CGFloat?) -> some View {
        Button {
            addClock()
        } label: {
            ZStack {
                RoundedRectangle(
                    cornerRadius: (size ?? 200) * 0.12
                )
                .stroke(
                    style: StrokeStyle(
                        lineWidth: max(3, (size ?? 200) * 0.03),
                        dash: [8]
                    )
                )
                .foregroundStyle(.secondary)

                Image(systemName: "plus")
                    .font(
                        .system(
                            size: max(36, (size ?? 200) * 0.18),
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("新しい時計を追加")
    }

    private func binding<Value>(
        for clock: ClockInstance,
        keyPath: ReferenceWritableKeyPath<ClockInstance, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                clock[keyPath: keyPath]
            },
            set: { newValue in
                clock[keyPath: keyPath] = newValue
            }
        )
    }

    private func setSettingsVisible(
        _ visible: Bool,
        for clock: ClockInstance
    ) {
        clock.showSettings = visible
    }

    private func updateTimeZone(
        _ timeZone: TimeZone,
        for clock: ClockInstance
    ) {
        clock.timeZoneIdentifier = timeZone.identifier
        persistClocks()
        lastChimeTargetStart = nil
    }

    private func closeDeleteActions() {
        closeDeleteActionsTrigger += 1
    }

    private func addClock() {
        let newId = UUID()
        let newClock = ClockInstance(
            id: newId,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        clocks.append(newClock)
        persistClocks()
    }

    private func restoreClocksIfNeeded() {
        guard clocks.isEmpty else {
            return
        }

        if let infos = try? JSONDecoder().decode(
            [ClockInfo].self,
            from: savedClocksData
        ) {
            clocks = infos.map { info in
                let designSettings = ClockDesignSettings(keyPrefix: "clockDesign.\(info.id).")
                return ClockInstance(
                    id: info.id,
                    timeZoneIdentifier: info.timeZoneIdentifier,
                    designSettings: designSettings
                )
            }
        } else {
            let defaultId = UUID()
            clocks = [
                ClockInstance(
                    id: defaultId,
                    timeZoneIdentifier: TimeZone.current.identifier
                )
            ]
            persistClocks()
        }
    }

    private func persistClocks() {
        let infos = clocks.map { ClockInfo(id: $0.id, timeZoneIdentifier: $0.timeZoneIdentifier) }

        guard let data = try? JSONEncoder().encode(infos) else {
            return
        }

        savedClocksData = data
    }

    /// 時計を削除し、関連するUserDefaultsのデザイン設定も削除するメソッド
    private func removeClock(_ clock: ClockInstance) {
        // Remove design settings from UserDefaults
        clock.designSettings.removeAllStoredSettings()

        // Remove from clocks array
        clocks.removeAll { $0.id == clock.id }
        persistClocks()
    }

    private func handleTimer(_ date: Date) {
        currentDate = date
        handleChime(date)

        guard !sweepSecondHand else {
            lastSecondPlayed = -1
            return
        }

        let timeZone = clocks.firstTimeZone()
        let calendar = calendar(timeZone: timeZone)
        let second = calendar.component(.second, from: date)

        guard second != lastSecondPlayed else {
            return
        }

        playTickSound()
        lastSecondPlayed = second
    }

    private func handleChime(_ date: Date) {
        guard hourlyChimeEnabled,
              hourlyChimeVolume > 0,
              let target = nextChimeTargetStart(after: date)
        else {
            return
        }

        let remaining = target.timeIntervalSince(date)

        guard remaining > 0,
              remaining <= hourlyChimeLeadTimeSeconds,
              lastChimeTargetStart != target
        else {
            return
        }

        let elapsed =
            hourlyChimeLeadTimeSeconds - remaining

        playHourlyChimeSound(
            elapsedFromIdealStart: elapsed
        )

        lastChimeTargetStart = target
    }

    private func nextChimeTargetStart(after date: Date) -> Date? {
        let calendar = calendar(
            timeZone: clocks.firstTimeZone()
        )
        let startOfDay = calendar.startOfDay(for: date)
        let interval = TimeInterval(
            normalizedChimeIntervalMinutes * 60
        )
        let elapsed = date.timeIntervalSince(startOfDay)
        let nextSlot = floor(elapsed / interval) + 1
        let seconds = Int(nextSlot * interval)

        return calendar.date(
            byAdding: .second,
            value: seconds,
            to: startOfDay
        )
    }

    private func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private func prepareAudioPlayers() {
        prepareAudioPlayer()
        prepareHourlyChimePlayer()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )

        try session.setActive(true)
    }

    private func prepareAudioPlayer() {
        guard !audioIsPrepared else {
            tickPlayer?.volume = Float(tickVolume)
            return
        }

        guard let url = Bundle.main.url(
            forResource: "CLOCK01",
            withExtension: "mp3"
        ) else {
            print("CLOCK01.mp3がBundleに見つかりません")
            return
        }

        do {
            try configureAudioSession()

            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(tickVolume)
            player.numberOfLoops = 0
            player.prepareToPlay()

            tickPlayer = player
            audioIsPrepared = true
        } catch {
            tickPlayer = nil
            audioIsPrepared = false
            print("CLOCK01.mp3の準備に失敗しました: \(error)")
        }
    }

    private func prepareHourlyChimePlayer() {
        guard !hourlyChimeAudioIsPrepared else {
            hourlyChimePlayer?.volume = Float(hourlyChimeVolume)
            return
        }

        guard let url = Bundle.main.url(
            forResource: "jihou",
            withExtension: "mp3"
        ) else {
            print("jihou.mp3がBundleに見つかりません")
            return
        }

        do {
            try configureAudioSession()

            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(hourlyChimeVolume)
            player.numberOfLoops = 0
            player.prepareToPlay()

            hourlyChimePlayer = player
            hourlyChimeAudioIsPrepared = true
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

        guard let player = tickPlayer else {
            return
        }

        player.stop()
        player.currentTime = 0
        player.volume = Float(tickVolume)
        player.play()
    }

    private func playHourlyChimeSound(
        elapsedFromIdealStart: TimeInterval
    ) {
        if !hourlyChimeAudioIsPrepared ||
            hourlyChimePlayer == nil {
            prepareHourlyChimePlayer()
        }

        guard let player = hourlyChimePlayer else {
            return
        }

        player.stop()
        player.volume = Float(hourlyChimeVolume)
        player.currentTime = min(
            max(0, elapsedFromIdealStart),
            player.duration
        )
        player.prepareToPlay()
        player.play()
    }
}

private struct SwipeToRevealDeleteButton<Content: View>: View {
    let canDelete: Bool
    let closeTrigger: Int
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var settledOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 88
    private let swipeThreshold: CGFloat = 36

    private var currentOffset: CGFloat {
        min(0, max(-actionWidth, settledOffset + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.title3)

                        Text("削除")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(.red)
                .contentShape(Rectangle())
            }

            content()
                .offset(x: canDelete ? currentOffset : 0)
                .contentShape(Rectangle())
                .allowsHitTesting(settledOffset == 0)
                .gesture(
                    DragGesture(minimumDistance: 16)
                        .onChanged { value in
                            guard canDelete,
                                  abs(value.translation.width) > abs(value.translation.height)
                            else {
                                return
                            }

                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            guard canDelete else {
                                return
                            }

                            let projectedOffset = settledOffset + value.translation.width
                            let shouldOpen = projectedOffset < -swipeThreshold

                            withAnimation(.snappy(duration: 0.2)) {
                                settledOffset = shouldOpen ? -actionWidth : 0
                                dragOffset = 0
                            }
                        }
                )
        }
        .clipped()
        .onChange(of: canDelete) { _, newValue in
            if !newValue {
                closeAction()
            }
        }
        .onChange(of: closeTrigger) { _, _ in
            closeAction()
        }
    }

    private func closeAction() {
        withAnimation(.snappy(duration: 0.2)) {
            settledOffset = 0
            dragOffset = 0
        }
    }
}

private extension Array where Element == ClockInstance {
    func firstTimeZone() -> TimeZone {
        guard let first = first else {
            return .current
        }

        return TimeZone(
            identifier: first.timeZoneIdentifier
        ) ?? .current
    }
}

#Preview {
    ContentView()
}

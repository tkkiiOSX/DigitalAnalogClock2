import SwiftUI
import Foundation
import PhotosUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Float
    @Binding var showOuterRing: Bool
    @Binding var timeZone: TimeZone

    @ObservedObject var designSettings: ClockDesignSettings

    var onOK: () -> Void

    @State private var showingDesignSettings = false

    private static let timeZoneOptions: [TimeZoneOption] = {
        let referenceDate = Date()

        return TimeZone.knownTimeZoneIdentifiers
            .compactMap { identifier in
                guard let timeZone = TimeZone(identifier: identifier) else {
                    return nil
                }

                return TimeZoneOption(
                    identifier: identifier,
                    timeZone: timeZone,
                    referenceDate: referenceDate
                )
            }
            .sorted {
                let nameComparison = $0.title.localizedStandardCompare(
                    $1.title
                )

                if nameComparison == .orderedSame {
                    return $0.identifier < $1.identifier
                }

                return nameComparison == .orderedAscending
            }
    }()

    private static let timeZoneOptionsByIdentifier: [String: TimeZoneOption] =
        Dictionary(
            uniqueKeysWithValues: timeZoneOptions.map {
                ($0.identifier, $0)
            }
        )

    private var currentTimeZoneTitle: String {
        Self.timeZoneOptionsByIdentifier[timeZone.identifier]?.title
            ?? timeZone.identifier
    }

    var body: some View {
        NavigationStack {
            Form {
                clockDesignSection
                timeZoneSection
                numeralStyleSection
            }
            .navigationTitle("設定 (Settings)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了 (Done)") {
                        closeSettings()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDesignSettings) {
            DesignSettingsView(
                keepLabelsUpright: $keepLabelsUpright,
                sweepSecondHand: $sweepSecondHand,
                tickVolume: $tickVolume,
                showOuterRing: $showOuterRing,
                settings: designSettings
            )
        }
    }

    private var clockDesignSection: some View {
        Section(header: Text("時計デザイン (Clock Design)")) {
            Button {
                showingDesignSettings = true
            } label: {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    DesignClockPreview(
                        settings: designSettings,
                        keepLabelsUpright: keepLabelsUpright
                    )
                    .frame(width: 220, height: 220)
                    .mask {
                        GeometryReader { geo in
                            let size = min(
                                geo.size.width,
                                geo.size.height
                            )

                            switch designSettings.frameStyle {
                            case .circle:
                                Circle()

                            case .rectangle:
                                Rectangle()

                            case .roundedRectangle:
                                RoundedRectangle(
                                    cornerRadius: size * 0.12
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

                            switch designSettings.frameStyle {
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
                                    cornerRadius: size * 0.12
                                )
                                .stroke(
                                    .secondary.opacity(0.35),
                                    lineWidth: 1
                                )
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(
                            "時計外観を変更\n"
                                + "(Change Clock Appearance)"
                        )
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var timeZoneSection: some View {
        Section(header: Text("タイムゾーン (Time Zone)")) {
            NavigationLink {
                TimeZoneSelectionView(
                    options: Self.timeZoneOptions,
                    selectedIdentifier: timeZone.identifier
                ) { option in
                    selectTimeZone(option)
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("タイムゾーン\n(Time Zone)")
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    Spacer(minLength: 8)

                    Text(currentTimeZoneTitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }

            Text(
                "同じUTC時差でも、地域ごとに夏時間や過去の時差変更が異なる場合があります。\n"
                    + "(Even with the same UTC offset, daylight saving time and historical offset changes may differ by region.)"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private var numeralStyleSection: some View {
        Section(header: Text("数字の表示 (Numeral Display)")) {
            Picker(
                selection: $designSettings.numeralStyle
            ) {
                ForEach(NumeralStyle.allCases) { style in
                    Text(style.displayName)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .tag(style)
                }
            } label: {
                Text(
                    "針の先端の数字\n"
                        + "(Numbers in Hand Tips)"
                )
                .multilineTextAlignment(.leading)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
            .pickerStyle(.segmented)

            Text(
                "複数の数字形式から選択できます。\n"
                    + "(You can choose from multiple number formats.)"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private func closeSettings() {
        onOK()
        dismiss()
    }

    private func selectTimeZone(_ option: TimeZoneOption) {
        timeZone = option.timeZone
    }
}

private struct TimeZoneSelectionView: View {
    let options: [TimeZoneOption]
    let selectedIdentifier: String
    let onSelect: (TimeZoneOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredOptions: [TimeZoneOption] {
        TimeZoneOption.filtered(
            options,
            searchText: searchText
        )
    }

    var body: some View {
        List {
            ForEach(filteredOptions) { option in
                Button {
                    onSelect(option)
                    dismiss()
                } label: {
                    TimeZoneOptionRow(
                        option: option,
                        isSelected: option.identifier == selectedIdentifier
                    )
                }
            }
        }
        .navigationTitle("タイムゾーン\n(Time Zone)")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "タイムゾーン名・都市名・識別子で検索\n(Search by time zone, city, or identifier)"
        )
    }
}

private struct TimeZoneOptionRow: View {
    let option: TimeZoneOption
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Text(option.identifier)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }
}

private struct TimeZoneOption: Identifiable, Hashable {
    let identifier: String
    let timeZone: TimeZone
    let title: String
    let normalizedSearchText: String

    var id: String {
        identifier
    }

    init(
        identifier: String,
        timeZone: TimeZone,
        referenceDate: Date
    ) {
        self.identifier = identifier
        self.timeZone = timeZone

        let title = Self.makeTitle(
            identifier: identifier,
            timeZone: timeZone,
            referenceDate: referenceDate
        )

        self.title = title
        self.normalizedSearchText = [
            title,
            identifier
        ]
        .joined(separator: " ")
        .normalizedForTimeZoneSearch
    }

    static func filtered(
        _ options: [TimeZoneOption],
        searchText: String
    ) -> [TimeZoneOption] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .normalizedForTimeZoneSearch

        guard !query.isEmpty else {
            return options
        }

        return options.filter {
            $0.normalizedSearchText.contains(query)
        }
    }

    private static func makeTitle(
        identifier: String,
        timeZone: TimeZone,
        referenceDate: Date
    ) -> String {
        let name: String

        if let location = locationNames[identifier] {
            name = "\(location.country)／\(location.city)"
        } else {
            name = timeZone.localizedName(
                for: .generic,
                locale: Locale(identifier: "ja_JP")
            ) ?? fallbackDisplayName(for: identifier)
        }

        let englishName = englishDisplayName(
            for: identifier
        )

        let utcText = utcOffsetString(
            for: timeZone,
            referenceDate: referenceDate
        )

        return "\(name) (\(englishName))\n（UTC\(utcText)）"
    }

    private static func englishDisplayName(
        for identifier: String
    ) -> String {
        identifier
            .split(separator: "/")
            .map { part in
                part
                    .replacingOccurrences(
                        of: "_",
                        with: " "
                    )
                    .replacingOccurrences(
                        of: "St ",
                        with: "St. "
                    )
            }
            .joined(separator: " / ")
    }

    private static func utcOffsetString(
        for timeZone: TimeZone,
        referenceDate: Date
    ) -> String {
        let seconds = timeZone.secondsFromGMT(
            for: referenceDate
        )

        let sign = seconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(seconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60

        return "\(sign)\(String(format: "%02d:%02d", hours, minutes))"
    }

    private static func fallbackDisplayName(
        for identifier: String
    ) -> String {
        identifier
            .replacingOccurrences(
                of: "_",
                with: " "
            )
            .replacingOccurrences(
                of: "/",
                with: "／"
            )
    }

    private static let locationNames: [
        String: (country: String, city: String)
    ] = [
        "Asia/Tokyo": ("日本", "東京"),
        "Europe/London": ("イギリス", "ロンドン"),
        "America/New_York": ("アメリカ", "ニューヨーク"),
        "America/Chicago": ("アメリカ", "シカゴ"),
        "America/Denver": ("アメリカ", "デンバー"),
        "America/Los_Angeles": ("アメリカ", "ロサンゼルス"),
        "America/Anchorage": ("アメリカ", "アンカレッジ"),
        "Pacific/Honolulu": ("アメリカ", "ホノルル"),
        "Europe/Paris": ("フランス", "パリ"),
        "Europe/Berlin": ("ドイツ", "ベルリン"),
        "Europe/Rome": ("イタリア", "ローマ"),
        "Europe/Madrid": ("スペイン", "マドリード"),
        "Asia/Seoul": ("韓国", "ソウル"),
        "Asia/Shanghai": ("中国", "上海"),
        "Asia/Hong_Kong": ("香港", "香港"),
        "Asia/Singapore": ("シンガポール", "シンガポール"),
        "Australia/Sydney": ("オーストラリア", "シドニー"),
        "Australia/Melbourne": ("オーストラリア", "メルボルン"),
        "Australia/Brisbane": ("オーストラリア", "ブリスベン"),
        "Australia/Adelaide": ("オーストラリア", "アデレード"),
        "Australia/Perth": ("オーストラリア", "パース"),
        "Australia/Darwin": ("オーストラリア", "ダーウィン"),
        "Australia/Hobart": ("オーストラリア", "ホバート"),
        "Pacific/Auckland": ("ニュージーランド", "オークランド"),
        "Asia/Dubai": ("アラブ首長国連邦", "ドバイ"),
        "Asia/Kolkata": ("インド", "コルカタ"),
        "America/Toronto": ("カナダ", "トロント"),
        "America/Vancouver": ("カナダ", "バンクーバー"),
        "America/Edmonton": ("カナダ", "エドモントン"),
        "America/Winnipeg": ("カナダ", "ウィニペグ"),
        "America/Halifax": ("カナダ", "ハリファックス"),
        "America/St_Johns": ("カナダ", "セントジョンズ"),
        "America/Sao_Paulo": ("ブラジル", "サンパウロ"),
        "Asia/Amman": ("ヨルダン", "アンマン"),
        "Europe/Vienna": ("オーストリア", "ウィーン"),
        "Europe/Brussels": ("ベルギー", "ブリュッセル"),
        "Africa/Cairo": ("エジプト", "カイロ"),
        "Europe/Prague": ("チェコ", "プラハ"),
        "Europe/Copenhagen": ("デンマーク", "コペンハーゲン"),
        "America/Port-au-Prince": ("ハイチ", "ポルトープランス"),
        "Europe/Budapest": ("ハンガリー", "ブダペスト"),
        "Atlantic/Reykjavik": ("アイスランド", "レイキャヴィーク"),
        "Africa/Nairobi": ("ケニア", "ナイロビ"),
        "Asia/Kuwait": ("クウェート", "クウェート"),
        "Europe/Vaduz": ("リヒテンシュタイン", "ファドゥーツ"),
        "Europe/Luxembourg": ("ルクセンブルク", "ルクセンブルク"),
        "Europe/Monaco": ("モナコ", "モナコ"),
        "Africa/Lagos": ("ナイジェリア", "ラゴス"),
        "Europe/Oslo": ("ノルウェー", "オスロ"),
        "Pacific/Nauru": ("ナウル", "ナウル"),
        "Asia/Muscat": ("オマーン", "マスカット"),
        "Pacific/Port_Moresby": ("パプアニューギニア", "ポートモレスビー"),
        "Europe/Warsaw": ("ポーランド", "ワルシャワ"),
        "Europe/Lisbon": ("ポルトガル", "リスボン"),
        "Asia/Qatar": ("カタール", "カタール"),
        "Europe/Moscow": ("ロシア", "モスクワ"),
        "Asia/Riyadh": ("サウジアラビア", "リヤド"),
        "Pacific/Guadalcanal": ("ソロモン諸島", "ホニアラ"),
        "Europe/Stockholm": ("スウェーデン", "ストックホルム"),
        "Europe/San_Marino": ("サンマリノ", "サンマリノ"),
        "Europe/Istanbul": ("トルコ", "イスタンブール"),
        "Europe/Kyiv": ("ウクライナ", "キーウ"),
        "Europe/Vatican": ("バチカン", "バチカン"),
        "Africa/Johannesburg": ("南アフリカ", "ヨハネスブルグ"),
        "America/Mexico_City": ("メキシコ", "メキシコシティ"),
        "America/Cancun": ("メキシコ", "カンクン"),
        "America/Chihuahua": ("メキシコ", "チワワ"),
        "America/Hermosillo": ("メキシコ", "エルモシージョ"),
        "America/Mazatlan": ("メキシコ", "マサトラン"),
        "America/Tijuana": ("メキシコ", "ティフアナ")
    ]
}

private extension String {
    var normalizedForTimeZoneSearch: String {
        folding(
            options: [
                .diacriticInsensitive,
                .caseInsensitive
            ],
            locale: Locale(identifier: "ja_JP")
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            keepLabelsUpright: .constant(true),
            sweepSecondHand: .constant(true),
            tickVolume: .constant(0.8),
            showOuterRing: .constant(true),
            timeZone: .constant(.current),
            designSettings: ClockDesignSettings()
        ) {}
    }
}

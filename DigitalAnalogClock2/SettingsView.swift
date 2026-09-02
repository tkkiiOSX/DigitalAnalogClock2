import SwiftUI
import Foundation
import PhotosUI
import UIKit

struct SettingsView: View {
    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Float
    @Binding var showOuterRing: Bool
    @Binding var timeZone: TimeZone
    @Binding var gpsSyncEnabled: Bool

    @ObservedObject var designSettings: ClockDesignSettings

    var onOK: () -> Void

    @State private var showingMultipleTimeZones = false
    @State private var showingUnavailableTimeZoneAlert = false
    @State private var regionTimeZoneCandidates: [TimeZoneOption] = []
    @State private var showingDesignSettings = false
    @State private var timeZonePickerSearchText: String = ""
    @State private var showingTimeZoneSearch = false
    @State private var timeZoneSearchText: String = ""

    private var timeZoneOptions: [TimeZoneOption] {
        TimeZone.knownTimeZoneIdentifiers
            .compactMap { identifier in
                guard let timeZone = TimeZone(identifier: identifier) else {
                    return nil
                }

                return TimeZoneOption(
                    identifier: identifier,
                    timeZone: timeZone
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
    }
    private var filteredTimeZoneOptions: [TimeZoneOption] {
        let q = timeZonePickerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return timeZoneOptions }
        let normalizedQuery = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return timeZoneOptions.filter { option in
            let candidates = [
                option.title,
                option.identifier,
                option.displayName
            ].map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
            return candidates.contains { $0.contains(normalizedQuery) }
        }
    }
    private var currentTimeZoneTitle: String {
        timeZoneOptions.first(where: { $0.identifier == timeZone.identifier })?.title ?? timeZone.identifier
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("時計デザイン")) {
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
                                    let size = min(geo.size.width, geo.size.height)
                                    switch designSettings.frameStyle {
                                    case .circle:
                                        Circle()
                                    case .rectangle:
                                        Rectangle()
                                    case .roundedRectangle:
                                        RoundedRectangle(cornerRadius: size * 0.12)
                                    }
                                }
                            }
                            .overlay {
                                GeometryReader { geo in
                                    let size = min(geo.size.width, geo.size.height)
                                    switch designSettings.frameStyle {
                                    case .circle:
                                        Circle().stroke(.secondary.opacity(0.35), lineWidth: 1)
                                    case .rectangle:
                                        Rectangle().stroke(.secondary.opacity(0.35), lineWidth: 1)
                                    case .roundedRectangle:
                                        RoundedRectangle(cornerRadius: size * 0.12)
                                            .stroke(.secondary.opacity(0.35), lineWidth: 1)
                                    }
                                }
                            }

                            HStack {
                                Text("時計外観を変更")
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section(header: Text("位置情報")) {
                    Toggle(
                        "GPSロケーションに同期",
                        isOn: $gpsSyncEnabled
                    )

                    Text(
                        "現在地に合わせてタイムゾーンを自動更新します"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section(header: Text("タイムゾーン")) {
                    NavigationLink {
                        TimeZoneSelectionView(
                            options: timeZoneOptions,
                            selectedIdentifier: timeZone.identifier
                        ) { option in
                            selectRegionTimeZone(option)
                        }
                    } label: {
                        HStack {
                            Text("タイムゾーン")
                            Spacer()
                            Text(currentTimeZoneTitle)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(
                        "同じUTC時差でも、地域ごとに夏時間や過去の時差変更が異なる場合があります。"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button {
                        applyRegionTimeZone()
                    } label: {
                        Label(
                            "言語と地域の地域を反映",
                            systemImage: "globe"
                        )
                    }
                    Button {
                        prefillAndOpenSearchFromRegion()
                    } label: {
                        Label(
                            "言語と地域の地域の設定から探す",
                            systemImage: "magnifyingglass"
                        )
                    }
                    .font(.footnote)
                }
            }
            .navigationTitle("設定")
        }
        .toolbar {
            ToolbarItem(
                placement: .navigationBarTrailing
            ) {
                Button("完了") {
                    onOK()
                }
            }
        }
        .alert(
            "タイムゾーンを自動判定できません",
            isPresented: $showingUnavailableTimeZoneAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("タイムゾーン一覧から選択して下さい。")
        }
        .confirmationDialog(
            "複数のタイムゾーンがあります。一覧から選択して下さい。",
            isPresented: $showingMultipleTimeZones,
            titleVisibility: .visible
        ) {
            ForEach(regionTimeZoneCandidates) { option in
                Button {
                    selectRegionTimeZone(option)
                } label: {
                    Text(option.displayName)
                }
            }

            Button("キャンセル", role: .cancel) {}
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
        .sheet(isPresented: $showingTimeZoneSearch) {
            TimeZoneSearchView(
                options: timeZoneOptions,
                searchText: $timeZoneSearchText
            ) { option in
                selectRegionTimeZone(option)
                showingTimeZoneSearch = false
            }
        }
    }

    private func applyRegionTimeZone() {
        guard let regionCode = Locale.current.regionCode else {
            showingUnavailableTimeZoneAlert = true
            return
        }

        let candidates = regionTimeZoneCandidates(
            for: regionCode
        )

        guard !candidates.isEmpty else {
            showingUnavailableTimeZoneAlert = true
            return
        }

        if candidates.count == 1,
           let candidate = candidates.first {
            selectRegionTimeZone(candidate)
        } else {
            regionTimeZoneCandidates = candidates
            showingMultipleTimeZones = true
        }
    }
    private func prefillAndOpenSearchFromRegion() {
        if let code = Locale.current.regionCode {
            let name = Locale.current.localizedString(forRegionCode: code) ?? code
            timeZoneSearchText = name
        } else {
            timeZoneSearchText = ""
        }
        showingTimeZoneSearch = true
    }

    private func selectRegionTimeZone(_ option: TimeZoneOption) {
        guard option.identifier != timeZone.identifier else {
            return
        }

        gpsSyncEnabled = false
        timeZone = option.timeZone
    }

    private func regionTimeZoneCandidates(
        for regionCode: String
    ) -> [TimeZoneOption] {
        regionCodeToTimeZoneIDs(regionCode.uppercased())
            .compactMap { identifier in
                guard let timeZone = TimeZone(identifier: identifier) else {
                    return nil
                }

                return TimeZoneOption(
                    identifier: identifier,
                    timeZone: timeZone
                )
            }
    }

    private func regionCodeToTimeZoneIDs(
        _ regionCode: String
    ) -> [String] {
        Self.regionTimeZoneMap[regionCode] ?? []
    }

    private static let regionTimeZoneMap: [
        String: [String]
    ] = [
        "AD": ["Europe/Andorra"],
        "AE": ["Asia/Dubai"],
        "AR": ["America/Argentina/Buenos_Aires"],
        "AT": ["Europe/Vienna"],
        "AU": [
            "Australia/Sydney",
            "Australia/Melbourne",
            "Australia/Brisbane",
            "Australia/Adelaide",
            "Australia/Perth",
            "Australia/Darwin",
            "Australia/Hobart"
        ],
        "BE": ["Europe/Brussels"],
        "BH": ["Asia/Bahrain"],
        "BR": [
            "America/Sao_Paulo",
            "America/Manaus",
            "America/Belem",
            "America/Fortaleza",
            "America/Recife",
            "America/Bahia",
            "America/Porto_Velho",
            "America/Boa_Vista",
            "America/Rio_Branco"
        ],
        "CA": [
            "America/Toronto",
            "America/Vancouver",
            "America/Edmonton",
            "America/Winnipeg",
            "America/Halifax",
            "America/St_Johns"
        ],
        "CH": ["Europe/Zurich"],
        "CN": ["Asia/Shanghai"],
        "CZ": ["Europe/Prague"],
        "DE": ["Europe/Berlin"],
        "DK": ["Europe/Copenhagen"],
        "EG": ["Africa/Cairo"],
        "ES": [
            "Europe/Madrid",
            "Atlantic/Canary"
        ],
        "FI": ["Europe/Helsinki"],
        "FO": ["Atlantic/Faroe"],
        "FR": ["Europe/Paris"],
        "GB": ["Europe/London"],
        "GG": ["Europe/Guernsey"],
        "GI": ["Europe/Gibraltar"],
        "GL": [
            "America/Nuuk",
            "America/Godthab",
            "America/Scoresbysund",
            "America/Thule"
        ],
        "GR": ["Europe/Athens"],
        "HK": ["Asia/Hong_Kong"],
        "HT": ["America/Port-au-Prince"],
        "HU": ["Europe/Budapest"],
        "ID": [
            "Asia/Jakarta",
            "Asia/Makassar",
            "Asia/Jayapura"
        ],
        "IE": ["Europe/Dublin"],
        "IM": ["Europe/Isle_of_Man"],
        "IN": ["Asia/Kolkata"],
        "IS": ["Atlantic/Reykjavik"],
        "IT": ["Europe/Rome"],
        "JE": ["Europe/Jersey"],
        "JO": ["Asia/Amman"],
        "JP": ["Asia/Tokyo"],
        "KE": ["Africa/Nairobi"],
        "KR": ["Asia/Seoul"],
        "KW": ["Asia/Kuwait"],
        "LI": ["Europe/Vaduz"],
        "LU": ["Europe/Luxembourg"],
        "MC": ["Europe/Monaco"],
        "MT": ["Europe/Malta"],
        "MX": [
            "America/Mexico_City",
            "America/Cancun",
            "America/Chihuahua",
            "America/Hermosillo",
            "America/Matamoros",
            "America/Mazatlan",
            "America/Merida",
            "America/Monterrey",
            "America/Ojinaga",
            "America/Tijuana"
        ],
        "VE": ["America/Caracas"],
        "PE": ["America/Lima"],
        "CL": [
            "America/Santiago",
            "Pacific/Easter"
        ],
        "CO": ["America/Bogota"],
        "EC": [
            "America/Guayaquil",
            "Pacific/Galapagos"
        ],
        "BO": ["America/La_Paz"],
        "PY": ["America/Asuncion"],
        "UY": ["America/Montevideo"],
        "PA": ["America/Panama"],
        "CR": ["America/Costa_Rica"],
        "GT": ["America/Guatemala"],
        "SV": ["America/El_Salvador"],
        "HN": ["America/Tegucigalpa"],
        "NI": ["America/Managua"],
        "DO": ["America/Santo_Domingo"],
        "CU": ["America/Havana"],
        "PR": ["America/Puerto_Rico"],
        "JM": ["America/Jamaica"],
        "TT": ["America/Port_of_Spain"],
        "BZ": ["America/Belize"],
        "GF": ["America/Cayenne"],
        "GY": ["America/Guyana"],
        "SR": ["America/Paramaribo"],
        "NL": ["Europe/Amsterdam"],
        "NO": ["Europe/Oslo"],
        "NR": ["Pacific/Nauru"],
        "NZ": [
            "Pacific/Auckland",
            "Pacific/Chatham"
        ],
        "OM": ["Asia/Muscat"],
        "PG": [
            "Pacific/Port_Moresby",
            "Pacific/Bougainville"
        ],
        "PL": ["Europe/Warsaw"],
        "PT": [
            "Europe/Lisbon",
            "Atlantic/Madeira",
            "Atlantic/Azores"
        ],
        "QA": ["Asia/Qatar"],
        "RU": [
            "Europe/Moscow",
            "Europe/Kaliningrad",
            "Europe/Samara",
            "Asia/Yekaterinburg",
            "Asia/Omsk",
            "Asia/Novosibirsk",
            "Asia/Irkutsk",
            "Asia/Yakutsk",
            "Asia/Vladivostok",
            "Asia/Magadan",
            "Asia/Sakhalin",
            "Asia/Kamchatka",
            "Asia/Anadyr"
        ],
        "SA": ["Asia/Riyadh"],
        "SB": ["Pacific/Guadalcanal"],
        "SE": ["Europe/Stockholm"],
        "SG": ["Asia/Singapore"],
        "SM": ["Europe/San_Marino"],
        "TR": ["Europe/Istanbul"],
        "UA": ["Europe/Kyiv"],
        "VA": ["Europe/Vatican"],
        "ZA": ["Africa/Johannesburg"]
    ]
}

private struct TimeZoneSelectionView: View {
    let options: [TimeZoneOption]
    let selectedIdentifier: String
    let onSelect: (TimeZoneOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filteredOptions: [TimeZoneOption] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return options }
        let normalizedQuery = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return options.filter { option in
            let candidates = [
                option.title,
                option.identifier,
                option.displayName
            ].map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
            return candidates.contains { $0.contains(normalizedQuery) }
        }
    }

    var body: some View {
        List {
            ForEach(filteredOptions) { option in
                Button {
                    onSelect(option)
                    dismiss()
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .foregroundStyle(.primary)
                            Text(option.identifier)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if option.identifier == selectedIdentifier {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("タイムゾーン")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "タイムゾーン名・都市名・識別子で検索"
        )
    }
}

private struct TimeZoneSearchView: View {
    let options: [TimeZoneOption]
    @Binding var searchText: String
    let onSelect: (TimeZoneOption) -> Void

    @Environment(\.dismiss) private var dismiss

    private var filteredOptions: [TimeZoneOption] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return options }
        let normalizedQuery = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return options.filter { option in
            let candidates = [
                option.title,
                option.identifier,
                option.displayName
            ].map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
            return candidates.contains { $0.contains(normalizedQuery) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredOptions.isEmpty {
                    Text("一致するタイムゾーンがありません。他の言語で入力してみてください。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredOptions) { option in
                        Button {
                            onSelect(option)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Text(option.identifier)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("タイムゾーンを検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "都市名・国名・識別子で検索"
            )
        }
    }
}

private struct TimeZoneOption: Identifiable {
    let identifier: String
    let timeZone: TimeZone

    var id: String {
        identifier
    }

    var displayName: String {
        "\(title)\n識別子: \(identifier)"
    }

    var title: String {
        let name: String

        if let location = locationName {
            name = "\(location.country)／\(location.city)"
        } else {
            name = timeZone.localizedName(
                for: .generic,
                locale: Locale(identifier: "ja_JP")
            ) ?? fallbackDisplayName
        }

        return "\(name)（UTC\(utcOffsetString)）"
    }

    private var utcOffsetString: String {
        let seconds = timeZone.secondsFromGMT(
            for: Date()
        )

        let sign = seconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(seconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60

        return "\(sign)\(String(format: "%02d:%02d", hours, minutes))"
    }

    private var locationName: (
        country: String,
        city: String
    )? {
        Self.locationNames[identifier]
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

    private var fallbackDisplayName: String {
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            keepLabelsUpright: .constant(true),
            sweepSecondHand: .constant(true),
            tickVolume: .constant(0.8),
            showOuterRing: .constant(true),
            timeZone: .constant(.current),
            gpsSyncEnabled: .constant(true),
            designSettings: ClockDesignSettings()
        ) {}
    }
}


import SwiftUI
import Foundation

struct SettingsView: View {
    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Float
    @Binding var showOuterRing: Bool
    @Binding var timeZone: TimeZone
    @Binding var gpsSyncEnabled: Bool

    var onOK: () -> Void

    @State private var showingMultipleTimeZones = false
    @State private var showingUnavailableTimeZoneAlert = false
    @State private var regionTimeZoneCandidates: [TimeZoneOption] = []

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
                $0.displayName.localizedStandardCompare($1.displayName)
                    == .orderedAscending
            }
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

                Section(header: Text("表示")) {
                    Toggle(
                        "文字盤の外側の丸枠を表示",
                        isOn: $showOuterRing
                    )
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
                    Picker(
                        "タイムゾーン",
                        selection: Binding(
                            get: {
                                timeZone.identifier
                            },
                            set: { identifier in
                                guard identifier != timeZone.identifier else {
                                    return
                                }

                                gpsSyncEnabled = false

                                if let selectedTimeZone = TimeZone(
                                    identifier: identifier
                                ) {
                                    timeZone = selectedTimeZone
                                }
                            }
                        )
                    ) {
                        ForEach(timeZoneOptions) { option in
                            Text(option.displayName)
                                .tag(option.identifier)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Button {
                        applyRegionTimeZone()
                    } label: {
                        Label(
                            "言語と地域の地域を反映",
                            systemImage: "globe"
                        )
                    }
                    .font(.footnote)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button("OK") {
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
                    Button(option.displayName) {
                        selectRegionTimeZone(option)
                    }
                }

                Button("キャンセル", role: .cancel) {}
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
        let identifiers = regionCodeToTimeZoneIDs(
            regionCode.uppercased()
        )

        return identifiers.compactMap { identifier in
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
        switch regionCode {
        case "AD":
            return ["Europe/Andorra"]

        case "AE":
            return ["Asia/Dubai"]

        case "AR":
            return ["America/Argentina/Buenos_Aires"]

        case "AT":
            return ["Europe/Vienna"]

        case "AU":
            return [
                "Australia/Sydney",
                "Australia/Melbourne",
                "Australia/Brisbane",
                "Australia/Adelaide",
                "Australia/Perth",
                "Australia/Darwin",
                "Australia/Hobart"
            ]

        case "BE":
            return ["Europe/Brussels"]

        case "BH":
            return ["Asia/Bahrain"]

        case "BR":
            return [
                "America/Sao_Paulo",
                "America/Manaus",
                "America/Belem",
                "America/Fortaleza",
                "America/Recife",
                "America/Bahia",
                "America/Porto_Velho",
                "America/Boa_Vista",
                "America/Rio_Branco"
            ]

        case "CA":
            return [
                "America/Toronto",
                "America/Vancouver",
                "America/Edmonton",
                "America/Winnipeg",
                "America/Halifax",
                "America/St_Johns"
            ]

        case "CH":
            return ["Europe/Zurich"]

        case "CN":
            return ["Asia/Shanghai"]

        case "CZ":
            return ["Europe/Prague"]

        case "DE":
            return ["Europe/Berlin"]

        case "DK":
            return ["Europe/Copenhagen"]

        case "EG":
            return ["Africa/Cairo"]

        case "ES":
            return [
                "Europe/Madrid",
                "Atlantic/Canary"
            ]

        case "FI":
            return ["Europe/Helsinki"]

        case "FO":
            return ["Atlantic/Faroe"]

        case "FR":
            return ["Europe/Paris"]

        case "GB":
            return ["Europe/London"]

        case "GG":
            return ["Europe/Guernsey"]

        case "GI":
            return ["Europe/Gibraltar"]

        case "GL":
            return [
                "America/Nuuk",
                "America/Godthab",
                "America/Scoresbysund",
                "America/Thule"
            ]

        case "GR":
            return ["Europe/Athens"]

        case "HK":
            return ["Asia/Hong_Kong"]

        case "HT":
            return ["America/Port-au-Prince"]

        case "HU":
            return ["Europe/Budapest"]

        case "ID":
            return [
                "Asia/Jakarta",
                "Asia/Makassar",
                "Asia/Jayapura"
            ]

        case "IE":
            return ["Europe/Dublin"]

        case "IM":
            return ["Europe/Isle_of_Man"]

        case "IN":
            return ["Asia/Kolkata"]

        case "IS":
            return ["Atlantic/Reykjavik"]

        case "IT":
            return ["Europe/Rome"]

        case "JE":
            return ["Europe/Jersey"]

        case "JO":
            return ["Asia/Amman"]

        case "KE":
            return ["Africa/Nairobi"]

        case "KR":
            return ["Asia/Seoul"]

        case "KW":
            return ["Asia/Kuwait"]

        case "LI":
            return ["Europe/Vaduz"]

        case "LU":
            return ["Europe/Luxembourg"]

        case "MC":
            return ["Europe/Monaco"]

        case "MX":
            return [
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
            ]

        case "MT":
            return ["Europe/Malta"]

        case "MY":
            return ["Asia/Kuala_Lumpur"]

        case "NC":
            return ["Pacific/Noumea"]

        case "NG":
            return ["Africa/Lagos"]

        case "NL":
            return ["Europe/Amsterdam"]

        case "NO":
            return ["Europe/Oslo"]

        case "NR":
            return ["Pacific/Nauru"]

        case "NZ":
            return [
                "Pacific/Auckland",
                "Pacific/Chatham"
            ]

        case "OM":
            return ["Asia/Muscat"]

        case "PG":
            return [
                "Pacific/Port_Moresby",
                "Pacific/Bougainville"
            ]

        case "PL":
            return ["Europe/Warsaw"]

        case "PT":
            return [
                "Europe/Lisbon",
                "Atlantic/Madeira",
                "Atlantic/Azores"
            ]

        case "QA":
            return ["Asia/Qatar"]

        case "RU":
            return [
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
            ]

        case "SA":
            return ["Asia/Riyadh"]

        case "SB":
            return ["Pacific/Guadalcanal"]

        case "SE":
            return ["Europe/Stockholm"]

        case "SG":
            return ["Asia/Singapore"]

        case "SM":
            return ["Europe/San_Marino"]

        case "TR":
            return ["Europe/Istanbul"]

        case "UA":
            return ["Europe/Kyiv"]

        case "US":
            return [
                "America/New_York",
                "America/Chicago",
                "America/Denver",
                "America/Los_Angeles",
                "America/Anchorage",
                "Pacific/Honolulu"
            ]

        case "VA":
            return ["Europe/Vatican"]

        case "ZA":
            return ["Africa/Johannesburg"]

        case "JP":
            return ["Asia/Tokyo"]

        default:
            return []
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
        let secondsFromGMT = timeZone.secondsFromGMT(
            for: Date()
        )

        let sign = secondsFromGMT >= 0 ? "+" : "-"
        let absoluteSeconds = abs(secondsFromGMT)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60

        return "\(sign)\(String(format: "%02d:%02d", hours, minutes))"
    }

    private var locationName: (country: String, city: String)? {
        switch identifier {
        case "Asia/Tokyo", "Japan":
            return ("日本", "東京")

        case "Europe/London":
            return ("イギリス", "ロンドン")

        case "America/New_York":
            return ("アメリカ", "ニューヨーク")

        case "America/Chicago":
            return ("アメリカ", "シカゴ")

        case "America/Denver":
            return ("アメリカ", "デンバー")

        case "America/Los_Angeles":
            return ("アメリカ", "ロサンゼルス")

        case "America/Anchorage":
            return ("アメリカ", "アンカレッジ")

        case "Pacific/Honolulu":
            return ("アメリカ", "ホノルル")

        case "Europe/Paris":
            return ("フランス", "パリ")

        case "Europe/Berlin":
            return ("ドイツ", "ベルリン")

        case "Europe/Rome":
            return ("イタリア", "ローマ")

        case "Europe/Madrid":
            return ("スペイン", "マドリード")

        case "Asia/Seoul":
            return ("韓国", "ソウル")

        case "Asia/Shanghai", "Asia/Chongqing", "Asia/Harbin":
            return ("中国", "上海")

        case "Asia/Hong_Kong":
            return ("香港", "香港")

        case "Asia/Singapore":
            return ("シンガポール", "シンガポール")

        case "Australia/Sydney":
            return ("オーストラリア", "シドニー")

        case "Australia/Melbourne":
            return ("オーストラリア", "メルボルン")

        case "Australia/Brisbane":
            return ("オーストラリア", "ブリスベン")

        case "Australia/Adelaide":
            return ("オーストラリア", "アデレード")

        case "Australia/Perth":
            return ("オーストラリア", "パース")

        case "Australia/Darwin":
            return ("オーストラリア", "ダーウィン")

        case "Australia/Hobart":
            return ("オーストラリア", "ホバート")

        case "Pacific/Auckland":
            return ("ニュージーランド", "オークランド")

        case "Asia/Dubai":
            return ("アラブ首長国連邦", "ドバイ")

        case "Asia/Kolkata", "Asia/Calcutta":
            return ("インド", "コルカタ")

        case "America/Toronto":
            return ("カナダ", "トロント")

        case "America/Vancouver":
            return ("カナダ", "バンクーバー")

        case "America/Edmonton":
            return ("カナダ", "エドモントン")

        case "America/Winnipeg":
            return ("カナダ", "ウィニペグ")

        case "America/Halifax":
            return ("カナダ", "ハリファックス")

        case "America/St_Johns":
            return ("カナダ", "セントジョンズ")

        case "America/Sao_Paulo":
            return ("ブラジル", "サンパウロ")

        case "Asia/Amman":
            return ("ヨルダン", "アンマン")

        case "Europe/Vienna":
            return ("オーストリア", "ウィーン")

        case "Europe/Brussels":
            return ("ベルギー", "ブリュッセル")

        case "Asia/Bahrain":
            return ("バーレーン", "バーレーン")

        case "Africa/Cairo":
            return ("エジプト", "カイロ")

        case "Europe/Prague":
            return ("チェコ", "プラハ")

        case "Europe/Copenhagen":
            return ("デンマーク", "コペンハーゲン")

        case "Atlantic/Faroe":
            return ("フェロー諸島", "フェロー諸島")

        case "Europe/Guernsey":
            return ("ガーンジー", "ガーンジー")

        case "Europe/Gibraltar":
            return ("ジブラルタル", "ジブラルタル")

        case "America/Port-au-Prince":
            return ("ハイチ", "ポルトープランス")

        case "Europe/Budapest":
            return ("ハンガリー", "ブダペスト")

        case "Atlantic/Reykjavik":
            return ("アイスランド", "レイキャヴィーク")

        case "Europe/Jersey":
            return ("ジャージー", "ジャージー")

        case "Africa/Nairobi":
            return ("ケニア", "ナイロビ")

        case "Asia/Kuwait":
            return ("クウェート", "クウェート")

        case "Europe/Vaduz":
            return ("リヒテンシュタイン", "ファドゥーツ")

        case "Europe/Luxembourg":
            return ("ルクセンブルク", "ルクセンブルク")

        case "Europe/Monaco":
            return ("モナコ", "モナコ")

        case "Africa/Lagos":
            return ("ナイジェリア", "ラゴス")

        case "Europe/Oslo":
            return ("ノルウェー", "オスロ")

        case "Pacific/Nauru":
            return ("ナウル", "ナウル")

        case "Asia/Muscat":
            return ("オマーン", "マスカット")

        case "Pacific/Port_Moresby":
            return ("パプアニューギニア", "ポートモレスビー")

        case "Europe/Warsaw":
            return ("ポーランド", "ワルシャワ")

        case "Europe/Lisbon":
            return ("ポルトガル", "リスボン")

        case "Asia/Qatar":
            return ("カタール", "カタール")

        case "Europe/Moscow":
            return ("ロシア", "モスクワ")

        case "Asia/Riyadh":
            return ("サウジアラビア", "リヤド")

        case "Pacific/Guadalcanal":
            return ("ソロモン諸島", "ホニアラ")

        case "Europe/Stockholm":
            return ("スウェーデン", "ストックホルム")

        case "Europe/San_Marino":
            return ("サンマリノ", "サンマリノ")

        case "Europe/Istanbul":
            return ("トルコ", "イスタンブール")

        case "Europe/Kyiv":
            return ("ウクライナ", "キーウ")

        case "Europe/Vatican":
            return ("バチカン", "バチカン")

        case "Africa/Johannesburg":
            return ("南アフリカ", "ヨハネスブルグ")

        case "America/Mexico_City":
            return ("メキシコ", "メキシコシティ")

        case "America/Cancun":
            return ("メキシコ", "カンクン")

        case "America/Chihuahua":
            return ("メキシコ", "チワワ")

        case "America/Hermosillo":
            return ("メキシコ", "エルモシージョ")

        case "America/Mazatlan":
            return ("メキシコ", "マサトラン")

        case "America/Tijuana":
            return ("メキシコ", "ティファナ")

        default:
            return genericLocationName
        }
    }

    private var genericLocationName: (
        country: String,
        city: String
    )? {
        let components = identifier.split(separator: "/")

        guard components.count >= 2 else {
            return nil
        }

        let area = String(components[0])
        let cityIdentifier = components
            .dropFirst()
            .joined(separator: "/")

        return (
            countryName(for: area),
            cityName(for: cityIdentifier)
        )
    }

    private func countryName(for area: String) -> String {
        switch area {
        case "Africa":
            return "アフリカ"

        case "America":
            return "アメリカ"

        case "Antarctica":
            return "南極"

        case "Arctic":
            return "北極"

        case "Asia":
            return "アジア"

        case "Atlantic":
            return "大西洋"

        case "Australia":
            return "オーストラリア"

        case "Europe":
            return "ヨーロッパ"

        case "Indian":
            return "インド洋"

        case "Pacific":
            return "太平洋"

        default:
            return area
        }
    }

    private func cityName(for cityIdentifier: String) -> String {
        let city = cityIdentifier
            .split(separator: "/")
            .last
            .map(String.init) ?? cityIdentifier

        let japaneseCityNames: [String: String] = [
            "Tokyo": "東京",
            "London": "ロンドン",
            "New_York": "ニューヨーク",
            "Los_Angeles": "ロサンゼルス",
            "Chicago": "シカゴ",
            "Denver": "デンバー",
            "Anchorage": "アンカレッジ",
            "Honolulu": "ホノルル",
            "Paris": "パリ",
            "Berlin": "ベルリン",
            "Rome": "ローマ",
            "Madrid": "マドリード",
            "Seoul": "ソウル",
            "Shanghai": "上海",
            "Hong_Kong": "香港",
            "Singapore": "シンガポール",
            "Sydney": "シドニー",
            "Melbourne": "メルボルン",
            "Brisbane": "ブリスベン",
            "Adelaide": "アデレード",
            "Perth": "パース",
            "Darwin": "ダーウィン",
            "Hobart": "ホバート",
            "Auckland": "オークランド",
            "Dubai": "ドバイ",
            "Kolkata": "コルカタ",
            "Calcutta": "コルカタ",
            "Toronto": "トロント",
            "Vancouver": "バンクーバー",
            "Edmonton": "エドモントン",
            "Winnipeg": "ウィニペグ",
            "Halifax": "ハリファックス",
            "Sao_Paulo": "サンパウロ",
            "Amman": "アンマン",
            "Mexico_City": "メキシコシティ",
            "Moscow": "モスクワ",
            "Cairo": "カイロ",
            "Johannesburg": "ヨハネスブルグ"
        ]

        return japaneseCityNames[city]
            ?? city.replacingOccurrences(
                of: "_",
                with: " "
            )
    }

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
            gpsSyncEnabled: .constant(true)
        ) {}
    }
}

import SwiftUI
import Foundation

struct SettingsView: View {
    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Float
    @Binding var showOuterRing: Bool
    @Binding var timeZone: TimeZone
    var onOK: () -> Void

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
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("文字を常に上向きにする", isOn: $keepLabelsUpright)
                }

                Section(header: Text("秒針")) {
                    Toggle("スイープ秒針", isOn: $sweepSecondHand)
                }

                Section(header: Text("表示")) {
                    Toggle("文字盤の外側の丸枠を表示", isOn: $showOuterRing)
                }

                Section(header: Text("タイムゾーン")) {
                    Picker(
                        "タイムゾーン",
                        selection: Binding(
                            get: { timeZone.identifier },
                            set: { identifier in
                                if let selectedTimeZone = TimeZone(identifier: identifier) {
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
                }

                Section(
                    header: Text("音量"),
                    footer: Text("ステップ秒針のときに鳴る音の音量")
                ) {
                    HStack {
                        Image(systemName: "speaker.fill")

                        Slider(
                            value: Binding(
                                get: { Double(tickVolume) },
                                set: { tickVolume = Float($0) }
                            ),
                            in: 0...1
                        )

                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
                .disabled(sweepSecondHand)
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        onOK()
                    }
                }
            }
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
        if let location = locationName {
            return "\(location.country)／\(location.city)"
        }

        return timeZone.localizedName(
            for: .generic,
            locale: Locale(identifier: "ja_JP")
        ) ?? fallbackDisplayName
    }

    private var locationName: (country: String, city: String)? {
        switch identifier {
        case "Asia/Tokyo", "Japan":
            return ("日本", "東京")

        case "Europe/London":
            return ("イギリス", "ロンドン")

        case "America/New_York":
            return ("アメリカ", "ニューヨーク")

        case "America/Los_Angeles":
            return ("アメリカ", "ロサンゼルス")

        case "America/Chicago":
            return ("アメリカ", "シカゴ")

        case "America/Denver":
            return ("アメリカ", "デンバー")

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

        case "America/Sao_Paulo":
            return ("ブラジル", "サンパウロ")

        default:
            return genericLocationName
        }
    }

    private var genericLocationName: (country: String, city: String)? {
        let components = identifier.split(separator: "/")

        guard components.count >= 2 else {
            return nil
        }

        let area = String(components[0])
        let cityIdentifier = components.dropFirst().joined(separator: "/")

        guard !cityIdentifier.hasPrefix("Etc/") else {
            return nil
        }

        let country = countryName(for: area)
        let city = cityName(for: cityIdentifier)

        return (country, city)
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
            "Paris": "パリ",
            "Berlin": "ベルリン",
            "Rome": "ローマ",
            "Madrid": "マドリード",
            "Seoul": "ソウル",
            "Shanghai": "上海",
            "Hong_Kong": "香港",
            "Singapore": "シンガポール",
            "Sydney": "シドニー",
            "Auckland": "オークランド",
            "Dubai": "ドバイ",
            "Kolkata": "コルカタ",
            "Calcutta": "コルカタ",
            "Toronto": "トロント",
            "Vancouver": "バンクーバー",
            "Sao_Paulo": "サンパウロ",
            "Moscow": "モスクワ",
            "Cairo": "カイロ",
            "Johannesburg": "ヨハネスブルグ",
            "Mexico_City": "メキシコシティ",
            "Honolulu": "ホノルル",
            "Anchorage": "アンカレッジ"
        ]

        return japaneseCityNames[city]
            ?? city.replacingOccurrences(of: "_", with: " ")
    }

    private var fallbackDisplayName: String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: "／")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            keepLabelsUpright: .constant(true),
            sweepSecondHand: .constant(true),
            tickVolume: .constant(0.8),
            showOuterRing: .constant(true),
            timeZone: .constant(.current)
        ) {}
    }
}

import Foundation
import WidgetKit

enum SharedClockStorage {
    static let appGroupIdentifier =
        "group.com.example.DigitalAnalogClock2"

    static let savedClocksKey = "savedClocks"

    static let defaults: UserDefaults = {
        guard let defaults = UserDefaults(
            suiteName: appGroupIdentifier
        ) else {
            fatalError(
                "App Group UserDefaultsを作成できません: "
                    + appGroupIdentifier
            )
        }

        return defaults
    }()

    static func clockDesignPrefix(for id: UUID) -> String {
        "clockDesign.\(id)."
    }

    static func migrateLegacySettingsIfNeeded() {
        let legacyDefaults = UserDefaults.standard
        let sharedDefaults = defaults

        let migrationKey = "sharedSettingsMigrationCompleted"

        guard !sharedDefaults.bool(forKey: migrationKey) else {
            return
        }

        migrateSavedClocks(
            from: legacyDefaults,
            to: sharedDefaults
        )

        migrateGlobalSettings(
            from: legacyDefaults,
            to: sharedDefaults
        )

        if let savedClocksData = sharedDefaults.data(
            forKey: savedClocksKey
        ),
        let clockInfos = try? JSONDecoder().decode(
            [SharedClockInfo].self,
            from: savedClocksData
        ) {
            for clockInfo in clockInfos {
                migrateClockDesignSettings(
                    clockID: clockInfo.id,
                    from: legacyDefaults,
                    to: sharedDefaults
                )
            }
        }

        sharedDefaults.set(
            true,
            forKey: migrationKey
        )
    }

    static func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func migrateSavedClocks(
        from source: UserDefaults,
        to destination: UserDefaults
    ) {
        guard destination.data(forKey: savedClocksKey) == nil,
              let data = source.data(forKey: savedClocksKey)
        else {
            return
        }

        destination.set(data, forKey: savedClocksKey)
    }

    private static func migrateGlobalSettings(
        from source: UserDefaults,
        to destination: UserDefaults
    ) {
        let keys = [
            "keepLabelsUpright",
            "sweepSecondHand",
            "tickVolume",
            "hourlyChimeEnabled",
            "hourlyChimeVolume",
            "hourlyChimeIntervalMinutes"
        ]

        for key in keys {
            guard destination.object(forKey: key) == nil,
                  let value = source.object(forKey: key)
            else {
                continue
            }

            destination.set(value, forKey: key)
        }
    }

    private static func migrateClockDesignSettings(
        clockID: UUID,
        from source: UserDefaults,
        to destination: UserDefaults
    ) {
        let prefix = clockDesignPrefix(for: clockID)

        let keys = [
            "frameStyle",
            "frameColor",
            "hourHandColor",
            "minuteHandColor",
            "secondHandColor",
            "backgroundColor",
            "backgroundImage",
            "numeralStyle"
        ]

        for key in keys {
            let fullKey = prefix + key

            guard destination.object(forKey: fullKey) == nil,
                  let value = source.object(forKey: fullKey)
            else {
                continue
            }

            destination.set(value, forKey: fullKey)
        }
    }
}

private struct SharedClockInfo: Codable {
    let id: UUID
    let timeZoneIdentifier: String
    let showOuterRing: Bool
}

//
//  AlertModels.swift
//  SkyRadar
//
//  Модели открытых сводок: уровень угрозы, район, событие и пакет фида.
//

import Foundation
import SwiftUI

/// Разбирает и записывает даты ISO8601: с дробными секундами и без них.
nonisolated enum RadarDateCodec {
    static func date(from string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: string)
    }

    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Date {
        let raw = try container.decode(String.self, forKey: key)
        guard let date = date(from: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Ожидалась дата в формате ISO8601."
            )
        }
        return date
    }
}

/// Уровень угрозы по открытой сводке и его визуальные акценты Liquid Glass.
nonisolated enum ThreatLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case clear
    case attention
    case danger
    case allClear

    /// Полное русское название статуса.
    var title: String {
        switch self {
        case .clear:
            "Спокойно"
        case .attention:
            "Внимание"
        case .danger:
            "Опасность"
        case .allClear:
            "Отбой"
        }
    }

    /// Короткая подпись для бейджа и компактного HUD.
    var shortStatus: String {
        switch self {
        case .clear:
            "Чисто"
        case .attention:
            "Наблюдение"
        case .danger:
            "Угроза"
        case .allClear:
            "Отбой"
        }
    }

    /// Чем больше значение, тем выше событие в списке.
    var sortPriority: Int {
        switch self {
        case .danger:
            400
        case .attention:
            300
        case .allClear:
            200
        case .clear:
            100
        }
    }

    /// SF Symbol статуса.
    var symbolName: String {
        switch self {
        case .clear:
            "checkmark.shield.fill"
        case .attention:
            "exclamationmark.triangle.fill"
        case .danger:
            "exclamationmark.octagon.fill"
        case .allClear:
            "checkmark.seal.fill"
        }
    }

    /// Основной цветовой акцент свечения.
    var accent: Color {
        switch self {
        case .clear:
            Color(red: 0.16, green: 0.84, blue: 0.70)
        case .attention:
            Color(red: 1.00, green: 0.72, blue: 0.28)
        case .danger:
            Color(red: 0.96, green: 0.22, blue: 0.33)
        case .allClear:
            Color(red: 0.49, green: 0.95, blue: 0.86)
        }
    }

    /// Второй цвет перелива стекла.
    var glowAccent: Color {
        switch self {
        case .clear:
            Color(red: 0.05, green: 0.55, blue: 0.62)
        case .attention:
            Color(red: 0.92, green: 0.45, blue: 0.10)
        case .danger:
            Color(red: 0.62, green: 0.04, blue: 0.14)
        case .allClear:
            Color(red: 0.18, green: 0.66, blue: 0.74)
        }
    }

    /// Градиент подсветки: яркий блик сверху-слева к мягкому краю.
    var glassGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.95),
                glowAccent.opacity(0.55),
                accent.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Район, который пользователь может поставить на контроль.
nonisolated struct MonitoredRegion: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let keywords: [String]
    let latitude: Double
    let longitude: Double
    let radiusKm: Double

    /// Готовые регионы и города России для первого запуска.
    static let presets: [MonitoredRegion] = [
        MonitoredRegion(
            id: "moscow",
            name: "Москва",
            keywords: ["москва", "мск", "столица"],
            latitude: 55.7558,
            longitude: 37.6173,
            radiusKm: 30
        ),
        MonitoredRegion(
            id: "moscow-oblast",
            name: "Московская область",
            keywords: ["московская область", "подмосковье", "мособласть"],
            latitude: 55.5830,
            longitude: 37.6660,
            radiusKm: 80
        ),
        MonitoredRegion(
            id: "saint-petersburg",
            name: "Санкт-Петербург",
            keywords: ["санкт-петербург", "петербург", "спб", "питер"],
            latitude: 59.9343,
            longitude: 30.3351,
            radiusKm: 28
        ),
        MonitoredRegion(
            id: "leningrad-oblast",
            name: "Ленинградская область",
            keywords: ["ленинградская область", "ленобласть"],
            latitude: 59.5764,
            longitude: 30.1283,
            radiusKm: 90
        ),
        MonitoredRegion(
            id: "belgorod-oblast",
            name: "Белгородская область",
            keywords: ["белгород", "белгородская область"],
            latitude: 50.5951,
            longitude: 36.5873,
            radiusKm: 70
        ),
        MonitoredRegion(
            id: "kursk-oblast",
            name: "Курская область",
            keywords: ["курск", "курская область"],
            latitude: 51.7373,
            longitude: 36.1874,
            radiusKm: 65
        ),
        MonitoredRegion(
            id: "bryansk-oblast",
            name: "Брянская область",
            keywords: ["брянск", "брянская область"],
            latitude: 53.2521,
            longitude: 34.3717,
            radiusKm: 65
        ),
        MonitoredRegion(
            id: "voronezh-oblast",
            name: "Воронежская область",
            keywords: ["воронеж", "воронежская область"],
            latitude: 51.6608,
            longitude: 39.2003,
            radiusKm: 75
        ),
        MonitoredRegion(
            id: "rostov-oblast",
            name: "Ростовская область",
            keywords: ["ростов", "ростов-на-дону", "ростовская область"],
            latitude: 47.2357,
            longitude: 39.7015,
            radiusKm: 85
        ),
        MonitoredRegion(
            id: "krasnodar-krai",
            name: "Краснодарский край",
            keywords: ["краснодар", "краснодарский край", "кубань"],
            latitude: 45.0355,
            longitude: 38.9753,
            radiusKm: 100
        ),
        MonitoredRegion(
            id: "tatarstan",
            name: "Республика Татарстан",
            keywords: ["татарстан", "казань", "республика татарстан"],
            latitude: 55.7961,
            longitude: 49.1064,
            radiusKm: 90
        ),
        MonitoredRegion(
            id: "samara-oblast",
            name: "Самарская область",
            keywords: ["самара", "самарская область"],
            latitude: 53.1959,
            longitude: 50.1002,
            radiusKm: 75
        ),
        MonitoredRegion(
            id: "nizhny-novgorod-oblast",
            name: "Нижегородская область",
            keywords: ["нижний новгород", "нижегородская область", "нижний"],
            latitude: 56.2965,
            longitude: 43.9361,
            radiusKm: 80
        ),
        MonitoredRegion(
            id: "sverdlovsk-oblast",
            name: "Свердловская область",
            keywords: ["свердловская область", "екатеринбург"],
            latitude: 56.8389,
            longitude: 60.6057,
            radiusKm: 100
        )
    ]
}

/// Одна запись открытой сводки с сроком актуальности.
nonisolated struct RadarAlert: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let regionId: String
    let regionName: String
    let level: ThreatLevel
    let summary: String
    let sourceName: String
    let sourceURL: String?
    let timestamp: Date
    let expiresAt: Date

    init(
        id: String,
        regionId: String,
        regionName: String,
        level: ThreatLevel,
        summary: String,
        sourceName: String,
        sourceURL: String?,
        timestamp: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.regionId = regionId
        self.regionName = regionName
        self.level = level
        self.summary = summary
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.timestamp = timestamp
        self.expiresAt = expiresAt
    }

    /// Срок сводки уже вышел.
    var isExpired: Bool {
        expiresAt <= Date()
    }

    /// Сколько полных минут ещё действует сводка. Ноль, если срок вышел.
    var remainingMinutes: Int {
        let seconds = expiresAt.timeIntervalSinceNow
        guard seconds > 0 else { return 0 }
        return Int(ceil(seconds / 60))
    }

    /// Относительное время публикации на русском.
    var timeAgoText: String {
        let seconds = max(0, Int(Date().timeIntervalSince(timestamp)))
        if seconds < 45 {
            return "только что"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) \(RadarRussianPlural.form(minutes, one: "минуту", few: "минуты", many: "минут")) назад"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) \(RadarRussianPlural.form(hours, one: "час", few: "часа", many: "часов")) назад"
        }
        let days = hours / 24
        return "\(days) \(RadarRussianPlural.form(days, one: "день", few: "дня", many: "дней")) назад"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case regionId
        case regionName
        case level
        case summary
        case sourceName
        case sourceURL
        case timestamp
        case expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        regionId = try container.decode(String.self, forKey: .regionId)
        regionName = try container.decode(String.self, forKey: .regionName)
        level = try container.decode(ThreatLevel.self, forKey: .level)
        summary = try container.decode(String.self, forKey: .summary)
        sourceName = try container.decode(String.self, forKey: .sourceName)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        timestamp = try RadarDateCodec.decode(from: container, forKey: .timestamp)
        expiresAt = try RadarDateCodec.decode(from: container, forKey: .expiresAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(regionId, forKey: .regionId)
        try container.encode(regionName, forKey: .regionName)
        try container.encode(level, forKey: .level)
        try container.encode(summary, forKey: .summary)
        try container.encode(sourceName, forKey: .sourceName)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encode(RadarDateCodec.string(from: timestamp), forKey: .timestamp)
        try container.encode(RadarDateCodec.string(from: expiresAt), forKey: .expiresAt)
    }
}

/// Пакет внешнего JSON-фида открытых сводок.
nonisolated struct RadarFeedPayload: Codable, Hashable, Sendable {
    let updatedAt: Date
    let alerts: [RadarAlert]

    init(updatedAt: Date, alerts: [RadarAlert]) {
        self.updatedAt = updatedAt
        self.alerts = alerts
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case alerts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try RadarDateCodec.decode(from: container, forKey: .updatedAt)
        alerts = try container.decode([RadarAlert].self, forKey: .alerts)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(RadarDateCodec.string(from: updatedAt), forKey: .updatedAt)
        try container.encode(alerts, forKey: .alerts)
    }
}

/// Русские формы существительного: 1 минуту, 2 минуты, 5 минут.
nonisolated enum RadarRussianPlural {
    static func form(_ value: Int, one: String, few: String, many: String) -> String {
        let absolute = abs(value)
        let remainder10 = absolute % 10
        let remainder100 = absolute % 100
        if remainder10 == 1, remainder100 != 11 {
            return one
        }
        if (2...4).contains(remainder10), !(12...14).contains(remainder100) {
            return few
        }
        return many
    }
}

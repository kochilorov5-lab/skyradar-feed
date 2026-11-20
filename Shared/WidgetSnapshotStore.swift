//
//  WidgetSnapshotStore.swift
//  SkyRadar
//
//  Общий снимок фида и выбранных регионов для виджета. Если App Group не подписан, пишет в контейнер приложения.
//

import Foundation

/// Короткая сводка, которую виджет читает без моделей основного приложения.
nonisolated struct SharedWidgetAlert: Codable, Hashable, Sendable {
    var id: String
    var regionId: String
    var regionName: String
    var level: String
    var summary: String
    var timestamp: Date
    var expiresAt: Date
}

/// Последний пакет сводок и список регионов, выбранных пользователем.
nonisolated struct SharedWidgetSnapshot: Codable, Hashable, Sendable {
    var updatedAt: Date
    var subscribedRegionIds: [String]
    var alerts: [SharedWidgetAlert]
}

/// Читает и пишет снимок в App Group, а если группа недоступна — в локальный контейнер.
nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.ru.skyradar.shared"
    static let regionsKey = "SkyRadar.subscribedRegionIds"

    private static let folderName = "SkyRadarShared"
    private static let fileName = "widget-snapshot.json"

    /// Сохраняет снимок и дублирует идентификаторы регионов в общую UserDefaults-сюиту.
    static func save(_ snapshot: SharedWidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        let directory = containerURL()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(snapshot.subscribedRegionIds, forKey: regionsKey)
    }

    /// Возвращает последний снимок, если файл ещё читается.
    static func load() -> SharedWidgetSnapshot? {
        let url = containerURL().appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SharedWidgetSnapshot.self, from: data)
    }

    /// Каталог App Group либо Application Support, если профиль ещё не содержит группу.
    static func containerURL() -> URL {
        if let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return shared.appendingPathComponent(folderName, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(folderName, isDirectory: true)
    }
}

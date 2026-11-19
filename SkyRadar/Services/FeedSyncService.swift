//
//  FeedSyncService.swift
//  SkyRadar
//
//  Загрузка внешнего JSON-фида, демо-сводки, TTL, дедупликация и дисковый кэш.
//

import Foundation

/// Ошибки сети и разбора внешнего фида открытых сводок.
nonisolated enum FeedSyncError: LocalizedError {
    case insecureURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .insecureURL:
            "Фид принимается только по HTTPS."
        case .invalidResponse:
            "Сервер вернул нераспознанный ответ."
        case .httpStatus(let code):
            "Сервер фида ответил кодом \(code)."
        }
    }
}

/// Синхронизирует открытые сводки и держит последний успешный пакет в Caches.
struct FeedSyncService {
    static let shared = FeedSyncService()

    private static let cacheFolderName = "SkyRadar"
    private static let cacheFileName = "radar-feed.json"
    private static let lastUpdateKey = "SkyRadar.lastSuccessfulUpdate"

    private let session: URLSession
    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.session = session
        self.defaults = defaults
        self.fileManager = fileManager
    }

    /// Момент последней успешной загрузки фида на это устройство.
    var lastSuccessfulUpdate: Date? {
        let interval = defaults.double(forKey: Self.lastUpdateKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    /// Скачивает фид по HTTPS, убирает просроченное и дубли, затем пишет кэш.
    func sync(from url: URL) async throws -> RadarFeedPayload {
        guard url.scheme?.lowercased() == "https" else {
            throw FeedSyncError.insecureURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw FeedSyncError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw FeedSyncError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(RadarFeedPayload.self, from: data)
        let prepared = prepare(decoded, now: Date())
        storeLastSuccessfulUpdate(Date())
        try? writeCache(decoded)
        return prepared
    }

    /// Демо-фид с живыми метками времени. Просроченные и повторы уже сняты.
    func demoFeed(now: Date = Date()) -> RadarFeedPayload {
        prepare(Self.rawDemoPayload(now: now), now: now)
    }

    /// Читает последний успешный фид с диска и заново применяет TTL.
    func cachedFeed(now: Date = Date()) -> RadarFeedPayload? {
        guard let data = try? Data(contentsOf: cacheFileURL()) else { return nil }
        guard let payload = try? JSONDecoder().decode(RadarFeedPayload.self, from: data) else { return nil }
        return prepare(payload, now: now)
    }

    /// Оставляет живые события, схлопывает одинаковые id и сортирует по угрозе и свежести.
    func prepare(_ payload: RadarFeedPayload, now: Date = Date()) -> RadarFeedPayload {
        RadarFeedPayload(
            updatedAt: payload.updatedAt,
            alerts: prepareAlerts(payload.alerts, now: now)
        )
    }

    private func prepareAlerts(_ alerts: [RadarAlert], now: Date) -> [RadarAlert] {
        var selected: [String: RadarAlert] = [:]
        for alert in alerts where alert.expiresAt > now {
            if let current = selected[alert.id] {
                if Self.isPreferred(alert, over: current) {
                    selected[alert.id] = alert
                }
            } else {
                selected[alert.id] = alert
            }
        }
        return selected.values.sorted(by: Self.isPreferred)
    }

    /// Сначала более опасный статус, затем более свежая публикация.
    private nonisolated static func isPreferred(_ lhs: RadarAlert, over rhs: RadarAlert) -> Bool {
        if lhs.level.sortPriority != rhs.level.sortPriority {
            return lhs.level.sortPriority > rhs.level.sortPriority
        }
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp > rhs.timestamp
        }
        return lhs.id < rhs.id
    }

    private func storeLastSuccessfulUpdate(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: Self.lastUpdateKey)
    }

    private func cacheDirectoryURL() throws -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent(Self.cacheFolderName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func cacheFileURL() -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent(Self.cacheFolderName, isDirectory: true)
            .appendingPathComponent(Self.cacheFileName)
    }

    private func writeCache(_ payload: RadarFeedPayload) throws {
        let directory = try cacheDirectoryURL()
        let data = try JSONEncoder().encode(payload)
        let url = directory.appendingPathComponent(Self.cacheFileName)
        try data.write(to: url, options: .atomic)
    }

    /// Сырой демо-пакет: есть и просроченная запись, и повтор id — их снимет `prepare`.
    private static func rawDemoPayload(now: Date) -> RadarFeedPayload {
        let alerts = [
            RadarAlert(
                id: "demo-moscow-danger",
                regionId: "moscow",
                regionName: "Москва",
                level: .danger,
                summary: "По открытым сводкам над Москвой сообщают о пролёте БПЛА. Это пересказ публичных сообщений, не данные датчиков телефона.",
                sourceName: "Открытый канал сводок",
                sourceURL: "https://example.com/feeds/moscow",
                timestamp: now.addingTimeInterval(-4 * 60),
                expiresAt: now.addingTimeInterval(26 * 60)
            ),
            RadarAlert(
                id: "demo-moscow-danger",
                regionId: "moscow",
                regionName: "Москва",
                level: .attention,
                summary: "Более ранняя дублирующая сводка по Москве. После дедупликации останется свежая запись.",
                sourceName: "Архив открытых сводок",
                sourceURL: nil,
                timestamp: now.addingTimeInterval(-40 * 60),
                expiresAt: now.addingTimeInterval(10 * 60)
            ),
            RadarAlert(
                id: "demo-rostov-attention",
                regionId: "rostov-oblast",
                regionName: "Ростовская область",
                level: .attention,
                summary: "Открытые источники просят повышенное внимание в Ростовской области: сообщения о возможной активности БПЛА расходятся.",
                sourceName: "Публичный мониторинг",
                sourceURL: "https://example.com/feeds/rostov",
                timestamp: now.addingTimeInterval(-18 * 60),
                expiresAt: now.addingTimeInterval(42 * 60)
            ),
            RadarAlert(
                id: "demo-belgorod-all-clear",
                regionId: "belgorod-oblast",
                regionName: "Белгородская область",
                level: .allClear,
                summary: "По открытым сводкам угроза по Белгородской области снята. Следите за следующей отметкой обновления.",
                sourceName: "Открытый канал сводок",
                sourceURL: "https://example.com/feeds/belgorod",
                timestamp: now.addingTimeInterval(-7 * 60),
                expiresAt: now.addingTimeInterval(35 * 60)
            ),
            RadarAlert(
                id: "demo-kursk-danger",
                regionId: "kursk-oblast",
                regionName: "Курская область",
                level: .danger,
                summary: "Свежая открытая сводка: в Курской области сообщают о БПЛА. Держитесь укрытий, пока сводка не обновится.",
                sourceName: "Сводка открытых каналов",
                sourceURL: nil,
                timestamp: now.addingTimeInterval(-2 * 60),
                expiresAt: now.addingTimeInterval(18 * 60)
            ),
            RadarAlert(
                id: "demo-tatarstan-clear",
                regionId: "tatarstan",
                regionName: "Республика Татарстан",
                level: .clear,
                summary: "По открытым источникам в Республике Татарстан спокойно. Новых сообщений об угрозе нет.",
                sourceName: "Публичный мониторинг",
                sourceURL: "https://example.com/feeds/tatarstan",
                timestamp: now.addingTimeInterval(-52 * 60),
                expiresAt: now.addingTimeInterval(70 * 60)
            ),
            RadarAlert(
                id: "demo-krasnodar-attention",
                regionId: "krasnodar-krai",
                regionName: "Краснодарский край",
                level: .attention,
                summary: "Открытые сводки фиксируют противоречивые сообщения по Краснодарскому краю. Статус — внимание, не подтверждённая угроза.",
                sourceName: "Сводка открытых каналов",
                sourceURL: nil,
                timestamp: now.addingTimeInterval(-27 * 60),
                expiresAt: now.addingTimeInterval(30 * 60)
            ),
            RadarAlert(
                id: "demo-samara-expired",
                regionId: "samara-oblast",
                regionName: "Самарская область",
                level: .attention,
                summary: "Эта сводка по Самарской области уже истекла и не должна попасть на экран после фильтрации срока актуальности.",
                sourceName: "Архив открытых сводок",
                sourceURL: nil,
                timestamp: now.addingTimeInterval(-100 * 60),
                expiresAt: now.addingTimeInterval(-12 * 60)
            )
        ]
        return RadarFeedPayload(updatedAt: now, alerts: alerts)
    }
}

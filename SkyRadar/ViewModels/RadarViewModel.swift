//
//  RadarViewModel.swift
//  SkyRadar
//
//  Состояние радара: регионы РФ, фильтр сводок, таймер, обновление и демо-тревога.
//

import Foundation
import Observation
import UserNotifications

/// Какие сводки показывать в ленте.
enum RadarFeedScope: String, CaseIterable, Identifiable {
    case mine
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mine:
            "Мои регионы"
        case .all:
            "Все по РФ"
        }
    }
}

/// Откуда взяты сводки на экране.
enum FeedOrigin: Equatable {
    case remote
    case cache
    case demo
    case empty

    var title: String {
        switch self {
        case .remote:
            "Удалённый фид"
        case .cache:
            "Кэш"
        case .demo:
            "Демо-данные"
        case .empty:
            "Нет данных"
        }
    }
}

/// Насколько свежа последняя успешная загрузка.
enum DataFreshness: Equatable {
    case fresh
    case aging
    case stale
    case unknown

    var title: String {
        switch self {
        case .fresh:
            "свежие"
        case .aging:
            "стареют"
        case .stale:
            "устарели"
        case .unknown:
            "нет отметки"
        }
    }
}

/// Показывает баннер локального уведомления, пока экран радара открыт.
final class RadarNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RadarNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// Экранное состояние SkyRadar.
@Observable
final class RadarViewModel {
    private static let subscribedKey = "SkyRadar.subscribedRegionIds"
    private static let customRegionsKey = "SkyRadar.customRegions"
    private static let feedURLKey = "SkyRadar.feedURL"
    private static let defaultRegionIDs = ["moscow", "belgorod-oblast", "rostov-oblast"]

    var subscribedRegionIds: Set<String> = []
    var customRegions: [MonitoredRegion] = []
    var scope: RadarFeedScope = .mine
    var payload: RadarFeedPayload?
    var lastUpdated: Date?
    var now: Date = Date()
    var isRefreshing = false
    var isDemoAlarmOn = false
    var feedOrigin: FeedOrigin = .empty
    var loadError: String?
    var notice: String?

    private var demoAlert: RadarAlert?
    private let feed: FeedSyncService
    private let notifications: NotificationManager
    private let defaults: UserDefaults
    private var didStart = false
    private var refreshTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?

    init(
        feed: FeedSyncService = .shared,
        notifications: NotificationManager = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.feed = feed
        self.notifications = notifications
        self.defaults = defaults
    }

    deinit {
        refreshTask?.cancel()
        clockTask?.cancel()
    }

    /// Пресеты регионов РФ и места, добавленные пользователем.
    var regions: [MonitoredRegion] {
        MonitoredRegion.presets + customRegions
    }

    var subscribedRegions: [MonitoredRegion] {
        regions.filter { subscribedRegionIds.contains($0.id) }
    }

    /// Сводки с учётом фильтра и включённой демо-тревоги.
    var visibleAlerts: [RadarAlert] {
        let merged = mergedAlerts
        switch scope {
        case .all:
            return merged
        case .mine:
            return merged.filter { subscribedRegionIds.contains($0.regionId) }
        }
    }

    /// Статус шапки по выбранным регионам РФ. Демо-тревога сразу поднимает его до опасности.
    var headlineLevel: ThreatLevel {
        if isDemoAlarmOn {
            return .danger
        }
        let relevant = (payload?.alerts ?? []).filter { subscribedRegionIds.contains($0.regionId) }
        return relevant.max { $0.level.sortPriority < $1.level.sortPriority }?.level ?? .clear
    }

    var freshness: DataFreshness {
        guard let lastUpdated else { return .unknown }
        let age = now.timeIntervalSince(lastUpdated)
        if age < 90 {
            return .fresh
        }
        if age < 10 * 60 {
            return .aging
        }
        return .stale
    }

    var lastUpdateText: String {
        guard let lastUpdated else { return "ещё не обновлялось" }
        return "обновлено в \(Self.clockFormatter.string(from: lastUpdated))"
    }

    var subscribedSummary: String {
        if feedOrigin == .empty, !isDemoAlarmOn {
            return "Нет данных"
        }
        let names = subscribedRegions.map(\.name)
        if names.isEmpty {
            return "Регионы не выбраны"
        }
        if names.count <= 3 {
            return names.joined(separator: " · ")
        }
        return "\(names.prefix(3).joined(separator: " · ")) · ещё \(names.count - 3)"
    }

    /// Пометка источника для карточки: мок, кэш или локальная демо-тревога.
    func sourceMark(for alert: RadarAlert) -> String? {
        if alert.id.hasPrefix("demo-") || isDemoAlarmOn && alert.sourceName == "Демо SkyRadar" {
            return "Демо-данные"
        }
        switch feedOrigin {
        case .cache:
            return "Кэш"
        case .demo:
            return "Демо-данные"
        case .remote, .empty:
            return nil
        }
    }

    /// Поднимает кэш или демо-фид и запускает периодическое обновление.
    func start() async {
        guard !didStart else { return }
        didStart = true
        restore()
        UNUserNotificationCenter.current().delegate = RadarNotificationDelegate.shared
        await refresh(manual: false)
        monitor()
    }

    /// Ручное или плановое обновление фида.
    func refresh(manual: Bool) async {
        if isRefreshing { return }
        isRefreshing = true
        defer { isRefreshing = false }

        now = Date()
        if isDemoAlarmOn {
            payload = feed.demoFeed(now: now)
            feedOrigin = .demo
            loadError = nil
        } else if let url = storedFeedURL() {
            do {
                payload = try await feed.sync(from: url)
                feedOrigin = .remote
                loadError = nil
            } catch {
                loadError = error.localizedDescription
                applyCachedOrEmpty(now: now)
            }
        } else if manual || payload == nil {
            loadError = nil
            applyCachedOrEmpty(now: now)
        } else if let payload {
            self.payload = feed.prepare(payload, now: now)
        }

        lastUpdated = now
        guard feedOrigin != .demo else { return }
        let alerts = payload?.alerts ?? []
        await notifications.evaluateAndNotify(alerts: alerts, subscribedRegionIds: subscribedRegionIds)
    }

    /// Включает или снимает мгновенную демо-тревогу и, если можно, шлёт локальный пуш.
    func setDemoAlarm(_ enabled: Bool) async {
        isDemoAlarmOn = enabled
        notice = nil
        guard enabled else {
            demoAlert = nil
            await refresh(manual: true)
            return
        }

        if subscribedRegionIds.isEmpty, let region = regions.first {
            subscribedRegionIds.insert(region.id)
            persistSubscriptions()
        }

        let region = subscribedRegions.first ?? MonitoredRegion.presets[0]
        payload = feed.demoFeed(now: Date())
        feedOrigin = .demo
        let alert = Self.makeDemoAlarm(for: region, now: Date())
        demoAlert = alert

        do {
            let allowed = try await notifications.requestAuthorization()
            if allowed {
                await notifications.evaluateAndNotify(
                    alerts: [alert],
                    subscribedRegionIds: subscribedRegionIds
                )
                notice = "Проверочное уведомление отправлено."
            } else {
                notice = "Уведомления выключены. Статус на экране уже обновлён."
            }
        } catch {
            notice = "Не удалось запросить уведомления. Статус на экране уже обновлён."
        }
    }

    func toggleSubscription(_ regionID: String) {
        if subscribedRegionIds.contains(regionID) {
            subscribedRegionIds.remove(regionID)
        } else {
            subscribedRegionIds.insert(regionID)
        }
        persistSubscriptions()
    }

    func addCustomRegion(name: String, keywords: [String], latitude: Double, longitude: Double, radiusKm: Double) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, latitude >= -90, latitude <= 90, longitude >= -180, longitude <= 180 else { return }
        let cleanedKeywords = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var storedKeywords = cleanedKeywords
        if storedKeywords.isEmpty {
            storedKeywords = [trimmedName]
        }
        let region = MonitoredRegion(
            id: "custom-\(UUID().uuidString.lowercased())",
            name: trimmedName,
            keywords: storedKeywords,
            latitude: latitude,
            longitude: longitude,
            radiusKm: min(max(radiusKm, 1), 80)
        )
        customRegions.append(region)
        subscribedRegionIds.insert(region.id)
        persistCustomRegions()
        persistSubscriptions()
    }

    func removeCustomRegion(_ regionID: String) {
        customRegions.removeAll { $0.id == regionID }
        subscribedRegionIds.remove(regionID)
        persistCustomRegions()
        persistSubscriptions()
    }

    private var mergedAlerts: [RadarAlert] {
        var alerts = payload?.alerts ?? []
        if let demoAlert, !demoAlert.isExpired, !alerts.contains(where: { $0.id == demoAlert.id }) {
            alerts.insert(demoAlert, at: 0)
        }
        return alerts
    }

    private func monitor() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                await self?.refresh(manual: false)
            }
        }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self else { return }
                now = Date()
                if let payload {
                    self.payload = feed.prepare(payload, now: now)
                }
            }
        }
    }

    private func restore() {
        if let data = defaults.data(forKey: Self.customRegionsKey),
           let decoded = try? JSONDecoder().decode([MonitoredRegion].self, from: data) {
            customRegions = decoded
        }
        let stored = Set(defaults.stringArray(forKey: Self.subscribedKey) ?? [])
        let known = Set(regions.map(\.id))
        let valid = stored.intersection(known)
        if defaults.object(forKey: Self.subscribedKey) == nil || valid.isEmpty {
            subscribedRegionIds = Set(Self.defaultRegionIDs)
            persistSubscriptions()
        } else {
            subscribedRegionIds = valid
        }
    }

    private func persistSubscriptions() {
        defaults.set(Array(subscribedRegionIds), forKey: Self.subscribedKey)
    }

    private func persistCustomRegions() {
        guard let data = try? JSONEncoder().encode(customRegions) else { return }
        defaults.set(data, forKey: Self.customRegionsKey)
    }

    /// Кэш, если он есть. Иначе пустой фид без мок-тревог.
    private func applyCachedOrEmpty(now: Date) {
        if let cached = feed.cachedFeed(now: now) {
            payload = cached
            feedOrigin = .cache
        } else {
            payload = RadarFeedPayload(updatedAt: now, alerts: [])
            feedOrigin = .empty
        }
    }

    private func storedFeedURL() -> URL? {
        guard let raw = defaults.string(forKey: Self.feedURLKey),
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    private static func makeDemoAlarm(for region: MonitoredRegion, now: Date) -> RadarAlert {
        RadarAlert(
            id: "demo-alarm-\(UUID().uuidString.lowercased())",
            regionId: region.id,
            regionName: region.name,
            level: .danger,
            summary: "Демо-тревога: проверка статуса, анимации и локального уведомления. Это не сводка из эфира.",
            sourceName: "Демо SkyRadar",
            sourceURL: nil,
            timestamp: now,
            expiresAt: now.addingTimeInterval(20 * 60)
        )
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

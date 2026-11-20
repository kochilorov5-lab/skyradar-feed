//
//  NotificationManager.swift
//  SkyRadar
//
//  Локальные уведомления по выбранным районам: danger, attention и переход в allClear.
//

import Foundation
import UserNotifications

/// Состояние системного разрешения на локальные уведомления.
enum NotificationAccess: Equatable {
    case notDetermined
    case allowed
    case provisional
    case denied

    var title: String {
        switch self {
        case .notDetermined:
            "Разрешение не запрошено"
        case .allowed:
            "Уведомления разрешены"
        case .provisional:
            "Уведомления тихие"
        case .denied:
            "Уведомления выключены"
        }
    }
}

/// Запрашивает разрешение и шлёт локальные пуши без повторов по паре id и уровня.
struct NotificationManager {
    static let shared = NotificationManager()

    private static let processedIDsKey = "SkyRadar.processedAlertIDs"
    private static let processedIDLimit = 400

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    /// Спрашивает показ уведомлений. Отказ пользователя возвращает `false`, не ошибку.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Текущее разрешение без запроса диалога.
    func authorizationState() async -> NotificationAccess {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral:
            return .allowed
        case .provisional:
            return .provisional
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    /// Пуш для новой сводки `danger` или `attention` и для перехода в `allClear`. Повтор той же пары id и уровня пропускается.
    func evaluateAndNotify(alerts: [RadarAlert], subscribedRegionIds: Set<String>) async {
        guard !subscribedRegionIds.isEmpty else { return }

        let settings = await center.notificationSettings()
        guard Self.isAuthorized(settings.authorizationStatus) else { return }

        let alreadyProcessed = processedFingerprints()
        let candidates = alerts.filter { alert in
            !alert.isExpired
                && subscribedRegionIds.contains(alert.regionId)
                && Self.isNotifiable(alert.level)
                && !alreadyProcessed.contains(Self.fingerprint(for: alert))
        }

        var delivered: [String] = []
        for alert in candidates {
            let fingerprint = Self.fingerprint(for: alert)
            let request = UNNotificationRequest(
                identifier: fingerprint,
                content: Self.content(for: alert),
                trigger: nil
            )
            do {
                try await center.add(request)
                delivered.append(fingerprint)
            } catch {
                continue
            }
        }

        if !delivered.isEmpty {
            rememberProcessed(delivered)
        }
    }

    private static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }

    /// Новая активная сводка или отбой. Спокойный статус `clear` сам по себе не пушится.
    private static func isNotifiable(_ level: ThreatLevel) -> Bool {
        switch level {
        case .danger, .attention, .allClear:
            true
        case .clear:
            false
        }
    }

    /// Ключ дедупликации: то же событие с тем же уровнем не отправляется повторно, смена уровня — отправляется.
    private static func fingerprint(for alert: RadarAlert) -> String {
        "\(alert.id)|\(alert.level.rawValue)"
    }

    private static func content(for alert: RadarAlert) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(alert.level.title) · \(alert.regionName)"
        content.subtitle = alert.sourceName
        content.body = alert.summary
        content.sound = .default
        content.threadIdentifier = alert.regionId
        content.userInfo = [
            "alertID": alert.id,
            "regionID": alert.regionId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = alert.level == .danger ? .timeSensitive : .active
            content.relevanceScore = alert.level == .danger ? 1 : 0.65
        }
        return content
    }

    private func processedFingerprints() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.processedIDsKey) ?? [])
    }

    private func rememberProcessed(_ ids: [String]) {
        var stored = defaults.stringArray(forKey: Self.processedIDsKey) ?? []
        stored.append(contentsOf: ids)
        if stored.count > Self.processedIDLimit {
            stored.removeFirst(stored.count - Self.processedIDLimit)
        }
        defaults.set(stored, forKey: Self.processedIDsKey)
    }
}

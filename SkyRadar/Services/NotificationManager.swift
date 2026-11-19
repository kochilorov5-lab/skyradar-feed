//
//  NotificationManager.swift
//  SkyRadar
//
//  Локальные уведомления только по выбранным районам и статусам danger / allClear.
//

import Foundation
import UserNotifications

/// Запрашивает разрешение и шлёт локальные пуши без повторов по id сводки.
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

    /// Спрашивает показ уведомлений и добавляет `.timeSensitive`, пока флаг есть в SDK.
    @discardableResult
    func requestAuthorization() async throws -> Bool {
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        if #available(iOS 15.0, *) {
            options.insert(.timeSensitive)
        }
        return try await center.requestAuthorization(options: options)
    }

    /// Отправляет пуш только для новых живых событий `danger` и `allClear` в подписанных районах.
    func evaluateAndNotify(alerts: [RadarAlert], subscribedRegionIds: Set<String>) async {
        guard !subscribedRegionIds.isEmpty else { return }

        let settings = await center.notificationSettings()
        guard Self.isAuthorized(settings.authorizationStatus) else { return }

        let alreadyProcessed = processedIDs()
        let candidates = alerts.filter { alert in
            !alert.isExpired
                && subscribedRegionIds.contains(alert.regionId)
                && Self.isNotifiable(alert.level)
                && !alreadyProcessed.contains(alert.id)
        }

        var delivered: [String] = []
        for alert in candidates {
            let request = UNNotificationRequest(
                identifier: alert.id,
                content: Self.content(for: alert),
                trigger: nil
            )
            do {
                try await center.add(request)
                delivered.append(alert.id)
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

    private static func isNotifiable(_ level: ThreatLevel) -> Bool {
        level == .danger || level == .allClear
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

    private func processedIDs() -> Set<String> {
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

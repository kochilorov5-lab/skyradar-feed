//
//  BackgroundRefreshManager.swift
//  SkyRadar
//
//  Фоновое обновление открытого фида через BGAppRefreshTask.
//

import BackgroundTasks
import Foundation

/// Планирует `BGAppRefreshTask` и в фоне обновляет кэш фида и локальные уведомления.
@MainActor
final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()

    /// Идентификатор из `BGTaskSchedulerPermittedIdentifiers` в Info.plist.
    static let taskIdentifier = "ru.skyradar.feed.refresh"

    private(set) var statusNote: String?
    private weak var model: RadarViewModel?
    private var didAttemptRegister = false
    private var isRegistered = false

    private init() {}

    /// Привязывает живой экран, чтобы фон обновил и интерфейс, если он ещё в памяти.
    func attach(_ model: RadarViewModel) {
        self.model = model
    }

    /// Регистрирует обработчик до завершения запуска. Повторный вызов ничего не делает.
    func register() {
        guard !didAttemptRegister else { return }
        didAttemptRegister = true
        isRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil,
            launchHandler: Self.handleLaunch
        )
        if !isRegistered {
            statusNote = "Фоновое обновление не зарегистрировано. Проверьте идентификатор в Info.plist."
        }
    }

    /// Ставит следующее обновление не раньше чем через 15 минут. Ошибки системы не роняют приложение.
    func schedule() async {
        guard isRegistered else {
            if statusNote == nil {
                statusNote = "Фоновое обновление не зарегистрировано."
            }
            return
        }

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try await BGTaskScheduler.shared.submitTaskRequest(request)
            statusNote = nil
        } catch {
            statusNote = Self.describe(error)
        }
    }

    /// Скачивает фид, пишет кэш и сверяет сводки с подписанными регионами.
    func handle(_ task: BGAppRefreshTask) async {
        await schedule()
        let success = await runRefresh()
        task.setTaskCompleted(success: success && !Task.isCancelled)
    }

    private func runRefresh() async -> Bool {
        if Task.isCancelled { return false }
        if let model {
            return await model.performBackgroundRefresh()
        }
        return await RadarViewModel.syncFeedForBackground()
    }

    nonisolated private static func handleLaunch(_ task: BGTask) {
        guard let refresh = task as? BGAppRefreshTask else {
            task.setTaskCompleted(success: false)
            return
        }
        let work = Task { @MainActor in
            await BackgroundRefreshManager.shared.handle(refresh)
        }
        refresh.expirationHandler = {
            work.cancel()
        }
    }

    private static func describe(_ error: Error) -> String {
        if let schedulerError = error as? BGTaskScheduler.Error {
            switch schedulerError.code {
            case .unavailable:
                return "Фоновые обновления сейчас недоступны на этом устройстве."
            case .notPermitted:
                return "Фоновое обновление не разрешено. Проверьте Info.plist и режим fetch."
            case .tooManyPendingTaskRequests:
                return "Слишком много запланированных фоновых задач."
            case .immediateRunIneligible:
                return "Фоновую задачу нельзя запустить прямо сейчас."
            @unknown default:
                return "Не удалось запланировать фоновое обновление."
            }
        }
        return "Не удалось запланировать фоновое обновление."
    }
}

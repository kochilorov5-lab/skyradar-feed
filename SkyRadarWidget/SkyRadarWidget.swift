//
//  SkyRadarWidget.swift
//  SkyRadarWidget
//
//  Виджет домашнего экрана и экрана блокировки: статус выбранных регионов РФ.
//

import SwiftUI
import WidgetKit

@main
struct SkyRadarWidgetBundle: WidgetBundle {
    var body: some Widget {
        SkyRadarStatusWidget()
    }
}

/// Домашний экран и Lock Screen: уровень угрозы, регион, сводка и время обновления.
struct SkyRadarStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ru.skyradar.status", provider: SkyRadarTimelineProvider()) { entry in
            SkyRadarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Сводки SkyRadar")
        .description("Статус выбранных регионов РФ по открытым сводкам.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct SkyRadarWidgetEntry: TimelineEntry {
    var date: Date
    var level: WidgetThreat
    var headline: String
    var regionLine: String
    var summary: String
    var updatedText: String
    var alertCount: Int

    static let placeholder = SkyRadarWidgetEntry(
        date: Date(),
        level: .clear,
        headline: "Спокойно",
        regionLine: "Мои регионы",
        summary: "Открытые сводки по выбранным регионам РФ.",
        updatedText: "обновление",
        alertCount: 0
    )

    /// Собирает экран из общего снимка. Просроченные сводки не учитывает.
    static func current(now: Date = Date()) -> SkyRadarWidgetEntry {
        guard let snapshot = WidgetSnapshotStore.load() else {
            return SkyRadarWidgetEntry(
                date: now,
                level: .clear,
                headline: "Нет данных",
                regionLine: "Откройте SkyRadar",
                summary: "Снимок сводок ещё не сохранён.",
                updatedText: "нет отметки",
                alertCount: 0
            )
        }

        let subscribed = Set(snapshot.subscribedRegionIds)
        let live = snapshot.alerts.filter { alert in
            alert.expiresAt > now && subscribed.contains(alert.regionId)
        }
        let ranked = live.sorted { lhs, rhs in
            let left = WidgetThreat(rawValue: lhs.level) ?? .clear
            let right = WidgetThreat(rawValue: rhs.level) ?? .clear
            if left.rank != right.rank { return left.rank > right.rank }
            return lhs.timestamp > rhs.timestamp
        }
        let level = ranked.first.flatMap { WidgetThreat(rawValue: $0.level) } ?? .clear
        let names = Array(Set(ranked.map(\.regionName))).sorted()
        let regionLine: String
        if subscribed.isEmpty && ranked.isEmpty {
            regionLine = "Регионы не выбраны"
        } else if names.isEmpty {
            regionLine = subscribed.isEmpty ? "Нет актуальных сводок" : "На контроле \(subscribed.count)"
        } else if names.count == 1 {
            regionLine = names[0]
        } else {
            regionLine = "\(names[0]) · ещё \(names.count - 1)"
        }
        let summary = ranked.first?.summary ?? "Актуальных сводок по выбранным регионам нет."
        return SkyRadarWidgetEntry(
            date: now,
            level: ranked.isEmpty ? .clear : level,
            headline: ranked.isEmpty ? "Спокойно" : level.title,
            regionLine: regionLine,
            summary: summary,
            updatedText: "обновлено в \(Self.clock.string(from: snapshot.updatedAt))",
            alertCount: ranked.count
        )
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

enum WidgetThreat: String {
    case clear
    case attention
    case danger
    case allClear

    var title: String {
        switch self {
        case .clear: "Спокойно"
        case .attention: "Внимание"
        case .danger: "Опасность"
        case .allClear: "Отбой"
        }
    }

    var symbolName: String {
        switch self {
        case .clear: "checkmark.shield.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .danger: "exclamationmark.octagon.fill"
        case .allClear: "checkmark.seal.fill"
        }
    }

    var rank: Int {
        switch self {
        case .danger: 4
        case .attention: 3
        case .allClear: 2
        case .clear: 1
        }
    }

    var tint: Color {
        switch self {
        case .clear: Color(red: 0.16, green: 0.84, blue: 0.70)
        case .attention: Color(red: 1.00, green: 0.72, blue: 0.28)
        case .danger: Color(red: 0.96, green: 0.22, blue: 0.33)
        case .allClear: Color(red: 0.49, green: 0.95, blue: 0.86)
        }
    }
}

/// Поставляет одну запись и просит систему обновить её через 15 минут.
struct SkyRadarTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SkyRadarWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SkyRadarWidgetEntry) -> Void) {
        completion(.current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SkyRadarWidgetEntry>) -> Void) {
        let entry = SkyRadarWidgetEntry.current()
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// Стеклянный виджет: домашний экран и компактные семейства экрана блокировки.
struct SkyRadarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SkyRadarWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(entry.regionLine)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(entry.updatedText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(2)
        .widgetGlass(entry.level.tint)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(entry.regionLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                Text(countLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.level.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(4)
                Spacer(minLength: 0)
                Text(entry.updatedText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(2)
        .widgetGlass(entry.level.tint)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.level.symbolName)
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.headline)
                    .font(.headline)
                    .widgetAccentable()
                Text("\(entry.regionLine) · \(entry.updatedText)")
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    private var circular: some View {
        VStack(spacing: 2) {
            Image(systemName: entry.level.symbolName)
                .font(.title3)
            Text(entry.alertCount > 0 ? "\(entry.alertCount)" : "0")
                .font(.caption.weight(.bold))
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.level.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(entry.level.tint)
            Text(entry.headline)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var countLine: String {
        let count = entry.alertCount
        let noun = Self.plural(count, one: "тревога", few: "тревоги", many: "тревог")
        return "\(count) \(noun)"
    }

    private static func plural(_ value: Int, one: String, few: String, many: String) -> String {
        let absolute = abs(value)
        let remainder10 = absolute % 10
        let remainder100 = absolute % 100
        if remainder10 == 1, remainder100 != 11 { return one }
        if (2...4).contains(remainder10), !(12...14).contains(remainder100) { return few }
        return many
    }
}

/// Стеклянная подложка виджета: тёмный фон, акцент статуса и светлая кромка.
private extension View {
    func widgetGlass(_ tint: Color) -> some View {
        containerBackground(for: .widget) {
            ZStack {
                Color(red: 0.03, green: 0.045, blue: 0.07)
                LinearGradient(
                    colors: [tint.opacity(0.48), tint.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ContainerRelativeShape()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
    }
}

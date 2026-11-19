//
//  AlertCardView.swift
//  SkyRadar
//
//  Стеклянная карточка одной открытой сводки.
//

import SwiftUI

/// Карточка сводки: статус, регион РФ, источник и оставшийся TTL.
struct AlertCardView: View {
    var alert: RadarAlert
    var sourceMark: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ThreatBadge(level: alert.level)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.regionName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(alert.timeAgoText)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                Spacer(minLength: 0)
                ttlLabel
            }

            Text(alert.summary)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(alert.level.accent)
                Text(alert.sourceName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                if let sourceMark {
                    Text(sourceMark)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(alert.level.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .liquidGlass(tint: alert.level.accent, cornerRadius: 10, material: .thinMaterial, glows: false)
                }
                Spacer(minLength: 0)
                if let sourceURL = alert.sourceURL, let url = URL(string: sourceURL) {
                    Link(destination: url) {
                        Label("источник", systemImage: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(alert.level.accent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(
            tint: alert.level.accent,
            cornerRadius: 28,
            material: .ultraThinMaterial,
            glows: true,
            animatesSheen: false,
            isPulsing: alert.level == .danger
        )
    }

    private var ttlLabel: some View {
        let minutes = alert.remainingMinutes
        let title = minutes <= 0
            ? "истекла"
            : "ещё \(minutes) \(RadarRussianPlural.form(minutes, one: "минута", few: "минуты", many: "минут"))"
        return Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(alert.level.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlass(
                tint: alert.level.accent,
                cornerRadius: 14,
                material: .thinMaterial,
                glows: false,
                animatesSheen: false,
                isPulsing: false
            )
    }
}

//
//  RadarStatusHeaderView.swift
//  SkyRadar
//
//  Центральный Liquid Glass-радар: кольца, развёртка и статус выбранных регионов РФ.
//

import SwiftUI

/// Шапка со статусом угрозы, временем обновления и свежестью данных.
struct RadarStatusHeaderView: View {
    var level: ThreatLevel
    var summary: String
    var lastUpdateText: String
    var freshness: DataFreshness
    var originTitle: String

    var body: some View {
        VStack(spacing: 18) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                RadarDial(level: level, date: timeline.date)
            }
            .frame(height: 236)

            VStack(spacing: 8) {
                Text(level.title)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                ThreatBadge(level: level, prominent: false)
                Text(originTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(tint: level.accent, cornerRadius: 14, material: .thinMaterial, glows: false)
                FreshnessPill(freshness: freshness, tint: level.accent)
                Spacer(minLength: 0)
                Text(lastUpdateText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .liquidGlass(
            tint: level.accent,
            cornerRadius: 36,
            material: .ultraThinMaterial,
            glows: true,
            animatesSheen: true,
            isPulsing: level == .danger
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.title). \(summary). \(originTitle). \(lastUpdateText). Данные \(freshness.title).")
    }
}

/// Концентрические кольца и мягкая развёртка луча.
struct RadarDial: View {
    var level: ThreatLevel
    var date: Date

    var body: some View {
        let cycle = date.timeIntervalSinceReferenceDate
        let sweep = cycle.truncatingRemainder(dividingBy: level == .danger ? 3.4 : 6.4) / (level == .danger ? 3.4 : 6.4) * 360
        let pulse = (sin(cycle * (level == .danger ? 3.4 : 1.5)) + 1) / 2

        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.14 - Double(index) * 0.02), lineWidth: 1)
                    .frame(width: 78 + CGFloat(index) * 42, height: 78 + CGFloat(index) * 42)
            }

            Circle()
                .stroke(level.accent.opacity(0.35), lineWidth: 10)
                .frame(width: 168, height: 168)
                .scaleEffect(1 + pulse * (level == .danger ? 0.08 : 0.035))
                .blur(radius: 0.4)

            Circle()
                .trim(from: 0, to: 0.22)
                .stroke(
                    AngularGradient(
                        colors: [level.accent.opacity(0.0), level.accent.opacity(0.95)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: 196, height: 196)
                .rotationEffect(.degrees(sweep))

            Circle()
                .fill(level.accent.opacity(0.18 + pulse * 0.12))
                .frame(width: 74, height: 74)
                .overlay {
                    Image(systemName: level.symbolName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(level.accent)
                        .symbolEffect(.pulse, options: level == .danger ? .repeating : .nonRepeating, value: level)
                }
                .liquidGlass(
                    tint: level.accent,
                    cornerRadius: 37,
                    material: .thinMaterial,
                    glows: true,
                    animatesSheen: false,
                    isPulsing: level == .danger
                )
        }
        .animation(.smooth(duration: 0.55), value: level)
    }
}

/// Точка и подпись свежести фида.
struct FreshnessPill: View {
    var freshness: DataFreshness
    var tint: Color

    private var color: Color {
        switch freshness {
        case .fresh:
            ThreatLevel.clear.accent
        case .aging:
            ThreatLevel.attention.accent
        case .stale:
            ThreatLevel.danger.accent
        case .unknown:
            Color.white.opacity(0.7)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(freshness.title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .liquidGlass(
            tint: color,
            cornerRadius: 14,
            material: .thinMaterial,
            glows: false,
            animatesSheen: false,
            isPulsing: false
        )
    }
}

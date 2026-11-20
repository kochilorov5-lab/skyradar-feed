//
//  MainRadarView.swift
//  SkyRadar
//
//  Собранный экран радара: фон, шапка, регионы РФ и лента открытых сводок.
//

import SwiftUI

/// Главный экран SkyRadar.
struct MainRadarView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = RadarViewModel()
    @State private var showsRegions = false
    @State private var showsFeedSettings = false
    @Namespace private var scopeNamespace

    var body: some View {
        ZStack {
            RadarAtmosphere(level: model.headlineLevel)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleRow
                    RadarStatusHeaderView(
                        level: model.headlineLevel,
                        summary: model.subscribedSummary,
                        lastUpdateText: model.lastUpdateText,
                        freshness: model.freshness,
                        originTitle: model.feedOrigin.title
                    )
                    if let loadError = model.loadError {
                        noteCard(loadError, tint: ThreatLevel.attention.accent)
                    }
                    controlBar
                    regionStrip
                    if let notice = model.notice {
                        noteCard(notice, tint: ThreatLevel.clear.accent)
                    }
                    alertFeed
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            disclaimer
        }
        .sheet(isPresented: $showsRegions) {
            RegionPickerSheet(model: model)
        }
        .sheet(isPresented: $showsFeedSettings) {
            FeedURLSheet(model: model)
        }
        .task {
            await model.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Task { await model.scheduleBackgroundRefresh() }
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: model.headlineLevel)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: model.visibleAlerts.map(\.id))
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SKYRADAR")
                    .font(.caption.weight(.bold))
                    .tracking(3)
                    .foregroundStyle(model.headlineLevel.accent)
                Text("Открытые сводки")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                Task { await model.refresh(manual: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                    .animation(model.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .smooth, value: model.isRefreshing)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .liquidGlass(tint: model.headlineLevel.accent, cornerRadius: 18, material: .thinMaterial, glows: true)
            .disabled(model.isRefreshing)
            .accessibilityLabel("Обновить сводки")
        }
    }

    private var controlBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(RadarFeedScope.allCases) { scope in
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                            model.scope = scope
                        }
                    } label: {
                        Text(scope.title)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(model.scope == scope ? Color.white : Color.white.opacity(0.62))
                            .background {
                                if model.scope == scope {
                                    Capsule()
                                        .fill(model.headlineLevel.accent.opacity(0.28))
                                        .matchedGeometryEffect(id: "scope", in: scopeNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .liquidGlass(tint: model.headlineLevel.accent, cornerRadius: 22, material: .thinMaterial, glows: false)

            Toggle(isOn: demoBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Демо-тревога")
                        .font(.subheadline.weight(.semibold))
                    Text("Мгновенно проверить статус, анимацию и пуш")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .tint(ThreatLevel.danger.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(
                tint: model.isDemoAlarmOn ? ThreatLevel.danger.accent : Color.white.opacity(0.35),
                cornerRadius: 22,
                material: .thinMaterial,
                glows: model.isDemoAlarmOn,
                isPulsing: model.isDemoAlarmOn
            )

            Button {
                showsFeedSettings = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(model.headlineLevel.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Адрес фида")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(model.isUsingDefaultFeedURL ? "Публичный фид по умолчанию" : "Свой адрес")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                    Text(model.feedOrigin.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(model.headlineLevel.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .liquidGlass(tint: model.headlineLevel.accent, cornerRadius: 22, material: .thinMaterial, glows: false)
            .accessibilityLabel("Настройки адреса фида")
        }
    }

    private var regionStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Выбранные регионы")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .textCase(.uppercase)
                Spacer()
                Button("Изменить") { showsRegions = true }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(model.headlineLevel.accent)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if model.subscribedRegions.isEmpty {
                        Text("Нет регионов на контроле")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.72))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .liquidGlass(tint: Color.white.opacity(0.3), cornerRadius: 16, material: .thinMaterial, glows: false)
                    } else {
                        ForEach(model.subscribedRegions) { region in
                            Button {
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                                    model.toggleSubscription(region.id)
                                }
                            } label: {
                                RegionChip(title: region.name, tint: model.headlineLevel.accent, isSelected: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var alertFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.scope == .mine ? "Сводки моих регионов" : "Все сводки по РФ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.55))
                .textCase(.uppercase)

            if model.visibleAlerts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.feedOrigin == .empty ? "Нет данных" : "Актуальных сводок нет")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(emptyFeedDetail)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.68))
                    Text(model.feedOrigin.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(model.headlineLevel.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .liquidGlass(tint: model.headlineLevel.accent, cornerRadius: 10, material: .thinMaterial, glows: false)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(tint: ThreatLevel.clear.accent, cornerRadius: 24, material: .ultraThinMaterial, glows: false)
            } else {
                ForEach(model.visibleAlerts) { alert in
                    AlertCardView(alert: alert, sourceMark: model.sourceMark(for: alert))
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    private func noteCard(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.white.opacity(0.86))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .liquidGlass(tint: tint, cornerRadius: 18, material: .thinMaterial, glows: false)
    }

    private var disclaimer: some View {
        Text("Данные собраны из открытых источников и носят информационный характер. Телефон не сканирует эфир.")
            .font(.caption2)
            .foregroundStyle(Color.white.opacity(0.62))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
            }
    }

    private var emptyFeedDetail: String {
        switch model.feedOrigin {
        case .empty:
            "Удалённый фид не ответил, сохранённой копии на устройстве нет."
        case .cache:
            "В кэше не осталось актуальных записей. Просроченные сводки скрыты."
        case .remote:
            "Свежий фид не содержит актуальных сводок. Просроченные записи скрыты."
        case .demo:
            "В демо-данных нет сводок для выбранного фильтра."
        }
    }

    private var demoBinding: Binding<Bool> {
        Binding(
            get: { model.isDemoAlarmOn },
            set: { enabled in
                withAnimation(.spring(response: 0.46, dampingFraction: 0.72)) {
                    model.isDemoAlarmOn = enabled
                }
                Task { await model.setDemoAlarm(enabled) }
            }
        )
    }
}

/// Шторка адреса фида: правка, сохранение и сброс на публичный JSON.
struct FeedURLSheet: View {
    var model: RadarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var validation = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    notificationCard
                    Text("Пока демо-тревога выключена, сводки берутся с этого HTTPS-адреса. При ошибке сети остаётся кэш, без подмешивания демо-данных.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.72))

                    TextField("https://", text: $draft, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .lineLimit(3...6)
                        .padding(14)
                        .liquidGlass(tint: Color.white.opacity(0.4), cornerRadius: 20, material: .thinMaterial, glows: false)

                    if !validation.isEmpty {
                        Text(validation)
                            .font(.caption)
                            .foregroundStyle(ThreatLevel.attention.accent)
                    }

                    Button {
                        guard model.applyFeedURL(draft) else {
                            validation = "Укажите полный адрес фида по HTTPS."
                            return
                        }
                        validation = ""
                        dismiss()
                        Task { await model.refresh(manual: true) }
                    } label: {
                        Text("Сохранить и обновить")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .liquidGlass(tint: ThreatLevel.clear.accent, cornerRadius: 18, material: .thinMaterial, glows: true)

                    Button {
                        model.resetFeedURL()
                        draft = model.feedURLString
                        validation = ""
                        dismiss()
                        Task { await model.refresh(manual: true) }
                    } label: {
                        Text("Сбросить на адрес по умолчанию")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .liquidGlass(tint: Color.white.opacity(0.35), cornerRadius: 18, material: .thinMaterial, glows: false)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background {
                ZStack {
                    Color(red: 0.02, green: 0.035, blue: 0.06)
                    Color.white.opacity(0.02)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Фид")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .task {
            draft = model.feedURLString
            await model.refreshNotificationStatus()
        }
    }

    /// Компактный статус пушей: проверка и запрос без отдельного экрана.
    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.notificationStatusTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("Новые danger и attention, а также переход в allClear по выбранным регионам.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.62))
            if let backgroundRefreshNote = model.backgroundRefreshNote {
                Text(backgroundRefreshNote)
                    .font(.caption)
                    .foregroundStyle(ThreatLevel.attention.accent)
            }
            Button {
                Task { await model.reviewNotificationAccess() }
            } label: {
                Text("Проверить / Запросить уведомления")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .liquidGlass(tint: ThreatLevel.attention.accent, cornerRadius: 18, material: .thinMaterial, glows: false)
        }
        .padding(14)
        .liquidGlass(tint: Color.white.opacity(0.35), cornerRadius: 22, material: .thinMaterial, glows: false)
    }
}

/// Глубокий фон со световыми пятнами текущего статуса.
struct RadarAtmosphere: View {
    var level: ThreatLevel
    @State private var drift = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.035, blue: 0.06)
            Circle()
                .fill(level.accent.opacity(0.42))
                .frame(width: 280, height: 280)
                .blur(radius: 78)
                .offset(x: drift ? -50 : 80, y: drift ? -180 : -70)
            Circle()
                .fill(level.glowAccent.opacity(0.38))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: drift ? 130 : 30, y: drift ? 240 : 120)
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .blur(radius: 46)
                .offset(x: drift ? -120 : -10, y: drift ? 40 : 200)
        }
        .ignoresSafeArea()
        .onAppear { drift = true }
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: drift)
        .animation(.smooth(duration: 0.7), value: level)
    }
}

#Preview {
    MainRadarView()
}

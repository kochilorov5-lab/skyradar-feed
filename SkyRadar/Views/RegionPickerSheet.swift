//
//  RegionPickerSheet.swift
//  SkyRadar
//
//  Стеклянный выбор регионов РФ: поиск, геолокация и свой город или район.
//

import CoreLocation
import MapKit
import SwiftUI

/// Лист подписки на регионы РФ и добавления своего города, направления или района.
struct RegionPickerSheet: View {
    @Bindable var model: RadarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var name = ""
    @State private var keywords = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var radius = "15"
    @State private var isLocating = false
    @State private var locationMessage = ""
    @State private var locator = RegionLocator()

    private var filteredRegions: [MonitoredRegion] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return model.regions }
        return model.regions.filter { region in
            region.name.lowercased().contains(needle)
                || region.keywords.contains { $0.lowercased().contains(needle) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchField
                    regionList
                    customForm
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(sheetBackground)
            .navigationTitle("Регионы РФ")
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
        .onAppear(perform: bindLocator)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.white.opacity(0.6))
            TextField("Регион, город или слово", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(14)
        .liquidGlass(
            tint: Color.white.opacity(0.45),
            cornerRadius: 20,
            material: .thinMaterial,
            glows: false
        )
    }

    private var regionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("На контроле")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.55))
                .textCase(.uppercase)

            if filteredRegions.isEmpty {
                Text("Ничего не найдено")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .liquidGlass(tint: Color.white.opacity(0.3), cornerRadius: 20, material: .thinMaterial, glows: false)
            } else {
                ForEach(filteredRegions) { region in
                    regionRow(region)
                }
            }
        }
    }

    private func regionRow(_ region: MonitoredRegion) -> some View {
        let selected = model.subscribedRegionIds.contains(region.id)
        return HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    model.toggleSubscription(region.id)
                }
            } label: {
                RegionChip(title: region.name, tint: ThreatLevel.clear.accent, isSelected: selected)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Text(String(format: "%.0f км", region.radiusKm))
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.5))
            if region.id.hasPrefix("custom-") {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        model.removeCustomRegion(region.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ThreatLevel.attention.accent)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Удалить \(region.name)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var customForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Свой город, направление или район")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.55))
                .textCase(.uppercase)

            Button {
                locator.request()
                isLocating = true
                locationMessage = "Определяем положение"
            } label: {
                HStack(spacing: 8) {
                    if isLocating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                    }
                    Text(isLocating ? "Ищем геолокацию" : "Определить по геолокации")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThreatLevel.clear.accent)
            .liquidGlass(tint: ThreatLevel.clear.accent, cornerRadius: 18, material: .thinMaterial, glows: true)

            glassField("Название", text: $name)
            glassField("Ключевые слова через запятую", text: $keywords)
            HStack(spacing: 10) {
                glassField("Широта", text: $latitude)
                glassField("Долгота", text: $longitude)
            }
            glassField("Радиус, км", text: $radius)

            if !locationMessage.isEmpty {
                Text(locationMessage)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.68))
            }

            Button(action: submitCustomRegion) {
                Text("Добавить место")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .liquidGlass(tint: ThreatLevel.attention.accent, cornerRadius: 18, material: .thinMaterial, glows: true)
        }
        .padding(16)
        .liquidGlass(
            tint: ThreatLevel.allClear.accent,
            cornerRadius: 28,
            material: .ultraThinMaterial,
            glows: true,
            animatesSheen: true
        )
    }

    private func glassField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .textInputAutocapitalization(.never)
            .padding(12)
            .liquidGlass(tint: Color.white.opacity(0.35), cornerRadius: 16, material: .thinMaterial, glows: false)
    }

    private var sheetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.10),
                Color(red: 0.02, green: 0.03, blue: 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func bindLocator() {
        locator.onUpdate = { latitudeValue, longitudeValue, placeName in
            latitude = String(format: "%.5f", latitudeValue)
            longitude = String(format: "%.5f", longitudeValue)
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let placeName {
                name = placeName
            }
            if keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let placeName {
                keywords = placeName
            }
            isLocating = false
            locationMessage = "Координаты подставлены. Проверьте название и слова."
        }
        locator.onFailure = { message in
            isLocating = false
            locationMessage = message
        }
    }

    private func submitCustomRegion() {
        guard let latitudeValue = Self.parseNumber(latitude),
              let longitudeValue = Self.parseNumber(longitude) else {
            locationMessage = "Введите широту и долготу числами."
            return
        }
        let radiusValue = Self.parseNumber(radius) ?? 15
        let keywordList = keywords.split(separator: ",").map(String.init)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
            model.addCustomRegion(
                name: name,
                keywords: keywordList,
                latitude: latitudeValue,
                longitude: longitudeValue,
                radiusKm: radiusValue
            )
        }
        name = ""
        keywords = ""
        locationMessage = "Место добавлено и включено в подписку."
    }

    private static func parseNumber(_ raw: String) -> Double? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

/// Одноразовое определение точки через CoreLocation и обратное геокодирование.
final class RegionLocator: NSObject, CLLocationManagerDelegate {
    var onUpdate: (@MainActor (Double, Double, String?) -> Void)?
    var onFailure: (@MainActor (String) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            onFailure?("Геолокация выключена. Координаты можно ввести вручную.")
        @unknown default:
            onFailure?("Не удалось запросить геолокацию.")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
            self.manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        Task { @MainActor in
            await self.resolve(latitude: latitude, longitude: longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.onFailure?(message)
        }
    }

    private func resolve(latitude: Double, longitude: Double) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            onUpdate?(latitude, longitude, nil)
            return
        }
        let item = try? await request.mapItems.first
        let placeName = item?.addressRepresentations?.cityName ?? item?.address?.shortAddress ?? item?.name
        onUpdate?(latitude, longitude, placeName)
    }
}

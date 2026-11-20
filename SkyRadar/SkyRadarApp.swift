//
//  SkyRadarApp.swift
//  SkyRadar
//
//  Created by Сергей on 19.11.2026.
//

import SwiftUI

@main
struct SkyRadarApp: App {
    init() {
        BackgroundRefreshManager.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            MainRadarView()
        }
    }
}

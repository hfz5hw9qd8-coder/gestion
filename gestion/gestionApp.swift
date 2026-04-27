//
//  gestionApp.swift
//  gestion
//
//  Created by Mathieu Perez on 26/04/2026.
//

import SwiftData
import SwiftUI

@main
struct gestionApp: App {
    private let modelContainer = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

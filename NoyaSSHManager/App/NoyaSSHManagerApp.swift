import AppKit
import NoyaCore
import SwiftUI

/// Point d'entrée de NOYA SSH Manager.
///
/// Une seule fenêtre principale et une fenêtre de réglages. L'application se
/// ferme entièrement avec sa dernière fenêtre : aucun processus ne reste actif.
@main
struct NoyaSSHManagerApp: App {
    @NSApplicationDelegateAdaptor(DelegueApplication.self) private var delegue
    @State private var store: ServeurStore

    init() {
        Reglages.enregistrerValeursParDefaut()
        _store = State(initialValue: ServeurStore())
    }

    var body: some Scene {
        Window("NOYA SSH Manager", id: "principale") {
            FenetrePrincipale()
                .environment(store)
                .frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            SidebarCommands()
            CommandesApplication(store: store)
        }

        Settings {
            VueReglages()
                .environment(store)
        }
    }
}

/// Délégué AppKit minimal.
final class DelegueApplication: NSObject, NSApplicationDelegate {
    /// Quitte l'application à la fermeture de la dernière fenêtre :
    /// les vérifications s'arrêtent avec elle.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var browserManager: BrowserManager
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(Localization.string(.settingsGeneral), systemImage: "gear")
                }
            
            BrowserListSettingsView(browserManager: browserManager)
                .tabItem {
                    Label(Localization.string(.settingsBrowsers), systemImage: "globe")
                }
                
            AboutSettingsView()
                .tabItem {
                    Label(Localization.string(.settingsAbout), systemImage: "info.circle")
                }
        }
        .frame(width: Constants.Window.width, height: Constants.Window.height)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @AppStorage(Constants.Keys.launchAtLogin) private var launchAtLogin = false
    @AppStorage(Constants.Keys.appLanguage) private var appLanguage = "auto"
    // Hack to force refresh when language changes
    @State private var refreshID = UUID()
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Language Picker
            HStack {
                Text(Localization.string(.settingsLanguage) + ":")
                Spacer()
                Picker("", selection: $appLanguage) {
                    Text(Localization.string(.settingsLanguageAuto)).tag("auto")
                    Text("English").tag("en")
                    Text("Türkçe").tag("tr")
                }
                .frame(width: 150)
                .onChange(of: appLanguage) { _ in
                    // In a real app we might need to restart or use @Environment object for locale.
                    // For this simple struct approach, we just force a redraw.
                    refreshID = UUID()
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Launch at Login
            HStack {
                Toggle(Localization.string(.settingsLaunchAtLogin), isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { newValue in
                        if #available(macOS 13.0, *) {
                            if newValue {
                                try? SMAppService.mainApp.register()
                            } else {
                                try? SMAppService.mainApp.unregister()
                            }
                        }
                    }
                Spacer()
            }
            .padding(.horizontal)
            
            // Explanation text
            Text(launchAtLogin ? Localization.string(.settingsLaunchAtLoginDescOn) : Localization.string(.settingsLaunchAtLoginDescOff))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 20)
        .id(refreshID) // Force redraw on language change
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct BrowserListSettingsView: View {
    @ObservedObject var browserManager: BrowserManager
    @State private var allBrowsers: [Browser] = []
    
    // We need to track hidden browsers here to toggle them
    @AppStorage(Constants.Keys.hiddenBrowsers) private var hiddenBrowsersData: Data = Data()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.settingsBrowserList))
                .font(.headline)
            Text(Localization.string(.settingsBrowserListDesc))
                .font(.caption)
                .foregroundColor(.secondary)
            
            List {
                ForEach(allBrowsers) { browser in
                    HStack {
                        if let icon = browser.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(browser.name)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: {
                                !isBrowserHidden(browser.bundleId)
                            },
                            set: { isVisible in
                                browserManager.toggleBrowserVisibility(bundleId: browser.bundleId, isHidden: !isVisible)
                            }
                        ))
                        .toggleStyle(.switch)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            self.allBrowsers = browserManager.getAllDetectedBrowsers()
        }
    }
    
    private func isBrowserHidden(_ bundleId: String) -> Bool {
        let list = UserDefaults.standard.stringArray(forKey: Constants.Keys.hiddenBrowsers) ?? []
        return list.contains(bundleId)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)!)
                .resizable()
                .frame(width: 48, height: 48)
            
            Text(Localization.string(.aboutTitle))
                .font(.headline)
                .bold()
            
            Text(Localization.string(.aboutDesc))
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(Localization.string(.aboutVersion))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(Localization.string(.aboutFooter))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

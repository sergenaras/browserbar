import Foundation
import AppKit
import SwiftUI
import CoreServices
import Combine

struct Browser: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleId: String
    let icon: NSImage?
}

class BrowserManager: ObservableObject {
    @Published var installedBrowsers: [Browser] = []
    @Published var defaultBrowserBundleId: String?
    
    // Persist hidden browsers
    private let hiddenBrowsersKey = Constants.Keys.hiddenBrowsers
    
    
    init() {
        refresh()
    }
    
    func refresh() {
        detectInstalledBrowsers()
        checkDefaultBrowser()
    }
    
    // Helper to get ALL installed browsers (even hidden ones)
    func getAllDetectedBrowsers() -> [Browser] {
        var found: [Browser] = []
        let workspace = NSWorkspace.shared
        
        // Use a dummy HTTP URL to find all apps that claim to handle it
        if let testURL = Constants.URLs.connectionTest as URL? {
            let appURLs = workspace.urlsForApplications(toOpen: testURL)
            
            for appURL in appURLs {
                if let bundle = Bundle(url: appURL), let bundleId = bundle.bundleIdentifier {
                    // Filter out non-browsers or helper tools if necessary.
                    // Generally, anything registering for "http" is considered a browser.
                    
                    let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String) 
                            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                            ?? appURL.deletingPathExtension().lastPathComponent
                    
                    let icon = workspace.icon(forFile: appURL.path)
                    
                    let browser = Browser(id: bundleId, name: name, bundleId: bundleId, icon: icon)
                    
                    // Avoid duplicates (sometimes same app returns multiple times or different versions)
                    if !found.contains(where: { $0.bundleId == bundleId }) {
                        found.append(browser)
                    }
                }
            }
        }
        
        // Sort alphabetically
        return found.sorted { $0.name < $1.name }
    }

    private func detectInstalledBrowsers() {
        let allBrowsers = getAllDetectedBrowsers()
        let hiddenIds = UserDefaults.standard.stringArray(forKey: hiddenBrowsersKey) ?? []
        
        let visibleBrowsers = allBrowsers.filter { !hiddenIds.contains($0.bundleId) }
        
        DispatchQueue.main.async {
            self.installedBrowsers = visibleBrowsers
        }
    }
    
    func toggleBrowserVisibility(bundleId: String, isHidden: Bool) {
        var hiddenIds = UserDefaults.standard.stringArray(forKey: hiddenBrowsersKey) ?? []
        
        if isHidden {
            if !hiddenIds.contains(bundleId) {
                hiddenIds.append(bundleId)
            }
        } else {
            hiddenIds.removeAll { $0 == bundleId }
        }
        
        UserDefaults.standard.set(hiddenIds, forKey: hiddenBrowsersKey)
        refresh() // Update the main list
    }
    
    func checkDefaultBrowser() {
        // Get the default handler for http
        if let currentUrl = NSWorkspace.shared.urlForApplication(toOpen: Constants.URLs.connectionTest) {
            if let bundle = Bundle(url: currentUrl)?.bundleIdentifier {
                DispatchQueue.main.async {
                    self.defaultBrowserBundleId = bundle
                }
            }
        }
    }
    
    func setDefault(browser: Browser) {
        // LSSetDefaultHandlerForURLScheme is the specific API for changing the handler of a protocol (http/https).
        // Error -54 (permErr) indicates that the App Sandbox is preventing this change.
        // To fix this, you must DISABLE "App Sandbox" in Xcode Project Settings -> Signing & Capabilities.
        
        let httpResult = LSSetDefaultHandlerForURLScheme("http" as CFString, browser.bundleId as CFString)
        let httpsResult = LSSetDefaultHandlerForURLScheme("https" as CFString, browser.bundleId as CFString)
        
        if httpResult == 0 && httpsResult == 0 {
            // Refresh to see if it took effect (might be delayed by user prompt)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkDefaultBrowser()
            }
        }
    }
}

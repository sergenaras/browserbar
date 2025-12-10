//
//  browserbarApp.swift
//  browserbar
//
//  Created by Sergen on 10.12.2025.
//

import SwiftUI
import AppKit
import Combine

@main
struct browserbarApp: App {
    // We connect the AppDelegate here
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var browserManager = BrowserManager()
    var cancellables = Set<AnyCancellable>()
    
    // Track the browser we are trying to switch to
    var targetBrowserBundleId: String?
    let preferredIconName: String = "arrow.triangle.2.circlepath" // Locked to 'Switch'
    
    enum IconState {
        case idle
        case switching
        case success
    }
    
    // Keep track of current state to prevent flickering
    var currentIconState: IconState = .idle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // print("DEBUG: Application Did Finish Launching. Configuring Status Item...")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(state: .idle)
        
        // Subscribe to changes in installedBrowsers
        browserManager.$installedBrowsers
            .receive(on: RunLoop.main)
            .sink { [weak self] browsers in
                // print("DEBUG: Browser list updated. Rebuilding menu with \(browsers.count) items.")
                self?.setupMenu()
            }
            .store(in: &cancellables)
            
        // Subscribe to default browser changes to update checkmarks AND icon color
        browserManager.$defaultBrowserBundleId
            .receive(on: RunLoop.main)
            .sink { [weak self] newBundleId in
                self?.handleDefaultBrowserChange(newBundleId)
            }
            .store(in: &cancellables)
    }
    
    func updateIcon(state: IconState) {
        // Update local state tracking
        self.currentIconState = state
        
        guard let button = statusItem?.button else { return }
        
        let symbolName = preferredIconName
        let fallbackName = "globe"
        
        // Helper to get base image
        var image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Browser Switcher")
        if image == nil {
            image = NSImage(systemSymbolName: fallbackName, accessibilityDescription: "Browser Switcher")
        }
        
        guard let finalImage = image else { return }
        
        switch state {
        case .idle:
            // Template mode adapts to system appearance (Light/Dark mode)
            finalImage.isTemplate = true
            button.image = finalImage
            button.contentTintColor = nil // Clear any tint
            
        case .switching:
            // Force Orange using Symbol Configuration
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
            button.image = finalImage.withSymbolConfiguration(config)
            button.contentTintColor = nil
            
        case .success:
            // Force Green using Symbol Configuration
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
            button.image = finalImage.withSymbolConfiguration(config)
            button.contentTintColor = nil
        }
    }
    
    func handleDefaultBrowserChange(_ newBundleId: String?) {
        setupMenu() // Always rebuild menu for checkmarks
        
        // CRITICAL: Only change Icon State if we have a target
        if let target = targetBrowserBundleId, let current = newBundleId {
            if target == current {
                // Success! We switched to the target.
                // print("DEBUG: Successfully switched to target. Showing Green.")
                updateIcon(state: .success)
                
                // Reset to normal after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Only reset if we haven't started another switch
                    if self.targetBrowserBundleId == target {
                        self.targetBrowserBundleId = nil
                        self.updateIcon(state: .idle)
                    }
                }
            } else {
                // Target exists, but does not match Current.
                // We MUST stay in .switching (Orange).
                // Do NOT reset to idle here.
                if currentIconState != .switching {
                    updateIcon(state: .switching)
                }
            }
        } else {
            // No active target.
            // If we are currently switching, but target is nil (timeout happened?), reset.
            // Or if just idle update.
            if targetBrowserBundleId == nil && currentIconState != .success {
                 updateIcon(state: .idle)
            }
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        // Only checking the default browser is fast enough to be done here
        browserManager.checkDefaultBrowser()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        let titleItem = NSMenuItem(title: Localization.string(.menuBrowsers), action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        for browser in browserManager.installedBrowsers {
            let item = NSMenuItem(title: browser.name, action: #selector(browserClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser
            
            if browser.bundleId == browserManager.defaultBrowserBundleId {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: Localization.string(.menuSettings), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: Localization.string(.menuQuit), action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func browserClicked(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? Browser else { return }
        
        // 1. Set Target
        targetBrowserBundleId = browser.bundleId
        
        // 2. Visual Feedback (Orange = Working)
        updateIcon(state: .switching)
        
        // 3. Perform Logic
        browserManager.setDefault(browser: browser)
        
        // 4. Polling for success (or timeout)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            self.browserManager.checkDefaultBrowser()
        }
        
        // Auto-cancel timer after 15s
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            timer.invalidate()
            // If still waiting, reset UI (assumed cancel/fail)
            if self.targetBrowserBundleId == browser.bundleId {
                self.targetBrowserBundleId = nil
                self.updateIcon(state: .idle)
            }
        }
    }
    
    // Settings Window Management
    var settingsWindow: NSWindow?
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(browserManager: browserManager)
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = Localization.string(.settingsTitle)
            window.setContentSize(NSSize(width: Constants.Window.width, height: Constants.Window.height))
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

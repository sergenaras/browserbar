import Foundation

struct Constants {
    struct Keys {
        static let hiddenBrowsers = "hiddenBrowsers"
        static let launchAtLogin = "launchAtLogin"
        static let appLanguage = "appLanguage"
    }
    
    struct URLs {
        // A reliable URL to test handling (Google or Apple both work)
        static let connectionTest = URL(string: "http://www.google.com")!
    }
    
    struct Window {
        static let width: CGFloat = 450
        static let height: CGFloat = 250
    }
}

import Foundation

/// Finds the SPM resource bundle inside Contents/Resources/ (app bundle)
/// or falls back to the SPM-generated Bundle.module (dev builds).
enum Resources {
    static let bundle: Bundle = {
        let bundleName = "RubberDuckWidget_RubberDuckWidget"
        // App bundle: Contents/Resources/<name>.bundle
        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("\(bundleName).bundle"),
           let b = Bundle(path: resourceURL.path) {
            return b
        }
        // Fallback: SPM build directory (works in dev/debug)
        return Bundle.module
    }()
}

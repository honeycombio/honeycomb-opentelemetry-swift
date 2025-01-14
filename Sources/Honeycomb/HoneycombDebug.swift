import Foundation

internal func configureDebug(options: HoneycombOptions) {
    if options.debug {
        print("🐝 Honeycomb SDK Debug Mode Enabled 🐝")
        print("Honeycomb options: \(options)")
    }
}

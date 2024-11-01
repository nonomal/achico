import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        PDFCacheManager.shared.cleanupOldFiles()
    }
}

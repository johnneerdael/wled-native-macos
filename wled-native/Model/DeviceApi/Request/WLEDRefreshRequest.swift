import Foundation
import CoreData

class WLEDRefreshRequest: WLEDRequest {
    let context: NSManagedObjectContext
    private(set) var info: Info?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // Special initializer for device verification during discovery
    @MainActor
    init() {
        // For verification, use a background context to avoid main-actor isolation and UI context contention
        self.context = PersistenceController.shared.container.newBackgroundContext()
    }
    
    func setInfo(info: Info) async {
        self.info = info
    }
    
    func getInfo() async -> Info? {
        // This is a simple getter for the stored info
        // In practice, you might want to wait for the request to complete
        return self.info
    }
}

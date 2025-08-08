import Foundation
import CoreData

class WLEDRefreshRequest: WLEDRequest {
    let context: NSManagedObjectContext
    private(set) var info: Info?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // Special initializer for device verification during discovery
    init() {
        // For verification, we'll use a temporary context
        self.context = PersistenceController.shared.container.viewContext
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

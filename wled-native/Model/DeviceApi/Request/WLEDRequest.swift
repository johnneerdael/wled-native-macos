import Foundation
import CoreData

protocol WLEDRequest {
    // The context property is removed from the protocol
    // to allow for requests that don't need it, like during discovery.
}

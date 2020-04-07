//
//  Created by Zsombor Szabo on 03/04/2020.
//  
//

import Foundation


/// https://github.com/Co-Epi/CEN
public class ContactTracingBluetoothService: NSObject {
    
    public var cenGenerator: () -> Data
    
    public var cenFinder: (Data) -> Void
    
    public var errorHandler: (Error) -> Void
    
    private var bluetoothController = BluetoothController()
    
    public init(
        cenGenerator: @escaping () -> Data,
        cenFinder: @escaping (Data) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        self.cenGenerator = cenGenerator
        self.cenFinder = cenFinder
        self.errorHandler = errorHandler
        super.init()
        self.bluetoothController.service = self
    }
    
    public func start() {
        self.bluetoothController.start()
    }
    
    public func stop() {
        self.bluetoothController.stop()
    }
    
}

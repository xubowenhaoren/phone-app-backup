//
//  Created by Zsombor Szabo on 25/03/2020.
//

import Foundation
import os.log

extension BluetoothController {
    
    func didFindContactEventNumber(_ cen: Data) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Did find contact event number=%@",
                log: self.log,
                cen.base64EncodedString()
            )
        }
        self.service?.cenFinder(cen)
    }
    
    func generateContactEventNumber() -> Data {
        let cen = self.service?.cenGenerator()
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Did generate contact event number=%@",
                log: self.log,
                cen?.base64EncodedString() ?? ""
            )
        }
        return cen ?? Data()
    }

}

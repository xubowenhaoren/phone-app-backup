@objc(ContactTracing)
class ContactTracing : CDVPlugin {

    var contactTracingBluetoothService : ContactTracingBluetoothService?
    var inMemoryCache : [ [ AnyHashable : Any ] ]?

    @objc(start:)
    func start( _ command : CDVInvokedUrlCommand ) {
        self.configureContactTracingService( callbackId : command.callbackId )
        self.contactTracingBluetoothService?.start()
        self.commandDelegate.send(
            CDVPluginResult( status : CDVCommandStatus_OK ),
            callbackId : command.callbackId )
    }
    
    @objc(stop:)
    func stop( _ command : CDVInvokedUrlCommand ) {
        self.contactTracingBluetoothService?.stop()
        self.commandDelegate.send(
            CDVPluginResult( status : CDVCommandStatus_OK ),
            callbackId : command.callbackId )
    }
    
    @objc(getCENs:)
    func getCENs( _ command : CDVInvokedUrlCommand ) {
        self.commandDelegate.send(
            CDVPluginResult( status : CDVCommandStatus_OK, messageAs : self.inMemoryCache ?? [] ),
            callbackId : command.callbackId )
    }
 
    func configureContactTracingService( callbackId : String ) {
        guard contactTracingBluetoothService == nil else { return }
        self.inMemoryCache = []
        contactTracingBluetoothService = ContactTracingBluetoothService(
            cenGenerator: { () -> Data in
                NSLog("Bluetooth sharing asked to generate a contact event number to share it")
                let data = withUnsafeBytes(of: UUID().uuid, { Data($0) })
                self.inMemoryCache?.append( [
                    "number" : data.base64EncodedString(),
                    "ts" : Date().timeIntervalSince1970,
                    "type" : "advertise"
                ] )
                return data
            }, cenFinder: { (data) in
                NSLog("Bluetooth sharing found a contact event number from a nearby device" )
                self.inMemoryCache?.append( [
                    "number" : data.base64EncodedString(),
                    "ts" : Date().timeIntervalSince1970,
                    "type" : "scan"
                ] )
            }, errorHandler: { ( error ) in
                self.commandDelegate.send(
                    CDVPluginResult(
                        status : CDVCommandStatus_ERROR,
                        messageAs : "ContactTracing service failed. Check BLE & Permissions settings." ),
                    callbackId : callbackId )
            }
        )
    }
        
}

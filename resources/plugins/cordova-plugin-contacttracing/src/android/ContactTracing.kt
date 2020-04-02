package org.covidwatch.libcontacttracing

import java.util.*
import android.bluetooth.*
import android.content.Intent
import android.Manifest
import org.apache.cordova.*
import org.json.*


class ContactTracing : CordovaPlugin() {

    private var scanContext: CallbackContext? = null
    private var adContext: CallbackContext? = null
    private var cenScanner: CENScanner? = null
    private var cenAdvertiser: CENAdvertiser? = null

    @Throws(JSONException::class)
    override fun execute(action: String, args: JSONArray, context: CallbackContext): Boolean {

        if ( !BluetoothAdapter.getDefaultAdapter().isEnabled ) {
            cordova.startActivityForResult(this, Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), 1)
        }
        if ( !PermissionHelper.hasPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ) {
            PermissionHelper.requestPermission(this, 2, Manifest.permission.ACCESS_COARSE_LOCATION);
        }

        cenScanner = cenScanner ?: CENScanner(
                cordova.activity.applicationContext,
                BluetoothAdapter.getDefaultAdapter().bluetoothLeScanner,
                UUIDs.CONTACT_EVENT_SERVICE,
                ScanCENHandler( ) )
        cenAdvertiser = cenAdvertiser ?: CENAdvertiser(
                cordova.activity.applicationContext,
                BluetoothAdapter.getDefaultAdapter().bluetoothLeAdvertiser,
                UUIDs.CONTACT_EVENT_SERVICE,
                UUIDs.CONTACT_EVENT_IDENTIFIER_CHARACTERISTIC,
                AdCENHandler( ),
                DefaultCENGenerator() )
        val result = PluginResult( PluginResult.Status.NO_RESULT )
        var uuid = UUIDs.CONTACT_EVENT_SERVICE

        try {
            when ( action ) {
                "startScanner" -> {
                    scanContext?.let{ throw Exception( "Scanner is already started" ) }
                    scanContext = context
                    try { uuid = UUID.fromString( args.getString(0) ) } catch (e: Exception) { }
                    cenScanner!!.startScanning( arrayOf( uuid ), args.getLong(1) ?: 10 )
                    result.setKeepCallback( true )
                    context.sendPluginResult( result )
                }
                "stopScanner" -> {
                    scanContext ?: throw Exception( "Scanner is already stopped" )
                    cenScanner!!.stopScanning()
                    scanContext!!.sendPluginResult( result )
                    scanContext = null
                    context.success()
                }
                "startAdvertiser" -> {
                    adContext?.let{ throw Exception( "Advertiser is already started" ) }
                    adContext = context
                    try { uuid = UUID.fromString( args.getString(0) ) } catch (e: Exception) { }
                    cenAdvertiser!!.startAdvertiser( uuid )
                    result.setKeepCallback( true )
                    context.sendPluginResult( result )
                }
                "stopAdvertiser" -> {
                    adContext ?: throw Exception( "Advertiser is already stopped" )
                    cenAdvertiser!!.stopAdvertiser()
                    adContext!!.sendPluginResult( result )
                    adContext = null
                    context.success()
                }
                "updateCEN" -> {
                    adContext ?: throw Exception( "Advertiser must be started first" )
                    cenAdvertiser!!.updateCEN()
                    context.success()
                }
                else -> throw Exception( "Invalid Action" )
            }
            return true
        } catch (e: Exception) {
            context.error( e.toString() )
            return false
        }

    }

    inner class ScanCENHandler : CENHandler {
        override fun handleCEN(cen: CEN) {
            scanContext ?: return
            val contactEvent = JSONObject()
            contactEvent.put( "cen", cen.toUUID().toString() )
            val result = PluginResult(PluginResult.Status.OK, contactEvent)
            result.setKeepCallback(true);
            scanContext!!.sendPluginResult(result)
        }
    }

    inner class AdCENHandler : CENHandler {
        override fun handleCEN(cen: CEN) {
            adContext ?: return
            val contactEvent = JSONObject()
            contactEvent.put( "cen", cen.toUUID().toString() )
            val result = PluginResult(PluginResult.Status.OK, contactEvent)
            result.setKeepCallback(true);
            adContext!!.sendPluginResult(result)
        }
    }

    inner class DefaultCENGenerator : CENGenerator {
        override fun generateCEN(): CEN {
            return CEN(UUID.randomUUID())
        }
    }

    object UUIDs {
        var CONTACT_EVENT_SERVICE: UUID = UUID.fromString("0000C019-0000-1000-8000-00805F9B34FB")
        var CONTACT_EVENT_IDENTIFIER_CHARACTERISTIC: UUID = UUID.fromString("D61F4F27-3D6B-4B04-9E46-C9D2EA617F62")
        var CONTACT_EVENT_IDENTIFIER_DESCRIPTOR: UUID = UUID.fromString("3109E184-B766-DEAD-BEEF-D7116B29A275")
    }

}
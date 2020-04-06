package org.covidwatch.libcontacttracing

import java.util.*
import android.bluetooth.*
import android.content.Intent
import android.Manifest
import org.apache.cordova.*
import org.json.*


class ContactTracing : CordovaPlugin() {

    private var cenScanner: CENScanner? = null
    private var cenAdvertiser: CENAdvertiser? = null
    private var inMemoryCache: MutableList<JSONObject>? = mutableListOf();

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
                    try { uuid = UUID.fromString( args.getString(0) ) } catch (e: Exception) { }
                    cenScanner!!.startScanning( arrayOf( uuid ), args.getLong(1) ?: 10 )
                    context.success();
                }
                "stopScanner" -> {
                    try { uuid = UUID.fromString( args.getString(0) ) } catch (e: Exception) { }
                    cenScanner!!.stopScanning()
                    context.success();
                }
                "startAdvertiser" -> {
                    try { uuid = UUID.fromString( args.getString(0) ) } catch (e: Exception) { }
                    cenAdvertiser!!.startAdvertiser( uuid )
                    context.success();
                }
                "stopAdvertiser" -> {
                    try { uuid = UUID.fromString( args.getString(0) ) } catch (e: Exception) { }
                    cenAdvertiser!!.stopAdvertiser()
                    context.success();
                }
                "updateCEN" -> {
                    context.success(JSONArray(inMemoryCache));
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
            val contactEvent = JSONObject()
            contactEvent.put( "number", cen.toUUID().toString() )
            contactEvent.put( "ts", System.currentTimeMillis()/1000)
            contactEvent.put( "type", "scan")
            inMemoryCache!!.add(contactEvent);
        }
    }

    inner class AdCENHandler : CENHandler {
        override fun handleCEN(cen: CEN) {
            val contactEvent = JSONObject()
            contactEvent.put( "number", cen.toUUID().toString() )
            contactEvent.put( "ts", System.currentTimeMillis()/1000)
            contactEvent.put("type", "advertise");
            inMemoryCache!!.add(contactEvent);
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
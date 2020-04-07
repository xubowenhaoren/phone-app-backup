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
            cordova.startActivityForResult( this, Intent( BluetoothAdapter.ACTION_REQUEST_ENABLE ), 1 )
        }
        if ( !PermissionHelper.hasPermission( this, Manifest.permission.ACCESS_COARSE_LOCATION ) ) {
            PermissionHelper.requestPermission( this, 2, Manifest.permission.ACCESS_COARSE_LOCATION )
        }

        cenScanner = cenScanner ?: CENScanner(
                cordova.activity.applicationContext,
                BluetoothAdapter.getDefaultAdapter().bluetoothLeScanner,
                UUIDs.CEN_SERVICE,
                ScanCENHandler( ) )
        cenAdvertiser = cenAdvertiser ?: CENAdvertiser(
                cordova.activity.applicationContext,
                BluetoothAdapter.getDefaultAdapter().bluetoothLeAdvertiser,
                UUIDs.CEN_SERVICE,
                UUIDs.CEN_CHARACTERISTIC,
                AdCENHandler( ),
                DefaultCENGenerator() )

        try {
            when ( action ) {
                "start" -> {
                    cenAdvertiser!!.startAdvertiser( UUIDs.CEN_SERVICE )
                    cenScanner!!.startScanning( arrayOf( UUIDs.CEN_SERVICE ), 10 )
                    Timer().scheduleAtFixedRate(
                        object : TimerTask() { override fun run() { cenAdvertiser!!.updateCEN() } },
                        15 * 60000,
                        15 * 60000 )
                    context.success()
                }
                "stop" -> {
                    cenAdvertiser!!.stopAdvertiser()
                    cenScanner!!.stopScanning()
                    context.success()
                }
                "getCENs" -> {
                    context.success( JSONArray( inMemoryCache ) )
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
            contactEvent.put( "ts", System.currentTimeMillis() )
            contactEvent.put( "type", "scan" )
            inMemoryCache!!.add(contactEvent);
        }
    }

    inner class AdCENHandler : CENHandler {
        override fun handleCEN(cen: CEN) {
            val contactEvent = JSONObject()
            contactEvent.put( "number", cen.toUUID().toString() )
            contactEvent.put( "ts", System.currentTimeMillis() )
            contactEvent.put( "type", "advertise" );
            inMemoryCache!!.add(contactEvent);
        }
    }

    inner class DefaultCENGenerator : CENGenerator {
        override fun generateCEN(): CEN {
            return CEN(UUID.randomUUID())
        }
    }

    object UUIDs {
        var CEN_SERVICE : UUID = UUID.fromString( "0000C019-0000-1000-8000-00805F9B34FB" )
        var CEN_CHARACTERISTIC : UUID = UUID.fromString( "D61F4F27-3D6B-4B04-9E46-C9D2EA617F62" )
    }

}
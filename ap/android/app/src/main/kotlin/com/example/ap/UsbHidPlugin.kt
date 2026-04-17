package com.example.ap

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Flutter platform channel plugin for USB HID communication with HW Signer.
 *
 * Exposes methods: enumerate, open, close, writeReport, readReport
 * via MethodChannel "com.mpcwallet.ap/usb_hid".
 *
 * USB bulk/interrupt transfers run on a dedicated background thread to avoid
 * blocking the Android main (UI) thread.
 */
class UsbHidPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "UsbHidPlugin"
        private const val CHANNEL = "com.mpcwallet.ap/usb_hid"
        private const val ACTION_USB_PERMISSION = "com.mpcwallet.ap.USB_PERMISSION"

        // HW Signer USB IDs (pid.codes open-source VID)
        private const val VENDOR_ID = 0x1209
        private const val PRODUCT_ID = 0x0001

        private const val REPORT_SIZE = 64
        private const val READ_TIMEOUT_MS = 30000
        private const val WRITE_TIMEOUT_MS = 5000
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())
    private val usbExecutor = Executors.newSingleThreadExecutor()

    private var usbManager: UsbManager? = null
    private var usbDevice: UsbDevice? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var endpointIn: UsbEndpoint? = null
    private var endpointOut: UsbEndpoint? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        closeDevice()
        usbExecutor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "enumerate" -> enumerate(result)
            "open" -> open(result)
            "close" -> close(result)
            "writeReport" -> writeReport(call, result)
            "readReport" -> readReport(result)
            else -> result.notImplemented()
        }
    }

    /**
     * List connected USB devices matching HW Signer VID/PID.
     */
    private fun enumerate(result: MethodChannel.Result) {
        val manager = usbManager ?: run {
            result.error("USB_ERROR", "USB manager not available", null)
            return
        }

        val devices = manager.deviceList.values.filter { device ->
            device.vendorId == VENDOR_ID && device.productId == PRODUCT_ID
        }.map { device ->
            val serial = try {
                if (manager.hasPermission(device)) device.serialNumber ?: "" else ""
            } catch (_: SecurityException) { "" }
            mapOf(
                "deviceName" to device.deviceName,
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "serialNumber" to serial,
            )
        }

        Log.d(TAG, "enumerate: found ${devices.size} device(s)")
        result.success(devices)
    }

    /**
     * Open connection to the first matching HW Signer device.
     */
    private fun open(result: MethodChannel.Result) {
        val manager = usbManager ?: run {
            result.error("USB_ERROR", "USB manager not available", null)
            return
        }

        val device = manager.deviceList.values.firstOrNull { d ->
            d.vendorId == VENDOR_ID && d.productId == PRODUCT_ID
        } ?: run {
            result.error("USB_NOT_FOUND", "No HW Signer device found", null)
            return
        }

        if (manager.hasPermission(device)) {
            openDevice(device, result)
        } else {
            requestPermission(device, result)
        }
    }

    private fun requestPermission(device: UsbDevice, result: MethodChannel.Result) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                context.unregisterReceiver(this)
                val granted = intent.getBooleanExtra(
                    UsbManager.EXTRA_PERMISSION_GRANTED, false
                )
                if (granted) {
                    openDevice(device, result)
                } else {
                    result.error("USB_PERMISSION", "USB permission denied", null)
                }
            }
        }

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val permissionIntent = PendingIntent.getBroadcast(
            context, 0, Intent(ACTION_USB_PERMISSION), flags
        )
        usbManager?.requestPermission(device, permissionIntent)
    }

    private fun openDevice(device: UsbDevice, result: MethodChannel.Result) {
        val manager = usbManager ?: run {
            result.error("USB_ERROR", "USB manager not available", null)
            return
        }

        // Find the HID interface
        var hidInterface: UsbInterface? = null
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            Log.d(TAG, "Interface $i: class=${iface.interfaceClass} subclass=${iface.interfaceSubclass} endpoints=${iface.endpointCount}")
            if (iface.interfaceClass == UsbConstants.USB_CLASS_HID) {
                hidInterface = iface
                break
            }
        }

        if (hidInterface == null) {
            result.error("USB_ERROR", "No HID interface found on device", null)
            return
        }

        // Find IN and OUT interrupt endpoints
        var epIn: UsbEndpoint? = null
        var epOut: UsbEndpoint? = null
        for (i in 0 until hidInterface.endpointCount) {
            val ep = hidInterface.getEndpoint(i)
            Log.d(TAG, "Endpoint $i: type=${ep.type} dir=${ep.direction} maxPkt=${ep.maxPacketSize}")
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT) {
                if (ep.direction == UsbConstants.USB_DIR_IN) {
                    epIn = ep
                } else {
                    epOut = ep
                }
            }
        }

        if (epIn == null || epOut == null) {
            result.error("USB_ERROR", "HID interface missing IN/OUT endpoints", null)
            return
        }

        val connection = manager.openDevice(device) ?: run {
            result.error("USB_ERROR", "Failed to open USB device", null)
            return
        }

        if (!connection.claimInterface(hidInterface, true)) {
            connection.close()
            result.error("USB_ERROR", "Failed to claim HID interface", null)
            return
        }

        usbDevice = device
        usbConnection = connection
        usbInterface = hidInterface
        endpointIn = epIn
        endpointOut = epOut

        Log.i(TAG, "Device opened: IN ep=${epIn.address} OUT ep=${epOut.address} maxPkt=${epIn.maxPacketSize}")

        // Small delay after claiming interface -- some devices need time to be ready.
        Thread.sleep(200)

        result.success(null)
    }

    /**
     * Close the USB connection.
     */
    private fun close(result: MethodChannel.Result) {
        closeDevice()
        result.success(null)
    }

    private fun closeDevice() {
        try {
            usbInterface?.let { usbConnection?.releaseInterface(it) }
            usbConnection?.close()
        } catch (_: Exception) {
        }
        usbDevice = null
        usbConnection = null
        usbInterface = null
        endpointIn = null
        endpointOut = null
    }

    /**
     * Write a 64-byte HID report to the device.
     * Runs on background thread to avoid blocking the UI thread.
     */
    private fun writeReport(call: MethodCall, result: MethodChannel.Result) {
        val conn = usbConnection ?: run {
            result.error("USB_NOT_CONNECTED", "Device not connected", null)
            return
        }
        val ep = endpointOut ?: run {
            result.error("USB_ERROR", "No OUT endpoint", null)
            return
        }

        val data = call.arguments as? ByteArray ?: run {
            result.error("INVALID_ARGS", "Expected byte array", null)
            return
        }

        // Ensure 64-byte report
        val report = if (data.size == REPORT_SIZE) data else {
            ByteArray(REPORT_SIZE).also { buf ->
                data.copyInto(buf, 0, 0, minOf(data.size, REPORT_SIZE))
            }
        }

        usbExecutor.execute {
            Log.d(TAG, "writeReport: ep=${ep.address} type=${ep.type} dir=${ep.direction} report=${report.size}bytes conn=$conn")
            val written = conn.bulkTransfer(ep, report, REPORT_SIZE, WRITE_TIMEOUT_MS)
            mainHandler.post {
                if (written < 0) {
                    Log.e(TAG, "writeReport: bulkTransfer returned $written (ep=${ep.address}, timeout=${WRITE_TIMEOUT_MS}ms)")
                    result.error("USB_WRITE_ERROR", "Write failed (code $written)", null)
                } else {
                    result.success(null)
                }
            }
        }
    }

    /**
     * Read a 64-byte HID report from the device.
     * Runs on background thread to avoid blocking the UI thread.
     * Blocks until data arrives or timeout (30s).
     */
    private fun readReport(result: MethodChannel.Result) {
        val conn = usbConnection ?: run {
            result.error("USB_NOT_CONNECTED", "Device not connected", null)
            return
        }
        val ep = endpointIn ?: run {
            result.error("USB_ERROR", "No IN endpoint", null)
            return
        }

        usbExecutor.execute {
            val buffer = ByteArray(REPORT_SIZE)
            val read = conn.bulkTransfer(ep, buffer, REPORT_SIZE, READ_TIMEOUT_MS)
            mainHandler.post {
                if (read < 0) {
                    Log.e(TAG, "readReport: bulkTransfer returned $read (timeout or error)")
                    result.error("USB_READ_ERROR", "Read failed or timed out (code $read)", null)
                } else if (read == 0) {
                    Log.e(TAG, "readReport: zero bytes read")
                    result.error("USB_READ_ERROR", "Read returned 0 bytes", null)
                } else if (read < REPORT_SIZE) {
                    Log.w(TAG, "readReport: short read $read bytes (expected $REPORT_SIZE)")
                    result.success(buffer)
                } else {
                    result.success(buffer)
                }
            }
        }
    }
}

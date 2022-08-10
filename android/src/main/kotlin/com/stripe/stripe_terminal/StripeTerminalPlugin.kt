package com.stripe.stripe_terminal

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import com.stripe.stripeterminal.Terminal
import com.stripe.stripeterminal.TerminalApplicationDelegate
import com.stripe.stripeterminal.external.OnReaderTips
import com.stripe.stripeterminal.external.callable.*
import com.stripe.stripeterminal.external.models.*
import com.stripe.stripeterminal.log.LogLevel
import io.flutter.app.FlutterActivityEvents
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** StripeTerminalPlugin */
class StripeTerminalPlugin : FlutterPlugin, MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener, ActivityAware, FlutterActivityEvents {

    private lateinit var channel: MethodChannel
    private var currentActivity: Activity? = null
    private val REQUEST_CODE_LOCATION = 1012
    private lateinit var tokenProvider: StripeTokenProvider
    private var cancelableDiscover: Cancelable? = null
    private var activeReaders: List<Reader> = arrayListOf()
    private var simulated = false
    private val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
        )
    } else {
        arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN,
        )
    }


    // Change this to other level soon
    private val logLevel = LogLevel.VERBOSE

    // Create your listener object. Override any methods that you want to be notified about
    val listener = object : TerminalListener {
        override fun onUnexpectedReaderDisconnect(reader: Reader) {
            // TODO: Trigger the user about the issue.
        }
    }


    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "stripe_terminal")
        channel.setMethodCallHandler(this)
    }


    fun _startStripe() {
        // Pass in the current application context, your desired logging level, your token provider, and the listener you created
        if (!Terminal.isInitialized()) {
            Terminal.initTerminal(
                currentActivity!!.applicationContext,
                logLevel,
                tokenProvider,
                listener
            )
            result?.success(true)
        }

    }

    private fun generateLog(code: String, message: String) {
        val log: HashMap<String, String> = HashMap()
        log["code"] = code
        log["message"] = message
        channel.invokeMethod("onNativeLog", log)
    }

    @OptIn(OnReaderTips::class)
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "init" -> {
                if (_isPermissionAllowed(result)) {
                    _startStripe()
                }
            }
            "clearReaderDisplay" -> {
                Terminal.getInstance().clearReaderDisplay(object :Callback{
                    override fun onFailure(e: TerminalException) {
                        return result.error(
                            "stripeTerminal#unableToClearDisplay",
                            e.errorMessage,
                            e.stackTraceToString()
                        )                    }

                    override fun onSuccess() {
                        result.success(true)
                    }
                })
            }
            "setReaderDisplay" -> {
                val arguments = call.arguments as HashMap<*, *>
                val rawReaderDisplay = arguments["readerDisplay"] as HashMap<*, *>

                val readerDisplay = ReaderDisplay.fromJson(Gson().toJson(rawReaderDisplay))
                    ?: return result.error(
                        "stripeTerminal#unableToDisplay",
                        "Invalid `readerDisplay` value provided",
                        null
                    )
                val cart = Cart.Builder(
                    currency = readerDisplay.cart.currency,
                    tax = readerDisplay.cart.tax,
                    total = readerDisplay.cart.total
                )
                cart.lineItems = readerDisplay.cart.lineItems.map {
                    CartLineItem.Builder(
                        description = it.description,
                        quantity = it.quantity,
                        amount = it.amount
                    ).build()
                }

                Terminal.getInstance().setReaderDisplay(cart.build(), object : Callback {
                    override fun onSuccess() {
                        result.success(true);
                    }

                    override fun onFailure(e: TerminalException) {
                        return result.error(
                            "stripeTerminal#unableToDisplay",
                            e.errorMessage,
                            e.stackTraceToString()
                        )
                    }
                })
            }
            "discoverReaders#start" -> {
                val arguments = call.arguments as HashMap<*, *>
                val discoverConfig = arguments["config"] as HashMap<*, *>

                generateLog(
                    "discoverReaders",
                    "Started the discover process. Simulated mode: $simulated"
                )

                val discoveryMethod =
                    StripeTerminalParser.getScanMethod(discoverConfig["discoveryMethod"] as String)
                        ?: return result.error(
                            "stripeTerminal#invalidRequest",
                            "`discoveryMethod` is not provided on discoverReaders function",
                            null
                        )

                val config = DiscoveryConfiguration(
                    isSimulated = discoverConfig["simulated"] as Boolean,
                    discoveryMethod = discoveryMethod,
                    location = discoverConfig["locationId"] as String?
                )

                cancelableDiscover =
                    Terminal.getInstance().discoverReaders(config, object : DiscoveryListener {

                        override fun onUpdateDiscoveredReaders(readers: List<Reader>) {
                            activeReaders = readers
                            val rawReaders = readers.map {
                                it.rawJson()
                            }
                            currentActivity?.runOnUiThread {
                                channel.invokeMethod("onReadersFound", rawReaders)
                                generateLog("onUpdateDiscoveredReaders", Gson().toJson(rawReaders))
                            }
                        }


                    }, object : Callback {
                        override fun onFailure(e: TerminalException) {
                            result.error(
                                "stripeTerminal#unabelToDiscover",
                                e.message,
                                e.stackTraceToString()
                            )
                        }

                        override fun onSuccess() {
                            result.success(true)
                        }
                    })
            }
            "discoverReaders#stop" -> {
                if (cancelableDiscover == null) {
                    result.error(
                        "stripeTerminal#unabelToCancelDiscover",
                        "There is no discover action running to stop.",
                        null
                    )
                } else {
                    cancelableDiscover?.cancel(object : Callback {
                        override fun onFailure(e: TerminalException) {
                            result.error(
                                "stripeTerminal#unabelToCancelDiscover",
                                "Unable to stop the discover action because ${e.errorMessage}",
                                e.stackTraceToString()
                            )
                        }

                        override fun onSuccess() {
                            result.success(true)
                        }
                    })
                    cancelableDiscover = null

                }
            }
            "fetchConnectedReader" -> {
                result.success(Terminal.getInstance().connectedReader?.rawJson())
            }
            "connectionStatus" -> {
                result.success(handleConnectionStatus(Terminal.getInstance().connectionStatus))
            }
            "connectToInternetReader" -> {
                when (Terminal.getInstance().connectionStatus) {
                    ConnectionStatus.NOT_CONNECTED -> {
                        val arguments = call.arguments as HashMap<*, *>
                        val readerSerialNumber = arguments["readerSerialNumber"] as String
                        val failIfInUse = arguments["failIfInUse"] as Boolean

                        generateLog(
                            "connectToInternetReader",
                            "Started connecting to $readerSerialNumber"
                        )

                        val reader = activeReaders.firstOrNull {
                            it.serialNumber == readerSerialNumber
                        }

                        if (reader == null) {
                            result.error(
                                "stripeTerminal#readerNotFound",
                                "Reader with provided serial number no longer exists",
                                null
                            )
                            return
                        }


                        val connectionConfig =
                            ConnectionConfiguration.InternetConnectionConfiguration(
                                failIfInUse = failIfInUse
                            )
                        Terminal.getInstance().connectInternetReader(
                            reader,
                            connectionConfig,
                            object : ReaderCallback {
                                override fun onFailure(e: TerminalException) {
                                    result.error(
                                        "stripeTerminal#unableToConnect",
                                        e.errorMessage,
                                        e.stackTraceToString()
                                    )
                                }

                                override fun onSuccess(reader: Reader) {
                                    result.success(true)
                                }

                            })
                    }
                    ConnectionStatus.CONNECTING -> {
                        result.error(
                            "stripeTerminal#deviceConnecting",
                            "A new connection is being established with a device thus you cannot request a new connection at the moment.",
                            null
                        )
                    }
                    ConnectionStatus.CONNECTED -> {
                        result.error(
                            "stripeTerminal#deviceAlreadyConnected",
                            "A device with serial number ${Terminal.getInstance().connectedReader!!.serialNumber} is already connected",
                            null
                        )
                    }
                }
            }
            "connectBluetoothReader" -> {
                when (Terminal.getInstance().connectionStatus) {
                    ConnectionStatus.NOT_CONNECTED -> {
                        val arguments = call.arguments as HashMap<*, *>
                        val readerSerialNumber = arguments["readerSerialNumber"] as String

                        generateLog(
                            "connectBluetoothReader",
                            "Started connecting to $readerSerialNumber"
                        )

                        val reader = activeReaders.firstOrNull {
                            it.serialNumber == readerSerialNumber
                        }

                        if (reader == null) {
                            result.error(
                                "stripeTerminal#readerNotFound",
                                "Reader with provided serial number no longer exists",
                                null
                            )
                            return
                        }


                        val locationId: String? = (arguments["locationId"]
                            ?: reader.location?.id) as String?

                        generateLog("connectBluetoothReader", "Location Id $locationId")

                        if (locationId == null) {
                            result.error(
                                "stripeTerminal#locationNotProvided",
                                "Either you have to provide the location id or device should be attached to a location",
                                null
                            )
                            return
                        }
                        val connectionConfig =
                            ConnectionConfiguration.BluetoothConnectionConfiguration(
                                locationId,
                            )
                        Terminal.getInstance().connectBluetoothReader(
                            reader,
                            connectionConfig,
                            object : BluetoothReaderListener {


                            },
                            object : ReaderCallback {
                                override fun onFailure(e: TerminalException) {
                                    result.error(
                                        "stripeTerminal#unableToConnect",
                                        e.errorMessage,
                                        e.stackTraceToString()
                                    )
                                }

                                override fun onSuccess(reader: Reader) {
                                    result.success(true)
                                }

                            })
                    }
                    ConnectionStatus.CONNECTING -> {
                        result.error(
                            "stripeTerminal#deviceConnecting",
                            "A new connection is being established with a device thus you cannot request a new connection at the moment.",
                            null
                        )
                    }
                    ConnectionStatus.CONNECTED -> {
                        result.error(
                            "stripeTerminal#deviceAlreadyConnected",
                            "A device with serial number ${Terminal.getInstance().connectedReader!!.serialNumber} is already connected",
                            null
                        )
                    }
                }
            }
            "readReusableCardDetail" -> {
                generateLog("readReusableCardDetail", "Started reading payment method")

                if (Terminal.getInstance().connectedReader == null) {
                    result.error(
                        "stripeTerminal#deviceNotConnected",
                        "You must connect to a device before you can use it.",
                        null
                    )
                } else {
                    val params = ReadReusableCardParameters.Builder().build()
                    Terminal.getInstance().readReusableCard(params, object : PaymentMethodCallback {
                        override fun onFailure(e: TerminalException) {
                            result.error(
                                "stripeTerminal#unableToReadCardDetail",
                                "Device was not able to read payment method details because ${e.errorMessage}",
                                e.stackTraceToString()
                            )
                        }

                        override fun onSuccess(paymentMethod: PaymentMethod) {
                            result.success(paymentMethod.rawJson())
                        }

                    })
                }
            }
            "collectPaymentMethod" -> {
                generateLog("collectPaymentMethod", "Started reading payment method")

                if (Terminal.getInstance().connectedReader == null) {
                    result.error(
                        "stripeTerminal#deviceNotConnected",
                        "You must connect to a device before you can use it.",
                        null
                    )
                } else {

                    val arguments = call.arguments as HashMap<*, *>
                    val paymentIntentClientSecret =
                        arguments["paymentIntentClientSecret"] as String?
                    if (paymentIntentClientSecret == null) {
                        result.error(
                            "stripeTerminal#invalidPaymentIntentClientSecret",
                            "The payment intent client_secret seems to be invalid or missing.",
                            null
                        )
                        return
                    }

                    val collectConfiguration =
                        arguments["collectConfiguration"] as HashMap<*, *>
                    val collectConfig =
                        CollectConfiguration(skipTipping = collectConfiguration["skipTipping"] as Boolean);
                    Terminal.getInstance()
                        .retrievePaymentIntent(
                            paymentIntentClientSecret,
                            object : PaymentIntentCallback {
                                override fun onFailure(e: TerminalException) {
                                    result.error(
                                        "stripeTerminal#unableToRetrivePaymentIntent",
                                        "Stripe was not able to fetch the payment intent with the provided client secret. ${e.errorMessage}",
                                        e.stackTraceToString()
                                    )
                                }

                                override fun onSuccess(paymentIntent: PaymentIntent) {
                                    Terminal.getInstance().collectPaymentMethod(
                                        paymentIntent,
                                        object : PaymentIntentCallback {

                                            override fun onSuccess(paymentIntent: PaymentIntent) {
                                                currentActivity?.runOnUiThread {
                                                    generateLog(
                                                        "collectPaymentMethod",
                                                        Gson().toJson(paymentIntent.rawJson())
                                                    )
                                                }
                                                Terminal.getInstance()
                                                    .processPayment(
                                                        paymentIntent,
                                                        object : PaymentIntentCallback {
                                                            override fun onSuccess(paymentIntent: PaymentIntent) {
                                                                currentActivity?.runOnUiThread {
                                                                    generateLog(
                                                                        "processPayment",
                                                                        Gson().toJson(paymentIntent.rawJson())
                                                                    )
                                                                }
                                                                result.success(paymentIntent.rawJson())
                                                            }

                                                            override fun onFailure(e: TerminalException) {
                                                                result.error(
                                                                    "stripeTerminal#unableToProcessPayment",
                                                                    "Stripe reader was not able to process the payment for the provided payment intent. ${e.errorMessage}",
                                                                    e.stackTraceToString()
                                                                )
                                                            }
                                                        })
                                            }

                                            override fun onFailure(e: TerminalException) {
                                                result.error(
                                                    "stripeTerminal#unableToCollectPaymentMethod",
                                                    "Stripe reader was not able to collect the payment method for the provided payment intent. ${e.errorMessage}",
                                                    e.stackTraceToString()
                                                )
                                            }
                                        },
                                        collectConfig,
                                    )
                                }

                            })
                }
            }
            "disconnectFromReader" -> {
                if (Terminal.getInstance().connectedReader != null) {
                    Terminal.getInstance().disconnectReader(object : Callback {
                        override fun onFailure(e: TerminalException) {
                            result.error(
                                "stripeTerminal#unableToDisconnect",
                                "Unable to disconnect from a reader because ${e.errorMessage}",
                                e.stackTraceToString()
                            )
                        }

                        override fun onSuccess() {
                            result.success(true)
                        }
                    })
                } else {
                    result.error(
                        "stripeTerminal#unableToDisconnect",
                        "No reader connected to disconnect from.",
                        null
                    )
                }
            }
            else -> result.notImplemented()
        }

    }

    var result: Result? = null
    private fun _isPermissionAllowed(result: Result): Boolean {
        val permissionStatus = permissions.map {
            ContextCompat.checkSelfPermission(currentActivity!!, it)
        }

        if (!permissionStatus.contains(PackageManager.PERMISSION_DENIED)) {
            result.success(true)
            return true
        }


        val cannotAskPermissions = permissions.map {
            ActivityCompat.shouldShowRequestPermissionRationale(currentActivity!!, it)
        }

        if (cannotAskPermissions.contains(true)) {
            result.error(
                "stripeTerminal#permissionDeclinedPermanenty",
                "You have declined the necessary permission, please allow from settings to continue.",
                null
            )
            return false
        }

        this.result = result

        ActivityCompat.requestPermissions(currentActivity!!, permissions, REQUEST_CODE_LOCATION)

        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        val permissionStatus = permissions.map {
            ContextCompat.checkSelfPermission(currentActivity!!, it)
        }
        if (!permissionStatus.contains(PackageManager.PERMISSION_DENIED)) {
            _startStripe()
        } else {
            result?.error(
                "stripeTerminal#insuffecientPermission",
                "You have not provided enough permission for the scanner to work",
                null
            )
        }
        return requestCode == REQUEST_CODE_LOCATION
    }


    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (Terminal.getInstance().connectedReader != null) {
            Terminal.getInstance().disconnectReader(object : Callback {
                override fun onFailure(e: TerminalException) {
                }

                override fun onSuccess() {
                }
            })
        }
        cancelableDiscover?.cancel(
            object : Callback {
                override fun onFailure(e: TerminalException) {
                }

                override fun onSuccess() {
                }
            }
        )
        cancelableDiscover = null
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        tokenProvider = StripeTokenProvider(currentActivity!!, channel)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        TerminalApplicationDelegate.onCreate(currentActivity!!.application)
        tokenProvider = StripeTokenProvider(currentActivity!!, channel)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        currentActivity = null
    }


    /*
     These functions are stub functions that are not relevent to the plugin but needs to be defined in order to get the few necessary callbacks
    */

    override fun onCreate(savedInstanceState: Bundle?) {
        TODO("Not yet implemented")
    }

    override fun onNewIntent(intent: Intent?) {
        TODO("Not yet implemented")
    }

    override fun onPause() {
        TODO("Not yet implemented")
    }

    override fun onStart() {
        TODO("Not yet implemented")
    }

    override fun onResume() {
        TODO("Not yet implemented")
    }

    override fun onPostResume() {
        TODO("Not yet implemented")
    }

    override fun onDestroy() {
        TODO("Not yet implemented")
    }

    override fun onStop() {
        TODO("Not yet implemented")
    }

    override fun onBackPressed(): Boolean {
        TODO("Not yet implemented")
    }

    override fun onUserLeaveHint() {
        TODO("Not yet implemented")
    }

    override fun onConfigurationChanged(p0: Configuration) {
        TODO("Not yet implemented")
    }

    override fun onLowMemory() {
        TODO("Not yet implemented")
    }

    override fun onTrimMemory(p0: Int) {
        TerminalApplicationDelegate.onTrimMemory(currentActivity!!.application, p0)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        TODO("Not yet implemented")
    }


}


fun Reader.rawJson(): HashMap<String, Any?> {
    val json = HashMap<String, Any?>()
    json["locationStatus"] = locationStatus.ordinal
    json["batteryStatus"] = handleBatteryLevel(batteryLevel)
    json["deviceType"] = handleDeviceType(deviceType)
    json["originalJSON"] = rawReaderData
    json["simulated"] = isSimulated
    json["label"] = label
    json["availableUpdate"] = availableUpdate?.hasFirmwareUpdate ?: false
    json["locationId"] = location?.id
    json["serialNumber"] = serialNumber
    return json
}

fun PaymentIntent.rawJson(): HashMap<String, Any?> {
    val json = HashMap<String, Any?>()
    json["id"] = id
    json["amount"] = amount
    json["amount_capturable"] = amountCapturable
    json["amount_received"] = amountReceived
    json["application"] = application
    json["application_fee_amount"] = applicationFeeAmount
    json["capture_method"] = captureMethod
    json["cancellation_reason"] = cancellationReason
    json["canceled_at"] = canceledAt
    json["client_secret"] = clientSecret
    json["confirmation_method"] = confirmationMethod
    json["created"] = created
    json["currency"] = currency
    json["customer"] = customer
    json["description"] = description
    json["invoice"] = invoice
    json["livemode"] = livemode
    json["metadata"] = metadata
    json["on_behalf_of"] = onBehalfOf
    json["payment_method_id"] = paymentMethodId
    json["status"] = status?.name?.lowercase()
    json["review"] = review
    json["receipt_email"] = receiptEmail
    json["transfer_group"] = transferGroup
    json["setup_future_usage"] = setupFutureUsage

    return json
}

fun handleConnectionStatus(connectionStatus: ConnectionStatus): Int {
    return when (connectionStatus) {
        ConnectionStatus.NOT_CONNECTED -> 0
        ConnectionStatus.CONNECTING -> 2
        ConnectionStatus.CONNECTED -> 1
        else -> 0
    }
}

fun handleBatteryLevel(batteryValue: Float?): Int {
    return when {
        batteryValue == null -> 0
        batteryValue <= .05 -> 1
        batteryValue <= .20 -> 2
        batteryValue > .20 -> 3
        else -> 0
    }
}

fun handleDeviceType(deviceType: DeviceType): Int {
    return when (deviceType) {
        DeviceType.CHIPPER_1X -> 5
        DeviceType.CHIPPER_2X -> 0
        DeviceType.STRIPE_M2 -> 3
        DeviceType.COTS_DEVICE -> 7
        DeviceType.VERIFONE_P400 -> 1
        DeviceType.WISECUBE -> 6
        DeviceType.WISEPAD_3 -> 7
        DeviceType.WISEPOS_E -> 4
        DeviceType.ETNA -> 7
        DeviceType.UNKNOWN -> 7
        else -> 7
    }

}

fun PaymentMethod.rawJson(): HashMap<String, Any?> {

    val json = HashMap<String, Any?>()
    json["id"] = id
    json["metadata"] = metadata
    json["billing_details"] = HashMap<Any, Any?>()
    json["object"] = "payment_method"
    json["created"] = System.currentTimeMillis() / 1000
    json["livemode"] = livemode
    json["type"] = "card"  // Not sure why there is no type object, probably M2 can only scan cards
    json["card"] = cardDetails?.rawJson()
    json["customer"] = customer
    return json

}

fun CardDetails.rawJson(): HashMap<String, Any?> {
    val json = HashMap<String, Any?>()

    json["brand"] = brand
    json["country"] = country
    json["exp_month"] = expMonth
    json["exp_year"] = expYear
    json["fingerprint"] = fingerprint
    json["funding"] = funding
    json["last4"] = last4
    return json
}
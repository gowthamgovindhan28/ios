import UIKit
import Flutter
import CoreLocation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    var locationManager: CLLocationManager?
    var methodChannel: FlutterMethodChannel?
    var locationTimer: Timer?
    var geofenceTimer: Timer?
    var geofenceRegion: CLCircularRegion?
    var lastGeofenceState: String = "unknown"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(name: "com.example.app/location", binaryMessenger: controller.binaryMessenger)

        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "startGeofencing" {
                guard let args = call.arguments as? [String: Any],
                      let lat = args["latitude"] as? CLLocationDegrees,
                      let long = args["longitude"] as? CLLocationDegrees,
                      let radius = args["radius"] as? CLLocationDistance else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters", details: nil))
                    return
                }
                self?.startGeofencing(lat: lat, long: long, radius: radius)
                result(nil)
            } else if call.method == "stopGeofencing" {
                self?.stopGeofencing()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func startGeofencing(lat: CLLocationDegrees, long: CLLocationDegrees, radius: CLLocationDistance) {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.startUpdatingLocation()

        geofenceRegion = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: long),
            radius: radius,
            identifier: "geofence_region"
        )
        geofenceRegion?.notifyOnEntry = true
        geofenceRegion?.notifyOnExit = true
        locationManager?.startMonitoring(for: geofenceRegion!)

        // Location timer every 15 minutes
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.sendCurrentLocation()
        }
        RunLoop.main.add(locationTimer!, forMode: .common)

        // Geofence timer every 15 minutes
        geofenceTimer?.invalidate()
        geofenceTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.sendGeofenceStatus()
        }
        RunLoop.main.add(geofenceTimer!, forMode: .common)
    }

    func stopGeofencing() {
        locationManager?.stopUpdatingLocation()
        for region in locationManager?.monitoredRegions ?? [] {
            locationManager?.stopMonitoring(for: region)
        }
        locationTimer?.invalidate()
        geofenceTimer?.invalidate()
        locationManager = nil
        locationTimer = nil
        geofenceTimer = nil
    }

    func sendCurrentLocation() {
        guard let loc = locationManager?.location else { return }
        let data: [String: Any] = [
            "type": "location",
            "latitude": loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "timestamp": Date().timeIntervalSince1970
        ]
        methodChannel?.invokeMethod("sendLocationUpdate", arguments: data)
    }

    func sendGeofenceStatus() {
        let data: [String: Any] = [
            "type": "geofence",
            "status": lastGeofenceState,
            "identifier": geofenceRegion?.identifier ?? "unknown",
            "timestamp": Date().timeIntervalSince1970
        ]
        methodChannel?.invokeMethod("sendGeofenceUpdate", arguments: data)
    }
}

extension AppDelegate: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Optional: for real-time, but not used in 15min logic
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        lastGeofenceState = "inside"
        let data: [String: Any] = [
            "type": "geofence_event",
            "event": "enter",
            "identifier": region.identifier,
            "timestamp": Date().timeIntervalSince1970
        ]
        methodChannel?.invokeMethod("sendGeofenceEvent", arguments: data)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        lastGeofenceState = "outside"
        let data: [String: Any] = [
            "type": "geofence_event",
            "event": "exit",
            "identifier": region.identifier,
            "timestamp": Date().timeIntervalSince1970
        ]
        methodChannel?.invokeMethod("sendGeofenceEvent", arguments: data)
    }
}

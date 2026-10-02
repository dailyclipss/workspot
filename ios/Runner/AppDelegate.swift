import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let googleMapsAPIKey = "AIzaSyBVxBSwR4qPRAW7oHdRrCZEiZ1afkPsd5I"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if googleMapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
      googleMapsAPIKey.contains("YOUR_ACTUAL")
    {
      NSLog("[GoogleMaps] WARNING: Missing or placeholder API key. Maps will not initialize correctly on iOS.")
    } else {
      NSLog("[GoogleMaps] Registering iOS API key before Flutter plugin registration.")
    }

    GMSServices.provideAPIKey(googleMapsAPIKey)
    NSLog("[GoogleMaps] GMSServices.provideAPIKey called.")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    NSLog("[GoogleMaps] Registering Flutter plugins after Google Maps API key setup.")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
import Flutter
import UIKit

import Mixpanel

@objc public class SwiftNativeMixpanelPlugin: NSObject, FlutterPlugin {

   var _deviceToken: Data? = nil
   var _getDeviceTokenClosure: ((Data?, Error?) -> Void)? = nil

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "native_mixpanel", binaryMessenger: registrar.messenger())
    let instance = SwiftNativeMixpanelPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }

  public func getPropertiesFromArguments(callArguments: Any?) throws -> Properties? {

    if let arguments = callArguments, let data = (arguments as! String).data(using: .utf8) {

      let properties = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
      var argProperties = [String: String]()
      for (key, value) in properties {
        argProperties[key] = String(describing: value)
      }
      return argProperties;
    }

    return nil;
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)  {

  if call.method == "requestNotificationsPermission" {
      let arguments = call.arguments as! [String: Any]
      if #available(iOS 10.0, *) {
          let center = UNUserNotificationCenter.current()
          var options: UNAuthorizationOptions = []
          if let sound = arguments["sound"] as? Bool, sound {
              options.insert(.sound)
          }
          if let alert = arguments["alert"] as? Bool, alert {
              options.insert(.alert)
          }
          if let badge = arguments["badge"] as? Bool, badge {
              options.insert(.badge)
          }
          center.requestAuthorization(options: options) { (_, error) in
              guard error == nil else {
                  result("Request is failed")
                  return
              }
              UIApplication.shared.registerForRemoteNotifications()
              result("Request is successful")
          }
      } else {
          var types: UIUserNotificationType = []
          if let sound = arguments["sound"] as? Bool, sound {
              types.insert(.sound)
          }
          if let alert = arguments["alert"] as? Bool, alert {
              types.insert(.alert)
          }
          if let badge = arguments["badge"] as? Bool, badge {
              types.insert(.badge)
          }
          let settings = UIUserNotificationSettings(types: types, categories: nil)
          UIApplication.shared.registerUserNotificationSettings(settings)
          UIApplication.shared.registerForRemoteNotifications()
          result("Request is successful")
      }
  } else if call.method == "getDeviceToken" {
      if let deviceToken = _deviceToken {
          result(deviceToken)
      } else {
          _getDeviceTokenClosure = { deviceToken, error in
              guard let deviceToken = deviceToken, error == nil else {
                  result(error.debugDescription)
                  return
              }
              result(deviceToken)
          }
      }
  }

    do {
      if (call.method == "initialize") {
        Mixpanel.initialize(token: call.arguments as! String)
      } else if(call.method == "identify") {
        Mixpanel.mainInstance().identify(distinctId: call.arguments as! String)
      } else if(call.method == "alias") {
        Mixpanel.mainInstance().createAlias(call.arguments as! String, distinctId: Mixpanel.mainInstance().distinctId)
      } else if(call.method == "aliasNull") {
        Mixpanel.mainInstance().createAlias(call.arguments as! String, distinctId: Mixpanel.mainInstance().distinctId)
        Mixpanel.mainInstance().identify(distinctId: Mixpanel.mainInstance().distinctId)
      } else if(call.method == "setPeopleProperties") {
            if let arguments = call.arguments, let data = (arguments as! String).data(using: .utf8) {
                let properties = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
                var argProperties = [String: String]()
                for (key, value) in properties {
                    argProperties[key] = String(describing: value)
                    if let content = argProperties[key] {
                         Mixpanel.mainInstance().people?.set(property:key ,to:content)
                    }
                }
            }
      } else if(call.method == "registerSuperProperties") {
        if let argProperties = try self.getPropertiesFromArguments(callArguments: call.arguments) {
          Mixpanel.mainInstance().registerSuperProperties(argProperties)
        } else {
          result(FlutterError(code: "Parse Error", message: "Could not parse arguments for registerSuperProperties platform call. Needs valid JSON data.", details: nil))
        }
      } else if(call.method == "reset") {
        Mixpanel.mainInstance().reset()
      } else if(call.method == "getDistinctId") {
        result(Mixpanel.mainInstance().distinctId)
      } else if(call.method == "flush") {
        Mixpanel.mainInstance().flush()
      } else if let argProperties = try self.getPropertiesFromArguments(callArguments: call.arguments) {
        Mixpanel.mainInstance().track(event: call.method, properties: argProperties)
      } else {
        Mixpanel.mainInstance().track(event: call.method)
      }

      result(true)
    } catch {
      print(error.localizedDescription)
      result(false)
    }
  }
}

extension SwiftNativeMixpanelPlugin: UIApplicationDelegate {
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
           Mixpanel.mainInstance().people.addPushDeviceToken(deviceToken)
         }
          _deviceToken = deviceToken
          _getDeviceTokenClosure?(deviceToken, nil)
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
          _getDeviceTokenClosure?(nil, error)
    }
}


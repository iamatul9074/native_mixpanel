import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;

abstract class _Mixpanel {

  Future track(String eventName, [dynamic props]);
}

class _MixpanelOptedOut extends _Mixpanel {

  Future track(String eventName, [dynamic props]) {
    // nothing to do when opted out
    return Future.value();
  }
}

class _MixpanelOptedIn extends _Mixpanel {
  final MethodChannel channel = const MethodChannel('native_mixpanel');

  Future track(String eventName, [dynamic props]) async {
    return await channel.invokeMethod(eventName, props);
  }
}

class _MixpanelDebugged extends _Mixpanel {

  final _Mixpanel child;

  _MixpanelDebugged({this.child});

  Future track(String eventName, [dynamic props]) async {
    String msg = """
    Sending event: $eventName with properties: $props
    """;
    debugPrint(msg);

    return await this.child.track(eventName, props);
  }  
}

class Mixpanel extends _Mixpanel {
  final MethodChannel channel = const MethodChannel('native_mixpanel');
  final bool shouldLogEvents;
  final bool isOptedOut;

  _Mixpanel _mp;

  Mixpanel({
    this.shouldLogEvents,
    this.isOptedOut,
  }) {

    _Mixpanel _mixpanel = isOptedOut ? _MixpanelOptedOut() : _MixpanelOptedIn();

    if (shouldLogEvents) _mp = _MixpanelDebugged(child: _mixpanel);
    else _mp = _mixpanel;
  }

  Future<dynamic> getDeviceToken() {
    if (Platform.isIOS) {
      return channel.invokeMethod('getDeviceToken');
    } else {
      return Future<String>.value("The function is only support iOS");
    }
  }

  Future<dynamic> requestNotificationsPermission({bool sound, bool badge, bool alert}) {
    if (Platform.isIOS) {
      return channel.invokeMethod('requestNotificationsPermission', {
        'sound': sound,
        'badge': badge,
        'alert': alert
      });
    } else {
      return Future<String>.value("The function is only support iOS");
    }
  }

  Future initialize(String token) {
    return this._mp.track('initialize', token);
  }

  Future identify(String distinctId) {
    return this._mp.track('identify', distinctId);
  }

  Future pushToken() {
    return this._mp.track('pushToken');
  }

  Future alias(String alias) {
    return this._mp.track('alias', alias);
  }

  Future setPeopleProperties(Map<String, dynamic> props) {
    return this._mp.track('setPeopleProperties', jsonEncode(props));
  }

  Future registerSuperProperties(Map<String, dynamic> props) {
    return this._mp.track('registerSuperProperties', jsonEncode(props));
  }

  Future reset() {
    return this._mp.track('reset');
  }

  Future flush() {
    return this._mp.track('flush');
  }

  Future track(String eventName, [dynamic props]) {
    return this._mp.track(eventName, jsonEncode(props));
  }
}

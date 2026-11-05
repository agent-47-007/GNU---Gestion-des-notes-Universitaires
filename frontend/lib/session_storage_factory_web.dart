import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_storage.dart';

SessionStorage createSessionStorage() {
  final uri = Uri.base;
  if (uri.scheme == 'http' && _isPrivateLanAddress(uri.host)) {
    // LAN HTTP is only for local device testing; browsers disable WebCrypto there.
    return LanTestSessionStorage();
  }

  return SecureWebSessionStorage();
}

bool _isPrivateLanAddress(String host) {
  final octets = host.split('.').map(int.tryParse).toList();
  if (octets.length != 4 || octets.any((octet) => octet == null)) {
    return false;
  }

  final first = octets[0]!;
  final second = octets[1]!;

  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

class LanTestSessionStorage implements SessionStorage {
  static const _prefix = 'gnu.lan-test.';

  JSObject get _localStorage => globalContext
      .getProperty<JSObject?>('window'.toJS)!
      .getProperty<JSObject?>('localStorage'.toJS)!;

  @override
  Future<String?> read(String key) async => _localStorage
      .callMethod<JSString?>('getItem'.toJS, '$_prefix$key'.toJS)
      ?.toDart;

  @override
  Future<void> write(String key, String value) async {
    _localStorage.callMethod<JSAny?>(
      'setItem'.toJS,
      '$_prefix$key'.toJS,
      value.toJS,
    );
  }

  @override
  Future<void> delete(String key) async {
    _localStorage.callMethod<JSAny?>('removeItem'.toJS, '$_prefix$key'.toJS);
  }
}

class SecureWebSessionStorage implements SessionStorage {
  SecureWebSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

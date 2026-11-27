import Flutter
import UIKit
import CommonCrypto
import Security

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "olib/weread_private", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(FlutterError(code: "UNAVAILABLE", message: nil, details: nil)); return }
        self.handlePrivateCall(call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var keychainQuery: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "olib.weread.mobile",
     kSecAttrAccount as String: "session"]
  }

  private func handlePrivateCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: String] ?? [:]
    switch call.method {
    case "read":
      var query = keychainQuery
      query[kSecReturnData as String] = true
      query[kSecMatchLimit as String] = kSecMatchLimitOne
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      if status == errSecItemNotFound { result(nil); return }
      guard status == errSecSuccess, let data = item as? Data,
            let value = String(data: data, encoding: .utf8) else {
        result(FlutterError(code: "WEREAD_PRIVATE_ERROR", message: "Keychain read failed", details: nil)); return
      }
      result(value)
    case "write":
      guard let value = arguments["value"] else { result(FlutterError(code: "INVALID_ARGUMENT", message: nil, details: nil)); return }
      SecItemDelete(keychainQuery as CFDictionary)
      var query = keychainQuery
      query[kSecValueData as String] = Data(value.utf8)
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let status = SecItemAdd(query as CFDictionary, nil)
      result(status == errSecSuccess ? nil : FlutterError(code: "WEREAD_PRIVATE_ERROR", message: "Keychain write failed", details: nil))
    case "delete":
      let status = SecItemDelete(keychainQuery as CFDictionary)
      result(status == errSecSuccess || status == errSecItemNotFound ? nil : FlutterError(code: "WEREAD_PRIVATE_ERROR", message: "Keychain delete failed", details: nil))
    case "sha1", "sha256":
      guard let value = arguments["value"] else { result(FlutterError(code: "INVALID_ARGUMENT", message: nil, details: nil)); return }
      let bytes = Array(value.utf8)
      var digest = [UInt8](repeating: 0, count: call.method == "sha1" ? Int(CC_SHA1_DIGEST_LENGTH) : Int(CC_SHA256_DIGEST_LENGTH))
      bytes.withUnsafeBytes { pointer in
        if call.method == "sha1" { _ = CC_SHA1(pointer.baseAddress, CC_LONG(bytes.count), &digest) }
        else { _ = CC_SHA256(pointer.baseAddress, CC_LONG(bytes.count), &digest) }
      }
      result(digest.map { String(format: "%02x", $0) }.joined())
    case "hmacSha1":
      guard let key = arguments["key"], let value = arguments["value"] else { result(FlutterError(code: "INVALID_ARGUMENT", message: nil, details: nil)); return }
      let keyBytes = Array(key.utf8)
      let valueBytes = Array(value.utf8)
      var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
      keyBytes.withUnsafeBytes { keyPointer in
        valueBytes.withUnsafeBytes { valuePointer in
          CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyPointer.baseAddress, keyBytes.count,
                 valuePointer.baseAddress, valueBytes.count, &digest)
        }
      }
      result(digest.map { String(format: "%02x", $0) }.joined())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

import Flutter
import UIKit
import CryptoKit
import UniformTypeIdentifiers
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let backupFiles = BackupFiles()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "app.familyvault/backup-files", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler(backupFiles.handle)
    let drive = FlutterMethodChannel(name: "app.familyvault/drive", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    drive.setMethodCallHandler { call, reply in
      guard call.method == "configured" else { reply(FlutterMethodNotImplemented); return }
      reply(Self.hasDriveConfiguration)
    }
    let reminders = FlutterMethodChannel(name: "app.familyvault/document-reminders", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    reminders.setMethodCallHandler(DocumentReminders.handle)
  }

  private static var hasDriveConfiguration: Bool {
    guard let client = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
      client.range(of: "^[0-9]+-[A-Za-z0-9_-]+\\.apps\\.googleusercontent\\.com$", options: .regularExpression) != nil,
      let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
    else { return false }
    let reversed = client.split(separator: ".").reversed().joined(separator: ".")
    return types.contains { ($0["CFBundleURLSchemes"] as? [String])?.contains(reversed) == true }
  }
}

private final class BackupFiles: NSObject, UIDocumentPickerDelegate {
  private struct Request {
    let source: URL
    let length: Int64
    let reply: FlutterResult
  }
  private var pending: Request?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil,
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      let size = args["bytes"] as? NSNumber,
      size.int64Value > 0,
      let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { result(unavailable); return }

    let file = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    let backupRoot = support.appendingPathComponent("backups", isDirectory: true).resolvingSymlinksInPath()
    guard file.deletingLastPathComponent().path == backupRoot.path,
      file.lastPathComponent.range(of: "^[a-f0-9-]{36}\\.fvbackup$", options: .regularExpression) != nil,
      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
      var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else { result(unavailable); return }
    while let presented = presenter.presentedViewController { presenter = presented }
    pending = Request(source: file, length: size.int64Value, reply: result)
    // A selected directory grants readback access to the copy in its provider.
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?.reply(nil)
    pending = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let request = pending else { return }
    guard let folder = urls.first else { documentPickerWasCancelled(controller); return }
    DispatchQueue.global(qos: .userInitiated).async {
      let receipt = try? self.copy(request, to: folder)
      DispatchQueue.main.async {
        self.pending = nil
        if let receipt = receipt { request.reply(receipt) } else { request.reply(self.unavailable) }
      }
    }
  }

  private var unavailable: FlutterError {
    FlutterError(code: "copy_failed", message: "Could not verify the selected backup copy.", details: nil)
  }

  private func copy(_ request: Request, to folder: URL) throws -> [String: Any] {
    guard folder.startAccessingSecurityScopedResource() else { throw CocoaError(.fileNoSuchFile) }
    defer { folder.stopAccessingSecurityScopedResource() }
    var failure: NSError?
    var result: [String: Any]?
    NSFileCoordinator().coordinate(writingItemAt: folder, options: [], error: &failure) { selected in
      let file = selected.appendingPathComponent(request.source.lastPathComponent)
      do {
        try FileManager.default.copyItem(at: request.source, to: file)
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var length: Int64 = 0
        var digest = SHA256()
        while let bytes = try handle.read(upToCount: 64 * 1024), !bytes.isEmpty {
          length += Int64(bytes.count)
          guard length <= request.length else { throw CocoaError(.fileReadCorruptFile) }
          digest.update(data: bytes)
        }
        guard length == request.length else { throw CocoaError(.fileReadCorruptFile) }
        result = ["bytes": length, "digest": digest.finalize().map { String(format: "%02x", $0) }.joined()]
      } catch {
        result = nil
      }
    }
    guard failure == nil, let result = result else { throw CocoaError(.fileReadCorruptFile) }
    return result
  }
}

private enum DocumentReminders {
  private static let prefix = "familyvault.document-"
  private static let identifiers = (0..<32).map { prefix + String($0) }

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "allowed", "request":
      Task { @MainActor in
        do {
          let settings = await center.notificationSettings()
          if call.method == "request" && settings.authorizationStatus == .notDetermined {
            result(try await center.requestAuthorization(options: [.alert]))
          } else {
            let status = settings.authorizationStatus
            result(status == .authorized || status == .provisional || status == .ephemeral)
          }
        } catch {
          result(failure)
        }
      }
    case "replace":
      guard let options = call.arguments as? [String: Any],
            let values = options["times"] as? [NSNumber], values.count <= identifiers.count
      else { result(failure); return }
      let hindi = options["language"] as? String == "hi"
      Task { @MainActor in
        do {
          center.removePendingNotificationRequests(withIdentifiers: identifiers)
          let now = Date().timeIntervalSince1970
          let dates = Array(Set(values.map { $0.doubleValue / 1000 }.filter { $0 > now })).sorted()
          if dates.isEmpty { center.removeDeliveredNotifications(withIdentifiers: identifiers) }
          for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "FamilyVault"
            content.body = hindi
              ? "दस्तावेज़ों की मियाद देखने के लिए FamilyVault खोलें।"
              : "Open your vault to review document dates."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date - now), repeats: false)
            try await center.add(UNNotificationRequest(identifier: identifiers[index], content: content, trigger: trigger))
          }
          result(nil)
        } catch {
          center.removePendingNotificationRequests(withIdentifiers: identifiers)
          result(failure)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static var failure: FlutterError {
    FlutterError(code: "reminder_failed", message: "Could not update document reminders.", details: nil)
  }
}

import Flutter
import UIKit
import PhotosUI
import BackgroundTasks
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PHPickerViewControllerDelegate {
    private let io = DispatchQueue(label: "org.viewq.storage")
    private let ocr = OcrQueue()
    private var store: LibraryStore?
    private var pickerReply: FlutterResult?
    private var channel: FlutterMethodChannel?

    override func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: OcrQueue.taskID, using: nil) { [weak self] task in
            guard let self = self else { task.setTaskCompleted(success: false); return }
            task.expirationHandler = { self.ocr.stop() }
            self.io.async {
                do { let store = try self.getStore(); self.ocr.run(store: store) { task.setTaskCompleted(success: $0) } }
                catch { task.setTaskCompleted(success: false) }
            }
        }
        NotificationCenter.default.addObserver(forName: UIScene.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.ocr.stop(); self?.ocr.schedule()
        }
        return super.application(application, didFinishLaunchingWithOptions: options)
    }
    // Only accessed on the serial storage queue.
    private func getStore() throws -> LibraryStore {
        if let store = store { return store }
        let next = try LibraryStore(); store = next; return next
    }
    func didInitializeImplicitFlutterEngine(_ bridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: bridge.pluginRegistry)
        let channel = FlutterMethodChannel(name: "org.viewq/library", binaryMessenger: bridge.applicationRegistrar.messenger())
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, reply in
            guard let self = self else { return }
            if call.method == "pick" { self.pick(reply); return }
            if call.method == "openLink" {
                let args = call.arguments as? [String: String] ?? [:]
                guard let url = URL(string: args["url"] ?? ""),
                      ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                      let host = url.host, !host.isEmpty else {
                    reply(FlutterError(code: "link", message: "Could not open link.", details: nil)); return
                }
                UIApplication.shared.open(url) { opened in
                    if opened { reply(nil) }
                    else { reply(FlutterError(code: "link", message: "Could not open link.", details: nil)) }
                }
                return
            }
            if call.method == "shareScreenshot" {
                let args = call.arguments as? [String: String] ?? [:]
                self.io.async {
                    do {
                        let images = try self.getStore().images.resolvingSymlinksInPath()
                        let image = URL(fileURLWithPath: args["path"] ?? "").resolvingSymlinksInPath()
                        let ext = args["extension"] ?? ""
                        guard image.deletingLastPathComponent().path == images.path,
                              ["png", "jpg", "gif", "webp", "heic", "img"].contains(ext) else {
                            throw ViewQError.message("Invalid screenshot.")
                        }
                        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("View-Q-share-" + UUID().uuidString)
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        let copy = folder.appendingPathComponent("View-Q-screenshot." + ext)
                        try FileManager.default.copyItem(at: image, to: copy)
                        DispatchQueue.main.async {
                            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                                  let presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                                try? FileManager.default.removeItem(at: folder)
                                reply(FlutterError(code: "share", message: "Could not share screenshot.", details: nil)); return
                            }
                            let sheet = UIActivityViewController(activityItems: [copy], applicationActivities: nil)
                            sheet.popoverPresentationController?.sourceView = presenter.view
                            sheet.popoverPresentationController?.sourceRect = presenter.view.bounds
                            sheet.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: folder) }
                            presenter.present(sheet, animated: true) { reply(nil) }
                        }
                    } catch {
                        DispatchQueue.main.async { reply(FlutterError(code: "share", message: "Could not share screenshot.", details: nil)) }
                    }
                }
                return
            }
            self.io.async {
                do {
                    let store = try self.getStore()
                    let args = call.arguments as? [String: Any] ?? [:]
                    var value: Any?
                    switch call.method {
                    case "list": value = try store.list(args["query"] as? String ?? "")
                    case "previews": value = try store.list(args["query"] as? String ?? "", previews: true)
                    case "screenshot": value = try store.list("", screenshotID: args["id"] as? String ?? "").first
                    case "setCategory":
                        let id = args["id"] as? String ?? ""
                        try store.setCategory(id, category: args["category"] as? String ?? "")
                        value = try store.list("", screenshotID: id).first
                    case "correctText":
                        let id = args["id"] as? String ?? ""
                        try store.correctText(id, text: args["text"] as? String ?? "")
                        value = try store.list("", screenshotID: id).first
                    case "indexStatus": value = try store.indexStatus()
                    case "themeMode":
                        if let dark = args["dark"] as? Bool { UserDefaults.standard.set(dark, forKey: "darkTheme") }
                        value = UserDefaults.standard.object(forKey: "darkTheme") as? Bool ?? true
                    case "favorites": value = UserDefaults.standard.stringArray(forKey: "favorites") ?? []
                    case "searchHistory", "recordSearchOpen":
                        let history = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
                        if call.method == "recordSearchOpen", let id = args["id"] as? String {
                            let updated = Array(([id] + history.filter { $0 != id }).prefix(50))
                            UserDefaults.standard.set(updated, forKey: "searchHistory")
                            value = updated
                        } else {
                            value = history
                        }
                    case "toggleFavorite":
                        guard let id = args["id"] as? String else { break }
                        var ids = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
                        if ids.remove(id) == nil { ids.insert(id) }
                        let updated = Array(ids)
                        UserDefaults.standard.set(updated, forKey: "favorites")
                        value = updated
                    case "resume": try store.importInbox(); self.ocr.run(store: store); self.ocr.schedule()
                    case "retry": try store.retry(args["id"] as? String ?? ""); self.ocr.run(store: store); self.ocr.schedule()
                    case "delete": try store.delete(args["id"] as? String ?? "")
                    default: DispatchQueue.main.async { reply(FlutterMethodNotImplemented) }; return
                    }
                    DispatchQueue.main.async { reply(value) }
                } catch { DispatchQueue.main.async { reply(FlutterError(code: "storage", message: error.localizedDescription, details: nil)) } }
            }
        }
    }
    private func pick(_ reply: @escaping FlutterResult) {
        guard pickerReply == nil else { reply(FlutterError(code: "busy",message: "The photo picker is already open.",details: nil)); return }
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            reply(FlutterError(code: "picker", message: "Could not open the photo picker.",details: nil)); return
        }
        pickerReply = reply
        var config = PHPickerConfiguration()
        config.filter = .images; config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let reply = pickerReply; pickerReply = nil
        guard let provider = results.first?.itemProvider else { reply?(false); return }
        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
            do {
                guard let url = url, error == nil else { throw ViewQError.message("Could not open that image. Please try again.") }
                try SharedInbox.save(url)
                self.io.async {
                    do {
                        let store = try self.getStore(); try store.importInbox()
                        self.ocr.run(store: store); self.ocr.schedule()
                        DispatchQueue.main.async { reply?(true) }
                    } catch { DispatchQueue.main.async { reply?(FlutterError(code:"save",message:"Image copied, but the library could not open. Reopen View Q to finish saving.",details:nil)) } }
                }
            } catch { DispatchQueue.main.async { reply?(FlutterError(code:"save",message:error.localizedDescription,details:nil)) } }
        }
    }
}

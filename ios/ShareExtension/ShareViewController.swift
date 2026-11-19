import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let done = UIButton(type: .system)
    private var started = false
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
        status.font = .preferredFont(forTextStyle: .title2)
        status.adjustsFontForContentSizeCategory = true
        status.numberOfLines = 0
        status.textColor = .label
        status.text = "Saving screenshot…"
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        done.titleLabel?.adjustsFontForContentSizeCategory = true
        done.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        done.addTarget(self, action: #selector(close), for: .touchUpInside)
        done.isEnabled = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView(arrangedSubviews: [status,done])
        stack.axis = .vertical; stack.spacing = 28; stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }; started = true
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        saveNext(providers, index: 0, saved: 0, failures: 0)
    }
    // Serial providers bound memory and avoid abandoning still-running copies.
    private func saveNext(_ providers: [NSItemProvider], index: Int, saved: Int, failures: Int) {
        guard index < providers.count else {
            DispatchQueue.main.async {
                self.status.text = failures == 0 && saved > 0 ? (saved == 1 ? "Screenshot saved" : "Screenshots saved") :
                    "\(saved) saved. Could not save \(max(1,failures)) image(s). Please share them again."
                self.done.isEnabled = true
                UIAccessibility.post(notification: .announcement, argument: self.status.text)
            }
            return
        }
        providers[index].loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
            var success = false
            if let url = url, error == nil { do { try SharedInbox.save(url); success = true } catch { } }
            self.saveNext(providers, index: index + 1, saved: saved + (success ? 1 : 0), failures: failures + (success ? 0 : 1))
        }
    }
    @objc private func close() { extensionContext?.completeRequest(returningItems: nil) }
}

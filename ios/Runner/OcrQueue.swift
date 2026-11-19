import Foundation
import UIKit
import ImageIO
import libtesseract
import BackgroundTasks

final class OcrQueue {
    static let taskID = "org.viewq.viewQ.ocr"
    private let queue = DispatchQueue(label: "org.viewq.ocr", qos: .utility)
    private let stateLock = NSLock()
    private var shouldStop = false
    func stop() { stateLock.lock(); shouldStop = true; stateLock.unlock() }
    private var stopped: Bool { stateLock.lock(); defer { stateLock.unlock() }; return shouldStop }
    func schedule() {
        let request = BGProcessingTaskRequest(identifier: Self.taskID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }
    func run(store: LibraryStore, completion: @escaping (Bool) -> Void = { _ in }) {
        stateLock.lock(); shouldStop = false; stateLock.unlock()
        queue.async {
            do {
                try store.importInbox()
                while !self.stopped, let (id,url,generation) = try store.pending() {
                    try autoreleasepool {
                        do {
                            guard let source = CGImageSourceCreateWithURL(url as CFURL,[kCGImageSourceShouldCache: false] as CFDictionary),
                                  let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString: Any],
                                  let width = properties[kCGImagePropertyPixelWidth] as? Double,
                                  let height = properties[kCGImagePropertyPixelHeight] as? Double else { throw ViewQError.message("Cannot decode image") }
                            let factor = min(1, min(4096/max(width,height),sqrt(4_000_000/(width*height))))
                            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways:true,
                                kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:Int(max(width,height)*factor)]
                            guard let image = CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else { throw ViewQError.message("Cannot decode image") }
                            // Native resources include tessdata/eng.traineddata; no runtime download.
                            let text = try self.recognize(UIImage(cgImage: image))
                            try store.finish(id,text: text,failed: false,generation: generation)
                        } catch { try store.finish(id,text: nil,failed: true,generation: generation) }
                    }
                }
                completion(true)
            } catch { completion(false) }
        }
    }

    // Use the C API directly: initialization failure must be recoverable, not a fatalError.
    private func recognize(_ image: UIImage) throws -> String {
        guard let model = Bundle.main.url(forResource: "eng", withExtension: "traineddata", subdirectory: "tessdata"),
              let api = TessBaseAPICreate() else { throw ViewQError.message("English OCR data is unavailable.") }
        defer { TessBaseAPIEnd(api); TessBaseAPIDelete(api) }
        guard TessBaseAPIInit2(api,model.deletingLastPathComponent().path,"eng",OEM_LSTM_ONLY) == 0,
              let bytes = image.pngData() else { throw ViewQError.message("Could not prepare text recognition.") }
        var pix = bytes.withUnsafeBytes { buffer in
            pixReadMem(buffer.bindMemory(to: UInt8.self).baseAddress, bytes.count)
        }
        guard pix != nil else { throw ViewQError.message("Could not read image.") }
        defer { pixDestroy(&pix) }
        TessBaseAPISetPageSegMode(api,PSM_SPARSE_TEXT)
        TessBaseAPISetImage2(api,pix)
        guard let result = TessBaseAPIGetUTF8Text(api) else { throw ViewQError.message("Text recognition failed.") }
        defer { TessDeleteText(result) }
        return String(cString: result).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

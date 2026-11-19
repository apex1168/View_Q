import XCTest
import UIKit
@testable import Runner

final class RunnerTests: XCTestCase {
    private var store: LibraryStore!
    private var sandbox: URL!
    private var inbox: URL!
    override func setUpWithError() throws {
        sandbox = FileManager.default.temporaryDirectory.appendingPathComponent("ViewQTests-" + UUID().uuidString)
        inbox = sandbox.appendingPathComponent("Inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        store = try LibraryStore(rootOverride: sandbox.appendingPathComponent("Library"), inboxOverride: inbox)
    }
    override func tearDownWithError() throws {
        store = nil
        try FileManager.default.removeItem(at: sandbox)
    }
    private func saveImage() throws -> (String, URL) {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40,height: 40)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x:0,y:0,width:40,height:40))
        }
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try XCTUnwrap(image.pngData()).write(to: source)
        try FileManager.default.copyItem(at: source, to: inbox.appendingPathComponent(UUID().uuidString + ".img"))
        try store.importInbox()
        try FileManager.default.removeItem(at: source)
        let job = try XCTUnwrap(store.pending())
        return (job.0, job.1)
    }
    func testSavedCopyAndQueueSurviveReopen() throws {
        let (id,url) = try saveImage()
        store = nil
        store = try LibraryStore(rootOverride: sandbox.appendingPathComponent("Library"), inboxOverride: inbox)
        XCTAssertTrue(FileManager.default.fileExists(atPath:url.path))
        XCTAssertEqual(try store.pending()?.0,id)
    }
    func testSearchAndDeleteWithLateOCR() throws {
        let (id,url) = try saveImage()
        try store.finish(id,text:"Train ticket: London, platform 7.",failed:false,generation:0)
        XCTAssertEqual(try store.list("TRAIN, ticket!").count,1)
        XCTAssertTrue(try store.list("tickets").isEmpty)
        XCTAssertTrue(try store.list("!!!").isEmpty)
        try store.delete(id)
        try store.finish(id,text:"Train ticket",failed:false,generation:0)
        XCTAssertTrue(try store.list("train").isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath:url.path))
    }
    func testFailureAndRetryRetainImage() throws {
        let (id,url) = try saveImage()
        try store.finish(id,text:nil,failed:true,generation:0)
        XCTAssertEqual(try store.list("").first?["status"] as? String,"failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath:url.path))
        try store.retry(id)
        XCTAssertEqual(try store.pending()?.0,id)
    }
}

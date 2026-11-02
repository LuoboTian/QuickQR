import AppKit
import Vision

var checks = 0
func require(_ condition: Bool, _ message: String) {
    checks += 1
    if !condition { fatalError(message) }
}
for value: String? in [nil, "", " \n\t", String(repeating: "x", count: 2001), String(repeating: "中", count: 667)] {
    do { _ = try QRCode.make(value); fatalError("Expected input rejection") } catch { checks += 1 }
}
for value in ["https://example.com/path?a=1&b=two#section", "https://example.com/%E4%B8%AD?q=a+b", "  text with spaces\n", "你好 QuickQR 👋", String(repeating: "a", count: 2000), "https://example.com/?q=" + String(repeating: "a", count: 1500)] {
    let qr = try QRCode.make(value)
    require(qr.width == qr.height, "Image must be square")
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    try VNImageRequestHandler(cgImage: qr).perform([request])
    require(request.results?.first?.payloadStringValue == value, "Round-trip mismatch")
}
print("PASS: \(checks) checks, including 6 Vision decode round-trips")

let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: scratch) }
let file = scratch.appendingPathComponent("favorites.json")
let library = try QRLibrary(file: file)
for n in 0..<12 { library.generated("item-\(n)") }
require(library.recent.count == 10 && library.recent.first == "item-11", "Recent limit/order")
library.generated("item-5")
require(library.recent.count == 10 && library.recent.first == "item-5", "Recent dedup")
require(!FileManager.default.fileExists(atPath: file.path), "Recent must not persist")
try library.save(name: "Example", text: "https://example.com/?token=fake-test")
let reloaded = try QRLibrary(file: file)
require(reloaded.recent.isEmpty, "New process history must be empty")
require(reloaded.favorites.first?.text == "https://example.com/?token=fake-test", "Favorite exact persistence")
library.clearRecent()
require(library.recent.isEmpty && library.favorites.count == 1, "Clear only recent")
try reloaded.delete(reloaded.favorites[0].id)
let afterDelete = try QRLibrary(file: file)
require(afterDelete.favorites.isEmpty, "Delete persisted")
try Data("invalid json".utf8).write(to: file)
do { _ = try QRLibrary(file: file); fatalError("Corrupt data must not be overwritten") } catch { checks += 1 }
print("PASS: \(checks) total checks including library persistence and recent lifetime")

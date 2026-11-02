import AppKit
import CoreImage

struct QRFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct QRCode {
    // Conservative bound for byte-mode QR at M correction; never truncate input.
    static let maxBytes = 2000
    static func make(_ text: String?) throws -> CGImage {
        guard let text else { throw QRFailure(message: "没有可用的文本。请选中文字，或复制文本后使用剪贴板入口。") }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw QRFailure(message: "内容为空。请选择或复制需要生成二维码的文本。")
        }
        let data = Data(text.utf8)
        guard data.count <= maxBytes else { throw QRFailure(message: "文本过长（最多 2000 个 UTF-8 字节）。请缩短后再试，内容不会被截断。") }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { throw QRFailure(message: "系统二维码生成器不可用。") }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage,
              let modules = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(output, from: output.extent) else {
            throw QRFailure(message: "无法编码这段文本，请缩短后再试。")
        }
        // Four modules of quiet zone, integer pixel scaling, opaque white background.
        let scale = max(1, 300 / (modules.width + 8))
        let side = (modules.width + 8) * scale
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw QRFailure(message: "无法创建二维码图像。")
        }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        ctx.interpolationQuality = .none
        ctx.draw(modules, in: CGRect(x: 4 * scale, y: 4 * scale, width: modules.width * scale, height: modules.height * scale))
        return ctx.makeImage()!
    }
}

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

struct QRCode {
    func exportSVG(url: String) throws -> String {
        let data = Data(url.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let image = filter.outputImage else {
            throw QRCodeError.generationFailed
        }

        let context = CIContext(options: [.useSoftwareRenderer: true])
        let extent = image.extent.integral

        guard let cgImage = context.createCGImage(image, from: extent) else {
            throw QRCodeError.rasterizationFailed
        }

        let modules = try moduleMatrix(from: cgImage)
        return svg(from: modules, moduleSize: 8, quietZone: 4)
    }

    private func moduleMatrix(from image: CGImage) throws -> [[Bool]] {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw QRCodeError.rasterizationFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rows: [[Bool]] = Array(
            repeating: Array(repeating: false, count: width),
            count: height
        )

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let red = pixels[offset]
                let green = pixels[offset + 1]
                let blue = pixels[offset + 2]
                let alpha = pixels[offset + 3]

                let isDark = alpha > 0 && red < 128 && green < 128 && blue < 128
                rows[y][x] = isDark
            }
        }

        return rows
    }

    private func svg(from modules: [[Bool]], moduleSize: Int, quietZone: Int) -> String {
        let height = modules.count
        let width = modules.first?.count ?? 0
        let totalWidth = (width + quietZone * 2) * moduleSize
        let totalHeight = (height + quietZone * 2) * moduleSize

        var rects: [String] = []

        for (y, row) in modules.enumerated() {
            var runStart: Int?

            for x in 0...row.count {
                let isDark = x < row.count ? row[x] : false

                if isDark && runStart == nil {
                    runStart = x
                } else if !isDark, let start = runStart {
                    let rectX = (start + quietZone) * moduleSize
                    let rectY = (y + quietZone) * moduleSize
                    let rectWidth = (x - start) * moduleSize

                    rects.append(
                        #"<rect x="\#(rectX)" y="\#(rectY)" width="\#(rectWidth)" height="\#(moduleSize)"/>"#
                    )
                    runStart = nil
                }
            }
        }

        let body = rects.joined(separator: "\n  ")

        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(totalWidth) \(totalHeight)" width="\(totalWidth)" height="\(totalHeight)" shape-rendering="crispEdges">
          <rect width="100%" height="100%" fill="white"/>
          \(body)
        </svg>
        """
    }
}

private enum QRCodeError: Error {
    case generationFailed
    case rasterizationFailed
}

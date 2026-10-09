// Encodes a folder of 1920×1080 JPEG frames into an H.264 MP4 with AVFoundation
// (BT.709 tagged), so no third-party encoder is needed.
//   swift render/encode.swift <framesDir> <out.mp4> <fps>
import AVFoundation
import Foundation
import ImageIO

let width = 1920
let height = 1080

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("encode: \(message)\n".utf8))
    exit(1)
}

func frameFiles(in dir: URL) -> [URL] {
    guard let all = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
        fail("cannot read \(dir.path)")
    }
    let files = all.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    if files.isEmpty { fail("no .jpg frames in \(dir.path)") }
    return files
}

func makeWriter(_ out: URL, fps: Int32) -> (AVAssetWriter, AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor) {
    try? FileManager.default.removeItem(at: out)
    guard let writer = try? AVAssetWriter(outputURL: out, fileType: .mp4) else { fail("cannot create \(out.path)") }
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 16_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoExpectedSourceFrameRateKey: fps,
        ],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
    writer.add(input)
    return (writer, input, adaptor)
}

func pixelBuffer(for file: URL, pool: CVPixelBufferPool) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let pixels = buffer,
          let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = CGColorSpace(name: CGColorSpace.sRGB) else { fail("cannot decode \(file.lastPathComponent)") }
    CVPixelBufferLockBaseAddress(pixels, [])
    defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
    let info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    guard let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixels), space: space, bitmapInfo: info
    ) else { fail("cannot draw \(file.lastPathComponent)") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

func encode(files: [URL], to out: URL, fps: Int32) {
    let (writer, input, adaptor) = makeWriter(out, fps: fps)
    guard writer.startWriting() else { fail("start failed: \(String(describing: writer.error))") }
    writer.startSession(atSourceTime: .zero)
    for (index, file) in files.enumerated() {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        guard let pool = adaptor.pixelBufferPool else { fail("no pixel buffer pool") }
        let time = CMTime(value: CMTimeValue(index), timescale: fps)
        if !adaptor.append(pixelBuffer(for: file, pool: pool), withPresentationTime: time) {
            fail("append failed at frame \(index): \(String(describing: writer.error))")
        }
    }
    input.markAsFinished()
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    finished.wait()
    guard writer.status == .completed else { fail("finish failed: \(String(describing: writer.error))") }
}

let args = CommandLine.arguments
guard args.count == 4, let fps = Int32(args[3]), fps > 0 else { fail("usage: encode <framesDir> <out.mp4> <fps>") }
let files = frameFiles(in: URL(fileURLWithPath: args[1]))
encode(files: files, to: URL(fileURLWithPath: args[2]), fps: fps)
print("encode: wrote \(files.count) frames to \(args[2])")

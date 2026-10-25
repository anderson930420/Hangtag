import AppKit
import UniformTypeIdentifiers

/// Opens a screenshot in the system Markup editor, the window macOS shows
/// when you click the thumbnail of a screenshot you just took. It is a
/// system extension, reached through the sharing service it registers.
@MainActor
final class Markup: NSObject, NSSharingServiceDelegate {
    static let shared = Markup()

    /// Called with the file once the edited image has been written back.
    var onSaved: (URL) -> Void = { _ in }

    private var editing: URL?
    private static let serviceName = NSSharingService.Name("com.apple.MarkupUI.Markup")

    func edit(_ url: URL) {
        guard let service = NSSharingService(named: Markup.serviceName),
              service.canPerform(withItems: [url]) else {
            // Without the extension, Preview is the closest thing.
            NSWorkspace.shared.open(url)
            return
        }
        editing = url
        service.delegate = self
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: [url])
    }

    // MARK: NSSharingServiceDelegate

    /// Done was pressed. The extension hands back the edited image and the
    /// host app is the one that writes it over the original file.
    nonisolated func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        MainActor.assumeIsolated { self.save(items) }
    }

    nonisolated func sharingService(_ sharingService: NSSharingService,
                                    didFailToShareItems items: [Any], error: Error) {
        log.notice("Markup ended without saving: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: Writing back

    private func save(_ items: [Any]) {
        guard let target = editing, let item = items.first else { return }
        editing = nil
        log.notice("Markup returned \(String(describing: type(of: item)), privacy: .public)")

        switch item {
        case let url as URL:
            write(from: url, to: target)
        case let image as NSImage:
            write(data: Markup.encoded(image, like: target), to: target)
        case let provider as NSItemProvider:
            load(provider, into: target)
        default:
            log.error("Markup returned an unexpected item")
        }
    }

    private func load(_ provider: NSItemProvider, into target: URL) {
        let types = provider.registeredTypeIdentifiers
        log.notice("Markup provider types: \(types.joined(separator: ", "), privacy: .public)")

        if types.contains(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async { if let url { self.write(from: url, to: target) } }
            }
            return
        }
        // Prefer the original format, then any image format.
        let original = UTType(filenameExtension: target.pathExtension)?.identifier
        let imageType = types.first { $0 == original }
            ?? types.first { UTType($0)?.conforms(to: .image) == true }
        guard let imageType else { return }
        provider.loadDataRepresentation(forTypeIdentifier: imageType) { data, _ in
            DispatchQueue.main.async {
                // Data in another format is written in the file's own, so a
                // .png never ends up holding TIFF.
                if imageType == original {
                    self.write(data: data, to: target)
                } else {
                    self.write(data: data.flatMap(NSImage.init(data:)).flatMap { Markup.encoded($0, like: target) },
                               to: target)
                }
            }
        }
    }

    private func write(from source: URL, to target: URL) {
        if source.standardizedFileURL == target.standardizedFileURL {
            onSaved(target)
        } else {
            write(data: try? Data(contentsOf: source), to: target)
        }
    }

    private func write(data: Data?, to target: URL) {
        guard let data else { return }
        do {
            try data.write(to: target, options: .atomic)
            onSaved(target)
        } catch {
            log.error("Could not save markup: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    /// The edited image in the original file's format, color space, depth and
    /// resolution, so an arrow adds kilobytes instead of doubling the file.
    /// Going through TIFF and the default PNG settings widened the pixels and
    /// turned every edit into a PNG. The size is the edited image's own, which
    /// differs from the original's after a crop.
    static func encoded(_ image: NSImage, like original: URL) -> Data? {
        guard let edited = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let source = CGImageSourceCreateWithURL(original as CFURL, nil)
        let originalImage = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) } as? [CFString: Any] ?? [:]
        let type = source.flatMap(CGImageSourceGetType) ?? UTType.png.identifier as CFString

        let space = originalImage?.colorSpace ?? edited.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let alphaInfo = originalImage?.alphaInfo ?? edited.alphaInfo
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(alphaInfo)
        guard let context = CGContext(
            data: nil, width: edited.width, height: edited.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space,
            bitmapInfo: (hasAlpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)
        else { return nil }
        context.draw(edited, in: CGRect(x: 0, y: 0, width: edited.width, height: edited.height))
        guard let flattened = context.makeImage() else { return nil }

        var options: [CFString: Any] = [:]
        for key in [kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight] { options[key] = properties[key] }
        if let lossy = UTType(type as String), lossy.conforms(to: .jpeg) || lossy.conforms(to: .heic) {
            options[kCGImageDestinationLossyCompressionQuality] = 0.9
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, flattened, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

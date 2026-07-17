import AppKit

/// 缓存已调整尺寸的应用图标，避免分页状态变化时重复访问工作区图标服务。
@MainActor
final class AppIconProvider {
    static let shared = AppIconProvider()

    private let cache = NSCache<NSString, NSImage>()
    private let iconLoader: (String) -> NSImage

    init(iconLoader: @escaping (String) -> NSImage = { NSWorkspace.shared.icon(forFile: $0) }) {
        self.iconLoader = iconLoader
    }

    func icon(for path: String, size: CGFloat) -> NSImage {
        let key = "\(path)#\(size)" as NSString
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let loadedIcon = iconLoader(path)
        let icon = (loadedIcon.copy() as? NSImage) ?? loadedIcon
        icon.size = NSSize(width: size, height: size)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

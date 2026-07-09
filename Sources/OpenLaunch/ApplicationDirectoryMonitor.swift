import CoreServices
import Foundation

/// 监听应用目录变化，用于在安装、删除或移动 app 后触发启动台刷新。
final class ApplicationDirectoryMonitor {
    private let directories: [URL]
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "dev.openlaunch.application-directory-monitor")
    private var eventStream: FSEventStreamRef?
    private var pendingChangeWorkItem: DispatchWorkItem?

    init(directories: [URL], debounceInterval: TimeInterval = 2.0, onChange: @escaping () -> Void) {
        self.directories = directories
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    /// 开始递归监听已存在的应用目录；安装过程中的 `.app` 内部写入完成也会触发防抖刷新。
    func start() {
        stop()

        let paths = directories
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map(\.standardizedFileURL.path)
            .removingDuplicates()

        guard !paths.isEmpty else {
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
        )

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, _, _, _, _ in
                guard let info else {
                    return
                }

                let monitor = Unmanaged<ApplicationDirectoryMonitor>
                    .fromOpaque(info)
                    .takeUnretainedValue()
                monitor.scheduleChangeNotification()
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            min(debounceInterval, 1.0),
            flags
        )

        if let eventStream {
            FSEventStreamSetDispatchQueue(eventStream, queue)
            FSEventStreamStart(eventStream)
        }
    }

    /// 停止监听并释放系统事件流。
    func stop() {
        pendingChangeWorkItem?.cancel()
        pendingChangeWorkItem = nil

        if let eventStream {
            FSEventStreamStop(eventStream)
            FSEventStreamInvalidate(eventStream)
            FSEventStreamRelease(eventStream)
            self.eventStream = nil
        }
    }

    deinit {
        stop()
    }

    private func scheduleChangeNotification() {
        pendingChangeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.onChange()
            }
        }
        pendingChangeWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

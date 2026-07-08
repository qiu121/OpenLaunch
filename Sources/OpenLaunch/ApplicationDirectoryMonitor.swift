import Darwin
import Foundation

/// 监听应用目录变化，用于在安装、删除或移动 app 后触发启动台刷新。
final class ApplicationDirectoryMonitor {
    private let directories: [URL]
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "dev.openlaunch.application-directory-monitor")
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pendingChangeWorkItem: DispatchWorkItem?

    init(directories: [URL], debounceInterval: TimeInterval = 2.0, onChange: @escaping () -> Void) {
        self.directories = directories
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    /// 开始监听已存在的应用目录；不存在或不可读的目录会被跳过。
    func start() {
        stop()

        for directory in directories {
            guard FileManager.default.fileExists(atPath: directory.path) else {
                continue
            }

            let fileDescriptor = open(directory.path, O_EVTONLY)
            guard fileDescriptor >= 0 else {
                continue
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .delete, .rename, .attrib],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.scheduleChangeNotification()
            }
            source.setCancelHandler {
                close(fileDescriptor)
            }
            sources.append(source)
            source.resume()
        }
    }

    /// 停止监听并释放目录文件描述符。
    func stop() {
        pendingChangeWorkItem?.cancel()
        pendingChangeWorkItem = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
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

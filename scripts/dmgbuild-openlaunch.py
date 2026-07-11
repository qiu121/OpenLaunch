# dmgbuild 原生配置：描述 DMG 安装窗口布局和卷图标。
icon = ".build/package-icons/OpenLaunchDiskIcon.icns"
background = "#f5f7fa"
icon_size = 112
format = "UDZO"
filesystem = "HFS+"
window_rect = ((180, 180), (560, 360))

files = [
    (".build/OpenLaunch.app", "OpenLaunch.app"),
]

symlinks = {
    "Applications": "/Applications",
}

icon_locations = {
    "OpenLaunch.app": (150, 180),
    "Applications": (410, 180),
}

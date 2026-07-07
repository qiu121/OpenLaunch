import XCTest
@testable import OpenLaunchCore

final class AppSortMenuLayoutTests: XCTestCase {
    func testSortMenuGroupsNestDirectionsUnderSortModes() {
        let groups = AppSortMenuLayout.groups

        XCTAssertEqual(groups.map(\.title), ["添加时间", "名称", "最近打开", "自定义"])
        XCTAssertEqual(groups[0].options.map(\.title), ["最早添加", "最近添加"])
        XCTAssertEqual(groups[1].options.map(\.title), ["A 到 Z", "Z 到 A"])
        XCTAssertEqual(groups[2].options.map(\.title), ["最早打开", "最近打开"])
        XCTAssertEqual(groups[3].options.map(\.title), ["自定义"])
    }

    func testCurrentSortSelectionMatchesModeAndDirection() {
        let settings = OpenLaunchSettings(
            sortMode: .lastOpened,
            sortDirection: .reverse,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil
        )

        XCTAssertEqual(AppSortSelection.current(for: settings), .lastOpenedReverse)
    }
}

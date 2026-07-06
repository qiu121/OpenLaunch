import XCTest
@testable import OpenLaunchCore

final class CustomAppOrderTests: XCTestCase {
    func testMovedOrderPlacesDraggedAppBeforeEarlierTarget() {
        let currentAppIDs = ["A", "B", "C", "D"]
        let movedOrder = CustomAppOrder.movedOrder(
            currentAppIDs: currentAppIDs,
            existingOrder: CustomAppOrder.dictionary(from: currentAppIDs),
            draggedAppID: "D",
            targetAppID: "B"
        )

        XCTAssertEqual(movedOrder, ["A", "D", "B", "C"])
    }

    func testMovedOrderPlacesDraggedAppAfterLaterTarget() {
        let currentAppIDs = ["A", "B", "C", "D"]
        let movedOrder = CustomAppOrder.movedOrder(
            currentAppIDs: currentAppIDs,
            existingOrder: CustomAppOrder.dictionary(from: currentAppIDs),
            draggedAppID: "B",
            targetAppID: "D"
        )

        XCTAssertEqual(movedOrder, ["A", "C", "D", "B"])
    }

    func testNormalizedOrderAppendsAppsMissingFromExistingOrder() {
        let normalizedOrder = CustomAppOrder.normalizedOrder(
            currentAppIDs: ["A", "B", "C"],
            existingOrder: ["B": 0, "A": 1]
        )

        XCTAssertEqual(normalizedOrder, ["B", "A", "C"])
    }
}

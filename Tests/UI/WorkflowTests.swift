import XCTest

@MainActor final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testSaveAndReopenRoom() throws {
    let app = XCUIApplication()
    app.launchEnvironment["ROOM_TEST_STORE"] = UUID().uuidString
    app.launch()
    XCTAssertTrue(app.buttons["add-table"].waitForExistence(timeout: 30), app.debugDescription)
    app.buttons["add-table"].tap()
    XCTAssertTrue(
      app.staticTexts["Furniture · 4/24"].waitForExistence(timeout: 10), app.debugDescription)
    app.buttons["Save a copy"].tap()
    XCTAssertTrue(
      app.buttons["Saved layouts · 1"].waitForExistence(timeout: 10), app.debugDescription)
    app.buttons["Saved layouts · 1"].tap()
    app.buttons["Compare"].tap()
    XCTAssertTrue(app.buttons["End comparison"].waitForExistence(timeout: 10), app.debugDescription)
    for _ in 0..<4 { app.scrollViews.firstMatch.swipeDown() }
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "Room layout comparison"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.terminate()
    app.launch()
    XCTAssertTrue(
      app.staticTexts["Furniture · 4/24"].waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertTrue(app.buttons["Saved layouts · 1"].exists, app.debugDescription)
    app.buttons["View in 3D"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["roomScene"].waitForExistence(timeout: 15),
      app.debugDescription)
    let volume = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    volume.name = "Tabletop room"
    volume.lifetime = .keepAlways
    add(volume)
  }
}

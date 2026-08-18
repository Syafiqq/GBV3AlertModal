//
//  GBV3AlertModalExampleUITests.swift
//  GBV3AlertModalExampleUITests
//
//  Created by engineering on 29/11/22.
//

import XCTest

@MainActor
final class GBV3AlertModalExampleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testApplicationLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    }
}

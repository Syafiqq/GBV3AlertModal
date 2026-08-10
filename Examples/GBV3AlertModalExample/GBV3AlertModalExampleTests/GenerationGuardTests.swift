// GenerationGuardTests.swift
import XCTest
@testable import GBV3AlertModalExample

/// `shouldApply` guards the double-tap / stale-async race: an in-flight async result
/// (e.g. a 1.5s "generating…" task) only applies if its captured generation still
/// matches the current generation — otherwise a newer tap (or dismissal) has superseded it.
final class GenerationGuardTests: XCTestCase {

    func test_matching_generation_applies() {
        XCTAssertTrue(shouldApply(resultGeneration: 1, currentGeneration: 1))
    }

    func test_matching_zero_generation_applies() {
        XCTAssertTrue(shouldApply(resultGeneration: 0, currentGeneration: 0))
    }

    func test_stale_generation_does_not_apply() {
        // result captured generation 1, but current has moved on to 2 (superseded)
        XCTAssertFalse(shouldApply(resultGeneration: 1, currentGeneration: 2))
    }

    func test_earlier_result_does_not_apply_to_later_generation() {
        XCTAssertFalse(shouldApply(resultGeneration: 0, currentGeneration: 1))
    }

    func test_later_result_does_not_apply_to_earlier_generation() {
        // defensive: shouldn't happen in practice, but the check is a strict equality
        XCTAssertFalse(shouldApply(resultGeneration: 2, currentGeneration: 1))
    }
}

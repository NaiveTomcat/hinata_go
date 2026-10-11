import AuthenticationServices
import Flutter
import XCTest
import UIKit
@testable import Runner

class RunnerTests: XCTestCase {
  func testAuthenticationCancellationUsesSystemCodes() {
    XCTAssertTrue(isAuthenticationCancellation(NSError(domain: ASAuthorizationError.errorDomain, code: 1001)))
    XCTAssertTrue(isAuthenticationCancellation(NSError(domain: ASWebAuthenticationSessionError.errorDomain, code: 1)))
    XCTAssertTrue(isAuthenticationCancellation(CancellationError()))
    XCTAssertFalse(isAuthenticationCancellation(NSError(domain: ASAuthorizationError.errorDomain, code: 1004)))
    XCTAssertFalse(isAuthenticationCancellation(NSError(domain: ASWebAuthenticationSessionError.errorDomain, code: 2)))
    XCTAssertFalse(isAuthenticationCancellation(NSError(domain: "server", code: 1001,
      userInfo: [NSLocalizedDescriptionKey: "Unable to cancel the request"])))
  }

  @MainActor
  func testFlutterSurfaceStaysVisibleAcrossTabChanges() async throws {
    let window = try XCTUnwrap(UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first)
    let shell = try XCTUnwrap(window.rootViewController as? NativeShellViewController)
    let flutter = try XCTUnwrap(shell.selectedViewController?.children
      .compactMap { $0 as? FlutterViewController }.first)
    defer { shell.nativeShell(setSelectedIndex: 0) }

    for index in [0, 1, 2, 0] {
      shell.nativeShell(setSelectedIndex: index)
      shell.view.layoutIfNeeded()
      let rendering = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in flutter.isDisplayingFlutterUI }, object: flutter)
      await fulfillment(of: [rendering], timeout: 10)
      XCTAssertTrue(flutter.parent === shell.viewControllers?[index])
    }
  }

  @MainActor
  func testFlutterSurfaceStaysVisibleWithUITabSelection() async throws {
    guard #available(iOS 18.0, *) else { throw XCTSkip("UITab requires iOS 18") }
    let window = try XCTUnwrap(UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first)
    let shell = try XCTUnwrap(window.rootViewController as? NativeShellViewController)
    let flutter = try XCTUnwrap(shell.selectedViewController?.children
      .compactMap { $0 as? FlutterViewController }.first)
    let delegate = try XCTUnwrap(shell.delegate)
    defer { shell.nativeShell(setSelectedIndex: 0) }
    var previousTab: UITab?

    for index in [1, 2, 0] {
      let target = try XCTUnwrap(shell.viewControllers?[index])
      let tab = UITab(title: "Tab \(index)", image: nil, identifier: "test-\(index)") { _ in
        target
      }
      // iOS 27 can call this entry point without calling shouldSelect UIViewController.
      let allowed = try XCTUnwrap(delegate.tabBarController?(shell, shouldSelectTab: tab),
        "The UITab selection callback must prepare Flutter before UIKit switches tabs")
      XCTAssertTrue(allowed)
      XCTAssertTrue(flutter.parent === target)
      shell.selectedViewController = target
      // Exercise the modern completion callback, not the legacy one.
      let notified = delegate.tabBarController?(
        shell, didSelectTab: tab, previousTab: previousTab)
      XCTAssertNotNil(notified, "The UITab completion callback must be implemented")
      previousTab = tab
      shell.view.layoutIfNeeded()
      let rendering = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in flutter.isDisplayingFlutterUI }, object: flutter)
      await fulfillment(of: [rendering], timeout: 10)
    }
  }

  @MainActor
  func testNativeShellActionLayoutAcrossTabsAndChromeChanges() throws {
    let window = try XCTUnwrap(UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first)
    let shell = try XCTUnwrap(window.rootViewController as? NativeShellViewController)
    shell.loadViewIfNeeded()
    shell.nativeShell(setActionButton: [
      "symbol": "plus", "label": "Layout regression action", "actionId": "test",
    ])
    let button = try XCTUnwrap(shell.view.subviews.compactMap { $0 as? UIButton }
      .first { $0.accessibilityLabel == "Layout regression action" })
    defer {
      shell.nativeShell(setChromeVisibility: true, dimmed: false)
      shell.nativeShell(setSelectedIndex: 0)
      shell.nativeShell(setActionButton: nil)
    }

    for visible in [true, false, true] {
      shell.nativeShell(setChromeVisibility: visible, dimmed: false)
      for index in 0..<3 {
        shell.nativeShell(setSelectedIndex: index)
        shell.view.setNeedsLayout()
        shell.view.layoutIfNeeded()
        XCTAssertEqual(shell.selectedIndex, index)
        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(button.isUserInteractionEnabled)
        XCTAssertFalse(button.hasAmbiguousLayout)
        let safeFrame = shell.view.safeAreaLayoutGuide.layoutFrame
        XCTAssertGreaterThan(button.frame.width, 0)
        XCTAssertGreaterThanOrEqual(button.frame.minY, safeFrame.minY)
        XCTAssertLessThanOrEqual(button.frame.maxY, safeFrame.maxY - 16 + 0.5)
        XCTAssertEqual(button.frame.maxX, safeFrame.maxX - 16, accuracy: 0.5)

        if !visible {
          XCTAssertEqual(button.frame.maxY, safeFrame.maxY - 16, accuracy: 0.5)
        } else if shell.tabBar.isDescendant(of: shell.view) {
          let barFrame = shell.tabBar.convert(shell.tabBar.bounds, to: shell.view)
          if barFrame.maxY >= safeFrame.maxY {
            XCTAssertLessThanOrEqual(button.frame.maxY, barFrame.minY - 16 + 0.5)
          }
        }
        if #available(iOS 18.0, *) {
          XCTAssertEqual(shell.isTabBarHidden, !visible)
          XCTAssertTrue((shell.viewControllers ?? []).allSatisfy {
            $0.additionalSafeAreaInsets.bottom == 0
          })
        }
      }
    }
  }

}

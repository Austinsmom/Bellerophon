//
//  BPManager.swift
//  Bellerophon
//
//  Created by Thibault Klein on 8/22/15.
//  Copyright (c) 2015 Prolific Interactive. All rights reserved.
//

import Foundation
import UIKit

public class BellerophonManager: NSObject {

    // MARK: Singleton instance

    /// Shared singleton instance of BellerophonManager
    public static let sharedInstance = BellerophonManager()
    override private init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector(stopTimer()), name: UIApplicationDidEnterBackgroundNotification, object: nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    // MARK: Public properties

    /// View to be shown when the kill switch is turned on. Must be set by the application using Bellerophon
    public var killSwitchView: UIView!

    /// BellerophonManager delegate
    public weak var delegate: BellerophonManagerDelegate?

    // MARK: Private properties
    private lazy var killSwitchWindow: UIWindow = {
        let window = BellerophonHelperMethods.newWindow()
        window.windowLevel = UIWindowLevelAlert
        let rootViewController = UIViewController()
        rootViewController.view.addSubview(self.killSwitchView)
        window.rootViewController = rootViewController
        return window
    }()
    private var requestPending = false
    private var retryTimer: NSTimer?

    // MARK: Public Methods

    /**
     Retrieves and handles the app status from the AMS endpoint
     */
    public func checkAppStatus() {
        assert(killSwitchView != nil, "The kill switch view has to be defined.")

        if requestPending {
            return;
        }

        requestPending = true
        stopTimer()

        delegate?.bellerophonStatus(self) { status, error in
            self.requestPending = false
            if let status = status {
                self.handleAppStatus(status)
            } else {
                self.dismissKillSwitchIfNeeded()
            }
        }
    }

    /**
     Use this function to retrieve and handle app status when the app has background mode enabled.

     - parameter completionHandler: Completion handler
     */
    public func fetchAppStatus(completionHandler: (result: UIBackgroundFetchResult) -> ()) {
        delegate?.bellerophonStatus(self) { status, error in
            if let status = status {
                self.handleAppStatus(status)
                if status.apiInactive() {
                    // If the kill switch or queue-it is still active we don't need to update anything
                    completionHandler(result: .NoData)
                } else {
                    // If the kill switch and queue-it are back to normal, we can stop fetching
                    completionHandler(result: .NewData)
                }
            } else {
                // An error occurred
                completionHandler(result: .Failed)
            }
        }
    }

    // MARK: Private Methods

    private func handleAppStatus(status: BellerophonObservable) {
        if status.apiInactive() {
            displayKillSwitch()
            startAutoChecking(status)
        } else if status.forceUpdate() {
            performForceUpdate()
        } else {
            dismissKillSwitchIfNeeded()
        }
    }

    private func stopTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func performForceUpdate() {
        delegate?.shouldForceUpdate()
    }

    private func displayKillSwitch() {
        if !killSwitchWindow.keyWindow {
            killSwitchView.frame = killSwitchWindow.bounds
            delegate?.bellerophonWillEngage?(self)
            killSwitchWindow.makeKeyAndVisible()
        }
    }

    private func dismissKillSwitchIfNeeded() {
        if killSwitchWindow.keyWindow {
            delegate?.bellerophonWillDisengage?(self)
            killSwitchWindow.hidden = true;
        }
    }

    private func startAutoChecking(status: BellerophonObservable) {
        if retryTimer == nil {
            retryTimer = BellerophonHelperMethods.timerWithStatus(status, target: self, selector: #selector(BellerophonManager.checkAppStatus))
        }
    }
}
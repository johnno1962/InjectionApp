//
//  InjectionMenuController.swift
//  Injectorator
//
//  Created by John Holdsworth on 22/12/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

import Cocoa

class INController: INPluginMenuController {

    var project: Project? {
        if Integration.shared.appDelegate.state.project == nil {
            Integration.shared.appDelegate.state.project = Project(target: nil)
        }
        return Integration.shared.appDelegate.state.project
    }

    override func workspacePath() -> String! {
        return project?.workspacePath
    }

    override func buildDirectory() -> String! {
        return project?.derivedData.url.appendingPathComponent("Build").path ?? "Unknown project deerived data"
    }

    override func logDirectory() -> String! {
        return project?.derivedData.url.appendingPathComponent("Logs/Build").path ?? "Unknown project deerived data"
    }

    override func enableFileWatcher(_ enabled: Bool) {
        super.enableFileWatcher(enabled)
        Integration.shared.updateState(newState: enabled ? .connected : .idle)
    }

    @IBAction func showTunable(sender: AnyObject!) {
        client.paramsPanel.makeKeyAndOrderFront(sender)
    }

    @IBAction func showConsole(sender: AnyObject!) {
        client.consolePanel.makeKeyAndOrderFront(sender)
    }

    @objc (injectSource:)
    @IBAction func injectSource(_ sender: AnyObject!) {
        Integration.shared.injectSource(sender: sender)
    }

    override func xcodeApp() -> String! {
        if let xcodeApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
            .first?.bundleURL?.path {
            return xcodeApp
        }
        let appName = project?.xCode?.className.replacingOccurrences(of: "Application", with: "")
        return "/Applications/\(appName ?? "Xcode").app"
    }

}

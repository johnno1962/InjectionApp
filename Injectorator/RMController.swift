//
//  RMController.swift
//  Injectorator
//
//  Created by John Holdsworth on 06/01/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

import Foundation

class RMController: RMPluginController {

    var project: Project? {
        return Integration.shared.appDelegate.state.project
    }

    @objc override func workspacePath() -> String! {
        return project?.workspacePath
    }

    @IBAction override func patch(_ sender: NSMenuItem!) {
        Integration.shared.remotePatch(sender: sender)
    }

    @IBAction override func unpatch(_ sender: NSMenuItem!) {
        Integration.shared.remoteUnpatch(sender: sender)
    }

}

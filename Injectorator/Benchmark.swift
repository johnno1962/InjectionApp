//
//  Benchmark.swift
//  Injectorator
//
//  Created by John Holdsworth on 07/01/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

import Foundation

extension Integration {

    @IBAction func optimise(sender: AnyObject!) {
        appDelegate.state.setup()
        var html = ""
        for line in LogParser(logDir: appDelegate.state.project!.derivedData+"/Logs/Build").profileLines() {
            let tabsep = line.components(separatedBy: "\t"), time = tabsep[0], location = tabsep[1], decl = tabsep[2]
            let colonsep = location.components(separatedBy: ":"), file = colonsep[0], line = colonsep[1], col = colonsep[2]
            html += "<tr><td><pre>\(time) <td><pre><a href='#' onclick='return gotoFile(\"\(file)\", \(line))'>\(file.url.lastPathComponent):\(line)</a>:\(col) <td><pre>\(decl)\n"
        }

        appDelegate.state.setChangesSource(header: "Compile time measurements...")
        if html == "" {
            html = "Add \"-Xfrontend -debug-time-function-bodies\" to \"Other Swift Flags\" of your project and build to benchmark compilation times"
        }
        else {
            html = "<table cellspacing=0 cellpadding=0>\(html)</table>"
        }
        appDelegate.state.appendSource(title: "", text: html)
    }

    @IBAction func findSpace(sender: AnyObject!) {
        if delegate == nil {
            Bundle.main.loadNibNamed("DiskTree", owner: self, topLevelObjects: nil)
        }
        let notification = Notification(name: .NSApplicationDidFinishLaunching)
        delegate.applicationDidFinishLaunching!(notification)
    }

}

extension LogParser {

    func profileLines() -> [NSString] {
        var out = [NSString]()
        for line in TaskGenerator( command: "gunzip <\"\(recentFirstLogs.first ?? "blah")\"", lineSeparator: "\r" ).sequence {
            if line.contains("ms\t/") {
                let line = line.replacingOccurrences(of: "^.*\"(\\d+\\.\\dms\t)", with: "$1", options: .regularExpression)
                if !line.hasPrefix("0.0ms") {
                    out.append(line as NSString)
                }
            }
        }
        return Set( out ).sorted {
            return $0.floatValue > $1.floatValue
        }
    }

}

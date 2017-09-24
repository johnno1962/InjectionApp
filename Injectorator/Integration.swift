//
//  SubApp.swift
//  Injectorator
//
//  Created by John Holdsworth on 21/12/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

import Foundation

//let kVK_ANSI_Equal: UInt16 = 0x18

class Integration: NSObject {

    static var shared: Integration!

    @IBOutlet var injection: INPluginMenuController!
    @IBOutlet var xprobe: XprobePluginMenuController!

    @IBOutlet var mainMenu: NSMenu!
    @IBOutlet var statusMenu: NSMenu!
    private var statusItem: NSStatusItem!

    var remote: RMPluginController!
    var appDelegate: AppDelegate!

    @IBOutlet var delegate: NSApplicationDelegate!

    init(appDelegate: AppDelegate, count: Int) {
        super.init()
        Integration.shared = self
        self.appDelegate = appDelegate

        setenv("IS_INJECTION_APP", Bundle.main.bundlePath, 1)
        signal(SIGPIPE, SIG_IGN)

        guard let appMenu = NSApplication.shared().mainMenu else { return }
        Bundle(for:Integration.self).loadNibNamed("Integration", owner: self, topLevelObjects: nil)

        let notification = Notification(name: .NSApplicationDidFinishLaunching)
        injection.applicationDidFinishLaunching(notification)
        xprobe.applicationDidFinishLaunching(notification)

        xprobe.injectionPlugin = INPluginMenuController.self
        injectionPlugin = injection
        xprobePlugin = xprobe

        appMenu.item(at: 0)?.submenu = mainMenu
        #if swift(>=3.2)
        appMenu.removeItem(at: 1)
        statusMenu.item(withTitle: "Refactor Swift")?.isHidden = true
        #else
        appMenu.item(at: 1)?.submenu?.title = "Refactorator"
        #endif

        let statusBar = NSStatusBar.system()
        statusItem = statusBar.statusItem(withLength: statusBar.thickness)
        statusItem.toolTip = "Injectorator"
        statusItem.highlightMode = true
        statusItem.menu = statusMenu
        statusItem.isEnabled = true
        statusItem.title = ""

        updateState(newState: .idle)

        _ = DDHotKeyCenter.shared()?.registerHotKey(withKeyCode: UInt16(kVK_ANSI_Equal),
                                                    modifierFlags: NSEventModifierFlags.control.rawValue,
                                                    target: self, action: #selector(injectSource(sender:)), object: nil)

        let expires = Date(timeIntervalSince1970: 1515929737.02325)//timeIntervalSinceNow:(2*31+8)*24*60*60)
        print("If not licensed, this copy will expire on: \(expires) \(expires.timeIntervalSince1970)")

        if !appDelegate.licensed && Date() > expires {
            let alert = NSAlert()
            alert.messageText = "Injection"
            alert.informativeText = "An update is available for Injection, please download a new copy"
            alert.runModal()
            appDelegate.help(sender: nil)
            NSApp.terminate(nil)
            return
        }
    }

    @discardableResult
    func error(_ msg: String) -> NSModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        print("Error: \(msg)")
        let alert = NSAlert()
        alert.messageText = "Injection App"
        alert.informativeText = msg
        return alert.runModal()
    }

    func pathForResource( name: String, ofType ext: String! ) -> String! {
        if let path = Bundle.main.path(forResource: name, ofType: ext) {
            return path
        } else {
            error("Could not locate resource \(name).\(ext)" )
            return nil
        }
    }

    func setMenuIcon( tiffName: String ) {
        if let path = pathForResource( name: tiffName, ofType:"tif" ) {
            statusItem.image = NSImage( contentsOfFile:path )
            statusItem.alternateImage = statusItem.image
        }
    }

    func updateState( newState: INBundleState ) {
        switch (newState) {
        case .idle:
            setMenuIcon(tiffName: "InjectionIdle")
        case .connected:
            setMenuIcon(tiffName: "InjectionOK")
        default:
            error("Invalid status \(newState.rawValue)")
            break
        }
    }

    func injectTooling(file: String? = nil) -> String? {
        let bundlePath = pathForResource(name: "InjectionLoader", ofType: "bundle")
        appDelegate.state.project = Project(target: file != nil ? Entity(file: file!) : nil)
        do {
            if !injection.client.connected() {
                if !HelperInstaller.isInstalled() {
                    error( "Injection needs to install a privileged helper to be able to inject code into " +
                        "an app running in the simulator. This is a standard macOS mechanism. " +
                        "You can remove the helper at any time by deleting:\n " +
                        "/Library/PrivilegedHelperTools/com.johnholdsworth.Injectorator.Helper.\n" +
                        "If you'd rather not authorize, you can select \"macOS Project/Patch App\" " +
                        "and use patched injection instead." )
                    try HelperInstaller.install()
                }
                try HelperProxy.inject( bundlePath )
                for _ in 0..<50 {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                    if injection.client.connected() {
                        NSApp.hide(nil)
                        return appDelegate.state.project?.entity?.file
                    }
                }
                error( "Timeout waiting for connection from client app" )
                return nil
            }
            NSApp.hide(nil)
            return appDelegate.state.project?.entity?.file
        }
        catch (let err as NSError) {
            print("Couldn't install Injection Helper (domain: \(err.domain) code: \(err.code))")
            error( "Injection Error:\n\(err.localizedDescription)" )
        }
        return nil
    }

    func runInjection( file: String ) {
        injection.client.runScript("injectSource.pl", withArg: file)
        injection.lastInjected[file] = NSDate()
        injection.lastFile = file
    }

    @IBAction func injectSource(sender: AnyObject!) {
        if let file = injectTooling() {
            runInjection(file: file)
        }
    }

    @IBAction func fileWatcher(sender: NSMenuItem!) {
        sender.state = 1-sender.state
        injection.watchButton.state = sender.state
        injection.watchChanged(sender)
    }

    @IBAction func patchProject(sender: AnyObject!) {
        appDelegate.state.project = Project(target: nil)
        injection.client.runScript("patchProject.pl", withArg: "\(SWIFT_INJECTION_PORT)")
    }

    @IBAction func revertProject(sender: AnyObject!) {
        appDelegate.state.project = Project(target: nil)
        injection.client.runScript("revertProject.pl", withArg: "")
    }

    @IBAction func bundleProject(sender: AnyObject!) {
        appDelegate.state.project = Project(target: nil)
        injection.client.runScript("openBundle.pl", withArg: "")
    }

    @IBAction func osxXprobe(sender: AnyObject!) {
        if let path = pathForResource(name: "XprobeBundle", ofType: "loader") {
            injection.client.write("/"+path)
        }
    }

    @IBAction func loadXprobe(sender: AnyObject!) {
        _ = injectTooling()
        injection.client.write("+")
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func refactorSwift(sender: AnyObject!) {
        if let appDelegate = NSApplication.shared().delegate as? AppDelegate {
            appDelegate.state.setup()
            appDelegate.window.makeKeyAndOrderFront(sender)
        }
    }

    func initRemote() -> RMPluginController {
        if remote == nil {
            remote = RMController()
            setenv("REMOTE_PORT", "\(SWIFT_REMOTE_PORT)", 1 )
            let notification = Notification(name: .NSApplicationDidFinishLaunching)
            remote.applicationDidFinishLaunching(notification)
            let title = "Remote Control"
            let index = statusMenu.indexOfItem(withTitle: title)
            statusMenu.removeItem(at: index)
            remote.remoteMenu.title = title
            statusMenu.insertItem(remote.remoteMenu, at: index)

            remote.remoteMenu.submenu?.item(at: 0)?.isHidden = true
        }
        return remote
    }

    @IBAction func remotePatch(sender: AnyObject!) {
        appDelegate.state.project = Project(target: nil)
        initRemote().runScript("patch")
    }

    @IBAction func remoteUnpatch(sender: AnyObject!) {
        appDelegate.state.project = Project(target: nil)
        initRemote().runScript("unpatch")
    }

    @IBAction func terminate(sender: AnyObject!) {
        NSApp.terminate(sender)
    }

}

extension AppDelegate {

    func applicationWillTerminate(_ notification: Notification) {
        _ = DDHotKeyCenter.shared()?.unregisterHotKey(withKeyCode: UInt16(kVK_ANSI_Equal),
                                                    modifierFlags: NSEventModifierFlags.control.rawValue)
    }

    @IBAction func help(sender: NSMenuItem!) {
        state.open(url: "http://johnholdsworth.com/injection.html?index=\(myIndex)")
    }

    @IBAction func donate(sender: NSMenuItem!) {
        state.open(url: "http://johnholdsworth.com/cgi-bin/injection.cgi?index=\(myIndex)")
    }
    
    @objc func inject(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        _ = pboard.string(forType: NSPasteboardTypeString)
        Integration.shared.injectSource(sender: nil)
    }

    @objc func injectFile(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        let options = [NSPasteboardURLReadingFileURLsOnlyKey:true]
        if let fileURLs = pboard.readObjects(forClasses: [NSURL.self], options: options),
            let file = (fileURLs.first as? NSURL)?.path {
            _ = Integration.shared.injectTooling(file: file)
            Integration.shared.runInjection(file: file)
        }
    }

    @objc func xprobe(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        _ = pboard.string(forType: NSPasteboardTypeString)
        Integration.shared.loadXprobe(sender: nil)
    }

}

// ['Snow', 'DarkKhaki', 'IndianRed', 'MistyRose', 'DarkGrey', 'FloralWhite', 'LightGreen', 'DeepSkyBlue', 'Gainsboro', 'Aquamarine', 'Khaki', 'Sienna', 'Purple', 'SlateGray', 'HotPink', 'White', 'PowderBlue', 'DarkGreen', 'PapayaWhip', 'OliveDrab', 'DarkOrange', 'Yellow', 'Crimson', 'MediumBlue', 'DarkMagenta', 'PeachPuff', 'LightCyan', 'MediumOrchid', 'Lime', 'GreenYellow', 'Gold', 'SlateGrey', 'LightYellow', 'Linen', 'DarkSlateGrey', 'PaleVioletRed', 'AliceBlue', 'MediumSeaGreen', 'LightSlateGrey', 'LawnGreen', 'LightGoldenRodYellow', 'SpringGreen', 'Chocolate', 'RoyalBlue', 'DimGrey', 'MediumSlateBlue', 'DarkOrchid', 'CadetBlue', 'PaleGoldenRod', 'BlanchedAlmond', 'Cornsilk', 'CornflowerBlue', 'PaleTurquoise', 'ForestGreen', 'YellowGreen', 'GoldenRod', 'Coral', 'SandyBrown', 'Wheat', 'Tan', 'Black', 'LavenderBlush', 'Turquoise', 'DarkCyan', 'WhiteSmoke', 'OldLace', 'SeaGreen', 'LightSteelBlue', 'DimGray', 'Ivory', 'Salmon', 'Olive', 'HoneyDew', 'Red', 'Beige', 'DarkGray', 'Green', 'DarkBlue', 'Bisque', 'Moccasin', 'Pink', 'LightSalmon', 'DarkSeaGreen', 'LightSlateGray', 'BlueViolet', 'GhostWhite', 'FireBrick', 'DarkRed', 'Orange', 'OrangeRed', 'DarkOliveGreen', 'LightSkyBlue', 'MediumTurquoise', 'DarkSalmon', 'NavajoWhite', 'RosyBrown', 'SteelBlue', 'LightBlue', 'SeaShell', 'SkyBlue', 'DarkSlateGray', 'LimeGreen', 'LightCoral', 'LightSeaGreen', 'SaddleBrown', 'MediumVioletRed', 'Azure', 'Thistle', 'Lavender', 'DarkSlateBlue', 'LightGrey', 'Chartreuse', 'Navy', 'Teal', 'Indigo', 'MediumSpringGreen', 'RebeccaPurple', 'Orchid', 'Tomato', 'PaleGreen', 'Aqua', 'Grey', 'MediumAquaMarine', 'DarkGoldenRod', 'LightGray', 'Violet', 'Fuchsia', 'Magenta', 'DodgerBlue', 'Maroon', 'DarkViolet', 'DeepPink', 'MidnightBlue', 'AntiqueWhite', 'SlateBlue', 'Blue', 'BurlyWood', 'Brown', 'Peru', 'Silver', 'LightPink', 'MediumPurple', 'MintCream', 'Plum', 'Cyan', 'Gray', 'DarkTurquoise', 'LemonChiffon']

let colors = String(data: Data(base64Encoded: "U25vdzpEYXJrS2hha2k6SW5kaWFuUmVkOk1pc3R5Um9zZTpEYXJrR3JleTpGbG9yYWxXaGl0ZTpMaWdodEdyZWVuOkRlZXBTa3lCbHVlOkdhaW5zYm9ybzpBcXVhbWFyaW5lOktoYWtpOlNpZW5uYTpQdXJwbGU6U2xhdGVHcmF5OkhvdFBpbms6V2hpdGU6UG93ZGVyQmx1ZTpEYXJrR3JlZW46UGFwYXlhV2hpcDpPbGl2ZURyYWI6RGFya09yYW5nZTpZZWxsb3c6Q3JpbXNvbjpNZWRpdW1CbHVlOkRhcmtNYWdlbnRhOlBlYWNoUHVmZjpMaWdodEN5YW46TWVkaXVtT3JjaGlkOkxpbWU6R3JlZW5ZZWxsb3c6R29sZDpTbGF0ZUdyZXk6TGlnaHRZZWxsb3c6TGluZW46RGFya1NsYXRlR3JleTpQYWxlVmlvbGV0UmVkOkFsaWNlQmx1ZTpNZWRpdW1TZWFHcmVlbjpMaWdodFNsYXRlR3JleTpMYXduR3JlZW46TGlnaHRHb2xkZW5Sb2RZZWxsb3c6U3ByaW5nR3JlZW46Q2hvY29sYXRlOlJveWFsQmx1ZTpEaW1HcmV5Ok1lZGl1bVNsYXRlQmx1ZTpEYXJrT3JjaGlkOkNhZGV0Qmx1ZTpQYWxlR29sZGVuUm9kOkJsYW5jaGVkQWxtb25kOkNvcm5zaWxrOkNvcm5mbG93ZXJCbHVlOlBhbGVUdXJxdW9pc2U6Rm9yZXN0R3JlZW46WWVsbG93R3JlZW46R29sZGVuUm9kOkNvcmFsOlNhbmR5QnJvd246V2hlYXQ6VGFuOkJsYWNrOkxhdmVuZGVyQmx1c2g6VHVycXVvaXNlOkRhcmtDeWFuOldoaXRlU21va2U6T2xkTGFjZTpTZWFHcmVlbjpMaWdodFN0ZWVsQmx1ZTpEaW1HcmF5Okl2b3J5OlNhbG1vbjpPbGl2ZTpIb25leURldzpSZWQ6QmVpZ2U6RGFya0dyYXk6R3JlZW46RGFya0JsdWU6QmlzcXVlOk1vY2Nhc2luOlBpbms6TGlnaHRTYWxtb246RGFya1NlYUdyZWVuOkxpZ2h0U2xhdGVHcmF5OkJsdWVWaW9sZXQ6R2hvc3RXaGl0ZTpGaXJlQnJpY2s6RGFya1JlZDpPcmFuZ2U6T3JhbmdlUmVkOkRhcmtPbGl2ZUdyZWVuOkxpZ2h0U2t5Qmx1ZTpNZWRpdW1UdXJxdW9pc2U6RGFya1NhbG1vbjpOYXZham9XaGl0ZTpSb3N5QnJvd246U3RlZWxCbHVlOkxpZ2h0Qmx1ZTpTZWFTaGVsbDpTa3lCbHVlOkRhcmtTbGF0ZUdyYXk6TGltZUdyZWVuOkxpZ2h0Q29yYWw6TGlnaHRTZWFHcmVlbjpTYWRkbGVCcm93bjpNZWRpdW1WaW9sZXRSZWQ6QXp1cmU6VGhpc3RsZTpMYXZlbmRlcjpEYXJrU2xhdGVCbHVlOkxpZ2h0R3JleTpDaGFydHJldXNlOk5hdnk6VGVhbDpJbmRpZ286TWVkaXVtU3ByaW5nR3JlZW46UmViZWNjYVB1cnBsZTpPcmNoaWQ6VG9tYXRvOlBhbGVHcmVlbjpBcXVhOkdyZXk6TWVkaXVtQXF1YU1hcmluZTpEYXJrR29sZGVuUm9kOkxpZ2h0R3JheTpWaW9sZXQ6RnVjaHNpYTpNYWdlbnRhOkRvZGdlckJsdWU6TWFyb29uOkRhcmtWaW9sZXQ6RGVlcFBpbms6TWlkbmlnaHRCbHVlOkFudGlxdWVXaGl0ZTpTbGF0ZUJsdWU6Qmx1ZTpCdXJseVdvb2Q6QnJvd246UGVydTpTaWx2ZXI6TGlnaHRQaW5rOk1lZGl1bVB1cnBsZTpNaW50Q3JlYW06UGx1bTpDeWFuOkdyYXk6RGFya1R1cnF1b2lzZTpMZW1vbkNoaWZmb24=")!, encoding: .utf8 )!.components(separatedBy: ":")

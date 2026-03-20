import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(name: "com.rumble.app/permissions", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { (call, result) in
      if call.method == "checkAccessibility" {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        print("native: checkAccessibility returning \(isTrusted)")
        result(isTrusted)
      } else if call.method == "openAccessibility" {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        result(nil)
      } else if call.method == "getAppPath" {
        result(Bundle.main.bundlePath)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Monitor modifier keys (Shift, Ctrl, Alt, Cmd) globally for PTT.
    // Carbon HotKeys don't support standalone modifiers, so we use NSEvent monitors.
    NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
        channel.invokeMethod("onModifierFlagsChanged", arguments: event.modifierFlags.rawValue)
    }
    
    // Also monitor locally for when the app is focused.
    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
        channel.invokeMethod("onModifierFlagsChanged", arguments: event.modifierFlags.rawValue)
        return event
    }

    super.awakeFromNib()
  }
}

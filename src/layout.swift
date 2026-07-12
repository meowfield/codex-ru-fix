import Carbon
import Foundation

func listInputSources() {
    guard let cfSources = TISCreateInputSourceList(nil, false),
          let sources = cfSources.takeRetainedValue() as? [TISInputSource] else {
        print("No input sources found.")
        return
    }
    for source in sources {
        let rawID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        let rawType = TISGetInputSourceProperty(source, kTISPropertyInputSourceType)

        let id = rawID != nil ? (Unmanaged<AnyObject>.fromOpaque(rawID!).takeUnretainedValue() as? String ?? "") : ""
        let type = rawType != nil ? (Unmanaged<AnyObject>.fromOpaque(rawType!).takeUnretainedValue() as? String ?? "") : ""

        // Filter for keyboard layouts or input methods
        if type == "TISTypeKeyboardLayout" {
            print("\(id) [\(type)]")
        }
    }
}

func getCurrentInputSourceID() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return nil
    }
    let rawID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
    if rawID == nil { return nil }
    return Unmanaged<AnyObject>.fromOpaque(rawID!).takeUnretainedValue() as? String
}

func setInputSource(to id: String) -> Bool {
    let filter = [kTISPropertyInputSourceID: id] as CFDictionary
    guard let cfSources = TISCreateInputSourceList(filter, false),
          let sources = cfSources.takeRetainedValue() as? [TISInputSource],
          let sourceToSelect = sources.first else {
        return false
    }
    return TISSelectInputSource(sourceToSelect) == noErr
}

let args = CommandLine.arguments
if args.count > 1 {
    let cmd = args[1]
    if cmd == "get" {
        if let current = getCurrentInputSourceID() {
            print(current)
            exit(0)
        } else {
            exit(1)
        }
    } else if cmd == "list" {
        listInputSources()
        exit(0)
    } else if cmd == "set" && args.count > 2 {
        let target = args[2]
        if setInputSource(to: target) {
            exit(0)
        } else {
            exit(1)
        }
    }
}
print("Usage: layout-switcher get | list | set <id>")
exit(1)

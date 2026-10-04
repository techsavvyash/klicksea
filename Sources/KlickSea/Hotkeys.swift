import Carbon

@MainActor
final class Hotkeys {
    private var handler: EventHandlerRef?
    private var refs: [EventHotKeyRef] = []
    var onPress: ((UInt32) -> Void)?

    func register() throws {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr else { return status }
            let hotkeys = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            let keyID = id.id
            Task { @MainActor in hotkeys.onPress?(keyID) }
            return noErr
        }, 1, &spec, context, &handler)
        guard status == noErr else { throw AppFailure("Could not install the shortcut handler (\(status)).") }
        // Control + Shift + 4 / 5 avoid Apple's Command + Shift shortcuts.
        for (id, key) in [(UInt32(1), UInt32(kVK_ANSI_4)), (UInt32(2), UInt32(kVK_ANSI_5))] {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(key, UInt32(controlKey | shiftKey),
                EventHotKeyID(signature: 0x4B534541, id: id), GetApplicationEventTarget(), 0, &ref)
            guard status == noErr, let ref else {
                unregister()
                throw AppFailure("Control–Shift–\(id == 1 ? "4" : "5") is already in use. Capture buttons still work.")
            }
            refs.append(ref)
        }
    }

    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll()
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}

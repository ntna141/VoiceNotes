import Foundation

enum DeviceEncoder {
    static func time(now: Date = Date(), calendar: Calendar = .current) -> Data {
        var payload = Data()
        payload.append(contentsOf: [0x74, 0x69, 0x6D, 0x00])
        payload.appendLittleEndian(UInt32(now.timeIntervalSince1970))
        payload.appendLittleEndian(Int16(calendar.timeZone.secondsFromGMT(for: now) / 60))
        return payload
    }

    static func wallpaper(_ bitmap: [UInt8]) -> Data {
        var payload = wallpaperReset()
        payload.append(contentsOf: bitmap)
        return payload
    }

    static func wallpaperReset() -> Data {
        Data([0x77, 0x61, 0x6C, 0x00])
    }
}

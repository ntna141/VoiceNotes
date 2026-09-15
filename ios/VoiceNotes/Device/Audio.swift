import Foundation

struct AudioDescriptor {
    static let codecImaAdpcm: UInt8 = 1
    static let size = 8
    static let blockHeaderBytes = 4

    let codec: UInt8
    let channels: Int
    let sampleRate: Int
    let blockSamples: Int

    init?(_ descriptor: Data) {
        guard descriptor.count >= Self.size else { return nil }
        let bytes = Array(descriptor)
        codec = bytes[0]
        channels = Int(bytes[1])
        sampleRate = Int(bytes[2]) | (Int(bytes[3]) << 8) | (Int(bytes[4]) << 16) | (Int(bytes[5]) << 24)
        blockSamples = Int(bytes[6]) | (Int(bytes[7]) << 8)
        guard codec == Self.codecImaAdpcm, channels == 1, sampleRate > 0, blockSamples > 0, blockSamples % 2 == 0 else {
            return nil
        }
    }

    var blockBytes: Int {
        Self.blockHeaderBytes + blockSamples / 2
    }
}

final class AdpcmDecoder {
    private static let indexTable: [Int] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
    private static let stepTable: [Int32] = [
        7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
        19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
        50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
        130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
        337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
        876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
        2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
        5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
        15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
    ]

    private let format: AudioDescriptor
    private var pending = Data()
    private var predictor: Int32 = 0
    private var stepIndex = 0

    init(format: AudioDescriptor) {
        self.format = format
    }

    func decode(_ data: Data) -> [Int16] {
        pending.append(data)
        var samples: [Int16] = []
        samples.reserveCapacity(pending.count / format.blockBytes * format.blockSamples)
        while pending.count >= format.blockBytes {
            let block = pending.prefix(format.blockBytes)
            pending.removeFirst(format.blockBytes)
            decodeBlock(Array(block), into: &samples)
        }
        return samples
    }

    func silence(droppedBytes: Int) -> [Int16] {
        pending.removeAll()
        let blocks = (droppedBytes + format.blockBytes - 1) / format.blockBytes
        return [Int16](repeating: 0, count: blocks * format.blockSamples)
    }

    private func decodeBlock(_ block: [UInt8], into samples: inout [Int16]) {
        predictor = Int32(Int16(bitPattern: UInt16(block[0]) | (UInt16(block[1]) << 8)))
        stepIndex = min(Int(block[2]), Self.stepTable.count - 1)
        for byte in block[AudioDescriptor.blockHeaderBytes...] {
            samples.append(decodeSample(byte & 0x0F))
            samples.append(decodeSample(byte >> 4))
        }
    }

    private func decodeSample(_ code: UInt8) -> Int16 {
        var step = Self.stepTable[stepIndex]
        var delta = step >> 3
        if code & 4 != 0 { delta += step }
        step >>= 1
        if code & 2 != 0 { delta += step }
        step >>= 1
        if code & 1 != 0 { delta += step }
        predictor += code & 8 != 0 ? -delta : delta
        predictor = min(max(predictor, Int32(Int16.min)), Int32(Int16.max))
        stepIndex = min(max(stepIndex + Self.indexTable[Int(code)], 0), Self.stepTable.count - 1)
        return Int16(predictor)
    }
}

final class WAVWriter {
    private let handle: FileHandle
    private let sampleRate: Int
    private let channels: Int
    private(set) var dataBytes = 0

    init(url: URL, sampleRate: Int, channels: Int) throws {
        self.sampleRate = sampleRate
        self.channels = channels
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        try handle.write(contentsOf: header(dataBytes: 0))
    }

    var durationSeconds: Double {
        Double(dataBytes) / Double(sampleRate * channels * 2)
    }

    func write(_ samples: [Int16]) throws {
        guard !samples.isEmpty else { return }
        let data = samples.map(\.littleEndian).withUnsafeBytes { Data($0) }
        try handle.write(contentsOf: data)
        dataBytes += data.count
    }

    func finish() throws {
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: header(dataBytes: dataBytes))
        try handle.close()
    }

    private func header(dataBytes: Int) -> Data {
        let bytesPerFrame = channels * 2
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36 + dataBytes))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(channels))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * bytesPerFrame))
        data.appendLittleEndian(UInt16(bytesPerFrame))
        data.appendLittleEndian(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(UInt32(dataBytes))
        return data
    }
}

extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}

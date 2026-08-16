import Foundation

enum HeartRateMeasurement {
    static func parse(_ data: Data) -> Int? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }

        let isSixteenBit = bytes[0] & 0x01 != 0
        let value: Int
        if isSixteenBit {
            guard bytes.count >= 3 else { return nil }
            value = Int(bytes[1]) | (Int(bytes[2]) << 8)
        } else {
            value = Int(bytes[1])
        }
        return (1...255).contains(value) ? value : nil
    }
}

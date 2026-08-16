import Darwin
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("not ok - \(message)\n".utf8))
        exit(1)
    }
}

require(HeartRateMeasurement.parse(Data([0x00, 76])) == 76, "parses an 8-bit heart-rate measurement")
require(HeartRateMeasurement.parse(Data([0x01, 0xC8, 0x00])) == 200, "parses a 16-bit heart-rate measurement")
require(HeartRateMeasurement.parse(Data()) == nil, "rejects an empty measurement")
require(HeartRateMeasurement.parse(Data([0x01, 0xC8])) == nil, "rejects a truncated 16-bit measurement")
require(HeartRateMeasurement.parse(Data([0x00, 0x00])) == nil, "rejects an invalid zero heart rate")

print("ok - Heart Rate Menu measurement tests")

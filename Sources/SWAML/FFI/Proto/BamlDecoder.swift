// BAML FFI Decoder - converts protobuf CFFIValueHolder to JSON

import Foundation
import SwiftProtobuf

#if BAML_FFI_ENABLED

// MARK: - CFFIValueHolder Response Types

/// Value holder for FFI responses
public struct CFFIValueHolder: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.CFFIValueHolder"

    public enum Value: Equatable, @unchecked Sendable {
        case nullValue
        case stringValue(String)
        case intValue(Int64)
        case floatValue(Double)
        case boolValue(Bool)
        case classValue(CFFIValueClass)
        case enumValue(CFFIValueEnum)
        case listValue(CFFIValueList)
        case mapValue(CFFIValueMap)
        // Other types we don't need to handle for basic responses
    }

    public var value: Value?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 2:
                // null_value - just set to null
                value = .nullValue
            case 3:
                var v: String?
                try decoder.decodeSingularStringField(value: &v)
                if let v = v { value = .stringValue(v) }
            case 4:
                var v: Int64 = 0
                try decoder.decodeSingularInt64Field(value: &v)
                value = .intValue(v)
            case 5:
                var v: Double = 0
                try decoder.decodeSingularDoubleField(value: &v)
                value = .floatValue(v)
            case 6:
                var v: Bool = false
                try decoder.decodeSingularBoolField(value: &v)
                value = .boolValue(v)
            case 7:
                var v: CFFIValueClass?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .classValue(v) }
            case 8:
                var v: CFFIValueEnum?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .enumValue(v) }
            case 11:
                var v: CFFIValueList?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .listValue(v) }
            case 12:
                var v: CFFIValueMap?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .mapValue(v) }
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? CFFIValueHolder else { return false }
        return self == other
    }
}

/// Class value in response
public struct CFFIValueClass: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.CFFIValueClass"

    public var name: CFFITypeName?
    public var fields: [CFFIMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &name)
            case 2: try decoder.decodeRepeatedMessageField(value: &fields)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? CFFIValueClass else { return false }
        return self == other
    }
}

/// Enum value in response
public struct CFFIValueEnum: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.CFFIValueEnum"

    public var name: CFFITypeName?
    public var value: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &name)
            case 2: try decoder.decodeSingularStringField(value: &value)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? CFFIValueEnum else { return false }
        return self == other
    }
}

/// List value in response
public struct CFFIValueList: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.CFFIValueList"

    public var items: [CFFIValueHolder] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 2: try decoder.decodeRepeatedMessageField(value: &items)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? CFFIValueList else { return false }
        return self == other
    }
}

/// Map value in response
public struct CFFIValueMap: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.CFFIValueMap"

    public var entries: [CFFIMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 3: try decoder.decodeRepeatedMessageField(value: &entries)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? CFFIValueMap else { return false }
        return self == other
    }
}

/// Map entry
public struct CFFIMapEntry: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.CFFIMapEntry"

    public var key: String = ""
    public var value: CFFIValueHolder?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &key)
            case 2: try decoder.decodeSingularMessageField(value: &value)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? CFFIMapEntry else { return false }
        return self == other
    }
}

/// Type name wrapper
public struct CFFITypeName: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.CFFITypeName"

    public var namespace: Int32 = 0
    public var name: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &namespace)
            case 2: try decoder.decodeSingularStringField(value: &name)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? CFFITypeName else { return false }
        return self == other
    }
}

// MARK: - Convert to JSON

/// Convert CFFIValueHolder to a JSON-compatible dictionary/array/value
public func valueHolderToJSON(_ holder: CFFIValueHolder) -> Any {
    guard let value = holder.value else {
        return NSNull()
    }

    switch value {
    case .nullValue:
        return NSNull()
    case .stringValue(let s):
        return s
    case .intValue(let i):
        return i
    case .floatValue(let f):
        return f
    case .boolValue(let b):
        return b
    case .classValue(let c):
        var dict: [String: Any] = [:]
        for field in c.fields {
            if let fieldValue = field.value {
                dict[field.key] = valueHolderToJSON(fieldValue)
            }
        }
        return dict
    case .enumValue(let e):
        return e.value
    case .listValue(let l):
        return l.items.map { valueHolderToJSON($0) }
    case .mapValue(let m):
        var dict: [String: Any] = [:]
        for entry in m.entries {
            if let entryValue = entry.value {
                dict[entry.key] = valueHolderToJSON(entryValue)
            }
        }
        return dict
    }
}

/// Decode protobuf response to JSON Data
public func decodeFFIResponse(_ data: Data) throws -> Data {
    // Try to decode as CFFIValueHolder
    let holder = try CFFIValueHolder(serializedBytes: data)
    let jsonValue = valueHolderToJSON(holder)
    return try JSONSerialization.data(withJSONObject: jsonValue)
}

#endif // BAML_FFI_ENABLED

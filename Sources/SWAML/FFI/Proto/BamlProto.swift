// Generated from baml/cffi/v1/*.proto
// Swift Protobuf types for BAML FFI communication

import Foundation
import SwiftProtobuf

#if BAML_FFI_ENABLED

// MARK: - BamlObjectHandle

/// Handle to an internal BAML object (TypeBuilder, Collector, etc.)
public struct BamlObjectHandle: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.BamlObjectHandle"

    public var ptr: UInt64 = 0
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(ptr: UInt64) {
        self.ptr = ptr
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularUInt64Field(value: &ptr)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if ptr != 0 {
            try visitor.visitSingularUInt64Field(value: ptr, fieldNumber: 1)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? BamlObjectHandle else { return false }
        return self == other
    }
}

// MARK: - HostEnumValue

/// Represents an enum value
public struct HostEnumValue: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostEnumValue"

    public var name: String = ""
    public var value: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &name)
            case 2: try decoder.decodeSingularStringField(value: &value)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !name.isEmpty { try visitor.visitSingularStringField(value: name, fieldNumber: 1) }
        if !value.isEmpty { try visitor.visitSingularStringField(value: value, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostEnumValue else { return false }
        return self == other
    }
}

// MARK: - HostMapEntry

/// A key-value entry in a map
public struct HostMapEntry: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostMapEntry"

    public enum Key: Equatable, Sendable {
        case stringKey(String)
        case intKey(Int64)
        case boolKey(Bool)
        case enumKey(HostEnumValue)
    }

    public var key: Key?
    public var value: HostValue?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(stringKey: String, value: HostValue) {
        self.key = .stringKey(stringKey)
        self.value = value
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1:
                var v: String?
                try decoder.decodeSingularStringField(value: &v)
                if let v = v { key = .stringKey(v) }
            case 2:
                var v: Int64 = 0
                try decoder.decodeSingularInt64Field(value: &v)
                key = .intKey(v)
            case 3:
                var v: Bool = false
                try decoder.decodeSingularBoolField(value: &v)
                key = .boolKey(v)
            case 5:
                var v: HostEnumValue?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { key = .enumKey(v) }
            case 6:
                try decoder.decodeSingularMessageField(value: &value)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let key = key {
            switch key {
            case .stringKey(let v): try visitor.visitSingularStringField(value: v, fieldNumber: 1)
            case .intKey(let v): try visitor.visitSingularInt64Field(value: v, fieldNumber: 2)
            case .boolKey(let v): try visitor.visitSingularBoolField(value: v, fieldNumber: 3)
            case .enumKey(let v): try visitor.visitSingularMessageField(value: v, fieldNumber: 5)
            }
        }
        try visitor.visitSingularMessageField(value: value ?? HostValue(), fieldNumber: 6)
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostMapEntry else { return false }
        return self == other
    }
}

// MARK: - HostListValue

/// A list of values
public struct HostListValue: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostListValue"

    public var values: [HostValue] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(values: [HostValue]) {
        self.values = values
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &values)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !values.isEmpty { try visitor.visitRepeatedMessageField(value: values, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostListValue else { return false }
        return self == other
    }
}

// MARK: - HostMapValue

/// A map of key-value entries
public struct HostMapValue: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostMapValue"

    public var entries: [HostMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(entries: [HostMapEntry]) {
        self.entries = entries
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &entries)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !entries.isEmpty { try visitor.visitRepeatedMessageField(value: entries, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostMapValue else { return false }
        return self == other
    }
}

// MARK: - HostClassValue

/// A class instance with named fields
public struct HostClassValue: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostClassValue"

    public var name: String = ""
    public var fields: [HostMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(name: String, fields: [HostMapEntry]) {
        self.name = name
        self.fields = fields
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &name)
            case 2: try decoder.decodeRepeatedMessageField(value: &fields)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !name.isEmpty { try visitor.visitSingularStringField(value: name, fieldNumber: 1) }
        if !fields.isEmpty { try visitor.visitRepeatedMessageField(value: fields, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostClassValue else { return false }
        return self == other
    }
}

// MARK: - HostValue

/// Core value type that can hold any BAML value
public struct HostValue: @unchecked Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostValue"

    public enum Value: Equatable, @unchecked Sendable {
        case stringValue(String)
        case intValue(Int64)
        case floatValue(Double)
        case boolValue(Bool)
        case listValue(HostListValue)
        case mapValue(HostMapValue)
        case classValue(HostClassValue)
        case enumValue(HostEnumValue)
        case handle(BamlObjectHandle)
    }

    public var value: Value?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(_ value: Value) {
        self.value = value
    }

    // Convenience initializers
    public static func string(_ v: String) -> HostValue { HostValue(.stringValue(v)) }
    public static func int(_ v: Int64) -> HostValue { HostValue(.intValue(v)) }
    public static func int(_ v: Int) -> HostValue { HostValue(.intValue(Int64(v))) }
    public static func float(_ v: Double) -> HostValue { HostValue(.floatValue(v)) }
    public static func bool(_ v: Bool) -> HostValue { HostValue(.boolValue(v)) }
    public static func list(_ v: [HostValue]) -> HostValue { HostValue(.listValue(HostListValue(values: v))) }
    public static func map(_ entries: [HostMapEntry]) -> HostValue { HostValue(.mapValue(HostMapValue(entries: entries))) }
    public static func classValue(name: String, fields: [HostMapEntry]) -> HostValue {
        HostValue(.classValue(HostClassValue(name: name, fields: fields)))
    }
    public static func enumValue(name: String, value: String) -> HostValue {
        HostValue(.enumValue(HostEnumValue(name: name, value: value)))
    }
    public static var null: HostValue { HostValue() }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 2:
                var v: String?
                try decoder.decodeSingularStringField(value: &v)
                if let v = v { value = .stringValue(v) }
            case 3:
                var v: Int64 = 0
                try decoder.decodeSingularInt64Field(value: &v)
                value = .intValue(v)
            case 4:
                var v: Double = 0
                try decoder.decodeSingularDoubleField(value: &v)
                value = .floatValue(v)
            case 5:
                var v: Bool = false
                try decoder.decodeSingularBoolField(value: &v)
                value = .boolValue(v)
            case 6:
                var v: HostListValue?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .listValue(v) }
            case 7:
                var v: HostMapValue?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .mapValue(v) }
            case 8:
                var v: HostClassValue?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .classValue(v) }
            case 9:
                var v: HostEnumValue?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .enumValue(v) }
            case 10:
                var v: BamlObjectHandle?
                try decoder.decodeSingularMessageField(value: &v)
                if let v = v { value = .handle(v) }
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = value {
            switch value {
            case .stringValue(let v): try visitor.visitSingularStringField(value: v, fieldNumber: 2)
            case .intValue(let v): try visitor.visitSingularInt64Field(value: v, fieldNumber: 3)
            case .floatValue(let v): try visitor.visitSingularDoubleField(value: v, fieldNumber: 4)
            case .boolValue(let v): try visitor.visitSingularBoolField(value: v, fieldNumber: 5)
            case .listValue(let v): try visitor.visitSingularMessageField(value: v, fieldNumber: 6)
            case .mapValue(let v): try visitor.visitSingularMessageField(value: v, fieldNumber: 7)
            case .classValue(let v): try visitor.visitSingularMessageField(value: v, fieldNumber: 8)
            case .enumValue(let v): try visitor.visitSingularMessageField(value: v, fieldNumber: 9)
            case .handle(let v): try visitor.visitSingularMessageField(value: v, fieldNumber: 10)
            }
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostValue else { return false }
        return self == other
    }
}

// MARK: - HostEnvVar

/// Environment variable key-value pair
public struct HostEnvVar: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostEnvVar"

    public var key: String = ""
    public var value: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &key)
            case 2: try decoder.decodeSingularStringField(value: &value)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !key.isEmpty { try visitor.visitSingularStringField(value: key, fieldNumber: 1) }
        if !value.isEmpty { try visitor.visitSingularStringField(value: value, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostEnvVar else { return false }
        return self == other
    }
}

// MARK: - HostClientProperty

/// Client configuration property
public struct HostClientProperty: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostClientProperty"

    public var name: String = ""
    public var provider: String = ""
    public var retryPolicy: String?
    public var options: [HostMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &name)
            case 2: try decoder.decodeSingularStringField(value: &provider)
            case 3: try decoder.decodeSingularStringField(value: &retryPolicy)
            case 4: try decoder.decodeRepeatedMessageField(value: &options)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !name.isEmpty { try visitor.visitSingularStringField(value: name, fieldNumber: 1) }
        if !provider.isEmpty { try visitor.visitSingularStringField(value: provider, fieldNumber: 2) }
        if let v = retryPolicy { try visitor.visitSingularStringField(value: v, fieldNumber: 3) }
        if !options.isEmpty { try visitor.visitRepeatedMessageField(value: options, fieldNumber: 4) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostClientProperty else { return false }
        return self == other
    }
}

// MARK: - HostClientRegistry

/// Client registry for overriding default clients
public struct HostClientRegistry: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostClientRegistry"

    public var primary: String?
    public var clients: [HostClientProperty] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &primary)
            case 2: try decoder.decodeRepeatedMessageField(value: &clients)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = primary { try visitor.visitSingularStringField(value: v, fieldNumber: 1) }
        if !clients.isEmpty { try visitor.visitRepeatedMessageField(value: clients, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostClientRegistry else { return false }
        return self == other
    }
}

// MARK: - HostFunctionArguments

/// Function arguments for BAML function calls
public struct HostFunctionArguments: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.HostFunctionArguments"

    /// Named function arguments
    public var kwargs: [HostMapEntry] = []
    /// Client registry override
    public var clientRegistry: HostClientRegistry?
    /// Environment variables
    public var env: [HostEnvVar] = []
    /// Collectors (internal)
    public var collectors: [BamlObjectHandle] = []
    /// Type builder (internal) - uses V2 format with typed pointer
    public var typeBuilder: BamlObjectHandleV2?
    /// Tags for tracing
    public var tags: [HostMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(kwargs: [HostMapEntry]) {
        self.kwargs = kwargs
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &kwargs)
            case 2: try decoder.decodeSingularMessageField(value: &clientRegistry)
            case 3: try decoder.decodeRepeatedMessageField(value: &env)
            case 4: try decoder.decodeRepeatedMessageField(value: &collectors)
            case 5: try decoder.decodeSingularMessageField(value: &typeBuilder)
            case 6: try decoder.decodeRepeatedMessageField(value: &tags)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !kwargs.isEmpty { try visitor.visitRepeatedMessageField(value: kwargs, fieldNumber: 1) }
        if let v = clientRegistry { try visitor.visitSingularMessageField(value: v, fieldNumber: 2) }
        if !env.isEmpty { try visitor.visitRepeatedMessageField(value: env, fieldNumber: 3) }
        if !collectors.isEmpty { try visitor.visitRepeatedMessageField(value: collectors, fieldNumber: 4) }
        if let v = typeBuilder { try visitor.visitSingularMessageField(value: v, fieldNumber: 5) }
        if !tags.isEmpty { try visitor.visitRepeatedMessageField(value: tags, fieldNumber: 6) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? HostFunctionArguments else { return false }
        return self == other
    }
}

// MARK: - InvocationResponse

/// Response from FFI invocation
public struct InvocationResponse: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.InvocationResponse"

    public enum Response: Equatable, Sendable {
        case error(String)
    }

    public var response: Response?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1:
                var v: String?
                try decoder.decodeSingularStringField(value: &v)
                if let v = v { response = .error(v) }
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let response = response {
            switch response {
            case .error(let v): try visitor.visitSingularStringField(value: v, fieldNumber: 1)
            }
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? InvocationResponse else { return false }
        return self == other
    }
}

// MARK: - BamlObjectType

/// Enum for all possible BAML object types
public enum BamlObjectType: Int, Sendable {
    case unspecified = 0
    case collector = 1
    case functionLog = 2
    case usage = 3
    case timing = 4
    case streamTiming = 5
    case llmCall = 6
    case llmStreamCall = 7
    case httpRequest = 8
    case httpResponse = 9
    case httpBody = 10
    case sseResponse = 11
    case mediaImage = 12
    case mediaAudio = 13
    case mediaPdf = 14
    case mediaVideo = 15
    case typeBuilder = 16
    case type = 17
    case enumBuilder = 18
    case enumValueBuilder = 19
    case classBuilder = 20
    case classPropertyBuilder = 21
}

// MARK: - BamlPointerType

/// Raw pointer type for BAML object handles
public struct BamlPointerType: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.BamlPointerType"

    public var pointer: Int64 = 0
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(pointer: Int64) {
        self.pointer = pointer
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt64Field(value: &pointer)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if pointer != 0 {
            try visitor.visitSingularInt64Field(value: pointer, fieldNumber: 1)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? BamlPointerType else { return false }
        return self == other
    }
}

// MARK: - BamlObjectHandleV2

/// Handle to an internal BAML object with typed oneof (matches actual BAML proto)
public struct BamlObjectHandleV2: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.BamlObjectHandle"

    public enum Object: Equatable, Sendable {
        case collector(BamlPointerType)
        case functionLog(BamlPointerType)
        case usage(BamlPointerType)
        case timing(BamlPointerType)
        case streamTiming(BamlPointerType)
        case llmCall(BamlPointerType)
        case llmStreamCall(BamlPointerType)
        case httpRequest(BamlPointerType)
        case httpResponse(BamlPointerType)
        case httpBody(BamlPointerType)
        case sseResponse(BamlPointerType)
        case mediaImage(BamlPointerType)
        case mediaAudio(BamlPointerType)
        case mediaPdf(BamlPointerType)
        case mediaVideo(BamlPointerType)
        case typeBuilder(BamlPointerType)
        case type(BamlPointerType)
        case enumBuilder(BamlPointerType)
        case enumValueBuilder(BamlPointerType)
        case classBuilder(BamlPointerType)
        case classPropertyBuilder(BamlPointerType)
    }

    public var object: Object?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(typeBuilder pointer: Int64) {
        self.object = .typeBuilder(BamlPointerType(pointer: pointer))
    }

    public init(enumBuilder pointer: Int64) {
        self.object = .enumBuilder(BamlPointerType(pointer: pointer))
    }

    /// Get the raw pointer value regardless of object type
    public var pointer: Int64 {
        switch object {
        case .collector(let p), .functionLog(let p), .usage(let p), .timing(let p),
             .streamTiming(let p), .llmCall(let p), .llmStreamCall(let p),
             .httpRequest(let p), .httpResponse(let p), .httpBody(let p),
             .sseResponse(let p), .mediaImage(let p), .mediaAudio(let p),
             .mediaPdf(let p), .mediaVideo(let p), .typeBuilder(let p),
             .type(let p), .enumBuilder(let p), .enumValueBuilder(let p),
             .classBuilder(let p), .classPropertyBuilder(let p):
            return p.pointer
        case .none:
            return 0
        }
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            var ptrType: BamlPointerType?
            try decoder.decodeSingularMessageField(value: &ptrType)
            guard let ptr = ptrType else { continue }

            switch fieldNumber {
            case 1: object = .collector(ptr)
            case 2: object = .functionLog(ptr)
            case 3: object = .usage(ptr)
            case 4: object = .timing(ptr)
            case 5: object = .streamTiming(ptr)
            case 6: object = .llmCall(ptr)
            case 7: object = .llmStreamCall(ptr)
            case 8: object = .httpRequest(ptr)
            case 9: object = .httpResponse(ptr)
            case 10: object = .httpBody(ptr)
            case 11: object = .sseResponse(ptr)
            case 12: object = .mediaImage(ptr)
            case 13: object = .mediaAudio(ptr)
            case 14: object = .mediaPdf(ptr)
            case 15: object = .mediaVideo(ptr)
            case 16: object = .typeBuilder(ptr)
            case 17: object = .type(ptr)
            case 18: object = .enumBuilder(ptr)
            case 19: object = .enumValueBuilder(ptr)
            case 20: object = .classBuilder(ptr)
            case 21: object = .classPropertyBuilder(ptr)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let object = object {
            switch object {
            case .collector(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 1)
            case .functionLog(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 2)
            case .usage(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 3)
            case .timing(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 4)
            case .streamTiming(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 5)
            case .llmCall(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 6)
            case .llmStreamCall(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 7)
            case .httpRequest(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 8)
            case .httpResponse(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 9)
            case .httpBody(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 10)
            case .sseResponse(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 11)
            case .mediaImage(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 12)
            case .mediaAudio(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 13)
            case .mediaPdf(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 14)
            case .mediaVideo(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 15)
            case .typeBuilder(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 16)
            case .type(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 17)
            case .enumBuilder(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 18)
            case .enumValueBuilder(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 19)
            case .classBuilder(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 20)
            case .classPropertyBuilder(let p): try visitor.visitSingularMessageField(value: p, fieldNumber: 21)
            }
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? BamlObjectHandleV2 else { return false }
        return self == other
    }
}

// MARK: - BamlObjectConstructorInvocation

/// Request to construct a BAML object (TypeBuilder, Collector, etc.)
public struct BamlObjectConstructorInvocation: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.BamlObjectConstructorInvocation"

    public var type: Int32 = 0  // BamlObjectType raw value
    public var kwargs: [HostMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(type: BamlObjectType, kwargs: [HostMapEntry] = []) {
        self.type = Int32(type.rawValue)
        self.kwargs = kwargs
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &type)
            case 2: try decoder.decodeRepeatedMessageField(value: &kwargs)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if type != 0 {
            try visitor.visitSingularInt32Field(value: type, fieldNumber: 1)
        }
        if !kwargs.isEmpty {
            try visitor.visitRepeatedMessageField(value: kwargs, fieldNumber: 2)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? BamlObjectConstructorInvocation else { return false }
        return self == other
    }
}

// MARK: - BamlObjectMethodInvocation

/// Request to invoke a method on a BAML object
public struct BamlObjectMethodInvocation: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.BamlObjectMethodInvocation"

    public var object: BamlObjectHandleV2?
    public var methodName: String = ""
    public var kwargs: [HostMapEntry] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public init(object: BamlObjectHandleV2, methodName: String, kwargs: [HostMapEntry] = []) {
        self.object = object
        self.methodName = methodName
        self.kwargs = kwargs
    }

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &object)
            case 2: try decoder.decodeSingularStringField(value: &methodName)
            case 3: try decoder.decodeRepeatedMessageField(value: &kwargs)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = object { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        if !methodName.isEmpty { try visitor.visitSingularStringField(value: methodName, fieldNumber: 2) }
        if !kwargs.isEmpty { try visitor.visitRepeatedMessageField(value: kwargs, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? BamlObjectMethodInvocation else { return false }
        return self == other
    }
}

// MARK: - ObjectInvocationResponse

/// Response from object constructor or method invocation
public struct ObjectInvocationResponse: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.InvocationResponse"

    public enum Response: Equatable, Sendable {
        case success(BamlObjectHandleV2)
        case error(String)
    }

    public var response: Response?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1:
                // Success case - nested message with object handle
                var successMsg: ObjectInvocationResponseSuccess?
                try decoder.decodeSingularMessageField(value: &successMsg)
                if let success = successMsg, let obj = success.object {
                    response = .success(obj)
                }
            case 2:
                var errorStr: String?
                try decoder.decodeSingularStringField(value: &errorStr)
                if let error = errorStr { response = .error(error) }
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let response = response {
            switch response {
            case .success(let obj):
                var success = ObjectInvocationResponseSuccess()
                success.object = obj
                try visitor.visitSingularMessageField(value: success, fieldNumber: 1)
            case .error(let v):
                try visitor.visitSingularStringField(value: v, fieldNumber: 2)
            }
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? ObjectInvocationResponse else { return false }
        return self == other
    }
}

// MARK: - ObjectInvocationResponseSuccess

/// Success wrapper for object invocation response
public struct ObjectInvocationResponseSuccess: Sendable, Equatable, SwiftProtobuf.Message {
    public static let protoMessageName: String = "baml.cffi.v1.InvocationResponseSuccess"

    public var object: BamlObjectHandleV2?
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public init() {}

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &object)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = object { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? ObjectInvocationResponseSuccess else { return false }
        return self == other
    }
}

#endif // BAML_FFI_ENABLED

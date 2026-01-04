import Foundation

public struct EncryptedValue<T: Codable>: Codable {
    public let encrypted: Data
    private let provider: EncryptionProvider?
    
    public init(_ value: T, provider: EncryptionProvider? = nil) throws {
        let encoded = try JSONEncoder().encode(value)
        let provider = provider ?? EncryptionManager.shared.instance
        self.encrypted = try provider.encrypt(encoded)
        self.provider = provider
    }
    
    public init(from decoder: any Decoder) throws {
        let decoder = try decoder.container(keyedBy: CodingKeys.self)
        let data = try decoder.decode(Data.self, forKey: .encrypted)
        self.encrypted = data
        self.provider = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var encoder = encoder.container(keyedBy: CodingKeys.self)
        try encoder.encode(self.encrypted, forKey: .encrypted)
    }
    
    public func decrypt() throws -> T {
        let provider = provider ?? EncryptionManager.shared.instance
        let decrypted = try provider.decrypt(encrypted)
        return try JSONDecoder().decode(T.self, from: decrypted)
    }
    
    public enum CodingKeys: CodingKey {
        case encrypted
    }
}

@propertyWrapper
public class Encrypted<T: Codable>: EncryptedValueType {
    public typealias WrappedType = T
    private let provider: EncryptionProvider?
    public var encryptedData: Data
    private var decrypted: T?
    
    public var wrappedValue: T {
        get {
            return try! read()
        }
        set {
            try! write(newValue)
        }
    }
    
    private func read() throws -> T {
        if let decrypted { return decrypted }
        let provider = provider ?? EncryptionManager.shared.instance
        let result = try JSONDecoder().decode(T.self, from: provider.decrypt(encryptedData))
        decrypted = result
        return result
    }
    
    private func write(_ newValue: T) throws {
        let provider = provider ?? EncryptionManager.shared.instance
        let encoded = try JSONEncoder().encode(newValue)
        decrypted = newValue
        encryptedData = try provider.encrypt(encoded)
    }
    
    public init(wrappedValue: T, provider: EncryptionProvider? = nil) {
        self.provider = provider
        let provider = provider ?? EncryptionManager.shared.instance
        do {
            let encoded = try JSONEncoder().encode(wrappedValue)
            self.encryptedData = try provider.encrypt(encoded)
        } catch let error as EncodingError {
            fatalError(error.localizedDescription)
        } catch let error as EncryptionError {
            fatalError(error.description)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    required public init?(fromPersistent representation: Data) {
        self.encryptedData = representation
        self.provider = nil
    }
}

extension Encrypted: Persistable, ColumnType where WrappedType: Persistable {
    public var sqliteTypeRepresentation: Data {
        encryptedData
    }
    
    public typealias SQLiteType = Data
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Self {
        let data = try Data.decode(sqliteValue: sqliteValue)
        return Self(fromPersistent: data)!
    }
    
    public typealias PersistentRepresentation = Data
    
    public var asPersistentRepresentation: PersistentRepresentation {
        encryptedData
    }
    
    public static var sqliteTypeName: SQLiteTypeName { .blob }
    
    public var sqliteValue: SQLiteValue {
        .blob(encryptedData)
    }
    
    enum CodingKeys: String, CodingKey {
        case encryptedData
    }
}

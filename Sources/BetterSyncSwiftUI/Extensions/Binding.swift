import SwiftUI
import BetterSync

public extension Binding where Value: EncryptedValueType {
    var decrypted: Binding<Value.WrappedType> {
        Binding<Value.WrappedType> (
            get: { self.wrappedValue.wrappedValue },
            set: { self.wrappedValue.wrappedValue = $0 }
        )
    }
}


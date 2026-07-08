#if canImport(SwiftUI)
    import Foundation
    @_exported import Vein
    import SwiftUI

    extension LazyField {
        public var projectedValue: Binding<WrappedType> {
            Binding<WrappedType> (
                get: {
                    self.wrappedValue
                },
                set: { newValue in
                    self.wrappedValue = newValue
                }
            )
        }
    }

    extension Field {
        public var projectedValue: Binding<WrappedType> {
            Binding<WrappedType> (
                get: {
                    self.wrappedValue
                },
                set: { newValue in
                    self.wrappedValue = newValue
                }
            )
        }
    }

    extension _OneRelationship {
        public var projectedValue: Binding<Value> {
            Binding<Value> (
                get: {
                    self.wrappedValue
                },
                set: { newValue in
                    self.wrappedValue = newValue
                }
            )
        }
    }

    extension _ManyRelationship {
        public var projectedValue: Binding<Value> {
            Binding<Value> (
                get: {
                    self.wrappedValue
                },
                set: { newValue in
                    self.wrappedValue = newValue
                }
            )
        }
    }
#endif

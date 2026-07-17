// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

#if canImport(SwiftUI)
    import Foundation
    @_exported import Vein
    import SwiftUI

    extension LazyField {
        public var projectedValue: Binding<WrappedType> {
            Binding<WrappedType>(
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
            Binding<WrappedType>(
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
            Binding<Value>(
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
            Binding<Value>(
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

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

import Foundation
import SQLiteDB

public enum SortDescriptorConversionError: Error {
    case invalidKeyPath
    case noFieldInformation
}

extension SortDescriptor where Compared: PersistentModel {
    var expressible: (any Expressible) {
        get throws(SortDescriptorConversionError) {
            guard let keyPath else { throw .invalidKeyPath }
            guard let information = Compared._predicateInformation(for: keyPath) else {
                throw .noFieldInformation
            }

            var expressible: any Expressible

            if let stringComparator {
                expressible = switch stringComparator {
                    case .lexical:
                        information.fetchExpressible(collatedBy: .binary)
                    #if os(Darwin)
                        case .localizedStandard, .localized:
                            information.fetchExpressible(collatedBy: .nocase)
                    #endif
                    default: information.fetchExpressible
                }
            } else {
                expressible = information.fetchExpressible
            }

            if order == .forward {
                return expressible.expression.asc
            }

            return expressible.expression.desc
        }
    }
}

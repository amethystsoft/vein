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
    import SwiftUI
    import Combine
    import Logging

    /// Fetches all instances of the attached model type matching the provided Predicate.
    @MainActor
    @propertyWrapper
    public struct Query<M: PersistentModel>: DynamicProperty {
        public typealias WrappedType = [M]
        @StateObject var queryObserver: QueryObserver<M>
        @Environment(\.modelContext) var context

        public var wrappedValue: [M] {
            if let results = queryObserver.results {
                return results.sorted(by: { $0.id < $1.id })
            }
            if queryObserver.results == nil && queryObserver.primaryObserver == nil {
                queryObserver.initialize(with: context)
            }
            return (queryObserver.primaryObserver?.results ?? queryObserver.results ?? [])
                .sorted(by: { $0.id < $1.id })
        }

        public init(_ predicate: ModelPredicate<M> = ModelPredicate<M>.all) {
            self._queryObserver = StateObject(wrappedValue: QueryObserver<M>(predicate))
        }

        public init(_ predicate: Predicate<M>) {
            do {
                let modelPredicate = try ModelPredicate(predicate)
                self._queryObserver = StateObject(wrappedValue: QueryObserver(modelPredicate))
            } catch {
                fatalError(
                    "Creating ModelPredicate from predicate '\(predicate.expression)' failed with: \(error.localizedDescription)"
                )
            }
        }
    }

    package final class QueryObserver<M: PersistentModel>: ObservableObject, @unchecked Sendable {
        typealias ModelType = M
        public let objectWillChange = PassthroughSubject<Void, Never>()
        static var logger: Logger { Logger(label: "Vein.QueryObserver<\(M.self)>") }

        private var publishToEnclosingObserver: (() -> Void)?

        fileprivate var primaryObserver: QueryObserver<M>?

        let predicate: ModelPredicate<M>

        public var usedPredicate: any AnyPredicateBuilder { predicate }

        @MainActor
        package var results: [M]? = nil

        @MainActor
        func initialize(with context: ManagedObjectContext) {
            guard results == nil && primaryObserver == nil else { return }

            guard let primary = context.getOrCreateQueryObserver(
                for: M.typeIdentifier,
                predicate.hashValue,
                createWith: {
                    return self
                }
            ) as? Self else {
                fatalError(
                    "Type mismatch: expected QueryObserver<\(M.self)>, got incompatible observer"
                )
            }

            if primary !== self {
                self.primaryObserver = primary
                let old = primary.publishToEnclosingObserver
                primary.publishToEnclosingObserver = { [weak self] in
                    old?()
                    self?.objectWillChange.send()
                }
            } else {
                fetchInitialResults(with: context)
            }
        }

        @MainActor
        private func fetchInitialResults(with context: ManagedObjectContext) {
            do {
                let initialResults = try context.fetchAll(predicate)
                self.results = initialResults
            } catch {
                if context.modelContainer.logConfiguration.modelContextErrors {
                    Self.logger
                        .error(
                            "Failed to fetch initial query results: \(error.localizedDescription)"
                        )
                }
                self.results = []
            }
        }

        @MainActor
        package func append(_ models: [M]) {
            // there is only one Query instance kept in the context for the same filter.
            // this triggers view updates on any other Query oberservers using the registered
            // Query as their source
            publishToEnclosingObserver?()
            objectWillChange.send()
            results?.append(contentsOf: models.filter {
                return predicate.runtimeFilter($0)
            })
        }

        @MainActor
        package func appendAny(_ models: [AnyObject]) {
            guard let typedModels = models as? [M] else { return }
            append(typedModels)
        }

        package init(_ predicate: ModelPredicate<M>) {
            self.predicate = predicate
        }

        @MainActor
        package func handleUpdate(_ model: any PersistentModel, matchedBeforeChange: Bool) {
            guard let model = model as? ModelType else { return }

            let matchesNow = predicate.runtimeFilter(model)
            guard matchesNow || matchedBeforeChange else { return }

            publishToEnclosingObserver?()
            objectWillChange.send()

            if matchesNow {
                if !matchedBeforeChange {
                    results?.append(model)
                }
            } else if matchedBeforeChange {
                results?.removeAll(where: { $0.id == model.id })
            }
        }

        @MainActor
        package func doesMatch(_ model: any PersistentModel) -> Bool {
            guard let model = model as? ModelType else { return false }
            return predicate.runtimeFilter(model)
        }

        @MainActor
        package func remove(_ model: any PersistentModel) {
            guard let model = model as? ModelType else { return }
            publishToEnclosingObserver?()
            objectWillChange.send()
            results?.removeAll(where: { $0.id == model.id })
        }
    }

    extension QueryObserver: @MainActor AnyQueryObserver {}

    public struct ContainerKey: EnvironmentKey {
        public static let defaultValue: Vein.ModelContainer? = nil
    }

    extension EnvironmentValues {
        public var modelContainer: Vein.ModelContainer? {
            get {
                self[ContainerKey.self]
            }
            set { self[ContainerKey.self] = newValue }
        }
    }

    extension EnvironmentValues {
        public var modelContext: ManagedObjectContext {
            guard let container = modelContainer else {
                fatalError(
                    "Tried to access 'EnvironmentValues.modelContainer' without it being set in the environment."
                )
            }
            return container.context
        }
    }

    public struct VeinContainer<Content: View>: View {
        @Environment(\.modelContainer) private var container
        @State private var isInitialized: Bool = false
        @State var error: Error?
        private let content: () -> Content
        static var logger: Logger { Logger(label: "Vein.VeinContainer") }

        public init(@ViewBuilder content: @escaping () -> Content ) {
            self.content = content
        }

        public var body: some View {
            if container != nil, isInitialized {
                content()
            } else if let container = container {
                if let error = error as? LocalizedError {
                    Text("An error occurred while migrating database:").font(.title3)
                    if let errorDescription = error.errorDescription {
                        Text(errorDescription).foregroundStyle(.red)
                    }
                    if let failureReason = error.failureReason {
                        Text(failureReason).foregroundStyle(.secondary)
                    }
                    if let recoverySuggestion = error.recoverySuggestion {
                        Text(recoverySuggestion).foregroundStyle(.secondary)
                    }
                } else if let error {
                    Text("An error occurred while migrating database:").font(.title3)
                    Text(error.localizedDescription).foregroundStyle(.red)
                } else {
                    ProgressView()
                        .task {
                            do {
                                try container.migrate()
                                isInitialized = true
                            } catch {
                                self.error = error
                                if container.logConfiguration.modelContextErrors {
                                    // swiftlint:disable line_length
                                    Self.logger
                                        .error(
                                            "An error occurred during migration of ModelContainer with version \(container.versionedSchema) and MigrationPlan \(container.migration): \(error.localizedDescription)"
                                        )
                                    // swiftlint:enable line_length
                                }
                            }
                        }
                }
            } else {
                ProgressView()
            }
        }
    }

    extension VeinContainer {
        public func modelContainer(_ container: Vein.ModelContainer) -> some View {
            self.environment(\.modelContainer, container)
        }
    }
#endif

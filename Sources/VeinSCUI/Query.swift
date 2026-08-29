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

#if VeinSCUI
    import SwiftCrossUI
    import Vein
    import Logging
    import Foundation

    #if VeinFilter
        import VeinFilter
    #endif

    @MainActor
    @propertyWrapper
    public class Query<M: PersistentModel>: @MainActor ObservableProperty {
        public var didChange: SwiftCrossUI.Publisher {
            queryObserver.didChange
        }

        public func update(
            with environment: SwiftCrossUI.EnvironmentValues,
            previousValue: Query<M>?
        ) {
            guard let context = environment[ContainerKey.self]?.context else {
                fatalError("Missing model container in environment")
            }
            self.context = context
        }

        public typealias WrappedType = [M]
        var queryObserver: QueryObserver<M>
        var context: ManagedObjectContext?
        let sortDescriptors: [SortRule<M>]

        public var wrappedValue: [M] {
            if let results = queryObserver.results {
                return results.sorted(using: sortDescriptors)
            }
            if queryObserver.results == nil && queryObserver.primaryObserver == nil {
                guard let context else {
                    fatalError("Missing model container in environment.")
                }
                queryObserver.initialize(with: context)
            }
            return (queryObserver.primaryObserver?.results ?? queryObserver.results ?? [])
                .sorted(using: sortDescriptors)
        }

        @available(macOS 14, iOS 17, tvOS 17, macCatalyst 17, *)
        public init(
            _ predicate: Predicate<M>,
            sortBy rules: [SortRule<M>] = [SortRule<M>(\.id)]
        ) {
            do {
                let modelPredicate = try ModelPredicate(predicate)
                self.queryObserver = QueryObserver(modelPredicate)
                self.sortDescriptors = rules
            } catch {
                fatalError(
                    "Creating ModelPredicate from predicate '\(predicate.expression)' failed with: \(error.localizedDescription)"
                )
            }
        }

        #if VeinFilter
            public init(
                _ predicate: Filter1<M>,
                sortBy rules: [SortRule<M>] = [SortRule<M>(\.id)]
            ) {
                do {
                    let modelPredicate = try ModelPredicate(predicate)
                    self.queryObserver = QueryObserver(modelPredicate)
                    self.sortDescriptors = rules
                } catch {
                    fatalError(
                        "Creating ModelPredicate from predicate '\(predicate.expression)' failed with: \(error.localizedDescription)"
                    )
                }
            }
        #endif

        public init(
            _ predicate: ModelPredicate<M> = ModelPredicate<M>.all,
            sortBy descriptors: [SortRule<M>] = [SortRule<M>(\.id)]
        ) {
            self.queryObserver = QueryObserver<M>(predicate)
            self.sortDescriptors = descriptors
        }
    }

    package final class QueryObserver<M: PersistentModel>: @unchecked Sendable {
        var id = UUID()
        var didChange = Publisher()
        static var logger: Logger { Logger(label: "Vein.QueryObserver<\(M.self)>") }

        typealias ModelType = M

        private let enclosingObservers = Mutex([UUID: () -> Void]())

        var primaryObserver: QueryObserver<M>?

        let predicate: ModelPredicate<M>

        public var usedPredicate: any AnyPredicateBuilder { predicate }

        @MainActor
        package var results: [M]? = nil

        @MainActor
        func initialize(with context: ManagedObjectContext) {
            guard results == nil && primaryObserver == nil else { return }

            guard let primary = context.getOrCreateQueryObserver(
                for: M.typeIdentifier,
                predicate.identity,
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
                primary.enclosingObservers.mutate { observers in
                    observers[id] = { [weak self] in
                        self?.didChange.send()
                    }
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
            results?.append(contentsOf: models.filter {
                return predicate.runtimeFilter($0)
            })
            // there is only one Query instance kept in the context for the same filter.
            // this triggers view updates on any other Query oberservers using the registered
            // Query as their source
            publishToEnclosingObserver()
            didChange.send()
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

            if matchesNow {
                if !matchedBeforeChange {
                    results?.append(model)
                }
            } else if matchedBeforeChange {
                results?.removeAll(where: { $0.id == model.id })
            }

            publishToEnclosingObserver()
            didChange.send()
        }

        @MainActor
        package func doesMatch(_ model: any PersistentModel) -> Bool {
            guard let model = model as? ModelType else { return false }
            return predicate.runtimeFilter(model)
        }

        @MainActor
        package func remove(_ model: any PersistentModel) {
            guard let model = model as? ModelType else { return }
            results?.removeAll(where: { $0.id == model.id })

            publishToEnclosingObserver()
            didChange.send()
        }

        func publishToEnclosingObserver() {
            let observers = enclosingObservers.mutate { $0.values }
            for publish in observers {
                publish()
            }
        }

        deinit {
            guard let primaryObserver else { return }
            primaryObserver.enclosingObservers.mutate { observers in
                observers[id] = nil
            }
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
                    Text("An error occured while migrating database:").font(.title3)
                    if let errorDescription = error.errorDescription {
                        Text(errorDescription).foregroundColor(.red)
                    }
                    if let failureReason = error.failureReason {
                        Text(failureReason).foregroundColor(.gray)
                    }
                    if let recoverySuggestion = error.recoverySuggestion {
                        Text(recoverySuggestion).foregroundColor(.gray)
                    }
                } else if let error {
                    Text("An error occured while migrating database:").font(.title3)
                    Text(error.localizedDescription).foregroundColor(.red)
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

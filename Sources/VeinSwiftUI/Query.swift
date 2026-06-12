#if canImport(SwiftUI)
import SwiftUI
import Combine
import Vein
import os.log

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
        return (queryObserver.primaryObserver?.results ?? queryObserver.results ?? []).sorted(by: { $0.id < $1.id })
    }
    
    public init(_ predicate: M._PredicateHelper = M._PredicateHelper()) {
        self._queryObserver = StateObject(wrappedValue: QueryObserver<M>(predicate._builder()))
    }
}

package final class QueryObserver<M: PersistentModel>: ObservableObject, @unchecked Sendable {
    typealias ModelType = M
    public let objectWillChange = PassthroughSubject<Void, Never>()
    
    private var publishToEnclosingObserver: (() -> Void)?
    
    fileprivate var primaryObserver: QueryObserver<M>?
    
    let predicate: PredicateBuilder<M>
    
    public var usedPredicate: AnyPredicateBuilder { predicate }
    
    @MainActor
    package var results: [M]? = nil
    
    @MainActor
    func initialize(with context: ManagedObjectContext) {
        guard results == nil && primaryObserver == nil else { return }
        
        let primary = context.getOrCreateQueryObserver(
            for: M.typeIdentifier,
            predicate.hashValue,
            createWith: {
                return self
            }
        ) as! Self
        
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
            os_log(.error, "Failed to fetch initial query results: %{public}@", error.localizedDescription)
            self.results = []
        }
    }
    
    
    @MainActor
    package func append(_ models: [M]) {
        results?.append(contentsOf: models.filter{ predicate.doesMatch($0) })
        // there is only one Query instance kept in the context for the same filter.
        // this triggers view updates on any other Query oberservers using the registered
        // Query as their source
        publishToEnclosingObserver?()
        objectWillChange.send()
    }
    
    @MainActor
    package func appendAny(_ models: [AnyObject]) {
        guard let typedModels = models as? [M] else { return }
        append(typedModels)
    }
    
    package init(_ predicate: PredicateBuilder<M>) {
        self.predicate = predicate
    }
    
    @MainActor
    package func handleUpdate(_ model: any PersistentModel, matchedBeforeChange: Bool) {
        guard let model = model as? ModelType else { return }
        if predicate.doesMatch(model) {
            if !matchedBeforeChange {
                results?.append(model)
            }
        } else if matchedBeforeChange {
            results?.removeAll(where: { $0.id == model.id })
        }
        publishToEnclosingObserver?()
        objectWillChange.send()
    }
    
    @MainActor
    package func doesMatch(_ model: any PersistentModel) -> Bool {
        guard let model = model as? ModelType else { return false }
        return predicate.doesMatch(model)
    }
    
    @MainActor
    package func remove(_ model: any PersistentModel) {
        guard let model = model as? ModelType else { return }
        results?.removeAll(where: { $0.id == model.id })
        publishToEnclosingObserver?()
        objectWillChange.send()
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
            fatalError("Tried to access 'EnvironmentValues.modelContainer' without it being set in the environment.")
        }
        return container.context
    }
}

public struct VeinContainer<Content: View>: View {
    @Environment(\.modelContainer) private var container
    @State private var isInitialized: Bool = false
    @State var error: Error?
    private let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content ) {
        self.content = content
    }
    
    public var body: some View {
        if let _ = container, isInitialized {
            content()
        } else if let container = container {
            Text("An error occurred while migrating database:").font(.title3)
            if let error = error as? LocalizedError {
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
                Text(error.localizedDescription).foregroundStyle(.red)
            } else {
                ProgressView()
                    .onAppear {
                        do {
                            try container.migrate()
                            isInitialized = true
                        } catch {
                            self.error = error
                            print(error.localizedDescription)
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

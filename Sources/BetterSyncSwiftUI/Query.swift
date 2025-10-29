import SwiftUI
import Combine
import BetterSync
import os.log

@MainActor
@propertyWrapper
public struct Query<M: PersistentModel>: DynamicProperty {
    public typealias WrappedType = [M]
    @StateObject var queryObserver: QueryObserver<M>
    @Environment(\.modelContext) var context
    
    public var wrappedValue: [M] {
        if let results = queryObserver.results {
            return results
        }
        do {
            if queryObserver.results == nil && queryObserver.primaryObserver == nil {
                queryObserver.initialize(with: context)
            }
            return queryObserver.primaryObserver?.results ?? queryObserver.results ?? []
        } catch {
            fatalError(error.localizedDescription)
        }
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
    
    @MainActor
    public var results: [M]? = nil
    
    @MainActor
    func initialize(with context: ManagedObjectContext) {
        guard results == nil && primaryObserver == nil else { return }
        
        let primary = context.getOrCreateQueryObserver(predicate.hashValue, createWith: {
            return self
        }) as! Self
        
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
        let initialResults = try! context.fetchAll(predicate)
        self.results = initialResults
    }
    
    
    @MainActor
    package func append(_ model: [M]) {
        results?.append(contentsOf: model)
        // there is only one Query instance kept in the context for the same filter.
        // this triggers view updates on any other Query oberservers using the registered
        // Query as their source
        publishToEnclosingObserver?()
        objectWillChange.send()
    }
    
    @MainActor
    package func appendAny(_ models: [AnyObject]) {
        guard let typedModel = models as? [M] else { return }
        append(typedModel)
    }
    
    public init(_ predicate: PredicateBuilder<M>) {
        self.predicate = predicate
    }
}

@MainActor
extension QueryObserver: AnyQueryObserver {}

public struct ContainerKey: EnvironmentKey {
    public static let defaultValue: BetterSync.ModelContainer? = nil
}

extension EnvironmentValues {
    public var modelContainer: BetterSync.ModelContainer? {
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

extension BetterSyncContainer {
    public func modelContainer(_ container: BetterSync.ModelContainer) -> some View {
        self.environment(\.modelContainer, container)
    }
}

public struct BetterSyncContainer<Content: View>: View {
    @Environment(\.modelContainer) private var container
    @State private var isInitialized: Bool = false
    private let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content ) {
        self.content = content
    }
    
    public var body: some View {
        if let container, isInitialized {
            content()
        } else if let container = container {
            ProgressView()
                .task {
                    do {
                        try await container.migrate()
                    } catch {
                        print(error.localizedDescription)
                    }
                    isInitialized = true
                }
        } else {
            ProgressView()
        }
    }
}

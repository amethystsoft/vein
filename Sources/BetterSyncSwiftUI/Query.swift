import SwiftUI
import BetterSync

@MainActor
@propertyWrapper
public class Query<M: PersistentModel>: DynamicProperty {
    public typealias WrappedType = [M]
    
    @State private var items = WrappedType()
    
    @State private var task: Task<Void, Never>?
    
    public var wrappedValue: [M] {
        items
    }
    
    public var projectedValue: Binding<[M]> {
        Binding(
            get: { self.items },
            set: { self.items = $0 }
        )
    }
    
    // must be called at View.onAppear time
    public func load() {
        task = Task {
            do {
                let fetched = try await ManagedObjectContext.instance.fetchAll(M.self)
                await MainActor.run {
                    self.items = fetched
                }
                // Subscribe to changes
                await setupObserver()
            } catch {
                print("Query fetch error: \(error)")
            }
        }
    }
    
    private func setupObserver() async {
        /*await ManagedObjectContext.instance.observeChanges(for: M.schema) { [weak self] _ in
            self?.load()
        }*/
    }
    
    public init() { }
}


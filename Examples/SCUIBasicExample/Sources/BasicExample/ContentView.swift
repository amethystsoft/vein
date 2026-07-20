import Foundation
import SwiftCrossUI
import VeinSCUI


struct ContentView: View {
    @Query
    var testItems: [Test]
    @State var stop = false
    @Environment(\.modelContext) var context
    
    init(predicate: Predicate<Test> = #Predicate<Test> { _ in true }) {
        self._testItems = Query<Test>(predicate)
    }
    
    var body: some View {
        VStack {
            Text("\(testItems.count)")
            Button("generate") {
                stop = false
                Task {
                    for _ in 0...30 {
                        if stop { return }
                        try? context.insert(Test(
                            flag: Int.random(in: 0...1) > 0,
                            randomValue: Int.random(in: 0...1000)
                        ))
                        await Task.yield()
                    }
                }
            }
            Button("printQuery") { print(testItems.map(\.id)) }
            Button("Stop") { stop = true }
            Button("print managed instances") {
                print(context.trackedObjectCount)
            }
            Button("save changes") {
                do {
                    try context.save()
                } catch {
                    print(error.localizedDescription)
                }
            }
            Button("add one") {
                do {
                    try context.insert(Test(
                        flag: Int.random(in: 0...1) > 0,
                        randomValue: Int.random(in: 0...1000)
                    ))
                } catch {
                    print(error.localizedDescription)
                }
            }
            if let first = testItems.first {
                Button("Set new item") {
                    first.child = TestChild()
                }
                ObservedTextField(item: first)
            }
            ScrollView {
                ForEach(testItems) { item in
                    TestModelDisplay(item: item)
                }
                .padding()
            }
        }
    }
}

struct ObservedTextField: View {
    @State var item: Test
    
    var body: some View {
        Toggle("", isOn: $item.flag)
        Picker(of: Group.allCases, selection: $item.selectedGroup)
    }
}

struct TestModelDisplay: View {
    @State var item: Test
    @Environment(\.modelContext) var context
    var body: some View {
        VStack {
            HStack {
                Toggle("", isOn: $item.flag)
                Text(item.selectedGroup?.rawValue ?? "none")
                Text(item.randomValue.description)
                if let child = item.child {
                    CounterDisplay(child: child)
                }
                Button("Delete") {
                    do {
                        try context.delete(item)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    struct CounterDisplay: View {
        @State var child: TestChild
        var body: some View {
            Button("-") {
                child.value -= 1
            }
            Text("\(child.value)")
            Button("+") {
                child.value += 1
            }
        }
    }
}

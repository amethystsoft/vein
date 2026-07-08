// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import SwiftUI
import Vein
import VeinSwiftUI

struct ContentView: View {
    @Query
    var testItems: [Test]
    @State var stop = false
    @Environment(\.modelContext) var context

    init(predicate: Predicate<Test> = #Predicate<Test> { _ in true } ) {
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
    @ObservedObject var item: Test

    var body: some View {
        Toggle("", isOn: $item.flag)
        Picker("", selection: $item.selectedGroup) {
            Text("none").tag(Optional<Group>.none)
            ForEach(Group.allCases, id: \.rawValue) { group in
                Text(group.rawValue)
                    .tag(group)
            }
        }
    }
}

struct TestModelDisplay: View {
    @ObservedObject var item: Test
    @Environment(\.modelContext) var context
    var body: some View {
        VStack {
            HStack {
                Toggle("", isOn: $item.flag)
                Text(item.selectedGroup?.rawValue ?? "none")
                Text(item.randomValue.description)
                if let child = item.child {
                    Button("-") {
                        child.value -= 1
                    }
                    Text("\(child.value)")
                    Button("+") {
                        child.value += 1
                    }
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
}

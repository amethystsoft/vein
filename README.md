# Amethyst Vein
> A familiar API, built better and open. Vein brings a refined, SwiftData-like interface to Apple, Linux, Android, and Windows, powered by a completely rewritten, highly optimized backend.

[![Sponsor Vein Development](https://img.shields.io/badge/Sponsor-Mia%20Koring-DE69FF?logo=github-sponsors)](https://github.com/sponsors/miakoring)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/amethystsoft/vein/swift-test-mac.yml?label=mac)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/amethystsoft/vein/swift-test-linux.yml?label=linux)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/amethystsoft/vein/swift-test-android.yml?label=android)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/amethystsoft/vein/swift-test-windows.yml?label=windows)

[Table of Contents](#table-of-contents)
[Docs and Tutorials](https://vein.amethystsoft.de)

## Example
### Declaring Models
```swift
enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any PersistentModel.Type] = [
        Post.self,
        Attachment.self
    ]

    @Model
    final class Post {
        var title: String
        var content: String

        @Relationship(
            inverse: \Attachment.post,
            deleteRule: .cascade
        )
        var attachments: [Attachment]

        init(title: String, content: String) {
            self.title = title
            self.content = content
        }
    }

    @Model
    final class Attachment {
        @Relationship
        var post: Post?

        var name: String
        var fileType: FileType
        var sizeMiB: Double

        @LazyField
        var data: Data?

        init(name: String, fileType: FileType, data: Data) {
            self.name = name
            self.fileType = fileType
            self.sizeMiB = Double(data.count) / 1024 / 1024
            self.data = data
        }

        enum FileType: String, RawRepresentablePersistable {
            case png
            case jpg
            case gif
            case swift
            // ...
        }
    }
}

typealias Post = V0_0_1.Post
typealias Attachment = V0_0_1.Attachment

enum Migration: SchemaMigrationPlan {
    static let schemas: [VersionedSchema.Type] = [
        V0_0_1.self
    ]

    static let stages: [MigrationStage] = []
}
```

### Use

```swift
func setupAndUseVein() throws {
    // Optional: Setup keyring for Linux support
    #if os(Linux)
        Keyring.appIdentifier.withLock { $0 = "com.example.app" }
    #endif

    let container = try ModelContainer(
        V0_0_1.self, // Your VersionedSchema
        migration: Migration.self, // Your SchemaMigrationPlan
        at: "path/to/db.sqlite3", // or nil for in memory
        appID: "com.example.app" // The id of your app
    )

    try container.migrate()

    let post = Post(title: "How to use Vein?", content: "It's very easy.")
    try container.context.insert(post)

    post.content = "What did I tell you?"

    try container.context.save()

    let posts = try container.context.fetchAll(#Predicate<Post> { post in
        post.title.contains("Vein")
    }) // gives back [post]

    try container.context.delete(post)
}
```

### Use in Views
More here: [SwiftUI](https://vein.amethystsoft.de/tutorials/swiftui-table-of-contents) [SwiftCrossUI](https://vein.amethystsoft.de/tutorials/scui-table-of-contents)

```swift
struct ContentView: View {
    @Query(#Predicate<Post> { post in
        post.title.contains("Swift")
    })
    var posts: [Post]

    @Environment(\.modelContext) var context

    var body: some View {
        Button("Add post") {
            do {
                try context.insert(Post(title: "New Post", content: "..."))
                try context.save()
            } catch {
                // Update some error state.
            }
        }
        List(posts) { post in
            Text(post.title)
        }
    }
}
```

## Table of Contents
- [What is Vein](#what)
- [Getting Started & Docs](#getting-started--documentation)
- [Why Vein](#why-vein)
  - [Same engine everywhere](#same-engine-everywhere)
  - [Mission](#the-mission-platform-independent-sync)
  - [Key Features](#key-features)
  - [Transactions](#how-transactions-work)
  - [Thread Safety & Concurrency](#thread-safety--concurrency)
  - [Relationships](#relationships)
  - [Serialization & Codable](#serialization-and-codable)
  - [Migration Testing](#testing-of-migrations)
  - [Save Transaction & Conflicts](#save-transaction-handling-and-conflicts)
  - [Dependency Footprint](#dependency-footprint)
- [Sponsoring, Alternative Licensing & CLA](#sponsoring-alternative-licensing--cla)
- [Third Party Licenses](#third-party-licenses)

## What?
Vein is a local first, highly abstracted ORM for Swift, backed by an SQLite (+ SQLCipher) database. Its API is heavily inspired by Apple's SwiftData framework.

Unlike SwiftData, Amethyst Vein is open source and aims to use the least amount of runtime magic possible while still providing a very user-friendly API. It is also compatible with every major consumer OS (Apple, Android, Linux and Windows), SwiftUI, SwiftCrossUI and functions independent of UI framework too, just without automatic reactivity.

## Getting started & Documentation
You can find our tutorials and docs at [vein.amethystsoft.de](https://vein.amethystsoft.de).

## Why Vein?

Amethyst Vein was built out of frustration with the current state of local persistence in the Swift ecosystem:

* **SwiftData is restricted:** It is closed-source, limited to Apple platforms, and heavily reliant on implicit runtime magic that can be difficult to debug.
* **Core Data is dated:** It's old, doesn't integrate nicely with declarative UI frameworks and like SwiftData it's limited to Apple's platforms.
* **Realm is deprecated & Apple-locked:** With MongoDB deprecating the Atlas Device SDK (Realm's sync engine), a massive gap has been left for cross-platform sync. Additionally, while Realm has SDKs for other languages, the `RealmSwift` SDK relies heavily on the Objective-C runtime (more than 50% objc code in RealmSwift). This makes it virtually impossible to compile your Swift models on Android, Linux, or Windows. And it just doesn't feel as nice as SwiftData.
* **Cross-platform Swift is growing:** With the rise of Swift on Android, Windows, Linux, and embedded systems, there is a critical need for a modern, local-first, thread-agnostic ORM where the exact same Swift models compile and run on every platform.

### Same Engine Everywhere
Vein is backed by the exact same SQLite + SQLCipher database engine across every platform. Unlike other frameworks that wrap Apple-exclusive APIs on iOS and switch engines elsewhere, Vein shares its entire core logic globally.

- Unified Core: `VeinCore`, `VeinSwiftUI`, and `VeinSCUI` are lightweight, platform-specific wrappers around the single, `Vein` target.
- Consistent Macros: The Swift macros generate identical model code on every OS. The only difference is additive, framework-specific code for UI reactivity (like SwiftUI vs. SwiftCrossUI).
- Zero Engine Drift: The only platform-specific implementation detail is secure database key storage.

This architectural consistency guarantees the exact same behavior, performance, and migration stability no matter where you're running it.

### The Mission: Platform-Independent Sync
Vein's long-term goal is to fill the void left by Realm's deprecation. We aim to construct a **platform-independent sync engine** that provides the same seamless device-to-cloud experience, but with privacy at its core via **end-to-end encryption (E2EE)** and selfhostability.

### Key Features
* **Zero-Boilerplate Schemas:** No need to manually define your database schema (unlike Fluent for example). Vein generates all information it needs automatically from your model declarations using the `@Model` macro at compile time.
* **Identity Map:** Ensures a maximum of one in-memory class instance per database row and context.
* **Declarative Migrations:** Schema migrations between versions are declared similarly to SwiftData. No raw SQL required. Every migration has to be declared explicitly and if any data is left unhandled the migration fails and rolls back. For the simple migrations there are single line helper functions.
* **UI Reactivity:** Out-of-the-box bindings for modern declarative UI frameworks.
* **Foundation.Predicate based filters & custom SQL**: You can use either the `#Predicate` macro or write a custom SQLExpression & runtime filter separately.
* **Control over time of fetch**: By default all fields are eager loaded. For bigger blobs, texts or data you just don't need that often, you can apply `@LazyField` to the property, then it will be fetched on first access.

### How Transactions Work
Vein provides a lightweight transaction API that directly wraps SQL transactions:
* **Guaranteed DB Rollback:** If a transaction fails, the underlying persistence layer is guaranteed to roll back safely, even when you called `context.save()`  multiple times.
* **In-Memory State:** SQL transactions do not automatically revert in-memory Swift object mutated states. To sync your in-memory objects back to the database state after a failed transaction (if you wish to do so), simply call `context.rollback()`.

### Thread Safety & Concurrency
Unlike Core Data or SwiftData, which enforce strict thread-confinement rules, **Vein models are thread-safe and can be shared and mutated freely across threads.**

Vein achieves thread agnosticism synchronously through the heavy use of unfair locks:
* **Field-Level Locking:** Each individual model property has its own lock, minimizing lock contention.
* **Context Synchronization:** Access to the `ManagedObjectContext` identity map and `context.save()` operations are synchronized via locks.

> [!IMPORTANT]
> **Performance Tip:** Because saving is blocking and synchronized, calling `context.save()` on the main thread while a background save is already in progress on the same context **will block the main thread** until the background save completes. For heavy concurrent write operations, we recommend using dedicated, short-lived child contexts.

* **UI Updates:** While model mutation is thread-safe, any resulting UI updates must still be dispatched to the main thread, as is standard.

### Relationships
Relationships only eager load the `ULID`s. Model instances will be resolved on access through the context. That ensures both low initial load times and prevents memory leaks while still keeping use easy.

### Serialization and Codable
Vein models do not conform to `Codable`. Since Vein knows all fields at compile time via the `@Model` macro, it bypasses `Codable` entirely.

### Testing of Migrations
You can create an in memory database by passing `nil` as path to a `ModelContainer`. Also Vein comes with a small Test helper in `VeinTesting`, reducing the code you need to write yourself. See the [migration unit testing tutorial](https://vein.amethystsoft.de/tutorials/veincore/migrationunittests).

### Save Transaction handling and conflicts
Each `context.save()` is atomic per context and happens inside an SQL transaction.

We generally recommend not to save the same models on multiple threads concurrently, for error handling becoming annoying alone.

### Dependency Footprint
Vein is designed to be highly portable, relying on standard Swift Evolution tools, cross platform wrappers and platform specific tools (for storing encryption keys), to make usage as seemless as possible for you.

- **Database & Security**: `skiptools/swift-sqlcipher` (cross platform sqlite and db level encryption)
- **Credentials**: `kishikawakatsumi/keychainaccess` (Apple), `amethystsoft/KeyringAccess` (our own lib for storing credentials in SecretService on Linux) and a Vein internal wrapper for CredW from the WinSDK on windows. Currently we don't support db level encryption on android automatically due to difficulties with storing keys safely caused by the way android is build. You can use your own implementation of `DatabaseKeyProvider`.
- **Metadata & Tooling**: `swiftlang/swift-syntax` (compile time macros), `apple/swift-log`, `apple/swift-atomics` (used only in a write once, read a lot place)
- **Testing**: `typelift/SwiftCheck` for property based testing.
- **SwiftCrossUI**: VeinSCUI depends on SwiftCrossUI. It's only used when the trait `VeinSCUI` is active.

## Sponsoring, Alternative Licensing & CLA

Amethyst Vein is independent open source. Swift and an open ecosystem are incredibly important to me. My goal is to strengthen the cross-platform Swift ecosystem (including my work as a core contributor to SwiftCrossUI). I currently work on these projects without traditional funding.

If Vein is valuable to your business, please consider supporting its development:

* **[Sponsor on GitHub Sponsors](https://github.com/sponsors/miakoring)**: Help me keep development active and sustainable.
* **Alternative/Commercial Licensing**: Vein is licensed under the MPL 2.0. Because I utilize a Contributor License Agreement (CLA) to maintain licensing flexibility under the **Amethyst Software** name, I can offer custom or commercial licensing terms if your organization's legal policies require them. Please reach out to me at [mia.koring@amethystsoft.de](mailto:mia.koring@amethystsoft.de).
* **My CLA Commitment (Safety Hatch)**: To protect contributors and ensure the project's longevity, the CLA includes a "safety hatch". If Amethyst Software (me) ever stops maintaining the open-source distribution of Vein, all contributors automatically gain the right to redistribute the entire codebase under any OSI-approved license. Your contributions will always remain free and open. Long live Swift, everywhere.

## Third-Party-Licenses
Licenses of third party projects are in the Acknowledgements folder.
* Vein contains a modified copy of [yaslab/ULID.swift](https://github.com/yaslab/ULID.swift.git).
  The original MIT license can be found in [Acknowledgements/ULID-LICENSE](./Acknowledgements/yaslab_ULID.swift/LICENSE).

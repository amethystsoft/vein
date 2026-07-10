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

import ArgumentParser
import VeinCore

@main
struct FacetCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "facet",
        abstract: "A utility for applying regex replace to Swift files.",
        subcommands: [Save.self, List.self, Get.self, Apply.self, Delete.self]
    )
}

extension FacetCLI {
    enum Error: Swift.Error {
        case noApplicationSupportDirectory
        case listExpectsEqualCountsForEachColumn
        case invalidRegEx(String)
    }

    static func makeModelContainer() async throws -> ModelContainer {
        guard
            let applicationSupportDir = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            throw Error.noApplicationSupportDirectory
        }

        let facetDir = applicationSupportDir.appendingPathComponent("facet-cli")

        if !FileManager.default.fileExists(atPath: facetDir.path()) {
            try FileManager.default.createDirectory(at: facetDir, withIntermediateDirectories: true)
        }

        let dbPath = facetDir.appendingPathComponent("db.sqlite3")

        let modelContainer = try ModelContainer(
            V1_0_0.self,
            migration: Migration.self,
            at: dbPath.path(),
            appID: "de.amethystsoft.facet-cli",
            encryptionEnabled: false
        )

        let task = Task { @MainActor in
            try modelContainer.migrate()
        }
        try await task.value

        return modelContainer
    }

    struct Save: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "save",
            abstract: "Store a new regex-replace combination (Facet)."
        )

        @Argument(
            help: "A short unique identifier for the regex-replace combination you use to run it."
        )
        var short: String

        @Argument(help: "The name of the new regex-replace combination.")
        var name: String

        @Argument(help: "The regular expression you want to save.")
        var regex: String

        @Argument(help: "The replacement you want to save.")
        var replacement: String

        func run() async throws {
            let container = try await makeModelContainer()

            if let facet = try container.context.fetchAll(
                #Predicate<Facet> { $0.short == short }
            ).first {
                print(
                    "A facet with the short '\(short)' already exists. Do you want to replace it? (y/n)"
                )

                while true {
                    guard
                        let input = readLine()?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    else {
                        print("No input received. Aborting.")
                        return
                    }

                    if input == "y" || input == "yes" {
                        facet.name = name
                        facet.regex = regex
                        facet.replacement = replacement

                        try container.context.save()
                        return
                    } else if input == "n" || input == "no" {
                        return
                    }

                    print("Invalid input. Please enter 'y' or 'n'.")
                }
            }

            let facet = Facet(
                short: short,
                name: name,
                regex: regex,
                replacement: replacement
            )

            try container.context.insert(facet)
            try container.context.save()
        }
    }

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all stored Facets."
        )

        @Option(help: "Filter the facets")
        var filter: String?

        func run() async throws {
            let container = try await makeModelContainer()

            var facets = [Facet]()

            if let filter {
                facets = try container.context.fetchAll(
                    #Predicate<Facet> { facet in
                        facet.name.contains(filter)
                            || facet.short.contains(filter)
                    }
                )
            } else {
                facets = try container.context.fetchAll(Facet.self)
            }

            let result = try FacetCLI.renderAsList(
                input: [
                    "short": facets.map(\.short),
                    "name": facets.map(\.name)
                ],
                order: [
                    "short",
                    "name"
                ]
            )

            print(result)
        }
    }

    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Get the Regex and its replacement for a given identifier."
        )

        @Argument(help: "The start of the Facet's short.")
        var short: String

        func run() async throws {
            let container = try await makeModelContainer()

            let facets = try container.context.fetchAll(
                #Predicate<Facet> {
                    $0.short.starts(with: short)
                }
            )

            guard !facets.isEmpty else {
                print("No results found for short '\(short)'.")
                return
            }

            guard facets.count == 1 else {
                print("More than one result for short '\(short)'.")
                return
            }

            guard let facet = facets.first else {
                print("How did we get here?")
                return
            }

            print("Regex: '\(facet.regex)'")
            print("Replacement: '\(facet.replacement)'")
        }
    }

    struct Apply: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "apply",
            abstract: "Apply the regex & replace to all swift files of a subfolder."
        )

        @Argument(
            help: "The path to the folder to apply the regex to.",
            transform: URL.init(fileURLWithPath: )
        )
        var pathURL: URL

        @Argument(
            help: "The shorts of the Facets in the order you want them to be applied."
        )
        var shorts: [String]

        mutating func validate() throws {
            guard FileManager.default.fileExists(atPath: pathURL.path) else {
                throw ValidationError("File does not exist at \(pathURL.path)")
            }
        }

        func run() async throws {
            let container = try await makeModelContainer()

            var positions = [String: Int]()

            for (index, short) in shorts.enumerated() {
                positions[short] = index
            }

            let facets = try container.context.fetchAll(Facet.self)
                .filter {
                    shorts.contains($0.short)
                }
                .sorted {
                    positions[$0.short]! < positions[$1.short]!
                }

            guard !facets.isEmpty else {
                print("No facets for given shorts found.")
                return
            }

            var isDirectory: ObjCBool = false

            guard
                FileManager.default.fileExists(
                    atPath: pathURL.path(),
                    isDirectory: &isDirectory
                )
            else {
                print("No file or folder at path: \(pathURL.path())")
                return
            }

            var filePathsToHandle = [String]()

            if isDirectory.boolValue {
                filePathsToHandle = try FileManager.default
                    .contentsOfDirectory(
                        atPath: pathURL.path()
                    )
                    .filter { $0.hasSuffix(".swift") }
                    .map { pathURL.appendingPathComponent($0).path() }
            } else {
                filePathsToHandle = [pathURL.path()]
            }

            var count: Int = 0

            for path in filePathsToHandle {
                guard
                    let content = FileManager.default.contents(atPath: path),
                    var string = String(data: content, encoding: .utf8)
                else {
                    print("skipped")
                    continue
                }

                for facet in facets {
                    string = try transformWithRegex(
                        input: string,
                        regex: facet.regex,
                        replacement: facet.replacement
                    )
                }

                let result = FileManager.default.createFile(
                    atPath: path,
                    contents: string.data(using: .utf8),
                    attributes: nil
                )
                
                if result {
                    count += 1
                }
            }

            print("\(count) files updated.")
        }

        func transformWithRegex(
            input: String,
            regex: String,
            replacement: String
        ) throws -> String {
            guard let regex = try? NSRegularExpression(pattern: regex, options: []) else {
                throw Error.invalidRegEx(regex)
            }

            let range = NSRange(input.startIndex..<input.endIndex, in: input)

            return regex.stringByReplacingMatches(
                in: input,
                range: range,
                withTemplate: replacement
            )
        }
    }

    struct Delete: AsyncParsableCommand {
        @Argument(
            help: "The short of the Facet you want to delete."
        )
        var short: String
        
        func run() async throws {
            let container = try await makeModelContainer()
            
            let facets = try container.context.fetchAll(
                #Predicate<Facet> {
                    $0.short == short
                }
            )
            
            guard !facets.isEmpty else {
                print("No results for short '\(short)'.")
                return
            }
            
            guard facets.count == 1 else {
                print("Multiple matches for short '\(short)'.")
                return
            }
            
            guard let facet = facets.first else {
                print("How did we get here?")
                return
            }
            
            try container.context.delete(facet)
            try container.context.save()
        }
    }

    static func renderAsList(input: [String: [String]], order: [String]) throws -> String {
        var longestForKey = [String: Int]()
        var count: Int?

        for (key, values) in input {
            longestForKey[key] = key.count

            if count == nil {
                count = values.count
            } else {
                guard count == values.count else {
                    throw Error.listExpectsEqualCountsForEachColumn
                }
            }

            for value in values {
                longestForKey[key] = max(longestForKey[key]!, value.count)
            }
        }

        var lineParts = [[String]]()

        for i in 0..<count! {
            var parts = [String]()

            for key in order {
                var part = input[key]![i]

                let spacesNeeded = longestForKey[key]! - part.count
                part += Array(repeating: " ", count: spacesNeeded)

                parts.append(part)
            }

            lineParts.append(parts)
        }

        let firstLineParts = order.map {
            var part = $0

            let spacesNeeded = longestForKey[$0]! - part.count
            part += Array(repeating: " ", count: spacesNeeded)

            return part
        }

        var resultString = firstLineParts.joined(separator: " ┃ ")
        resultString += "\n" + firstLineParts.map {
            Array(repeating: "━", count: $0.count).joined()
        }.joined(separator: "━╋━")

        for linePart in lineParts {
            resultString += "\n" + linePart.joined(separator: " ┃ ")
        }

        return resultString
    }
}

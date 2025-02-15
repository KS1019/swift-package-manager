/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Basics
import Foundation
import PackageLoading
import PackageModel
import PackageRegistry
import SPMTestSupport
import TSCBasic
import XCTest

final class RegistryManagerTests: XCTestCase {
    func testFetchVersions() throws {
        let registryURL = "https://packages.example.com"
        let identity = PackageIdentity.plain("mona.LinkedList")
        let (scope, name) = identity.scopeAndName!
        let releasesURL = URL(string: "\(registryURL)/\(scope)/\(name)")!

        let handler: HTTPClient.Handler = { request, _, completion in
            switch (request.method, request.url) {
            case (.get, releasesURL):
                XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+json")

                let data = #"""
                {
                    "releases": {
                        "1.1.1": {
                            "url": "https://packages.example.com/mona/LinkedList/1.1.1"
                        },
                        "1.1.0": {
                            "url": "https://packages.example.com/mona/LinkedList/1.1.0",
                            "problem": {
                                "status": 410,
                                "title": "Gone",
                                "detail": "this release was removed from the registry"
                            }
                        },
                        "1.0.0": {
                            "url": "https://packages.example.com/mona/LinkedList/1.0.0"
                        }
                    }
                }
                """#.data(using: .utf8)!

                completion(.success(.init(statusCode: 200,
                                          headers: .init([
                                              .init(name: "Content-Length", value: "\(data.count)"),
                                              .init(name: "Content-Type", value: "application/json"),
                                              .init(name: "Content-Version", value: "1"),
                                          ]),
                                          body: data)))
            default:
                XCTFail("method and url should match")
            }
        }

        var httpClient = HTTPClient(handler: handler)
        httpClient.configuration.circuitBreakerStrategy = .none
        httpClient.configuration.retryStrategy = .none

        var configuration = RegistryConfiguration()
        configuration.defaultRegistry = Registry(url: URL(string: registryURL)!)

        let registryManager = RegistryManager(
            configuration: configuration,
            identityResolver: DefaultIdentityResolver(),
            customArchiverProvider: { _ in MockArchiver() },
            customHTTPClient: httpClient
        )

        let versions = try tsc_await { callback in registryManager.fetchVersions(of: identity, observabilityScope: ObservabilitySystem.NOOP, completion: callback) }
        XCTAssertEqual(["1.1.1", "1.0.0"], versions)
    }

    func testFetchManifest() throws {
        let registryURL = "https://packages.example.com"
        let identity = PackageIdentity.plain("mona.LinkedList")
        let (scope, name) = identity.scopeAndName!
        let version = Version("1.1.1")
        let manifestURL = URL(string: "\(registryURL)/\(scope)/\(name)/\(version)/Package.swift")!

        let handler: HTTPClient.Handler = { request, _, completion in
            switch (request.method, request.url) {
            case (.get, manifestURL):
                XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+swift")

                let data = #"""
                // swift-tools-version:5.0
                import PackageDescription

                let package = Package(
                    name: "LinkedList",
                    products: [
                        .library(name: "LinkedList", targets: ["LinkedList"])
                    ],
                    targets: [
                        .target(name: "LinkedList"),
                        .testTarget(name: "LinkedListTests", dependencies: ["LinkedList"]),
                    ],
                    swiftLanguageVersions: [.v4, .v5]
                )
                """#.data(using: .utf8)!

                completion(.success(.init(statusCode: 200,
                                          headers: .init([
                                              .init(name: "Content-Length", value: "\(data.count)"),
                                              .init(name: "Content-Type", value: "text/x-swift"),
                                              .init(name: "Content-Version", value: "1"),
                                          ]),
                                          body: data)))
            default:
                XCTFail("method and url should match")
            }
        }

        var httpClient = HTTPClient(handler: handler)
        httpClient.configuration.circuitBreakerStrategy = .none
        httpClient.configuration.retryStrategy = .none

        var configuration = RegistryConfiguration()
        configuration.defaultRegistry = Registry(url: URL(string: registryURL)!)

        let registryManager = RegistryManager(
            configuration: configuration,
            identityResolver: DefaultIdentityResolver(),
            customArchiverProvider: { _ in MockArchiver() },
            customHTTPClient: httpClient
        )

        let manifestLoader = ManifestLoader(toolchain: .default)
        let manifest = try tsc_await { callback in
            registryManager.fetchManifest(for: version, of: identity, using: manifestLoader, observabilityScope: ObservabilitySystem.NOOP, completion: callback)
        }

        XCTAssertEqual(manifest.displayName, "LinkedList")

        XCTAssertEqual(manifest.products.count, 1)
        XCTAssertEqual(manifest.products.first?.name, "LinkedList")
        XCTAssertEqual(manifest.products.first?.type, .library(.automatic))

        XCTAssertEqual(manifest.targets.count, 2)
        XCTAssertEqual(manifest.targets.first?.name, "LinkedList")
        XCTAssertEqual(manifest.targets.first?.type, .regular)
        XCTAssertEqual(manifest.targets.last?.name, "LinkedListTests")
        XCTAssertEqual(manifest.targets.last?.type, .test)

        XCTAssertEqual(manifest.swiftLanguageVersions, [.v4, .v5])
    }

    // FIXME: this fails with error "the package manifest at '/Package.swift' cannot be accessed (/Package.swift doesn't exist in file system)"
    /*
     func testFetchManifestForSwiftVersion() throws {
         let registryURL = "https://packages.example.com"
         let identity = PackageIdentity.plain("mona.LinkedList")
         let (scope, name) = identity.scopeAndName!
         let version = Version("1.1.1")
         let swiftVersion = SwiftLanguageVersion(string: "5.0")!
         let manifestURL = URL(string: "\(registryURL)/\(scope)/\(name)/\(version)/Package.swift?swift-version=\(swiftVersion)")!

         let handler: HTTPClient.Handler = { request, _, completion in
             switch (request.method, request.url) {
             case (.get, manifestURL):
                 XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+swift")

                 let data = #"""
                 // swift-tools-version:5.0
                 import PackageDescription

                 let package = Package(
                     name: "LinkedList",
                     products: [
                         .library(name: "LinkedList", targets: ["LinkedList"])
                     ],
                     targets: [
                         .target(name: "LinkedList"),
                         .testTarget(name: "LinkedListTests", dependencies: ["LinkedList"]),
                     ],
                     swiftLanguageVersions: [.v4, .v5]
                 )
                 """#.data(using: .utf8)!

                 completion(.success(.init(statusCode: 200,
                                           headers: .init([
                                             .init(name: "Content-Length", value: "\(data.count)"),
                                             .init(name: "Content-Type", value: "text/x-swift"),
                                             .init(name: "Content-Version", value: "1")
                                           ]),
                                           body: data)))
             default:
                 XCTFail("method and url should match")
             }
         }

         var httpClient = HTTPClient(handler: handler)
         httpClient.configuration.circuitBreakerStrategy = .none
         httpClient.configuration.retryStrategy = .none

         var configuration = RegistryConfiguration()
         configuration.defaultRegistry = Registry(url: URL(string: registryURL)!)

         let registryManager = RegistryManager(
             configuration: configuration,
             identityResolver: DefaultIdentityResolver(),
             customArchiverFactory: { _ in MockArchiver() },
             customHTTPClient: httpClient
         )

         let manifestLoader = ManifestLoader(toolchain: .default)
         let manifest = try tsc_await { callback in
             registryManager.fetchManifest(for: version, of: identity, using: manifestLoader, swiftLanguageVersion: swiftVersion,
                                              observabilityScope: ObservabilitySystem.NOOP, completion: callback)
         }

         XCTAssertEqual(manifest.displayName, "LinkedList")

         XCTAssertEqual(manifest.products.count, 1)
         XCTAssertEqual(manifest.products.first?.name, "LinkedList")
         XCTAssertEqual(manifest.products.first?.type, .library(.automatic))

         XCTAssertEqual(manifest.targets.count, 2)
         XCTAssertEqual(manifest.targets.first?.name, "LinkedList")
         XCTAssertEqual(manifest.targets.first?.type, .regular)
         XCTAssertEqual(manifest.targets.last?.name, "LinkedListTests")
         XCTAssertEqual(manifest.targets.last?.type, .test)

         XCTAssertEqual(manifest.swiftLanguageVersions, [.v4, .v5])
     }
      */

    func testFetchSourceArchiveChecksum() throws {
        let registryURL = "https://packages.example.com"
        let identity = PackageIdentity.plain("mona.LinkedList")
        let (scope, name) = identity.scopeAndName!
        let version = Version("1.1.1")
        let metadataURL = URL(string: "\(registryURL)/\(scope)/\(name)/\(version)")!

        let handler: HTTPClient.Handler = { request, _, completion in
            switch (request.method, request.url) {
            case (.get, metadataURL):
                XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+json")

                let data = #"""
                {
                    "id": "mona.LinkedList",
                    "version": "1.1.1",
                    "resources": [
                        {
                            "name": "source-archive",
                            "type": "application/zip",
                            "checksum": "a2ac54cf25fbc1ad0028f03f0aa4b96833b83bb05a14e510892bb27dea4dc812"
                        }
                    ],
                    "metadata": {
                        "description": "One thing links to another."
                    }
                }
                """#.data(using: .utf8)!

                completion(.success(.init(statusCode: 200,
                                          headers: .init([
                                              .init(name: "Content-Length", value: "\(data.count)"),
                                              .init(name: "Content-Type", value: "application/json"),
                                              .init(name: "Content-Version", value: "1"),
                                          ]),
                                          body: data)))
            default:
                XCTFail("method and url should match")
            }
        }

        var httpClient = HTTPClient(handler: handler)
        httpClient.configuration.circuitBreakerStrategy = .none
        httpClient.configuration.retryStrategy = .none

        var configuration = RegistryConfiguration()
        configuration.defaultRegistry = Registry(url: URL(string: registryURL)!)

        let registryManager = RegistryManager(
            configuration: configuration,
            identityResolver: DefaultIdentityResolver(),
            customArchiverProvider: { _ in MockArchiver() },
            customHTTPClient: httpClient
        )

        let checksum = try tsc_await { callback in
            registryManager.fetchSourceArchiveChecksum(for: version, of: identity, observabilityScope: ObservabilitySystem.NOOP, completion: callback)
        }
        XCTAssertEqual("a2ac54cf25fbc1ad0028f03f0aa4b96833b83bb05a14e510892bb27dea4dc812", checksum)
    }

    func testDownloadSourceArchiveWithExpectedChecksumProvided() throws {
        let registryURL = "https://packages.example.com"
        let identity = PackageIdentity.plain("mona.LinkedList")
        let (scope, name) = identity.scopeAndName!
        let version = Version("1.1.1")
        let downloadURL = URL(string: "\(registryURL)/\(scope)/\(name)/\(version).zip")!

        let checksumAlgorithm: HashAlgorithm = SHA256()
        let expectedChecksum = checksumAlgorithm.hash(emptyZipFile).hexadecimalRepresentation

        let handler: HTTPClient.Handler = { request, _, completion in
            switch (request.method, request.url) {
            case (.get, downloadURL):
                XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+zip")

                let data = Data(emptyZipFile.contents)

                completion(.success(.init(statusCode: 200,
                                          headers: .init([
                                              .init(name: "Content-Length", value: "\(data.count)"),
                                              .init(name: "Content-Type", value: "application/zip"),
                                              .init(name: "Content-Version", value: "1"),
                                              .init(name: "Content-Disposition", value: #"attachment; filename="LinkedList-1.1.1.zip""#),
                                              .init(name: "Digest", value: "sha-256=bc6c9a5d2f2226cfa1ef4fad8344b10e1cc2e82960f468f70d9ed696d26b3283"),
                                          ]),
                                          body: data)))
            default:
                XCTFail("method and url should match")
            }
        }

        var httpClient = HTTPClient(handler: handler)
        httpClient.configuration.circuitBreakerStrategy = .none
        httpClient.configuration.retryStrategy = .none

        var configuration = RegistryConfiguration()
        configuration.defaultRegistry = Registry(url: URL(string: registryURL)!)

        let registryManager = RegistryManager(
            configuration: configuration,
            identityResolver: DefaultIdentityResolver(),
            customArchiverProvider: { _ in MockArchiver() },
            customHTTPClient: httpClient
        )

        let expectation = XCTestExpectation(description: "download source archive")

        let fileSystem = InMemoryFileSystem()
        let path = AbsolutePath("/LinkedList-1.1.1")
        registryManager.downloadSourceArchive(for: version, of: identity, into: fileSystem, at: path,
                                              expectedChecksum: expectedChecksum, checksumAlgorithm: checksumAlgorithm,
                                              observabilityScope: ObservabilitySystem.NOOP) { result in
            defer { expectation.fulfill() }

            guard case .success = result else {
                return XCTAssertResultSuccess(result)
            }

            XCTAssertNoThrow {
                let data = try fileSystem.readFileContents(path)
                XCTAssertEqual(data, emptyZipFile)
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testDownloadSourceArchiveWithoutExpectedChecksumProvided() throws {
        let registryURL = "https://packages.example.com"
        let identity = PackageIdentity.plain("mona.LinkedList")
        let (scope, name) = identity.scopeAndName!
        let version = Version("1.1.1")
        let downloadURL = URL(string: "\(registryURL)/\(scope)/\(name)/\(version).zip")!
        let metadataURL = URL(string: "\(registryURL)/\(scope)/\(name)/\(version)")!

        let checksumAlgorithm: HashAlgorithm = SHA256()

        let handler: HTTPClient.Handler = { request, _, completion in
            switch (request.method, request.url) {
            case (.get, downloadURL):
                XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+zip")

                let data = Data(emptyZipFile.contents)

                completion(.success(.init(statusCode: 200,
                                          headers: .init([
                                              .init(name: "Content-Length", value: "\(data.count)"),
                                              .init(name: "Content-Type", value: "application/zip"),
                                              .init(name: "Content-Version", value: "1"),
                                              .init(name: "Content-Disposition", value: #"attachment; filename="LinkedList-1.1.1.zip""#),
                                              .init(name: "Digest", value: "sha-256=bc6c9a5d2f2226cfa1ef4fad8344b10e1cc2e82960f468f70d9ed696d26b3283"),
                                          ]),
                                          body: data)))
            // `downloadSourceArchive` calls this API to fetch checksum
            case (.get, metadataURL):
                XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+json")

                let data = """
                {
                  "id": "mona.LinkedList",
                  "version": "1.1.1",
                  "resources": [
                    {
                      "name": "source-archive",
                      "type": "application/zip",
                      "checksum": "\(checksumAlgorithm.hash(emptyZipFile).hexadecimalRepresentation)"
                    }
                  ],
                  "metadata": {
                    "description": "One thing links to another."
                  }
                }
                """.data(using: .utf8)!

                completion(.success(.init(statusCode: 200,
                                          headers: .init([
                                              .init(name: "Content-Length", value: "\(data.count)"),
                                              .init(name: "Content-Type", value: "application/json"),
                                              .init(name: "Content-Version", value: "1"),
                                          ]),
                                          body: data)))
            default:
                XCTFail("method and url should match")
            }
        }

        var httpClient = HTTPClient(handler: handler)
        httpClient.configuration.circuitBreakerStrategy = .none
        httpClient.configuration.retryStrategy = .none

        var configuration = RegistryConfiguration()
        configuration.defaultRegistry = Registry(url: URL(string: registryURL)!)

        let registryManager = RegistryManager(
            configuration: configuration,
            identityResolver: DefaultIdentityResolver(),
            customArchiverProvider: { _ in MockArchiver() },
            customHTTPClient: httpClient
        )

        let expectation = XCTestExpectation(description: "download source archive")

        let fileSystem = InMemoryFileSystem()
        let path = AbsolutePath("/LinkedList-1.1.1")
        registryManager.downloadSourceArchive(for: version, of: identity, into: fileSystem, at: path,
                                              expectedChecksum: nil, checksumAlgorithm: checksumAlgorithm,
                                              observabilityScope: ObservabilitySystem.NOOP) { result in
            defer { expectation.fulfill() }

            guard case .success = result else {
                return XCTAssertResultSuccess(result)
            }

            XCTAssertNoThrow {
                let data = try fileSystem.readFileContents(path)
                XCTAssertEqual(data, emptyZipFile)
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testLookupIdentities() throws {
        let registryURL = "https://packages.example.com"
        let packageURL = URL(string: "https://example.com/mona/LinkedList")!
        let identifiersURL = URL(string: "\(registryURL)/identifiers?url=\(packageURL.absoluteString)")!

        let handler: HTTPClient.Handler = { request, _, completion in
            switch (request.method, request.url) {
            case (.get, identifiersURL):
                XCTAssertEqual(request.headers.get("Accept").first, "application/vnd.swift.registry.v1+json")

                let data = #"""
                {
                    "identifiers": [
                      "mona.LinkedList"
                    ]
                }
                """#.data(using: .utf8)!

                completion(.success(.init(statusCode: 200,
                                          headers: .init([
                                              .init(name: "Content-Length", value: "\(data.count)"),
                                              .init(name: "Content-Type", value: "application/json"),
                                              .init(name: "Content-Version", value: "1"),
                                          ]),
                                          body: data)))
            default:
                XCTFail("method and url should match")
            }
        }

        var httpClient = HTTPClient(handler: handler)
        httpClient.configuration.circuitBreakerStrategy = .none
        httpClient.configuration.retryStrategy = .none

        var configuration = RegistryConfiguration()
        configuration.defaultRegistry = Registry(url: URL(string: registryURL)!)

        let registryManager = RegistryManager(
            configuration: configuration,
            identityResolver: DefaultIdentityResolver(),
            customArchiverProvider: { _ in MockArchiver() },
            customHTTPClient: httpClient
        )

        let identities = try tsc_await { callback in registryManager.lookupIdentities(for: packageURL, observabilityScope: ObservabilitySystem.NOOP, completion: callback) }
        XCTAssertEqual([PackageIdentity.plain("mona.LinkedList")], identities)
    }
}

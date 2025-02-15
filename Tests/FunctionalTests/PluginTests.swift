/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SPMTestSupport
import TSCBasic

class PluginTests: XCTestCase {
    
    func testUseOfBuildToolPluginTargetByExecutableInSamePackage() throws {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif
        
        fixture(name: "Miscellaneous/Plugins") { path in
            do {
                let (stdout, _) = try executeSwiftBuild(path.appending(component: "MySourceGenPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
                XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
            }
            catch {
                print(error)
                throw error
            }
        }
    }

    func testUseOfBuildToolPluginProductByExecutableAcrossPackages() throws {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif

        fixture(name: "Miscellaneous/Plugins") { path in
            do {
                let (stdout, _) = try executeSwiftBuild(path.appending(component: "MySourceGenClient"), configuration: .Debug, extraArgs: ["--product", "MyTool"])
                XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Linking MyTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
            }
            catch {
                print(error)
                throw error
            }
        }
    }

    func testUseOfPrebuildPluginTargetByExecutableAcrossPackages() throws {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif

        fixture(name: "Miscellaneous/Plugins") { path in
            do {
                let (stdout, _) = try executeSwiftBuild(path.appending(component: "MySourceGenPlugin"), configuration: .Debug, extraArgs: ["--product", "MyOtherLocalTool"])
                XCTAssert(stdout.contains("Compiling MyOtherLocalTool bar.swift"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Compiling MyOtherLocalTool baz.swift"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Linking MyOtherLocalTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
            }
            catch {
                print(error)
                throw error
            }
        }
    }

    func testUseOfPluginWithInternalExecutable() {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif

        fixture(name: "Miscellaneous/Plugins") { path in
            let (stdout, _) = try executeSwiftBuild(path.appending(component: "ClientOfPluginWithInternalExecutable"))
            XCTAssert(stdout.contains("Compiling PluginExecutable main.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking PluginExecutable"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Compiling RootTarget foo.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking RootTarget"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
    }

    func testInternalExecutableAvailableOnlyToPlugin() {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif

        fixture(name: "Miscellaneous/Plugins") { path in
            do {
                let (stdout, _) = try executeSwiftBuild(path.appending(component: "InvalidUseOfInternalPluginExecutable"))
                XCTFail("Illegally used internal executable.\nstdout:\n\(stdout)")
            }
            catch SwiftPMProductError.executionFailure(_, _, let stderr) {
                XCTAssert(
                    stderr.contains(
                        "product 'PluginExecutable' required by package 'invaliduseofinternalpluginexecutable' target 'RootTarget' not found in package 'PluginWithInternalExecutable'."
                    ),
                    "stderr:\n\(stderr)"
                )
            }
        }
    }

    func testContrivedTestCases() throws {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif
        
        fixture(name: "Miscellaneous/Plugins") { path in
            do {
                let (stdout, _) = try executeSwiftBuild(path.appending(component: "ContrivedTestPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
                XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
            }
            catch {
                print(error)
                throw error
            }
        }
    }

    func testPluginScriptSandbox() throws {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif

        #if os(macOS)
        fixture(name: "Miscellaneous/Plugins") { path in
            do {
                let (stdout, _) = try executeSwiftBuild(path.appending(component: "SandboxTesterPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
                XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
            }
            catch {
                print(error)
                throw error
            }
        }
        #endif
    }

    func testUseOfVendedBinaryTool() throws {
        // Check if the host compiler supports the '-entry-point-function-name' flag.  It's not needed for this test but is needed to build any executable from a package that uses tools version 5.5.
        #if swift(<5.5)
        try XCTSkipIf(true, "skipping because host compiler doesn't support '-entry-point-function-name'")
        #endif

        #if os(macOS)
        fixture(name: "Miscellaneous/Plugins") { path in
            do {
                let (stdout, _) = try executeSwiftBuild(path.appending(component: "MyBinaryToolPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
                XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
                XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
            }
            catch {
                print(error)
                throw error
            }
        }
        #endif
    }
}

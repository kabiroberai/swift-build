// This source file is part of the Swift open source project.
// Licensed under Apache License v2.0 with Runtime Library Exception.

import Foundation
import SWBCore
import SWBTestSupport
import SWBUtil
import SwiftBuild
import SwiftBuildTestSupport
import Testing

@Suite(.requireHostOS(.macOS), .requireSDKs(.macOS))
fileprivate struct ProcessExecutionDelegateTests: CoreBasedTests {
    @Test(arguments: [false, true], [false, true])
    func shellExecutionThroughClient(enabled: Bool, handled: Bool) async throws {
        try await withTemporaryDirectory { tmpDir in
            let marker = tmpDir.join("native-execution")
            let project = TestProject(
                "HookProject",
                sourceRoot: tmpDir,
                groupTree: TestGroup("Sources"),
                targets: [TestAggregateTarget("HookTarget", buildPhases: [
                    TestShellScriptBuildPhase(
                        name: "Hook", originalObjectID: "Hook",
                        contents: "printf native > '\(marker.str)'", alwaysOutOfDate: true)
                ])])
            try await confirmation("One client request per process", expectedCount: enabled ? 1 : 0) { called in
                final class Delegate: SWBPlanningOperationDelegate {
                    let handled: Bool
                    let called: Confirmation

                    init(handled: Bool, called: Confirmation) {
                        self.handled = handled
                        self.called = called
                    }

                    func provisioningTaskInputs(targetGUID: String, provisioningSourceData: SWBProvisioningTaskInputsSourceData) async -> SWBProvisioningTaskInputs {
                        SWBProvisioningTaskInputs()
                    }

                    func executeExternalTool(commandLine: [String], workingDirectory: String?, environment: [String: String]) async throws -> SWBExternalToolResult {
                        guard commandLine.last?.hasSuffix("Script-Hook.sh") == true else { return .deferred }
                        called()
                        // These are supplied by llbuild, after task-action spawning.
                        #expect(environment["LLBUILD_BUILD_ID"] != nil)
                        #expect(environment["LLBUILD_LANE_ID"] != nil)
                        #expect(environment["LLBUILD_CONTROL_FD"] == nil)
                        await Task.yield()
                        return handled ? .result(status: .exit(0), stdout: Data(), stderr: Data()) : .deferred
                    }
                }

                try await withTester(project, userPreferences: UserPreferences.defaultForTesting.with(allowsExternalToolExecution: enabled)) { tester in
                    try await tester.checkBuild(SWBBuildParameters(configuration: "Debug", activeRunDestination: .macOS), delegate: Delegate(handled: handled, called: called)) { results in
                        results.checkNoFailedTasks()
                        results.checkNoDiagnostics()
                    }
                }
            }
            #expect(localFS.exists(marker) == !(enabled && handled))
        }
    }
}

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

public import SWBCore
import SWBUtil
public import SWBLLBuild
import Foundation
import SWBProtocol

public final class DeferredExecutionTaskAction: TaskAction {
    public override class var toolIdentifier: String {
        "deferrable-shell-task"
    }

    public override func performTaskAction(_ task: any ExecutableTask, dynamicExecutionDelegate: any DynamicTaskExecutionDelegate, executionDelegate: any TaskExecutionDelegate, clientDelegate: any TaskExecutionClientDelegate, outputDelegate: any TaskOutputDelegate) async -> CommandResult {
        let processDelegate = TaskProcessDelegate(outputDelegate: outputDelegate)
        do {
            try await spawn(commandLine: Array(task.commandLineAsStrings), environment: task.environment.bindingsDictionary, workingDirectory: task.workingDirectory, dynamicExecutionDelegate: dynamicExecutionDelegate, clientDelegate: clientDelegate, processDelegate: processDelegate)
        } catch {
            outputDelegate.error(error.localizedDescription)
            return .failed
        }
        if let error = processDelegate.executionError {
            outputDelegate.error(error)
            return .failed
        }
        return processDelegate.commandResult ?? .failed
    }
}

extension TaskAction {
    func spawn(commandLine: [String], environment: [String: String], workingDirectory: Path, dynamicExecutionDelegate: any DynamicTaskExecutionDelegate, clientDelegate: any TaskExecutionClientDelegate, processDelegate: any ProcessDelegate) async throws {
        try await dynamicExecutionDelegate.spawn(commandLine: commandLine, environment: environment, workingDirectory: workingDirectory, processDelegate: processDelegate)
    }
}

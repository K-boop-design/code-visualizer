import Foundation

final class PythonBridge: @unchecked Sendable {
    static let shared = PythonBridge()

    private init() {}

    func analyze(code: String, mode: String = "full") async -> PythonScript {
        await runProcess(args: ["--mode", mode, "--code", code])
    }

    func analyze(notebookPath: String, mode: String = "full") async -> PythonScript {
        await runProcess(args: ["--mode", mode, "--notebook", notebookPath])
    }

    func analyze(filePath: String, mode: String = "full") async -> PythonScript {
        await runProcess(args: ["--mode", mode, "--file", filePath])
    }

    private func runProcess(args: [String]) async -> PythonScript {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.runProcessSync(args: args)
                continuation.resume(returning: result)
            }
        }
    }

    private func runProcessSync(args: [String], stdin: String? = nil) -> PythonScript {
        let scriptPath = findScriptPath()
        guard !scriptPath.isEmpty else {
            return PythonScript(valid: false, error: "Python service script not found")
        }

        let pythonPath = findPythonPath()
        guard !pythonPath.isEmpty else {
            return PythonScript(valid: false, error: "Python 3 not found. Install Python from python.org")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath] + args
        process.environment = ProcessInfo.processInfo.environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = stdin != nil ? Pipe() : nil
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        var outputData = Data()
        var errorData = Data()

        do {
            try process.run()

            if let inputPipe = inputPipe, let stdinStr = stdin {
                inputPipe.fileHandleForWriting.write(stdinStr.data(using: .utf8)!)
                inputPipe.fileHandleForWriting.closeFile()
            }

            let finished = DispatchGroup()
            let started = DispatchGroup()
            started.enter()
            started.enter()

            finished.enter()
            DispatchQueue.global(qos: .default).async {
                started.leave()
                outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                finished.leave()
            }
            finished.enter()
            DispatchQueue.global(qos: .default).async {
                started.leave()
                errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                finished.leave()
            }

            started.wait()
            process.waitUntilExit()
            finished.wait()

            if process.terminationStatus != 0 {
                let errorMsg = String(data: errorData, encoding: .utf8) ?? ""
                let outputPreview = String(data: outputData, encoding: .utf8)?.prefix(300) ?? ""
                return PythonScript(valid: false, error: "Python exit code \(process.terminationStatus): \(errorMsg.prefix(500))\nstdout: \(outputPreview)")
            }

            let errorStr = String(data: errorData, encoding: .utf8) ?? ""
            guard let outputStr = String(data: outputData, encoding: .utf8),
                  let jsonData = outputStr.data(using: .utf8) else {
                let preview = String(data: outputData, encoding: .utf8)?.prefix(500) ?? "nil"
                let errInfo = errorStr.isEmpty ? "" : " | stderr: \(errorStr.prefix(300))"
                return PythonScript(valid: false, error: "Failed to decode Python output: '\(preview)'\(errInfo)")
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(PythonScript.self, from: jsonData)
            if let stages = result.pipeline?.stages, let first = stages.first {
                print("[PipelineDebug] codeSnippet=\(first.codeSnippet?.count ?? -1) codeContext=\(first.codeContext != nil)")
            }
            return result
        } catch let error as DecodingError {
            let detail: String
            switch error {
            case .typeMismatch(let t, let ctx):
                detail = "typeMismatch \(t): \(ctx.debugDescription) at \(ctx.codingPath.map {$0.stringValue}.joined(separator: "."))"
            case .valueNotFound(let t, let ctx):
                detail = "valueNotFound \(t): \(ctx.debugDescription) at \(ctx.codingPath.map {$0.stringValue}.joined(separator: "."))"
            case .keyNotFound(let k, let ctx):
                detail = "keyNotFound \(k): \(ctx.debugDescription) at \(ctx.codingPath.map {$0.stringValue}.joined(separator: "."))"
            case .dataCorrupted(let ctx):
                detail = "dataCorrupted: \(ctx.debugDescription) at \(ctx.codingPath.map {$0.stringValue}.joined(separator: "."))"
            @unknown default:
                detail = "unknown decoding error: \(error.localizedDescription)"
            }
            return PythonScript(valid: false, error: "Decode error: \(detail)")
        } catch {
            return PythonScript(valid: false, error: "Process error: \(error.localizedDescription)")
        }
    }

    func queryAI(prompt: String, apiKey: String = "", provider: String = "groq", context: String = "", system: String = "") async -> AIResponse {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let payload = AIRequest(prompt: prompt, api_key: apiKey, provider: provider, context: context, system: system, messages: nil)
                let encoder = JSONEncoder()
                guard let jsonData = try? encoder.encode(payload),
                      let jsonStr = String(data: jsonData, encoding: .utf8) else {
                    continuation.resume(returning: AIResponse(response: nil, error: "Failed to encode AI request"))
                    return
                }
                let result = self.runAISync(stdin: jsonStr)
                continuation.resume(returning: result)
            }
        }
    }

    func queryAIConversation(messages: [AIChatMessage], apiKey: String, provider: String) async -> AIResponse {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let payload = AIRequest(prompt: "", api_key: apiKey, provider: provider, context: "", system: "", messages: messages)
                let encoder = JSONEncoder()
                guard let jsonData = try? encoder.encode(payload),
                      let jsonStr = String(data: jsonData, encoding: .utf8) else {
                    continuation.resume(returning: AIResponse(response: nil, error: "Failed to encode AI conversation"))
                    return
                }
                let result = self.runAISync(stdin: jsonStr)
                continuation.resume(returning: result)
            }
        }
    }

    private func runAISync(stdin: String) -> AIResponse {
        let scriptPath = findScriptPath()
        guard !scriptPath.isEmpty else {
            return AIResponse(response: nil, error: "Python service script not found")
        }

        let pythonPath = findPythonPath()
        guard !pythonPath.isEmpty else {
            return AIResponse(response: nil, error: "Python 3 not found")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath, "--mode", "ai"]
        process.environment = ProcessInfo.processInfo.environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        var outputData = Data()
        var errorData = Data()

        do {
            try process.run()

            inputPipe.fileHandleForWriting.write(stdin.data(using: .utf8)!)
            inputPipe.fileHandleForWriting.closeFile()

            let finished = DispatchGroup()
            let started = DispatchGroup()
            started.enter()
            started.enter()

            finished.enter()
            DispatchQueue.global(qos: .default).async {
                started.leave()
                outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                finished.leave()
            }
            finished.enter()
            DispatchQueue.global(qos: .default).async {
                started.leave()
                errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                finished.leave()
            }

            started.wait()
            process.waitUntilExit()
            finished.wait()

            guard let outputStr = String(data: outputData, encoding: .utf8),
                  let jsonData = outputStr.data(using: .utf8) else {
                let preview = String(data: outputData, encoding: .utf8)?.prefix(300) ?? "nil"
                return AIResponse(response: nil, error: "Failed to decode output: \(preview)")
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(AIResponse.self, from: jsonData)
            return result
        } catch {
            return AIResponse(response: nil, error: "Process error: \(error.localizedDescription)")
        }
    }

    private func findScriptPath() -> String {
        let scriptName = "code_visualizer.py"

        if let resourcePath = Bundle.main.resourcePath {
            let bundled = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("PythonService")
                .appendingPathComponent(scriptName)
                .path
            if FileManager.default.fileExists(atPath: bundled) {
                return bundled
            }
        }

        let searchPaths = [
            FileManager.default.currentDirectoryPath + "/PythonService/" + scriptName,
            FileManager.default.currentDirectoryPath + "/../PythonService/" + scriptName,
            "/Users/kiranvitly/Desktop/CodeVisualizer/PythonService/" + scriptName,
        ]
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return ""
    }

    private func findPythonPath() -> String {
        let candidates = [
            "/opt/anaconda3/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.9/bin/python3",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "python3"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
        } catch {}

        return ""
    }
}

struct AIRequest: Encodable {
    let prompt: String
    let api_key: String
    let provider: String
    let context: String
    let system: String
    let messages: [AIChatMessage]?
}

struct AIResponse: Codable {
    let response: String?
    let error: String?
    var status: String? = nil
}

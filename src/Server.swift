import Foundation
import CoreFoundation

final class Server {
    private let transport: Transport
    private var initialized = false
    private var ready = false
    init(transport: Transport) { self.transport = transport }

    func receive(_ data: Data) -> [String: Any]? {
        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return malformed() }
        guard let request = parsed as? [String: Any],
            request["jsonrpc"] as? String == "2.0", let method = request["method"] as? String else {
            return failure(NSNull(), -32600, "Invalid JSON-RPC request.")
        }
        let id = request["id"]
        if let id = id, !(id is String), !(id is NSNull) {
            guard let number = id as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
                return failure(NSNull(), -32600, "Invalid request ID.")
            }
        }
        if request["params"] != nil && !(request["params"] is [String: Any]) {
            return failure(id ?? NSNull(), -32602, "Expected named parameters.")
        }
        let parameters = request["params"] as? [String: Any] ?? [:]
        if method == "notifications/initialized" { if initialized { ready = true }; return nil }
        if method.hasPrefix("notifications/") { return nil }
        guard let id = id else { return nil }
        if method == "initialize" {
            guard !initialized else { return failure(id, -32600, "Already initialized.") }
            initialized = true
            let requested = parameters["protocolVersion"] as? String ?? ""
            let versions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
            return success(id, ["protocolVersion": versions.contains(requested) ? requested : versions[0],
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": ["name": "palworld-mcp", "version": BuildInfo.version],
                "instructions": L10n.text("instructions")])
        }
        if method == "ping" { return success(id, [:]) }
        guard ready else { return failure(id, -32000, "Initialize the MCP session first.") }
        if method == "tools/list" { return success(id, ["tools": gameTools.map(\.definition)]) }
        if method == "tools/call" {
            guard let name = parameters["name"] as? String, let tool = gameTools.first(where: { $0.name == name }),
                parameters["arguments"] == nil || parameters["arguments"] is [String: Any] else {
                return failure(id, -32602, "Unknown tool or invalid arguments.")
            }
            do {
                let request = try tool.request(parameters["arguments"] as? [String: Any] ?? [:])
                let response = try transport.call(request)
                let data = try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])
                return success(id, ["content": [["type": "text", "text": String(decoding: data, as: UTF8.self)]],
                    "isError": response["ok"] as? Bool != true])
            } catch {
                return success(id, ["content": [["type": "text", "text": error.localizedDescription]], "isError": true])
            }
        }
        return failure(id, -32601, "Method not found.")
    }

    func malformed() -> [String: Any] { failure(NSNull(), -32700, "Malformed or oversized JSON message.") }
    private func success(_ id: Any, _ result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }
    private func failure(_ id: Any, _ code: Int, _ message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }
}

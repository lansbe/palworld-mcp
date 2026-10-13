import Foundation
import Darwin

func output(_ value: [String: Any]) {
    guard var data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else { return }
    data.append(10)
    FileHandle.standardOutput.write(data)
}
var arguments = Array(CommandLine.arguments.dropFirst())
var socketPath: String?
if let index = arguments.firstIndex(of: "--socket") {
    guard arguments.count > index + 1 else { fputs("--socket requires a path\n", stderr); exit(2) }
    socketPath = arguments[index+1]; arguments.removeSubrange(index...index+1)
}
let transport = Transport(path: socketPath)
if arguments.first == "call" {
    do {
        guard arguments.count >= 2 else { throw BridgeError.message("Usage: palworld-mcp call METHOD [JSON]") }
        let data = Data((arguments.count > 2 ? arguments[2] : "{}").utf8)
        guard var request = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw BridgeError.message("Expected a JSON object.") }
        request["method"] = arguments[1]
        let result = try transport.call(request); output(result)
        exit(result["ok"] as? Bool == true ? 0 : 1)
    } catch { fputs(error.localizedDescription + "\n", stderr); exit(1) }
}
if arguments.first == "installed" { print(L10n.text("cli.installed")); exit(0) }
if arguments.first == "--help" {
    print(L10n.text("cli.help"))
    print("palworld-mcp [--stdio] [--socket PATH]\npalworld-mcp call METHOD [JSON]\npalworld-mcp config")
    exit(0)
}
if arguments.first == "config" {
    let path = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
    output(["mcpServers": ["palworld": ["command": path, "args": ["--stdio"]]]])
    exit(0)
}
guard arguments.isEmpty || arguments == ["--stdio"] else { fputs("Unknown arguments. Use --help.\n", stderr); exit(2) }
let server = Server(transport: transport)
var buffer = Data(), oversized = false
while true {
    let data = FileHandle.standardInput.availableData
    if data.isEmpty { break }
    for byte in data {
        if byte == 10 {
            if oversized { output(server.malformed()) }
            else if !buffer.isEmpty, let reply = server.receive(buffer) { output(reply) }
            buffer.removeAll(keepingCapacity: true); oversized = false
        } else if !oversized {
            if buffer.count < 65536 { buffer.append(byte) } else { oversized = true; buffer.removeAll(keepingCapacity: true) }
        }
    }
}

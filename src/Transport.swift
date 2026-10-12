import Foundation
import Darwin

enum BridgeError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct Transport {
    let path: String
    init(path: String? = nil) {
        self.path = path ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PalworldMods/control.sock").path
    }
    func call(_ request: [String: Any]) throws -> [String: Any] {
        guard path.utf8.count < 104 else { throw BridgeError.message("The socket path is too long.") }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw BridgeError.message("Cannot create a local socket.") }
        defer { close(fd) }
        var timeout = timeval(tv_sec: 20, tv_usec: 0), noPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX); address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.utf8) + [0]) }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { throw BridgeError.message("Open Palworld with Palworld Mods before connecting.") }
        var uid: uid_t = 0, gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { throw BridgeError.message("The socket owner does not match this user.") }
        var data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        guard data.count <= 65535 else { throw BridgeError.message("Request exceeds 64 KiB.") }
        data.append(10)
        try data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let count = send(fd, base.advanced(by: offset), buffer.count-offset, 0)
                guard count > 0 else { throw BridgeError.message("The game connection closed. The action was not retried.") }
                offset += count
            }
        }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 8192)
        while result.count <= 1_048_576 {
            let count = recv(fd, &buffer, buffer.count, 0)
            guard count > 0 else { throw BridgeError.message("No game response. Inspect state before retrying an action.") }
            result.append(contentsOf: buffer.prefix(count))
            if let newline = result.firstIndex(of: 10) {
                guard let object = try JSONSerialization.jsonObject(with: result[..<newline]) as? [String: Any] else {
                    throw BridgeError.message("Invalid game response.")
                }
                return object
            }
        }
        throw BridgeError.message("Game response exceeds 1 MiB.")
    }
}

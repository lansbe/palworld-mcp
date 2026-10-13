import Foundation
import CoreFoundation

struct GameTool {
    let name: String
    let method: String
    let description: String
    let properties: [String: [String: Any]]
    let required: [String]
    let readOnly: Bool

    var definition: [String: Any] {
        ["name": name, "description": L10n.text(description),
         "inputSchema": ["type": "object", "properties": properties, "required": required, "additionalProperties": false],
         "annotations": ["readOnlyHint": readOnly, "destructiveHint": !readOnly, "openWorldHint": !readOnly]]
    }

    func request(_ arguments: [String: Any]) throws -> [String: Any] {
        guard required.allSatisfy({ arguments[$0] != nil }), Set(arguments.keys).isSubset(of: Set(properties.keys)) else {
            throw BridgeError.message("Missing or unexpected tool arguments.")
        }
        for (key, value) in arguments {
            let schema = properties[key]!
            switch schema["type"] as? String {
            case "string":
                guard let text = value as? String, text.count <= (schema["maxLength"] as? Int ?? 1024) else { throw BridgeError.message("Invalid string: \(key)") }
                if let choices = schema["enum"] as? [String], !choices.contains(text) { throw BridgeError.message("Unknown value: \(key)") }
            case "boolean":
                guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { throw BridgeError.message("Expected boolean: \(key)") }
            case "number":
                guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                    number.doubleValue >= (schema["minimum"] as? Double ?? -.greatestFiniteMagnitude),
                    number.doubleValue <= (schema["maximum"] as? Double ?? .greatestFiniteMagnitude) else { throw BridgeError.message("Number is out of range: \(key)") }
            case "object":
                guard value is [String: Any] else { throw BridgeError.message("Expected object: \(key)") }
            default: throw BridgeError.message("Unsupported argument schema.")
            }
        }
        var result = arguments; result["method"] = method; return result
    }
}

let textField: [String: Any] = ["type": "string", "maxLength": 256]
let modField: [String: Any] = ["type": "string", "enum": ["minimap", "autonomy"]]
func numberField(_ minimum: Double, _ maximum: Double) -> [String: Any] {
    ["type": "number", "minimum": minimum, "maximum": maximum]
}
let gameTools: [GameTool] = [
    .init(name: "palworld_language", method: "language.get", description: "tool.language", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_set_language", method: "language.set", description: "tool.set_language",
          properties: ["language": ["type": "string", "enum": ["auto"] + L10n.languages]], required: ["language"], readOnly: false),
    .init(name: "palworld_inventory", method: "game.inventory", description: "tool.inventory", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_observe", method: "game.observe", description: "tool.observe", properties: ["radius_m": numberField(1, 500), "capture": ["type": "boolean"]], required: [], readOnly: true),
    .init(name: "palworld_path", method: "game.path", description: "tool.path", properties: ["target": textField], required: ["target"], readOnly: true),
    .init(name: "palworld_aim", method: "game.aim", description: "tool.aim", properties: ["target": textField, "smooth": ["type": "boolean"], "melee": ["type": "boolean"]], required: ["target"], readOnly: false),
    .init(name: "palworld_mod_status", method: "mods.call", description: "tool.mod_status", properties: ["mod": modField, "operation": ["type": "string", "enum": ["status", "settings"]]], required: ["mod", "operation"], readOnly: true),
    .init(name: "palworld_status", method: "host.status", description: "tool.status", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_state", method: "game.state", description: "tool.state", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_ui", method: "ui.list", description: "tool.ui", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_open_menu", method: "ui.open", description: "tool.open_menu",
          properties: ["menu": ["type": "string", "enum": ["options", "inventory", "technology", "pals", "map", "build"]]], required: ["menu"], readOnly: false),
    .init(name: "palworld_click", method: "ui.activate", description: "tool.click",
          properties: ["element": textField], required: ["element"], readOnly: false),
    .init(name: "palworld_set_text", method: "ui.set_text", description: "tool.set_text",
          properties: ["element": textField, "text": textField], required: ["element", "text"], readOnly: false),
    .init(name: "palworld_scroll", method: "ui.scroll", description: "tool.scroll",
          properties: ["element": textField, "amount": numberField(-2000, 2000)], required: ["element", "amount"], readOnly: false),
    .init(name: "palworld_close_menu", method: "ui.back", description: "tool.close_menu",
          properties: ["screen": textField], required: ["screen"], readOnly: false),
    .init(name: "palworld_move", method: "game.move", description: "tool.move",
          properties: ["forward": numberField(-1, 1), "right": numberField(-1, 1), "seconds": numberField(0.05, 2)], required: [], readOnly: false),
    .init(name: "palworld_look", method: "game.look", description: "tool.look",
          properties: ["yaw": numberField(-360, 360), "pitch": numberField(-60, 60), "seconds": numberField(0.1, 2), "smooth": ["type": "boolean"]], required: ["yaw"], readOnly: false),
    .init(name: "palworld_action", method: "game.action", description: "tool.action",
          properties: ["name": ["type": "string", "enum": ["fire", "aim", "alt_fire", "sprint", "dodge", "jump", "crouch", "reload", "throw_pal", "throw_object", "interact", "interact2", "interact3", "interact4", "weapon_next", "weapon_previous", "pal"]], "seconds": numberField(0.05, 2), "kind": numberField(1, 4)], required: ["name"], readOnly: false),
    .init(name: "palworld_stop", method: "game.stop", description: "tool.stop", properties: [:], required: [], readOnly: false),
    .init(name: "palworld_mods", method: "mods.list", description: "tool.mods", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_install_mod", method: "mods.install", description: "tool.install_mod", properties: ["mod": modField], required: ["mod"], readOnly: false),
    .init(name: "palworld_remove_mod", method: "mods.remove", description: "tool.remove_mod", properties: ["mod": modField], required: ["mod"], readOnly: false),
    .init(name: "palworld_enable_mod", method: "mods.enable", description: "tool.enable_mod", properties: ["mod": modField, "enabled": ["type": "boolean"]], required: ["mod", "enabled"], readOnly: false),
    .init(name: "palworld_configure_mod", method: "mods.configure", description: "tool.configure_mod",
          properties: ["mod": modField, "settings": ["type": "object"]], required: ["mod", "settings"], readOnly: false),
    .init(name: "palworld_diagnostics", method: "diagnostics", description: "tool.diagnostics", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_fullscreen", method: "display.fullscreen", description: "tool.fullscreen", properties: [:], required: [], readOnly: false),
]

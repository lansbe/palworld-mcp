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
        ["name": name, "description": description,
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
    .init(name: "palworld_inventory", method: "game.inventory", description: "Read item counts, capture history, carrying capacity and hunger.", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_observe", method: "game.observe", description: "Incrementally observe nearby wild Pals and natural resources. Poll until ready; each call has a bounded scan budget.", properties: ["radius_m": numberField(1, 500), "capture": ["type": "boolean"]], required: [], readOnly: true),
    .init(name: "palworld_path", method: "game.path", description: "Read a walking route to an observed target within 500 metres.", properties: ["target": textField], required: ["target"], readOnly: true),
    .init(name: "palworld_aim", method: "game.aim", description: "Aim smoothly at an observed target and report alignment.", properties: ["target": textField, "smooth": ["type": "boolean"], "melee": ["type": "boolean"]], required: ["target"], readOnly: false),
    .init(name: "palworld_mod_status", method: "mods.call", description: "Read an installed mod's settings or status.", properties: ["mod": modField, "operation": ["type": "string", "enum": ["status", "settings"]]], required: ["mod", "operation"], readOnly: true),
    .init(name: "palworld_status", method: "host.status", description: "Check the local launcher and connection.", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_state", method: "game.state", description: "Read player pose, health, loading and menu state.", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_ui", method: "ui.list", description: "Read current native screens and element IDs. Refresh before each action; IDs expire.", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_open_menu", method: "ui.open", description: "Open a game menu without desktop input.",
          properties: ["menu": ["type": "string", "enum": ["options", "inventory", "technology", "pals", "map", "build"]]], required: ["menu"], readOnly: false),
    .init(name: "palworld_click", method: "ui.activate", description: "Activate an enabled native button from palworld_ui. Do not retry on timeout without inspecting state.",
          properties: ["element": textField], required: ["element"], readOnly: false),
    .init(name: "palworld_set_text", method: "ui.set_text", description: "Edit a visible game text field.",
          properties: ["element": textField, "text": textField], required: ["element", "text"], readOnly: false),
    .init(name: "palworld_scroll", method: "ui.scroll", description: "Scroll a visible native list.",
          properties: ["element": textField, "amount": numberField(-2000, 2000)], required: ["element", "amount"], readOnly: false),
    .init(name: "palworld_close_menu", method: "ui.back", description: "Close the explicitly selected screen from palworld_ui.",
          properties: ["screen": textField], required: ["screen"], readOnly: false),
    .init(name: "palworld_move", method: "game.move", description: "Move on foot relative to the current camera. Movement expires after at most two seconds.",
          properties: ["forward": numberField(-1, 1), "right": numberField(-1, 1), "seconds": numberField(0.05, 2)], required: [], readOnly: false),
    .init(name: "palworld_look", method: "game.look", description: "Set a camera heading with smooth movement by default.",
          properties: ["yaw": numberField(-360, 360), "pitch": numberField(-60, 60), "seconds": numberField(0.1, 2), "smooth": ["type": "boolean"]], required: ["yaw"], readOnly: false),
    .init(name: "palworld_action", method: "game.action", description: "Use an ordinary player input. Only use in the world the user authorized.",
          properties: ["name": ["type": "string", "enum": ["fire", "aim", "alt_fire", "sprint", "dodge", "jump", "crouch", "reload", "throw_pal", "throw_object", "interact", "interact2", "interact3", "interact4", "weapon_next", "weapon_previous", "pal"]], "seconds": numberField(0.05, 2), "kind": numberField(1, 4)], required: ["name"], readOnly: false),
    .init(name: "palworld_stop", method: "game.stop", description: "Release held inputs and stop movement and camera automation.", properties: [:], required: [], readOnly: false),
    .init(name: "palworld_mods", method: "mods.list", description: "List installed and available mods.", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_install_mod", method: "mods.install", description: "Install a bundled mod without restarting the game.", properties: ["mod": modField], required: ["mod"], readOnly: false),
    .init(name: "palworld_remove_mod", method: "mods.remove", description: "Uninstall a mod and clean up its runtime state.", properties: ["mod": modField], required: ["mod"], readOnly: false),
    .init(name: "palworld_enable_mod", method: "mods.enable", description: "Enable or disable an installed mod.", properties: ["mod": modField, "enabled": ["type": "boolean"]], required: ["mod", "enabled"], readOnly: false),
    .init(name: "palworld_configure_mod", method: "mods.configure", description: "Update validated settings. Autonomy only starts when running is explicitly true.",
          properties: ["mod": modField, "settings": ["type": "object"]], required: ["mod", "settings"], readOnly: false),
    .init(name: "palworld_diagnostics", method: "diagnostics", description: "Read bounded runtime errors and CPU timing samples.", properties: [:], required: [], readOnly: true),
    .init(name: "palworld_fullscreen", method: "display.fullscreen", description: "Apply and save fullscreen mode.", properties: [:], required: [], readOnly: false),
]

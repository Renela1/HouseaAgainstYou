# House Against You

A small, data-driven 2D escape-room prototype in **Godot 4.7**. Pick up keys,
work around the house's hostile watchers, and get out through the final door
before your patience with the house runs out.

## Requirements

- **Godot 4.7+** (developed with 4.7.2, GL Compatibility renderer). No external
  runtime dependencies. On Windows the console executable may be named
  `godot_console.exe` instead of `godot` — use whichever is on your `PATH`.

## Play

1. Open `project.godot` in Godot and press **F5**, or run:

   ```powershell
   godot --path .
   ```

2. **WASD** or the **arrow keys** move the player. The camera follows.
3. **Left-click** an object while the player's faint reach ring overlaps it to
   interact. Clicking something out of reach is refused with on-screen feedback.
4. Explore, collect the **golden key**, and interact with every hostile to calm
   it (`IDLE`) or shut it down with the **EMP gadget** (`DISABLED`).
5. Reach the **final door** with the golden key while all hostiles are disabled.
   A failed attempt wakes any idle hostiles and costs one unit of patience; when
   the patience meter fills you still leave — but the house burns, and the level
   restarts with pickups and consumables restored.

## How it works

Everything gameplay-related is defined in `Resource` files, so new objects need
no new scripts:

| Folder | Contents |
| --- | --- |
| `items/` | `ItemData` (one resource per item), `PickableItem`, inventory UI, `definitions/*.tres` |
| `interactions/` | `InteractableData`, `InteractionRule`, `InteractableObject`, `FinalDoor`, `definitions/*.tres` |
| `hostiles/` | `HostileData`, `HostileObject`, `definitions/*.tres` |
| `containers/` | `ContainerData`, `ContainerEntry`, `ContainerObject`, `definitions/*.tres` |
| `components/` | `InteractZone` — the shared reach/click gatekeeper for pickups, objects and hostiles |
| `systems/` | `Inventory` autoload (12 slots, item queries, reset) |
| `ui/` | Inventory HUD and the patience meter |
| `addons/godot_mcp/` | Optional editor tooling for the Godot MCP bridge; not needed to play |

### Interactables

An `InteractableData` resource describes the look, the `solid` collision flag,
and a list of `InteractionRule`s (required inventory item, optional consumable,
success/failure text). Doors drop their blocker when opened; fixtures stay
solid. `FinalDoor` extends `InteractableObject` and reuses the same reach and
click routing while adding the key gate, hostile wake-up logic and patience.

### Hostiles

Each hostile runs its own state machine and timers, all configured on its
`HostileData` resource:

- `IDLE` — counts down `wake_seconds` (0 disables the countdown). If the player
  stands in its sight cone, the countdown **stops and resets**, resuming at full
  length when the player looks away.
- `ACTIVE` — alert and latched. If the player enters its sight cone it enters
  `HIDE` instead.
- `HIDE` — alert but hiding from the player's gaze; returns to `ACTIVE` when the
  player leaves its line of sight.
- `DISABLED` — has no sight at all. Counts down `disable_seconds` and comes back
  when it expires (0 = stays down permanently).

Interacting normally calms a hostile to `IDLE` (with a short blind grace period);
interacting while carrying the EMP gadget disables it. Every state can have its
own colour and, when a `SpriteFrames` resource is assigned, its own animation
(`idle`, `active`, `hide`, `disabled`). Hostiles are solid in every state; the
collision blocker always uses the base size so an active scale change cannot
push the player around.

### Containers

`ContainerData` definitions in `containers/definitions/` describe the solid
body, `InteractionRule` conditions (the same key/item rules as interactables), a
list of `ContainerEntry` resources (item + amount), feedback messages, and a
`SpriteFrames` set with `closed` / `open` animations. Place an instance of
`container_object.tscn` in a level, assign its data, and optionally set
`starts_open` / `starts_full` on the instance.

A container is solid like a fixture in both states. Interacting while **FULL**
checks the conditions and the bag's remaining room; on success it consumes any
consumable condition, transfers every item at once, flips to **EMPTY** and
forces **OPEN**. While EMPTY, interactions only toggle OPEN/CLOSED (conditions
still apply). If the bag cannot hold all the loot, the interaction is refused
before the key is spent or the contents change. `refill()` restores the full
state. The demo cabinet in `main.tscn` needs the rusty key and holds three coins
and another key.

### Pause menu

A small burgundy pause button sits in the top-left corner; clicking it or
pressing **Escape** / **P** freezes the game and drops down four buttons:
**Back to Main Menu** and **Options** are placeholders that just acknowledge the
click, **Resume** unfreezes the game, and **Restart** clears the inventory and
reloads the scene so every object returns to its starting state.

The button artwork is the three-state burgundy tileset in
`art/ui/three_state_burgundy_buttons.png`. `ui/definitions/burgundy_button.tres`
maps its rows to normal, hover and pressed regions; edit that one resource to
change the look of every menu button. `ButtonSkin` also supplies flat-colour
fallbacks if no atlas is assigned.

## Verification

A quick headless load should exit cleanly with no script errors:

```powershell
godot --headless --path . --quit-after 20
```

## License

MIT — see [LICENSE](LICENSE).

# Fast Travel To and From Interiors

Developed using Bethesda's Creation Kit and Papyrus scripting language.  
This mod lets Skyrim players travel directly to predefined destinations, including interior locations that Skyrim's normal fast-travel system does not support.

**Published mod:** [Fast Travel To and From Interiors SE on Nexus Mods](https://www.nexusmods.com/skyrimspecialedition/mods/43429)

## The programming challenge

The implementation had to work around two important limitations:

1. Creation Kit's Message-based menu system does not support hierarchical submenus.
2. Papyrus does not support multidimensional arrays or arrays of arrays.

Bethesda’s Creation Kit modding toolset provides a Message-based menu system that can be displayed to the end user, but it does not provide native support for hierarchical navigation. Since this mod needs to provide access to as many as 100 fast-travel locations organized into logical categories, a single flat menu would quickly become cumbersome.

To solve that limitation, a custom submenu system was built on top of Bethesda's existing menu API. The code stores the menu structure separately from the interface and tracks the user's current position within that structure. Each selection is interpreted according to the current menu level, allowing the program to display the appropriate child categories, destinations, or navigation controls such as Back.

In effect, the mod treats Bethesda's flat menu as a rendering layer and implements the hierarchy itself in code. This makes it possible to present a large number of destinations through a compact, intuitive navigation structure without requiring native submenu support from the game engine.

The main challenge was not simply displaying different menus, but maintaining the relationship between menu state, displayed options, and the action associated with each selection. The resulting system provides predictable navigation through multiple levels while remaining within the constraints of Bethesda's scripting environment.

Papyrus presents another constraint: it does not support arrays of arrays. Conceptually, the destination data is two-dimensional — a destination belongs to a category and occupies a position within that category — but it cannot be represented directly that way. The solution is to store the destinations in a one-dimensional array and translate the current category, page, and menu selection into the corresponding array index. This allows the code to treat the data as though it were organized in multiple dimensions while remaining compatible with Papyrus's simpler array model.

## About Skyrim and why this mod

Bethesda's Skyrim video game includes a fast-travel system that allows players to travel between discovered locations, but generally restricts travel to exterior locations outside buildings and city walls. The game's built-in fast-travel system does not support traveling directly to or from most interior locations.

This mod works around that limitation by bypassing Skyrim's fast-travel system entirely and using a separate mechanism to move the player's character directly to predefined destinations, including interior locations. Players select their destinations through a hierarchy of custom in-game menus, providing quick access to as many as 100 locations organized by category.

## How the destination data works

Each category occupies a fixed block of ten positions in `LocationMasterList`. Conceptually, the data represents:

```text
destinations[category][slot]
```

The script translates those two coordinates into a single array index:

```papyrus
Int slotIndex = (buttonIndex - 1) + (pageIndex * EntriesPerPage)
Return (categoryIndex * EntriesPerCategory) + slotIndex
```

Destination buttons are numbered 1–5, while array slots start at zero. Each page accounts for five destinations, and each category accounts for ten array positions.

For example, choosing the second destination on the second page of the Smiths category gives:

| Value | Result |
| --- | --- |
| Category index | `3` |
| Page index | `1` |
| Destination button | `2` |
| Slot within the category | `(2 - 1) + (1 * 5) = 6` |
| Flat array index | `(3 * 10) + 6 = 36` |
| Destination property | `Loc24Markarth` |

Categories with fewer than ten destinations leave their unused slots unassigned.

A separate `CategoryMenu` array stores the Message forms:

- `CategoryMenu[categoryIndex]` stores the category's first page.
- `CategoryMenu[categoryIndex + 10]` stores its second page.

The destination array and menu array therefore have different layouts, connected by the same category index.

## Navigation and source organization

A loop is used with local variables for the selected category and page. Back and More update those variables; the next iteration displays the appropriate menu.

The flattened arrays still organize the data. The loop handles movement through the menus.

| Function | Responsibility |
| --- | --- |
| `Initialize

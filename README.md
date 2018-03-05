# Fork
This is a fork of [/Azurblau/AzBot](https://github.com/Azurblau/AzBot) with new features and some bugfixes.

Here is a list of notable changes compared to the original version:
- Unidirectional links.
- Links which are only usable by fast zombies.
- Some more specific movement instructions for nodes to allow bots to handle obstacles better. (Duck when on a node, duck when moving towards a node, aim straight when on a node, aim straight towards a node, ...)
- Conditions for nodes. (Allow or disallow the use of a node, if the said node is close to specific entities like doors, breakables, physic props, etc.)
- Pouncing behaviour for fast zombies or zombies based on that class. This makes these zombies much more dangerous, as they will hit you with a high certainty if you are within their jump range. They'll also use that ability to jump to the next or second next node if possible.
- Small adjustments to the inner workings of the pathfinding algorithm. For example bots will now walk towards the next node until they are within its reach, and not until they are closest to it. This makes the bots movement behaviour more predictable for nodemesh creators, and also prevents bots from running in circles sometimes.
- Zombies will only attack if the target is within reach. This makes wraith and fast zombie attacks much more surprising and effective.
- Fix bots glitching outside of the map if they spawn inside a trigger_zombieclass brush.
- Fix zombie class selection logic for bots.
- Bots now crouch when their target is low.
- Prevent links linking a node to itself.
- Github friendly navmesh format.
- More example navmeshes, which make use of all the new features.
- Some smaller things i possibly forgot.

This fork is backward compatible, but there are some changes which prevents you to use navmeshes from this fork in the original version. To make them work just replace all occurences of `\n` with `;`.

Everything below here is the original readme, but with updated informations:

![](https://github.com/Azurblau/AzBot/raw/master/media/screenshot1.jpg)
Server: pussfoot.ovh:27015 [EU] Zombie Survival | AzBot | Custom Content

# AzBot
A very primitive AI for GMod bots primarily designed to work with Jetboom's Zombie Survival gamemode.

AzBot uses A* pathfinding with directed Monte Carlo-based execution.

# License
I, the author, have not decided on a license yet.

Though I won't take measures against illegimate usage unless I have reasons to do so.
##### Things I'll accept:
- Using AzBot on your own server even if it accepts donations.
- Making derivatives (aka copies with changes) of AzBot or its derivatives as long as it's made clear at least ingame that they're AzBot derivatives.
  
  I suggest giving the derivative your own name (e.g. BobBot) and putting e.g. "BobBot is based on AzBot" in your MotD, GUI, HUD or automatic chat messages.

##### Things I won't like:
- Selling AzBot or its derivatives (I don't plan to sell it either).

# Prerequisites
- Zombie Survival gamemode
- Multiplayer (bots use player slots, local server is sufficient)
- ULX (navmesh editor, !botmod and !human commands)
- NavMeshes (see "How to create navmeshes" below)

# How to test:
- Install addon (e.g. garrysmod/addons/azbot/lua/...).
- Download and install zs_villagehouse.bsp: https://garrysmods.org/download/16130/zs-villagehousezip
- Move data/azbot/navmesh/map/zs_villagehouse.txt to garrysmod/data/azbot/navmesh/map/zs_villagehouse.txt (the addons/\*/data/ folder didn't seem to work in my tests, making this step necessary).
- Launch Garry's Mod and start a 32 slot local server game with Zombie Survival gamemode on zs_villagehouse.
- If 2 bots spawn and chase after you, everything is working as intended.
- Type !azbot viewmesh \* to see the navmesh and !botmod -999 to kick all bots (both commands require ULX).

![](https://github.com/Azurblau/AzBot/raw/master/media/navmesh1.jpg)

# How to create navmeshes:
- Use the console command "azbot editmesh \<your name\>" to enter the editor.
  - Use IN_RELOAD to cycle through the edit modes:
    - Create node: Place nodes with IN_ATTACK.
    - Link nodes: Link nodes by selecting the first then the second node, both with IN_ATTACK. Clear selection with IN_RELOAD.
    - Reposition nodes: Select a node with IN_ATTACK and use IN_ATTACK to reposition it or IN_ATTACK2 to reposition it using only the aim axis (X, Y or Z). Clear selection with IN_RELOAD.
    - Resize nodes: Select a node with IN_ATTACK and use IN_ATTACK2 to resize it on the aim axis (X or Y). Clear selection with IN_RELOAD.
    - Copy nodes: Select nodes with IN_ATTACK and use IN_ATTACK2 to copy them offset towards the aim axis (first selected node and cursored position are used as reference for the offset distance).
    - Delete items: Delete a node or link with IN_ATTACK, clear node areas with IN_ATTACK2.
- Use "azbot setparam \<id\> \<name\> \<value\>" (example: azbot setparam 1 Jump Disabled) to set special parameters:
  - Node parameters:
    - Jump = Disabled: Bots won't jump if located in this node.
    - Jump = Always: Bots will always jump if located in this node.
    - JumpTo = Disabled: Bots won't jump if heading towards this node.
    - JumpTo = Always: Bots will always jump if heading towards this node.
    - Duck = Disabled: Bots won't crouch if located in this node.
    - Duck = Always: Bots will always crouch if located in this node.
    - DuckTo = Disabled: Bots won't crouch if heading towards this node.
    - DuckTo = Always: Bots will always crouch if heading towards this node.
    - Wall = Suicide: Bots suicide if trying to navigate towards this node higher than crouch-jumping height. Use this when respawn is the only way to get to that node.
    - Wall = Retarget: Same as Wall = Suicide but target is changed instead of suiciding. If no other targets are available, target remains the same. Use this for unreachable or low priority nodes.
    - See = Disabled: Bot does not approach target in straight line even if target is visible to him unless he is on the same node as the target. Use this on heightened nodes visible to, but not directly accessible from lower nodes.
    - Aim = Straight: Bot goes straight to the next node. Use this if bots need to get through small holes in the floor or walk on narrow paths without falling down.
    - AimTo = Straight: Bot goes straight to this node. Use this if bots need to get through narrow windows or small holes in the floor.
    - Cost: Add a penalty for paths using this node. Higher values makes it less likely for bots to use a path containing this node.
	- Condition = Unblocked: Only use this node for pathfinding if there is no entity within a range of one inch. Detected entities are func_breakable, prop_physics, prop_dynamic, prop_door_rotating, func_door, func_physbox_multiplayer, func_movelinear.
	- Condition = Blocked: Opposite of above. Use this for breakable pathways.
  - Link parameters:
    - Cost: Add a penalty for paths using this link. Higher values makes it less likely for bots to use a path containing this link.
	- Direction = Forward: Only allow paths from the first to the second element of the link. "azbot setparam 1-2 Unidir Forward" will only allow the bot to move from 1 to 2.
	- Direction = Backward: Same as above, but backwards.
	- Pouncing = Needed: Only classes with the ability to pounce/leap can use this link.
- Use "azbot reloadmesh" to discard changes.
- Use "azbot savemesh" to save the changes to garrysmod/data/azbot/navmesh/map/\<mapname\>.txt.
- Use "azbot setmapparam \<name\> \<value\>" (example: azbot setmapparam botmod 5) to set map specific parameters:
  - BotMod: Map specific zombie count formula offset.
- Prefix a command with an exclamation mark to use it in chat.

### Notes:
- Restart the map after saving the mesh for the first time. Every map that has a navmesh at addon loading time is treated as a bot map (enabling the bot count director, !human command and survivor bonuses). Move the navmesh file if that effect is not desired.
- Use !botmod to change the desired zombies count. Examples: !botmod -100 for no bots, !botmod 100 for full server minus 2 slots for joining players, default is !botmod 1.
- Navmeshes can be edited on the fly. Feel free to fix your meshes during testing.
- This sketch might help: https://github.com/Azurblau/AzBot/raw/master/media/navmesh2.png
- Having sized nodes helps locating (= "what node are you in?"). Unsized nodes use a small sphere instead of a rectangular area.
- Once a bot enters a node's area/sphere, he immediately moves towards the next node's position.
- It is recommended to use sized nodes for rooms/areas and unsized nodes for doors. Each hallway, intersection and groove should have their own sized node. For ladders, two unsized nodes, one at bottom and one at top, suffice.
- Locating works by proximity check. If a separate node lies behind a wall but closer to the middle of two distant linked nodes than them, bots may assume wrongly that they are located at the other node if they're in the middle. Avoid that by using a third sized node for the gap between the two linked nodes and re-link them.
- Once a bot sees the target, he moves straight for it (see also: See = Disabled parameter).
- All links are bidirectional (see also: Wall = Suicide parameter).
- Bots can take any route with tendency towards the shortest.
- Bots stubbornly move towards the next node unless they enter another node at time of path refresh (occurs roughly every second). Link wisely.

![](https://github.com/Azurblau/AzBot/raw/master/media/screenshot2.jpg)

# Current Project Status
Not being worked on. ETA for ToDo: +∞. Just bugfixes or dirty changes on contributor's demand.

# ToDo
Starting with highest public priority:
- Making a config.txt for the static variables.
- Refactoring, e.g. stable API, stable navmesh standard, consistency, bot metatable, gamemode independence by adding hooks usable by gamemodes or gamemode-based plugins, ...
- Detailed linking e.g. required jump height, movement behaviour (gap-jumping, ...), link unlock conditions, ...
- Map information in navmeshes using a singleton item type solely for storing parameters (e.g. zombie count multiplier).
- Leap behaviour for headcrab bots.
- Sloped nodes for more accurate locating of entities.
- Triangle-based nodes using vertices with automatic adjacence linking.
- Subpaths in nodes for more accurate movement (no "wall-sliding").
- Shooting, escape and equipment upgrading behaviour for survivor bots.
- Caching of non-branching paths as a single node to optimize the pathfinding performance.

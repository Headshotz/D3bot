D3bot.Handlers.Survivor_Fallback = D3bot.Handlers.Survivor_Fallback or {}
local HANDLER = D3bot.Handlers.Survivor_Fallback

HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_SURVIVOR or (TEAM_REDEEMER and team == TEAM_REDEEMER)
end

HANDLER.Weapon_Types = {}
HANDLER.Weapon_Types.RANGED = 1
HANDLER.Weapon_Types.MELEE = 2

function HANDLER.WeaponRatingFunction(weapon, targetDistance)
	local sweptable = weapons.GetStored(weapon.ClassName)
	local weaponType = HANDLER.Weapon_Types.MELEE
	if weapon.Base == "weapon_zs_base" then
		weaponType = HANDLER.Weapon_Types.RANGED
	end
	
	local targetDiameter = 2
	local targetArea = math.pi * math.pow(targetDiameter / 2, 2)
	
	local numShots = sweptable.Primary.NumShots or 1
	local damage = (sweptable.Damage or sweptable.Primary.Damage or 0)
	local delay = sweptable.Primary.Delay or 1
	local cone = ((weapon.ConeMax or 45) + (weapon.ConeMin or 45)*10) / 11
	
	local dmgPerSec = damage * numShots / delay -- TODO: Use more parameters like reload time.
	local maxDistance = targetDiameter / math.tan(math.rad(cone)) / 2
	local spreadArea = math.pi * math.pow(math.tan(math.rad(cone)) * targetDistance, 2)
	
	local areaIntersection = math.min(targetArea, spreadArea) / spreadArea
	
	local rating = dmgPerSec * areaIntersection
	
	return weaponType, rating, maxDistance
end

function HANDLER.UpdateBotCmdFunction(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	if not bot:Alive() then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end
	
	bot:D3bot_UpdatePathProgress()
	local mem = bot.D3bot_Mem
	
	local result, actions, forwardSpeed, aimAngle = D3bot.Basics.WalkAttackAuto(bot)
	if result then
		actions.Attack = false
	else
		result, actions, forwardSpeed, aimAngle = D3bot.Basics.AimAndShoot(bot, mem.AttackTgtOrNil, mem.maxShootingDistance)
		if not result then
			result, actions, forwardSpeed, aimAngle = D3bot.Basics.LookAround(bot)
			if not result then return end
		end
	end
	
	local buttons
	if actions then
		buttons = bit.bor(actions.Attack and IN_ATTACK or 0, actions.Attack2 and IN_ATTACK2 or 0, actions.Reload and IN_RELOAD or 0, actions.Duck and IN_DUCK or 0, actions.Jump and IN_JUMP or 0, actions.Use and IN_USE or 0)
	end
	
	if aimAngle then bot:SetEyeAngles(aimAngle)	cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	if buttons then cmd:SetButtons(buttons) end
end

function HANDLER.FindEscapePath(node, enemies)
	local tempNodePenalty = {}
	for _, enemy in pairs(enemies) do
		tempNodePenalty = D3bot.NeighbourNodeFalloff(D3bot.MapNavMesh:GetNearestNodeOrNil(enemy:GetPos()), 2, 1, 0.5, tempNodePenalty)
	end
	
	local function pathCostFunction(node, linkedNode, link)
		
		local nodeMetadata = D3bot.NodeMetadata[linkedNode]
		local playerFactorBySurvivors = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_SURVIVOR] or 0
		local playerFactorByUndead = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_UNDEAD] or 0
		local cost = -playerFactorBySurvivors * 50 + playerFactorByUndead * 150 + (tempNodePenalty[linkedNode] or 0) * 500
		--for _, enemy in pairs(enemies) do
		--	cost = cost + 100 / (LerpVector(0.5, node.Pos, linkedNode.Pos):Distance(enemy:GetPos()) + 100) * 0.1 * node.Pos:Distance(linkedNode.Pos) -- Weight by link length
		--end
		return cost-- + node.Pos:Distance(linkedNode.Pos) * 2
	end
	local function heuristicCostFunction(node)
		local nodeMetadata = D3bot.NodeMetadata[node]
		--local playerFactorBySurvivors = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_SURVIVOR] or 0
		local playerFactorByUndead = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_UNDEAD] or 0
		return playerFactorByUndead * 150 + (tempNodePenalty[node] or 0) * 10
	end
	return D3bot.GetEscapeMeshPathOrNil(node, 50, pathCostFunction, heuristicCostFunction, {Walk = true})
end

function HANDLER.FindPathToHuman(node)
	local function pathCostFunction(node, linkedNode, link)
		return node.Pos:Distance(linkedNode.Pos)
	end
	local function heuristicCostFunction(node)
		local nodeMetadata = D3bot.NodeMetadata[node]
		local playerFactorBySurvivors = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_SURVIVOR] or 0
		local playerFactorByUndead = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_UNDEAD] or 0
		return - playerFactorBySurvivors * 160 + playerFactorByUndead * 150
	end
	return D3bot.GetEscapeMeshPathOrNil(node, 400, pathCostFunction, heuristicCostFunction, {Walk = true})
end

function HANDLER.CanShootTarget(bot, target)
	if not IsValid(target) then return end
	local origin = bot:D3bot_GetViewCenter()
	local targetPos = target:D3bot_GetViewCenter()
	local tr = util.TraceLine({
		start = origin,
		endpos = targetPos,
		filter = player.GetAll(),
		mask = MASK_SHOT_HULL
	})
	return not tr.Hit
end

function HANDLER.ThinkFunction(bot)
	local mem = bot.D3bot_Mem
	local botPos = bot:GetPos()
	
	if not HANDLER.IsEnemy(bot, mem.AttackTgtOrNil) then mem.AttackTgtOrNil = nil end
	
	if mem.nextUpdateSurroundingPlayers and mem.nextUpdateSurroundingPlayers < CurTime() or not mem.nextUpdateSurroundingPlayers then
		mem.nextUpdateSurroundingPlayers = CurTime() + 0.5
		local enemies = D3bot.From(player.GetAll()):Where(function(k, v) return HANDLER.IsEnemy(bot, v) end).R
		local closeEnemies = D3bot.From(enemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 1000 end).R -- TODO: Constant for the distance
		local closerEnemies = D3bot.From(closeEnemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 600 end).R -- TODO: Constant for the distance
		local dangerouscloseEnemies = D3bot.From(closerEnemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 300 end).R -- TODO: Constant for the distance
		if table.Count(dangerouscloseEnemies) > 0 then
			mem.AttackTgtOrNil = table.Random(dangerouscloseEnemies)
			-- Check if undead can see/walk to bot, and then calculate escape path.
			if mem.AttackTgtOrNil:D3bot_CanSeeTarget(nil, bot) and (not mem.NextNodeOrNil or mem.lastEscapePath and mem.lastEscapePath < CurTime() - 2 or not mem.lastEscapePath) then
				mem.lastEscapePath = CurTime()
				escapePath = HANDLER.FindEscapePath(D3bot.MapNavMesh:GetNearestNodeOrNil(botPos), closeEnemies)
				if escapePath then
					D3bot.Debug.DrawPath(GetPlayerByName("D3"), escapePath, nil, nil, true)
					mem.holdPathTime = CurTime() + 2
					bot:D3bot_ResetTgt()
					bot:D3bot_SetPath(escapePath) -- Dirty overwrite of the path, as long as no other target is set it works fine
				end
			end
		else
			if not mem.holdPathTime or mem.holdPathTime < CurTime() then
				bot:D3bot_ResetTgt()
			end
			if not HANDLER.IsEnemy(bot, mem.AttackTgtOrNil) or not HANDLER.CanShootTarget(bot, mem.AttackTgtOrNil) then mem.AttackTgtOrNil = table.Random(closeEnemies) or table.Random(enemies) or nil end
			if (mem.nextHumanPath or 0) < CurTime() then
				mem.nextHumanPath = CurTime() + 10 + math.random() * 20
				path = HANDLER.FindPathToHuman(D3bot.MapNavMesh:GetNearestNodeOrNil(botPos))
				if path then
					D3bot.Debug.DrawPath(GetPlayerByName("D3"), path, nil, Color(0, 0, 255), true)
					mem.holdPathTime = CurTime() + 20
					bot:D3bot_ResetTgt()
					bot:D3bot_SetPath(path) -- Dirty overwrite of the path, as long as no other target is set it works fine
				end
			end
		end
	end
	
	if mem.nextUpdateOffshoot and mem.nextUpdateOffshoot < CurTime() or not mem.nextUpdateOffshoot then
		mem.nextUpdateOffshoot = CurTime() + 0.4 + math.random() * 0.2
		bot:D3bot_UpdateAngsOffshoot() -- TODO: Less offshoot
	end
	
	if mem.nextUpdatePath and mem.nextUpdatePath < CurTime() or not mem.nextUpdatePath then
		mem.nextUpdatePath = CurTime() + 0.9 + math.random() * 0.2
		bot:D3bot_UpdatePath()
	end
	
	if mem.nextHeldWeaponUpdate and mem.nextHeldWeaponUpdate < CurTime() or not mem.nextHeldWeaponUpdate then
		mem.nextHeldWeaponUpdate = CurTime() + 1 + math.random() * 1
		local weapons = bot:GetWeapons()
		local filteredWeapons = {}
		local bestRating, bestWeapon = 0, nil
		local enemyDistance = mem.AttackTgtOrNil and mem.AttackTgtOrNil:GetPos():Distance(bot:GetPos()) or 300
		for _, v in pairs(weapons) do
			local weaponType, rating, maxDistance = HANDLER.WeaponRatingFunction(v, enemyDistance)
			local ammoType = v:GetPrimaryAmmoType()
			local ammo = v:Clip1() + bot:GetAmmoCount(ammoType)
			if ammo > 0 and bestRating < rating and weaponType == HANDLER.Weapon_Types.RANGED then
				bestRating, bestWeapon, bestMaxDistance = rating, v.ClassName, maxDistance
			end
		end
		if bestWeapon then
			bot:SelectWeapon(bestWeapon)
			mem.maxShootingDistance = bestMaxDistance
		end
	end
end

function HANDLER.OnTakeDamageFunction(bot, dmg)
	local attacker = dmg:GetAttacker()
	if not HANDLER.CanBeShootTgt(bot, attacker) then return end
	local mem = bot.D3bot_Mem
	--if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():Distance(bot:GetPos()) <= D3bot.BotTgtFixationDistMin then return end
	mem.AttackTgtOrNil = attacker
	--bot:Say("Stop That! I'm gonna shoot you, "..attacker:GetName().."!")
	--bot:Say("help")
end

function HANDLER.OnDoDamageFunction(bot, dmg)
	--bot:Say("Gotcha!")
end

function HANDLER.OnDeathFunction(bot)
	--bot:Say("rip me!")
end

function HANDLER.IsEnemy(bot, ply)
	if IsValid(ply) and bot ~= ply and ply:IsPlayer() and ply:Team() ~= TEAM_SURVIVOR and ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive() then return true end
end

function HANDLER.CanBeShootTgt(bot, target)
	if not target or not IsValid(target) then return end
	if target:IsPlayer() and target ~= bot and target:Team() ~= TEAM_SURVIVOR and target:GetObserverMode() == OBS_MODE_NONE and target:Alive() then return true end
end
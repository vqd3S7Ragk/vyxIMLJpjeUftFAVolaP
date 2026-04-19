--my dumbass forgot to save any changes i made, ima rebuild from the ground up anyways

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local TeleportService  = game:GetService("TeleportService")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local SoundService     = game:GetService("SoundService")
local GuiService        = game:GetService("GuiService")
local HttpService       = game:GetService("HttpService")

local mfloor  = math.floor
local mclamp  = math.clamp
local mabs    = math.abs
local mrandom = math.random
local tick    = tick


--REFS
local plr      = Players.LocalPlayer
local char     = plr.Character or plr.CharacterAdded:Wait()
local hrp      = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local cam      = Workspace.CurrentCamera
local mouse    = plr:GetMouse()
local rocketSystem = ReplicatedStorage:WaitForChild("RocketSystem")
local ev           = rocketSystem:WaitForChild("Events")
local fx           = ev:WaitForChild("RocketReloadedFX")
local fire         = ev:WaitForChild("FireRocket")
local hitRemote    = ev:WaitForChild("RocketHit")
local expEvent     = ev:FindFirstChild("ExplosionsMake")

--STATES (add more as new functions are added)
local states = {
    flying = false,
    flySpeed = 100,
    espEnabled = false,
    espBoxes = {},
    vehicleESPBoxes = {},
    myBase = nil,
    flyBV = nil,
    flyBG = nil,
    keys = { W=false,A=false,S=false,D=false,Space=false,Ctrl=false,E=false,Q=false },
    firerate = 0.001,
    maxDistance = 8000,
    rocketsPerTarget = 1,
    spreadRadius = 1,
    whitelist = {},
    simultaneousFire = false,
    clickRPGEnabled = false,
    rpgEnabled = false,
    isMouseHeld = false,
    patternMode = "None",
    patternSize = 200,
    customText = "PROXY",
    targetTypes = { Players=true, Vehicles=false, BaseShields=false, ElectricalBoxes=false },
    cachedWeapon = nil,
    cachedTargets = {},
    lastTargetUpdate = 0,
    TARGET_CACHE_RATE = 0.1,
    noClipEnabled = false; noClipConnection  = nil; noClipOriginals = {},
    spinBotEnabled = false,
    spinBotSpeed = 360,
    spinBAV = nil,
    spinSavedAutoRotate  = true,
    selfChamsEnabled  = false; selfChamsHighlight = nil,
    cbringEnabled = false,
    cbringTarget = nil,
    cbringConnection = nil,
    cbringTargets = {},
    terminated = false
}
local flying = states.flying
local flySpeed = states.flySpeed
local espEnabled = states.espEnabled
local espBoxes = states.espBoxes
local vehicleESPBoxes = states.vehicleESPBoxes
local myBase = states.myBase
local flyBV = states.flyBV
local flyBG = states.flyBG
local keys = states.keys
local firerate = states.firerate
local maxDistance = states.maxDistance
local rocketsPerTarget = states.rocketsPerTarget
local spreadRadius = states.spreadRadius
local whitelist = states.whitelist
local simultaneousFire = states.simultaneousFire
local clickRPGEnabled = states.clickRPGEnabled
local rpgEnabled = states.rpgEnabled
local isMouseHeld = states.isMouseHeld
local patternMode = states.patternMode
local patternSize = states.patternSize
local customText = states.customText
local targetTypes = states.targetTypes
local cachedWeapon = states.cachedWeapon
local cachedTargets = states.cachedTargets
local lastTargetUpdate = states.lastTargetUpdate
local TARGET_CACHE_RATE = states.TARGET_CACHE_RATE
local noClipEnabled = states.noClipEnabled
local noClipConnection = states.noClipConnection
local noClipOriginals = states.noClipOriginals
local spinBotEnabled = states.spinBotEnabled
local spinBotSpeed = states.spinBotSpeed
local spinBAV = states.spinBAV
local spinSavedAutoRotate = states.spinSavedAutoRotate
local selfChamsEnabled = states.selfChamsEnabled
local selfChamsHighlight = states.selfChamsHighlight
local cbringEnabled = states.cbringEnabled
local cbringTarget = states.cbringTarget
local cbringConnection = states.cbringConnection
local cbringTargets = states.cbringTargets
local terminated = states.terminated
--Constants
local VEHICLE_WORKSPACES = {
	{name="Gunship Workspace"},{name="Vehicle Workspace"},{name="Tank Workspace"},
	{name="Submarine Workspace"},{name="Rc Workspace"},{name="Helicopter Workspace"},
	{name="Hovercraft Workspace"},{name="Plane Workspace"},{name="Boat Workspace"},
}
local VEHICLE_ROOT_NAMES = {"HumanoidRootPart","Main","Seat","VehicleSeat","DriveSeat","Body","Hull","Frame"}
local PATTERNS           = {"None","Custom Text", "Star", "Circle", "Cross", "Diamond", "Square"}

--UTILS
local function findVehicleRoot(v)
	if not v or not v.Parent then return nil end

	local priority = {"HumanoidRootPart", "Main", "Seat", "VehicleSeat", "DriveSeat", "Body", "Hull", "Frame", "Chassis", "Root"}

	for _, name in ipairs(priority) do
		local part = v:FindFirstChild(name)
		if part and part:IsA("BasePart") and part.Parent then
			return part
		end
	end

	-- Safe PrimaryPart check
	local pp = v.PrimaryPart
	if pp and pp:IsA("BasePart") and pp.Parent then
		return pp
	end

	-- Largest valid BasePart fallback
	local best, bestSize = nil, 0
	for _, desc in pairs(v:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name ~= "Handle" and desc.Parent then
			local size = desc.Size.Magnitude
			if size > bestSize then
				best = desc
				bestSize = size
			end
		end
	end

	return best
end

local function getPlayersInVehicles()
	local r={}; local gs=workspace:FindFirstChild("Game Systems"); if not gs then return r end
	for _,wd in ipairs(VEHICLE_WORKSPACES) do
		local f=gs:FindFirstChild(wd.name); if not f then continue end
		for _,veh in pairs(f:GetChildren()) do
			for _,p in pairs(Players:GetPlayers()) do
				if p~=plr and p.Character then
					local h=p.Character:FindFirstChildOfClass("Humanoid")
					if h and h.SeatPart and h.SeatPart:IsDescendantOf(veh) then r[p]=veh end
				end
			end
		end
	end; return r
end

local function vehicleHasWhitelistedPlayer(veh)
	for _,p in pairs(Players:GetPlayers()) do
		if p~=plr and whitelist[p.Name] and p.Character then
			local h=p.Character:FindFirstChildOfClass("Humanoid")
			if h and h.SeatPart and h.SeatPart:IsDescendantOf(veh) then return true end
		end
	end; return false
end

local function isTycoonProtected(ty)
	local o=ty:FindFirstChild("Owner"); if not o or not o.Value then return true end
	return o.Value==plr.Name or whitelist[o.Value]
end

local function findMyBase()
	local tf=workspace:FindFirstChild("Tycoon"); if not tf then return nil end
	local ts=tf:FindFirstChild("Tycoons"); if not ts then return nil end
	for _,t in ts:GetChildren() do local o=t:FindFirstChild("Owner"); if o and o.Value==plr.Name then myBase=t; return t end end
end
local function isMyBasePart(p) return myBase and p:IsDescendantOf(myBase) end
task.spawn(function() while not myBase and not terminated do findMyBase(); task.wait(2) end end)

local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            table.insert(names, p.Name)
        end
    end
    return names
end

--RPG
local function initSystem()
	if not rocketSystem then
		rocketSystem=ReplicatedStorage:FindFirstChild("RocketSystem"); if not rocketSystem then return false end
		ev=rocketSystem:FindFirstChild("Events"); if not ev then return false end
		fx=ev:FindFirstChild("RocketReloadedFX") or ev:FindFirstChild("RocketReloaded")
		fire=ev:FindFirstChild("FireRocketReplicated") or ev:FindFirstChild("FireRocket")
		hitRemote=ev:FindFirstChild("RocketHit"); expEvent=ev:FindFirstChild("ExplosionsMake")
	end; return true
end

local function getRPG()
	if cachedWeapon and cachedWeapon.Parent and (cachedWeapon.Parent==plr.Character or cachedWeapon.Parent==plr.Backpack) then return cachedWeapon end
	for _,c in ipairs({plr.Character,plr.Backpack}) do
		if c then for _,t in c:GetChildren() do if t:IsA("Tool") then local l=string.lower(t.Name); if l:find("rpg") or l:find("rocket") then cachedWeapon=t; return t end end end end
	end; cachedWeapon=nil; return nil
end

local FIRE_SETTINGS={
	expShake={fadeInTime=0.05,magnitude=3,rotInfluence=Vector3.new(0.4,0,0.4),fadeOutTime=0.5,roughness=3,posInfluence=Vector3.new(1,1,0)},
	gravity=Vector3.new(0,0,0),HelicopterDamage=450,FireRate=15,VehicleDamage=350,ExpName="RPG",
	RocketAmount=1,ExpRadius=12,BoatDamage=300,TankDamage=300,Acceleration=8,ShieldDamage=170,
	Distance=8000,PlaneDamage=500,GunshipDamage=170,velocity=200,ExplosionDamage=120,
}
local rocketModel=rocketSystem:FindFirstChild("Rockets") and rocketSystem.Rockets:FindFirstChild("RPG Rocket")

local _sr        = spreadRadius * 100
local fireGen    = 0
local simRunning = false
local rpgConnection = nil
local rpgTimer = 0
local hasShot    = false

-- fireSingleFast: only FireServer calls — zero yield, zero ping dependency.
-- FireRocket (InvokeServer) is dropped entirely. It only spawns a cosmetic rocket
-- model and does NOT deal damage. All damage comes from RocketHit + ExplosionsMake.
local function fireSingleFast(pos, dir, wep, hp, cp, d, gen)
	if not rpgEnabled and not clickRPGEnabled then return end
	if fireGen ~= gen then return end
	if hitRemote and hp then
		hitRemote:FireServer({
			Normal=Vector3.new(0,0,-1), Player=plr, Label=plr.Name.."Rocket0",
			HitPart=hp, Vehicle=wep, Position=pos, Weapon=wep,
		})
	end
	if expEvent and d >= 15 then
		expEvent:FireServer(pos, 25, 220, plr, wep, "RPG_Explosion", tick())
	end
end

local function fireAtTarget(tp, wep, hp, cp, gen)
	if not rpgEnabled then return end
	if not wep or not wep.Parent then return end
	if rocketsPerTarget == 1 then
		local d = (tp - cp).Magnitude
		if d >= 15 then fireSingleFast(tp, (tp-cp).Unit, wep, hp, cp, d, gen) end
		return
	end
	local sr = _sr
	for i = 1, rocketsPerTarget do
		if not rpgEnabled then return end
		local fp = (i > 1 and sr > 0)
			and tp + Vector3.new(mrandom(-sr,sr)/100, mrandom(-sr,sr)/100, mrandom(-sr,sr)/100)
			or  tp
		local d = (fp - cp).Magnitude
		if d >= 15 then fireSingleFast(fp, (fp-cp).Unit, wep, hp, cp, d, gen) end
	end
end

local function fireClickRocket(pos, wep)
	local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not r then return end
	local cp = r.Position
	local d  = (pos - cp).Magnitude
	if d < 15 then return end

	if patternMode == "None" then
		fireSingleFast(pos, (pos-cp).Unit, wep, workspace.Terrain, cp, d, fireGen)
	else
		local points = getPatternPoints(pos, patternMode, patternSize, customText, Vector3.new(0,1,0))
		for _, point in ipairs(points) do
			local pd = (point - cp).Magnitude
			if pd >= 15 then
				fireSingleFast(point, (point-cp).Unit, wep, workspace.Terrain, cp, pd, fireGen)
			end
		end
	end
end

local function updateSpreadCache() _sr = spreadRadius * 100 end

local function setTargetTypes(selection)
    if type(selection) == "string" then
        selection = {selection}
    end
    local newTypes = {
        Players = false,
        Vehicles = false,
        BaseShields = false,
        ElectricalBoxes = false,
    }
    if type(selection) == "table" then
        for _, value in ipairs(selection) do
            if value == "Players" then
                newTypes.Players = true
            elseif value == "Vehicles" then
                newTypes.Vehicles = true
            elseif value == "Shields" then
                newTypes.BaseShields = true
            elseif value == "Electrical Boxes" then
                newTypes.ElectricalBoxes = true
            end
        end
    end
    targetTypes = newTypes
    states.targetTypes = targetTypes
end

local function collectRPGTargets()
    local targets = {}
    if not hrp or not hrp.Parent then
        return targets
    end
    local myPos = hrp.Position

    if targetTypes.Players then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= plr and player.Character and player.Character.Parent then
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if targetRoot and humanoid and humanoid.Health > 0 then
                    local distance = (targetRoot.Position - myPos).Magnitude
                    if distance <= maxDistance then
                        targets[#targets + 1] = {
                            Position = targetRoot.Position,
                            HitPart = targetRoot,
                        }
                    end
                end
            end
        end
    end

    if targetTypes.Vehicles then
        local gs = workspace:FindFirstChild("Game Systems")
        if gs then
            for _, wd in ipairs(VEHICLE_WORKSPACES) do
                local workspaceFolder = gs:FindFirstChild(wd.name)
                if workspaceFolder then
                    for _, veh in ipairs(workspaceFolder:GetChildren()) do
                        local rootPart = findVehicleRoot(veh)
                        if rootPart and rootPart.Parent then
                            local distance = (rootPart.Position - myPos).Magnitude
                            if distance <= maxDistance then
                                targets[#targets + 1] = {
                                    Position = rootPart.Position,
                                    HitPart = rootPart,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if targetTypes.BaseShields then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local lowerName = obj.Name:lower()
                if lowerName:find("shield") then
                    local distance = (obj.Position - myPos).Magnitude
                    if distance <= maxDistance then
                        targets[#targets + 1] = {
                            Position = obj.Position,
                            HitPart = obj,
                        }
                    end
                end
            end
        end
    end

    if targetTypes.ElectricalBoxes then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local lowerName = obj.Name:lower()
                if lowerName:find("elect") or lowerName:find("power") or lowerName:find("breaker") then
                    local distance = (obj.Position - myPos).Magnitude
                    if distance <= maxDistance then
                        targets[#targets + 1] = {
                            Position = obj.Position,
                            HitPart = obj,
                        }
                    end
                end
            end
        end
    end

    return targets
end

local function startRPG()
    if rpgConnection then
        return
    end
    rpgTimer = 0
    rpgConnection = RunService.Heartbeat:Connect(function(dt)
        if terminated or not hrp or not hrp.Parent or not rpgEnabled then
            return
        end

        local now = tick()
        if now - lastTargetUpdate >= TARGET_CACHE_RATE then
            cachedTargets = collectRPGTargets()
            states.cachedTargets = cachedTargets
            lastTargetUpdate = now
            states.lastTargetUpdate = lastTargetUpdate
        end

        if #cachedTargets == 0 then
            return
        end

        local weapon = getRPG()
        if not weapon then
            return
        end

        rpgTimer = rpgTimer + dt
        if rpgTimer < firerate then
            return
        end

        rpgTimer = rpgTimer - firerate
        if simultaneousFire then
            fireGen = fireGen + 1
            local currentGen = fireGen
            for _, target in ipairs(cachedTargets) do
                fireAtTarget(target.Position, weapon, target.HitPart, hrp.Position, currentGen)
            end
        else
            local target = cachedTargets[math.random(#cachedTargets)]
            if target then
                fireAtTarget(target.Position, weapon, target.HitPart, hrp.Position, fireGen)
            end
        end
    end)
end

local function stopRPG()
    if rpgConnection then
        rpgConnection:Disconnect()
        rpgConnection = nil
    end
end

--LETTERS (i wanna add swastika click like m5ware)
local function getLetterPoints(ch,sx,cz,sc)
	local p={}
	local function ins(v) p[#p+1]=v end
	local function v3(x,y,z) return Vector3.new(x,y,z) end
	if ch=="A" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)) end
	elseif ch=="B" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for y=0,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for y=-3,0,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="C" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="D" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,2.5,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for y=-2,2,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="E" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="F" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)) end
	elseif ch=="G" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for x=1.5,3,0.5 do ins(v3((sx+x)*sc,0,cz*sc)) end
		for y=0,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="H" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,cz*sc)) end
	elseif ch=="I" then
		for y=-3,3,0.5 do ins(v3((sx+1.5)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="J" then
		for y=-3,3,0.5 do ins(v3((sx+2.5)*sc,0,(cz+y)*sc)) end
		for x=0,2.5,0.5 do ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		ins(v3((sx+0.5)*sc,0,(cz+2)*sc))
	elseif ch=="K" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for i=0,3,0.5 do ins(v3((sx+i)*sc,0,(cz-i)*sc)); ins(v3((sx+i)*sc,0,(cz+i)*sc)) end
	elseif ch=="L" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="M" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+4)*sc,0,(cz+y)*sc)) end
		for i=0,2,0.5 do ins(v3((sx+i)*sc,0,(cz-3+i)*sc)); ins(v3((sx+4-i)*sc,0,(cz-3+i)*sc)) end
	elseif ch=="N" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for i=0,6,0.5 do ins(v3((sx+i*0.5)*sc,0,(cz-3+i)*sc)) end
	elseif ch=="O" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="P" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)) end
		for y=-3,0,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="Q" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for i=0,2,0.5 do ins(v3((sx+2+i*0.5)*sc,0,(cz+1+i)*sc)) end
	elseif ch=="R" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)) end
		for y=-3,0,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for i=0,3,0.5 do ins(v3((sx+i)*sc,0,(cz+i)*sc)) end
	elseif ch=="S" then
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for y=-3,0,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for y=0,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="T" then
		for y=-3,3,0.5 do ins(v3((sx+1.5)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)) end
	elseif ch=="U" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="V" then
		for i=0,6,0.5 do ins(v3((sx+i*0.25)*sc,0,(cz-3+i)*sc)); ins(v3((sx+3-i*0.25)*sc,0,(cz-3+i)*sc)) end
	elseif ch=="W" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+4)*sc,0,(cz+y)*sc)) end
		for i=0,2,0.5 do ins(v3((sx+i)*sc,0,(cz+3-i)*sc)); ins(v3((sx+4-i)*sc,0,(cz+3-i)*sc)) end
	elseif ch=="X" then
		for i=0,6,0.5 do ins(v3((sx+i*0.5)*sc,0,(cz-3+i)*sc)); ins(v3((sx+i*0.5)*sc,0,(cz+3-i)*sc)) end
	elseif ch=="Y" then
		for y=-3,0,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for y=0,3,0.5 do ins(v3((sx+1.5)*sc,0,(cz+y)*sc)) end
		for x=0,1.5,0.5 do ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+3-x)*sc,0,cz*sc)) end
	elseif ch=="Z" then
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for i=0,6,0.5 do ins(v3((sx+3-i*0.5)*sc,0,(cz-3+i)*sc)) end
	elseif ch=="0" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="1" then
		for y=-3,3,0.5 do ins(v3((sx+1.5)*sc,0,(cz+y)*sc)) end
		ins(v3((sx+0.5)*sc,0,(cz-2)*sc))
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="2" then
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for y=-3,0,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for y=0,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
	elseif ch=="3" then
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for y=-3,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="4" then
		for y=-3,0,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,cz*sc)) end
		for y=-3,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="5" then
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for y=-3,0,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for y=0,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="6" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
		for y=0,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
	elseif ch=="7" then
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)) end
		for i=0,6,0.5 do ins(v3((sx+3-i*0.3)*sc,0,(cz-3+i)*sc)) end
	elseif ch=="8" then
		for y=-3,3,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)); ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="9" then
		for y=-3,0,0.5 do ins(v3(sx*sc,0,(cz+y)*sc)) end
		for y=-3,3,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)); ins(v3((sx+x)*sc,0,(cz+3)*sc)) end
	elseif ch=="!" then
		for y=-3,1,0.5 do ins(v3((sx+1.5)*sc,0,(cz+y)*sc)) end; ins(v3((sx+1.5)*sc,0,(cz+3)*sc))
	elseif ch=="?" then
		for x=0,3,0.5 do ins(v3((sx+x)*sc,0,(cz-3)*sc)); ins(v3((sx+x)*sc,0,cz*sc)) end
		for y=-3,0,0.5 do ins(v3((sx+3)*sc,0,(cz+y)*sc)) end
		for y=0,1.5,0.5 do ins(v3((sx+1.5)*sc,0,(cz+y)*sc)) end; ins(v3((sx+1.5)*sc,0,(cz+3)*sc))
	end
	return p
end

local NORMAL_VECTORS={
	[Enum.NormalId.Top]=Vector3.new(0,1,0),[Enum.NormalId.Bottom]=Vector3.new(0,-1,0),
	[Enum.NormalId.Front]=Vector3.new(0,0,-1),[Enum.NormalId.Back]=Vector3.new(0,0,1),
	[Enum.NormalId.Left]=Vector3.new(-1,0,0),[Enum.NormalId.Right]=Vector3.new(1,0,0),
}

local function getSurfaceCFrame(hp,hn)
	local wu=Vector3.new(0,1,0)
	if mabs(hn.Y)>0.7 then
		local cr=cam.CFrame.RightVector; local cf=cam.CFrame.LookVector
		local tr=Vector3.new(cr.X,0,cr.Z); if tr.Magnitude<0.01 then tr=Vector3.new(1,0,0) end; tr=tr.Unit
		local tu=Vector3.new(cf.X,0,cf.Z); if tu.Magnitude<0.01 then tu=Vector3.new(0,0,-1) end; tu=tu.Unit
		return CFrame.fromMatrix(hp,tr,tu,-hn)
	else
		local tu=(wu-hn*wu:Dot(hn)); if tu.Magnitude<0.01 then tu=Vector3.new(0,1,0) end; tu=tu.Unit
		-- tu:Cross(hn) gives rightward vector when wall faces you; hn:Cross(tu) was flipped
		return CFrame.fromMatrix(hp, tu:Cross(hn).Unit, tu, -hn)
	end
end

local function getPatternPoints(center,mode,size,text,hn)
	if mode=="Custom Text" then
		local pos={}; local sc=size/40; local sp=5; local tw=(#text*sp-sp); local sx=-tw/2
		local scf=getSurfaceCFrame(center,hn or Vector3.new(0,1,0)); local ocf=scf*CFrame.new(0,0,-0.5)
		for i=1,#text do
			local ch=text:sub(i,i):upper(); local lx=sx+(i-1)*sp
			for _,pt in ipairs(getLetterPoints(ch,lx,0,sc)) do
				pos[#pos+1]=(ocf*CFrame.new(pt.X,-pt.Z,0)).Position
			end
		end; return pos
	end; return {center}
end

--ESP
local espPartCache = {}

local function refreshESPCache(p)
	local c=p.Character; if not c then espPartCache[p]=nil; return nil end
	local ca=espPartCache[p]; if ca and ca.char==c then return ca end
	local tH=c:FindFirstChild("HumanoidRootPart"); if not tH then espPartCache[p]=nil; return nil end
	local tHum=c:FindFirstChildOfClass("Humanoid"); if not tHum then espPartCache[p]=nil; return nil end
	local d={char=c,hrp=tH,hum=tHum,head=c:FindFirstChild("Head")}; espPartCache[p]=d; return d
end

local function newESPBox(p)
	local box=Drawing.new("Square"); box.Visible=false; box.Color=Color3.fromRGB(255,0,0); box.Thickness=2; box.Transparency=1; box.Filled=false
	local hb=Drawing.new("Square");  hb.Visible=false;  hb.Color=Color3.fromRGB(0,255,0);   hb.Thickness=1; hb.Transparency=1; hb.Filled=true
	local nt=Drawing.new("Text");    nt.Visible=false;  nt.Color=Color3.fromRGB(255,255,255); nt.Size=15; nt.Center=true; nt.Outline=true; nt.Text=p.Name
	local dt=Drawing.new("Text");    dt.Visible=false;  dt.Color=Color3.fromRGB(200,200,200); dt.Size=13; dt.Center=true; dt.Outline=true
	local wt=Drawing.new("Text");    wt.Visible=false;  wt.Color=Color3.fromRGB(255,200,100); wt.Size=12; wt.Center=true; wt.Outline=true
	local tr=Drawing.new("Line");    tr.Visible=false;  tr.Color=Color3.fromRGB(255,0,0);     tr.Thickness=1; tr.Transparency=1
	return {box=box,healthBar=hb,nameText=nt,distanceText=dt,weaponText=wt,tracer=tr,player=p}
end

local function newVehicleESPBox()
	local box=Drawing.new("Square"); box.Visible=false; box.Color=Color3.fromRGB(255,200,50); box.Thickness=2; box.Transparency=1; box.Filled=false
	local nt=Drawing.new("Text");    nt.Visible=false;  nt.Color=Color3.fromRGB(255,255,255); nt.Size=15; nt.Center=true; nt.Outline=true
	local dt=Drawing.new("Text");    dt.Visible=false;  dt.Color=Color3.fromRGB(200,200,200); dt.Size=13; dt.Center=true; dt.Outline=true
	local tr=Drawing.new("Line");    tr.Visible=false;  tr.Color=Color3.fromRGB(255,200,50);  tr.Thickness=1; tr.Transparency=1
	return {box=box,nameText=nt,distanceText=dt,tracer=tr}
end

local function hideESP(d,isV)
	d.box.Visible=false; d.nameText.Visible=false; d.distanceText.Visible=false; d.tracer.Visible=false
	if not isV then d.healthBar.Visible=false; d.weaponText.Visible=false end
end

local function updateESP()
	if not hrp or not hrp.Parent then return end
	local lCam=cam; local vp=lCam.ViewportSize
	local vcx,vby=vp.X*0.5,vp.Y
	local camCF=lCam.CFrame; local camPos=camCF.Position; local camFwd=camCF.LookVector
	local myPos=hrp.Position

	if not espEnabled then
		for _,d in pairs(espBoxes)        do pcall(hideESP,d,false) end
		for _,d in pairs(vehicleESPBoxes) do pcall(hideESP,d,true)  end
		return
	end

	local piv=getPlayersInVehicles()

	for _,d in pairs(espBoxes) do
		local p=d.player; if not p or not p.Parent then continue end
		if piv[p] then hideESP(d,false); continue end
		local cache=refreshESPCache(p); if not cache then hideESP(d,false); continue end
		local tH=cache.hrp; local tHum=cache.hum
		if tHum.Health<=0 then hideESP(d,false); continue end
		if (tH.Position-camPos):Dot(camFwd)<-8 then hideESP(d,false); continue end
		local vec,on=lCam:WorldToViewportPoint(tH.Position); if not on then hideESP(d,false); continue end
		local hp=cache.head and cache.head.Position or (tH.Position+Vector3.new(0,2,0))
		local tv=lCam:WorldToViewportPoint(hp); local bv=lCam:WorldToViewportPoint(tH.Position-Vector3.new(0,3,0))
		local h=mabs(tv.Y-bv.Y); if h<4 then h=4 end; local w=h*0.5; local bx=vec.X-w*0.5
		d.box.Size=Vector2.new(w,h); d.box.Position=Vector2.new(bx,tv.Y); d.box.Visible=true
		local hp2=mclamp(tHum.Health/tHum.MaxHealth,0,1)
		d.healthBar.Size=Vector2.new(3,h*hp2); d.healthBar.Position=Vector2.new(bx-5,tv.Y+h*(1-hp2))
		d.healthBar.Color=Color3.fromRGB(mfloor(255*(1-hp2)),mfloor(255*hp2),0); d.healthBar.Visible=true
		d.nameText.Position=Vector2.new(vec.X,tv.Y-18); d.nameText.Visible=true
		d.distanceText.Text=mfloor((tH.Position-myPos).Magnitude).."m"; d.distanceText.Position=Vector2.new(vec.X,bv.Y+4); d.distanceText.Visible=true
		local wpn=cache.char:FindFirstChildOfClass("Tool")
		if wpn then d.weaponText.Text=wpn.Name; d.weaponText.Position=Vector2.new(vec.X,bv.Y+18); d.weaponText.Visible=true else d.weaponText.Visible=false end
		local ec=whitelist[p.Name] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
		d.box.Color=ec; d.tracer.Color=ec; d.tracer.From=Vector2.new(vcx,vby); d.tracer.To=Vector2.new(vec.X,vec.Y); d.tracer.Visible=true
	end

	local active={}; local gs=workspace:FindFirstChild("Game Systems")
	if gs then
		for _,wd in ipairs(VEHICLE_WORKSPACES) do
			local f=gs:FindFirstChild(wd.name); if not f then continue end
			for _,veh in pairs(f:GetChildren()) do
				local owner=veh:FindFirstChild("Owner"); local pip=nil
				for pp,v2 in pairs(piv) do if v2==veh then pip=pp; break end end
				local show,oName=false,"Unknown"
				if pip then oName=pip.Name; show=pip~=plr and not whitelist[pip.Name]
				elseif not owner or not owner.Value then show=true; oName="Unowned"
				elseif owner.Value~=plr.Name and not whitelist[owner.Value] then show=true; oName=owner.Value end
				if not show then continue end
				local vRoot = findVehicleRoot(veh)
				if not vRoot or not vRoot.Parent then 
    				if vehicleESPBoxes[veh] then hideESP(vehicleESPBoxes[veh], true) end
    				continue 
				end

				-- Extra safety check
				if (vRoot.Position - camPos):Dot(camFwd) < -8 then
    				if vehicleESPBoxes[veh] then hideESP(vehicleESPBoxes[veh], true) end
    				continue
				end

                -- Extra safety before any calculations
                if not vRoot.Parent or (vRoot.Position - camPos):Dot(camFwd) < -8 then
                    if vehicleESPBoxes[veh] then hideESP(vehicleESPBoxes[veh], true) end
                    continue
                end
				active[veh]=true; local vec,on=lCam:WorldToViewportPoint(vRoot.Position)
				if on then
					if not vehicleESPBoxes[veh] then vehicleESPBoxes[veh]=newVehicleESPBox() end
					local d=vehicleESPBoxes[veh]; local sz=veh:GetExtentsSize()
					local tv=lCam:WorldToViewportPoint(vRoot.Position+Vector3.new(0,sz.Y*0.5,0))
					local bv=lCam:WorldToViewportPoint(vRoot.Position-Vector3.new(0,sz.Y*0.5,0))
					local h=mabs(tv.Y-bv.Y); if h<4 then h=4 end; local w=h*0.8
					d.box.Size=Vector2.new(w,h); d.box.Position=Vector2.new(vec.X-w*0.5,tv.Y); d.box.Visible=true
					d.nameText.Text=veh.Name.." ("..oName..")"; d.nameText.Position=Vector2.new(vec.X,tv.Y-18); d.nameText.Visible=true
					d.distanceText.Text=mfloor((vRoot.Position-myPos).Magnitude).."m"; d.distanceText.Position=Vector2.new(vec.X,bv.Y+4); d.distanceText.Visible=true
					d.tracer.From=Vector2.new(vcx,vby); d.tracer.To=Vector2.new(vec.X,vec.Y); d.tracer.Visible=true
				elseif vehicleESPBoxes[veh] then hideESP(vehicleESPBoxes[veh],true) end
			end
		end
	end
	for v,d in pairs(vehicleESPBoxes) do
		if not active[v] or not v.Parent then
			pcall(function() d.box:Remove(); d.nameText:Remove(); d.distanceText:Remove(); d.tracer:Remove() end)
			vehicleESPBoxes[v]=nil
		end
	end
end

local function initializeESP()
	for _,p in pairs(Players:GetPlayers()) do if p~=plr and not espBoxes[p] then espBoxes[p]=newESPBox(p) end end
end
local function removeESPBox(p)
	local d=espBoxes[p]; if d then pcall(function() d.box:Remove(); d.healthBar:Remove(); d.nameText:Remove(); d.distanceText:Remove(); d.weaponText:Remove(); d.tracer:Remove() end); espBoxes[p]=nil end
	espPartCache[p]=nil
end
Players.PlayerAdded:Connect(function(p)   if p~=plr then espBoxes[p]=newESPBox(p) end end)
Players.PlayerRemoving:Connect(function(p) removeESPBox(p) end)
initializeESP()

--FLY
local function startFly()
	if flying or not hrp or not hrp.Parent then return end; flying=true
	flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e9,1e9,1e9); flyBV.Velocity=Vector3.zero; flyBV.Parent=hrp
	flyBG=Instance.new("BodyGyro");    flyBG.MaxTorque=Vector3.new(1e9,1e9,1e9); flyBG.P=9e4; flyBG.CFrame=hrp.CFrame; flyBG.Parent=hrp
	if humanoid and not humanoid.SeatPart then humanoid.PlatformStand=true end
end
local function stopFly()
	flying=false; if flyBV then flyBV:Destroy(); flyBV=nil end; if flyBG then flyBG:Destroy(); flyBG=nil end
	if humanoid and humanoid.Parent and not humanoid.SeatPart then humanoid.PlatformStand=false end
end

--function definitions
local function applyNoClip(en)
	if en then if noClipConnection then return end; noClipOriginals={}
		if char then for _,p in pairs(char:GetDescendants()) do if p:IsA("BasePart") then noClipOriginals[p]=p.CanCollide end end end
		noClipConnection=RunService.Stepped:Connect(function()
			if char then for _,p in pairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
		end)
	else if noClipConnection then noClipConnection:Disconnect(); noClipConnection=nil
			for p,o in pairs(noClipOriginals) do if p and p.Parent then p.CanCollide=o end end; noClipOriginals={} end
	end
end
local function applySelfChams(en)
	if en then if not selfChamsHighlight and char then
		selfChamsHighlight=Instance.new("Highlight"); selfChamsHighlight.FillColor=Color3.fromRGB(255,0,255)
		selfChamsHighlight.OutlineColor=Color3.fromRGB(255,255,255); selfChamsHighlight.FillTransparency=0.5
		selfChamsHighlight.OutlineTransparency=0; selfChamsHighlight.Parent=char end
	else if selfChamsHighlight then selfChamsHighlight:Destroy(); selfChamsHighlight=nil end end
end
local function applySpinBot(en)
	if en then
		if not hrp or not hrp.Parent then return end
		-- Tear down any existing BAV first
		if spinBAV then spinBAV:Destroy(); spinBAV = nil end

		-- Disable AutoRotate so the humanoid doesn't fight the angular velocity
		if humanoid and humanoid.Parent then
			spinSavedAutoRotate = humanoid.AutoRotate
			humanoid.AutoRotate = false
		end

		spinBAV = Instance.new("BodyAngularVelocity")
		spinBAV.AngularVelocity = Vector3.new(0, math.rad(spinBotSpeed), 0)
		spinBAV.MaxTorque       = Vector3.new(0, 1e9, 0)
		spinBAV.P               = 1e9
		spinBAV.Parent          = hrp
	else
		if spinBAV then spinBAV:Destroy(); spinBAV = nil end
		-- Restore AutoRotate
		if humanoid and humanoid.Parent then
			humanoid.AutoRotate = spinSavedAutoRotate
		end
	end
end

local function updateSpinBotSpeed()
	if spinBAV and spinBAV.Parent then
		spinBAV.AngularVelocity = Vector3.new(0, math.rad(spinBotSpeed), 0)
	end
end

local function startCBring()
	if cbringConnection then
		cbringConnection:Disconnect()
	end

	cbringConnection = RunService.Heartbeat:Connect(function()
		if not cbringEnabled or #cbringTargets == 0 then return end
		local myRoot = hrp
		if not myRoot then return end

		local validTargets = {}
		for _, player in ipairs(cbringTargets) do
			if player and player.Parent and player ~= plr and player.Character then
				table.insert(validTargets, player)
			end
		end
		cbringTargets = validTargets
		if #cbringTargets == 0 then return end

		local radius = 50
		local count = #cbringTargets
		for index, player in ipairs(cbringTargets) do
			local character = player.Character
			if not character then continue end

			local targetRoot = character:FindFirstChild("HumanoidRootPart")
			if not targetRoot then continue end

			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Sit = false end

			local angle = (index - 1) * (2 * math.pi) / count
			local offset = myRoot.CFrame.RightVector * (math.cos(angle) * radius) + myRoot.CFrame.LookVector * (math.sin(angle) * radius)
			local targetCFrame = CFrame.new(myRoot.Position + offset, myRoot.Position)

			targetRoot.CFrame = targetRoot.CFrame:Lerp(targetCFrame, 0.45)
			targetRoot.Velocity = Vector3.new(0, 0, 0)
			targetRoot.RotVelocity = Vector3.new(0, 0, 0)
		end
	end)
end

local function stopCBring()
	if cbringConnection then
		cbringConnection:Disconnect()
		cbringConnection = nil
	end
end

--Renderstepped
RunService.RenderStepped:Connect(function(dt)
	if terminated or not hrp or not hrp.Parent then return end
	updateESP()
	if flying then
		local mv=Vector3.zero; local cf=cam.CFrame
		if keys.W then mv+=cf.LookVector end; if keys.S then mv-=cf.LookVector end
		if keys.A then mv-=cf.RightVector end; if keys.D then mv+=cf.RightVector end
		if keys.Space or keys.E then mv+=Vector3.yAxis end; if keys.Ctrl or keys.Q then mv-=Vector3.yAxis end
		if mv.Magnitude>0 then mv=mv.Unit*flySpeed end
		if flyBV then flyBV.Velocity=mv end
		if flyBG then
			-- When spinning, let BAV holds the Y axis, gyro only stabilises pitch/roll
			flyBG.MaxTorque = spinBotEnabled and Vector3.new(1e9,0,1e9) or Vector3.new(1e9,1e9,1e9)
			flyBG.CFrame = cf
		end
	end
	if spinBotEnabled and humanoid and not humanoid.SeatPart then
		-- character spin is handled server-side by spinBAV (BodyAngularVelocity)
	end
end)

--GUI
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWareUI-Lib/refs/heads/main/PasteWareUIlib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWareUI-Lib/refs/heads/main/manage2.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWareUI-Lib/refs/heads/main/manager.lua"))()
local Window = Library:CreateWindow({
    Title = 'MumbaiVirus | Proxy Phalanxs',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local MainTab = Window:AddTab("Main")
local flybox = MainTab:AddLeftGroupbox("Fly")
flybox:AddToggle("FlyToggle", {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        if value then
            startFly()
        else
            stopFly()
        end
    end,
})
flybox:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = 100,
    Min = 16,
    Max = 20000,
    Callback = function(value)
        flySpeed = value
    end,
})

local playerbox = MainTab:AddRightGroupbox("Player")
playerbox:AddToggle("NoClip", {
    Text = "NoClip",
    Default = false,
    Callback = function(value)
        noClipEnabled = value
        applyNoClip(value)
    end,
})
playerbox:AddToggle("SpinBot", {
    Text = "Spin Bot",
    Default = false,
    Callback = function(value)
        spinBotEnabled = value
        applySpinBot(value)
    end,
})
playerbox:AddSlider("SpinBotSpeed", {
    Text = "Spin Bot Speed",
    Default = 360,
    Min = 1,
    Max = 1000,
    Callback = function(value)
        spinBotSpeed = value
        updateSpinBotSpeed()
    end,
})

local skidtourturebox = MainTab:AddLeftGroupbox("Skid Tourture")
skidtourturebox:AddToggle("LoopCbring", {
    Text = "Loop Cbring",
    Default = false,
    Callback = function(value)
        cbringEnabled = value
        if value then
            if #cbringTargets > 0 then
                startCBring()
            else
                warn("Select one or more CBring targets first")
                cbringEnabled = false
            end
        else
            stopCBring()
        end
    end,
})
skidtourturebox:AddDropdown("CbringTargets", {
    Text = "CBring Targets",
    Values = getPlayerNames(),
    Default = nil,
    Multi = true,
    Callback = function(value)
        cbringTargets = {}
        if type(value) == "string" then
            local player = Players:FindFirstChild(value)
            if player and player ~= plr then
                table.insert(cbringTargets, player)
            end
        elseif type(value) == "table" then
            for _, name in ipairs(value) do
                local player = Players:FindFirstChild(name)
                if player and player ~= plr then
                    table.insert(cbringTargets, player)
                end
            end
        end
        if cbringEnabled and #cbringTargets > 0 then
            startCBring()
        end
    end,
})
local RPGTab = Window:AddTab("RPG")
local rpgbox = RPGTab:AddLeftGroupbox("RPG")
rpgbox:AddToggle("EnableRPG", {
    Text = "Enable RPG",
    Default = false,
    Callback = function(value)
        rpgEnabled = value
        states.rpgEnabled = value
        if value then
            startRPG()
        else
            stopRPG()
        end
    end,
})
rpgbox:AddToggle("SimultaneousFire", {
    Text = "Simultaneous",
    Default = false,
    Callback = function(value)
        simultaneousFire = value
        states.simultaneousFire = value
    end,
})
rpgbox:AddSlider("FireRate", {
    Text = "Fire Rate",
    Default = 1,
    Min = 0.1,
    Max = 1000,
    Callback = function(value)
        firerate = value
        states.firerate = value
    end,
})
rpgbox:AddSlider("RPGRange", {
    Text = "RPG Range",
    Default = 5000,
    Min = 10,
    Max = 8000,
    Callback = function(value)
        maxDistance = value
        states.maxDistance = value
    end,
})
rpgbox:AddSlider("RocketsPerTarget", {
    Text = "Rockets Per Target",
    Default = 1,
    Min = 1,
    Max = 100,
    Callback = function(value)
        rocketsPerTarget = value
        states.rocketsPerTarget = value
    end,
})
rpgbox:AddToggle("ClickRPG", {
    Text = "Click RPG",
    Default = false,
    Callback = function(value)
        clickRPGEnabled = value
        states.clickRPGEnabled = value
    end,
})
rpgbox:AddSlider("RPG Spread", {
    Text = "RPG Spread",
    Default = 0,
    Min = 0,
    Max = 100,
    Callback = function(value)
        spreadRadius = value
        states.spreadRadius = value
        updateSpreadCache()
    end,
})

local targetingbox = RPGTab:AddRightGroupbox("Targeting")
targetingbox:AddDropdown("TargetTypes", {
    Text = "Target Types",
    Values = {"Players", "Vehicles", "Shields", "Electrical Boxes"},
    Default = "Players",
    Multi = true,
    Callback = function(value)
        setTargetTypes(value)
    end,
})
targetingbox:AddDropdown("PatternMode", {
    Text = "Pattern Mode",
    Values = {"None","Custom Text", "Star", "Circle", "Cross", "Diamond", "Square"},
    Default = "None",
    Callback = function(value)
        patternMode = value
        states.patternMode = value
    end,
})
targetingbox:AddSlider("PatternSize", {
    Text = "Pattern Size",
    Default = 200,
    Min = 10,
    Max = 1000,
    Callback = function(value)
        patternSize = value
        states.patternSize = value
    end,
})
targetingbox:AddInput("CustomText", {
    Text = "Custom Text",
    Default = "PROXY",
    Callback = function(value)
        customText = value
        states.customText = value
    end,
})
local VisualsTab = Window:AddTab("Visuals")
local espbox = VisualsTab:AddLeftGroupbox("ESP")
espbox:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = false,
    Callback = function(value)
        espEnabled = value
        updateESP()
    end,
})

local settingsTab = Window:AddTab("Settings")
local MenuGroup = settingsTab:AddLeftGroupbox("Menu")
MenuGroup:AddButton("Unload", function() Library:Unload() end)
MenuGroup:AddButton("Load Old RPG", function() loadstring(game:HttpGet("https://raw.githubusercontent.com/vqd3S7Ragk/ldCGQ9GS7GjrS1hu7Dep/refs/heads/main/ldCGQ9GS7GjrS1hu7Dep.lua"))() end)
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "None", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddToggle("ShowKeybinds", {
    Text = "Show Keybinds",
    Default = Library.KeybindFrame and Library.KeybindFrame.Visible or false,
    Callback = function(value)
        Library:SetKeybindListVisible(value)
    end,
})

if Library.KeybindFrame and Toggles and Toggles.ShowKeybinds then
    Library:SetKeybindListVisible(Toggles.ShowKeybinds.Value)
end

if Options and Options.MenuKeybind then
    Library.ToggleKeybind = Options.MenuKeybind
end
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab)
SaveManager:BuildConfigSection(settingsTab)

-- Click RPG handler
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and clickRPGEnabled then
        local weapon = getRPG()
        if weapon then
            isMouseHeld = true
            task.spawn(function()
                while isMouseHeld and clickRPGEnabled and not terminated do
                    local mousePos = UserInputService:GetMouseLocation()
                    local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
                    local targetPos = ray.Origin + ray.Direction * 1000
                    local hn = Vector3.new(0, 1, 0)
                    local hp = mouse.Target
                    if hp and hp:IsA("BasePart") then
                        hn = (hp.CFrame:VectorToWorldSpace(NORMAL_VECTORS[mouse.TargetSurface] or Vector3.new(0,1,0))).Unit
                    end
                    local points = getPatternPoints(targetPos, patternMode, patternSize, customText, hn)
                    for _, point in ipairs(points) do
                        task.spawn(fireClickRocket, point, weapon)
                        task.wait(0.001)
                    end
                    task.wait(0.001)
                end
            end)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseHeld = false
    end
end)


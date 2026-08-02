-- GameServer.lua
-- Place this as a Script inside ServerScriptService.
--
-- Builds the whole level in code (no manual building needed in Studio),
-- spawns two kinds of patrolling enemies, handles coins, the win goal,
-- player lives, and tells clients when to play sounds / show menus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

--------------------------------------------------------------------
-- Remote events (client <-> server communication)
--------------------------------------------------------------------

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "GameRemotes"
remotesFolder.Parent = ReplicatedStorage

local function newRemoteEvent(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local playerWonEvent = newRemoteEvent("PlayerWon")
local playerLostEvent = newRemoteEvent("PlayerLost")
local playSoundEvent = newRemoteEvent("PlaySound")
local requestExitEvent = newRemoteEvent("RequestExit")

--------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------

local function createPart(name, size, position, color, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = canCollide
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = Workspace
	return part
end

local function topOf(part)
	return part.Position.Y + (part.Size.Y / 2)
end

--------------------------------------------------------------------
-- Level layout (a simple stepped path, similar in spirit to
-- Skyline Dash: start -> platforms with gaps -> goal at the end).
-- Gaps are kept to 8-10 studs and height steps to 1-3 studs, since a
-- default Roblox character (WalkSpeed 16, JumpPower 50) can only
-- clear roughly that much per jump. Two wider platforms give the
-- Walker enemies room to patrol.
--------------------------------------------------------------------

local groundPart = createPart("Ground", Vector3.new(40, 2, 20), Vector3.new(0, 0, 0), Color3.fromRGB(90, 160, 90), true)
local platformTwo = createPart("PlatformTwo", Vector3.new(16, 2, 16), Vector3.new(36, 1, 0), Color3.fromRGB(90, 160, 90), true)
local platformThree = createPart("PlatformThree", Vector3.new(16, 2, 16), Vector3.new(60, 3, 0), Color3.fromRGB(90, 160, 90), true)
local platformFour = createPart("PlatformFour", Vector3.new(32, 2, 20), Vector3.new(92, 4, 0), Color3.fromRGB(90, 160, 90), true)
local platformFive = createPart("PlatformFive", Vector3.new(16, 2, 16), Vector3.new(124, 6, 0), Color3.fromRGB(90, 160, 90), true)
local platformSix = createPart("PlatformSix", Vector3.new(32, 2, 20), Vector3.new(156, 7, 0), Color3.fromRGB(90, 160, 90), true)
local platformSeven = createPart("PlatformSeven", Vector3.new(16, 2, 16), Vector3.new(190, 9, 0), Color3.fromRGB(90, 160, 90), true)
local goalPlatform = createPart("GoalPlatform", Vector3.new(40, 2, 20), Vector3.new(226, 10, 0), Color3.fromRGB(90, 160, 90), true)

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "MainSpawn"
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.Position = Vector3.new(-10, topOf(groundPart) + 0.5, 0)
spawnLocation.Anchored = true
spawnLocation.CanCollide = true
spawnLocation.Transparency = 1
spawnLocation.Parent = Workspace

local goalPart = createPart("Goal", Vector3.new(4, 8, 4), Vector3.new(236, topOf(goalPlatform) + 4, 0), Color3.fromRGB(60, 200, 90), false)

--------------------------------------------------------------------
-- Coins
--------------------------------------------------------------------

local coinPositions = {
	Vector3.new(0, topOf(groundPart) + 3, 0),
	Vector3.new(36, topOf(platformTwo) + 3, 0),
	Vector3.new(60, topOf(platformThree) + 3, 0),
	Vector3.new(92, topOf(platformFour) + 3, 0),
	Vector3.new(124, topOf(platformFive) + 3, 0),
	Vector3.new(156, topOf(platformSix) + 3, 0),
	Vector3.new(190, topOf(platformSeven) + 3, 0),
}

local function createCoin(position)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.6, 3, 3)
	coin.Orientation = Vector3.new(0, 0, 90)
	coin.Position = position
	coin.Anchored = true
	coin.CanCollide = false
	coin.Color = Color3.fromRGB(255, 210, 60)
	coin.Material = Enum.Material.Neon
	coin.Parent = Workspace

	local debounce = false
	coin.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or debounce then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or not player:FindFirstChild("leaderstats") then
			return
		end
		debounce = true
		player.leaderstats.Score.Value = player.leaderstats.Score.Value + 1
		playSoundEvent:FireClient(player, "Coin")
		coin:Destroy()
	end)

	-- simple spin "animation" for the coin
	task.spawn(function()
		while coin.Parent do
			coin.Orientation = Vector3.new(0, (tick() * 90) % 360, 90)
			RunService.Heartbeat:Wait()
		end
	end)
end

for _, position in ipairs(coinPositions) do
	createCoin(position)
end

--------------------------------------------------------------------
-- Enemies: two kinds, each patrolling within its own fixed area.
-- Movement + a simple procedural walk/idle animation are both driven
-- by a Heartbeat loop (no external animation assets required).
--------------------------------------------------------------------

local hitDebounce = {} -- [player] = true while briefly invulnerable

local function damagePlayer(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player or not player:FindFirstChild("leaderstats") then
		return
	end
	if hitDebounce[player] then
		return
	end
	hitDebounce[player] = true
	playSoundEvent:FireClient(player, "Hit")

	player.leaderstats.Lives.Value = player.leaderstats.Lives.Value - 1
	if player.leaderstats.Lives.Value <= 0 then
		playerLostEvent:FireClient(player)
		task.delay(1.5, function()
			player.leaderstats.Lives.Value = 3
			player.leaderstats.Score.Value = 0
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				humanoidRootPart.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
			end
		end)
	else
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
		end
	end

	task.delay(2, function()
		hitDebounce[player] = nil
	end)
end

local function connectDamageOnTouch(part)
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			damagePlayer(character)
		end
	end)
end

-- Builds one enemy model (a body plus two small "leg" parts) and
-- returns handles so the caller can drive its patrol + animation.
local function buildEnemyModel(name, bodyColor, bodySize, position)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = Workspace

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = bodySize
	body.Position = position
	body.Anchored = true
	body.CanCollide = false
	body.Color = bodyColor
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"
	leftLeg.Size = Vector3.new(0.8, 2, 0.8)
	leftLeg.Anchored = true
	leftLeg.CanCollide = false
	leftLeg.Color = bodyColor:Lerp(Color3.new(0, 0, 0), 0.4)
	leftLeg.Parent = model

	local rightLeg = leftLeg:Clone()
	rightLeg.Name = "RightLeg"
	rightLeg.Parent = model

	connectDamageOnTouch(body)
	connectDamageOnTouch(leftLeg)
	connectDamageOnTouch(rightLeg)

	return model, body, leftLeg, rightLeg
end

-- A ground enemy that walks back and forth between two X positions.
local function spawnWalkerEnemy(startX, endX, z, y, speed)
	local startPosition = Vector3.new(startX, y, z)
	local model, body, leftLeg, rightLeg = buildEnemyModel("Walker", Color3.fromRGB(200, 60, 60), Vector3.new(3, 3, 2), startPosition)

	task.spawn(function()
		local direction = 1
		local x = startX
		local pausedUntil = 0
		while model.Parent do
			local dt = RunService.Heartbeat:Wait()
			local now = tick()
			local isMoving = now >= pausedUntil

			if isMoving then
				x = x + (speed * direction * dt)
				if x >= endX then
					x = endX
					direction = -1
					pausedUntil = now + 0.6
				elseif x <= startX then
					x = startX
					direction = 1
					pausedUntil = now + 0.6
				end
			end

			body.Position = Vector3.new(x, y, z)

			if isMoving then
				local swing = math.sin(now * 9) * 25
				leftLeg.CFrame = body.CFrame * CFrame.new(-0.8, -2, 0) * CFrame.Angles(math.rad(swing), 0, 0)
				rightLeg.CFrame = body.CFrame * CFrame.new(0.8, -2, 0) * CFrame.Angles(math.rad(-swing), 0, 0)
			else
				local bob = math.sin(now * 3) * 0.15
				body.Position = Vector3.new(x, y + bob, z)
				leftLeg.CFrame = body.CFrame * CFrame.new(-0.8, -2, 0)
				rightLeg.CFrame = body.CFrame * CFrame.new(0.8, -2, 0)
			end
		end
	end)

	return model
end

-- A flying enemy that hovers up and down between two Y positions.
local function spawnFlyerEnemy(x, z, minY, maxY, speed)
	local startPosition = Vector3.new(x, minY, z)
	local model, body, leftLeg, rightLeg = buildEnemyModel("Flyer", Color3.fromRGB(150, 70, 200), Vector3.new(3, 2, 3), startPosition)
	body.Shape = Enum.PartType.Ball
	leftLeg.CanCollide = false
	rightLeg.CanCollide = false
	leftLeg.Size = Vector3.new(2, 0.4, 1.2)
	rightLeg.Size = Vector3.new(2, 0.4, 1.2)
	leftLeg.Color = body.Color
	rightLeg.Color = body.Color

	task.spawn(function()
		local direction = 1
		local y = minY
		local pausedUntil = 0
		while model.Parent do
			local dt = RunService.Heartbeat:Wait()
			local now = tick()
			local isMoving = now >= pausedUntil

			if isMoving then
				y = y + (speed * direction * dt)
				if y >= maxY then
					y = maxY
					direction = -1
					pausedUntil = now + 0.4
				elseif y <= minY then
					y = minY
					direction = 1
					pausedUntil = now + 0.4
				end
			end

			body.Position = Vector3.new(x, y, z)

			-- wings always flap gently (idle) but flap faster while moving
			local flapSpeed = isMoving and 12 or 4
			local flap = math.rad(math.sin(now * flapSpeed) * 35)
			leftLeg.CFrame = body.CFrame * CFrame.new(-1.6, 0, 0) * CFrame.Angles(0, 0, flap)
			rightLeg.CFrame = body.CFrame * CFrame.new(1.6, 0, 0) * CFrame.Angles(0, 0, -flap)
		end
	end)

	return model
end

spawnWalkerEnemy(80, 104, 0, topOf(platformFour) + 1.5, 6)
spawnWalkerEnemy(144, 168, 0, topOf(platformSix) + 1.5, 5)
spawnFlyerEnemy(215, 0, topOf(goalPlatform) + 2, topOf(goalPlatform) + 12, 6)

--------------------------------------------------------------------
-- Goal (win condition)
--------------------------------------------------------------------

do
	local debounceByPlayer = {}
	goalPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or debounceByPlayer[player] then
			return
		end
		debounceByPlayer[player] = true
		playSoundEvent:FireClient(player, "Win")
		playerWonEvent:FireClient(player)

		task.delay(2, function()
			debounceByPlayer[player] = nil
			if player and player:FindFirstChild("leaderstats") then
				player.leaderstats.Lives.Value = 3
				player.leaderstats.Score.Value = 0
			end
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				humanoidRootPart.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
			end
		end)
	end)
end

--------------------------------------------------------------------
-- Player setup: leaderstats + safety net if a player falls off the map
--------------------------------------------------------------------

local FALL_RESET_Y = -50

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local lives = Instance.new("IntValue")
	lives.Name = "Lives"
	lives.Value = 3
	lives.Parent = leaderstats

	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Value = 0
	score.Parent = leaderstats

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		-- start frozen; GameClient unfreezes movement once "Start Game" is pressed
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0

		task.spawn(function()
			while character.Parent do
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart and humanoidRootPart.Position.Y < FALL_RESET_Y then
					damagePlayer(character)
				end
				task.wait(0.5)
			end
		end)
	end)
end)

--------------------------------------------------------------------
-- Exit button support
--------------------------------------------------------------------

requestExitEvent.OnServerEvent:Connect(function(player)
	player:Kick("Thanks for playing! Feel free to rejoin any time.")
end)

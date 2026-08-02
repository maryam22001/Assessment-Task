-- GameClient.lua
-- Place this as a LocalScript inside StarterPlayerScripts.
--
-- Builds the main menu GUI, the in-game HUD, and the win/lose screens
-- entirely in code, and reacts to the server's remote events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local playerWonEvent = remotesFolder:WaitForChild("PlayerWon")
local playerLostEvent = remotesFolder:WaitForChild("PlayerLost")
local playSoundEvent = remotesFolder:WaitForChild("PlaySound")
local requestExitEvent = remotesFolder:WaitForChild("RequestExit")

--------------------------------------------------------------------
-- Sound setup
--------------------------------------------------------------------
-- NOTE: these SoundIds point at sound files bundled with every
-- Roblox client, so they always load without needing any uploaded
-- assets. Swap in your own rbxassetid:// values from the Toolbox
-- if you'd like different sound effects; an invalid SoundId just
-- fails to play silently, it will not crash the game.

local soundEnabled = true

local backgroundMusic = Instance.new("Sound")
backgroundMusic.Name = "BackgroundMusic"
backgroundMusic.SoundId = "rbxasset://sounds/impact_water.mp3"
backgroundMusic.Looped = true
backgroundMusic.Volume = 0.3
backgroundMusic.Parent = playerGui

local sfxIds = {
	Jump = "rbxasset://sounds/action_jump.mp3",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Hit = "rbxasset://sounds/action_falling.mp3",
	Win = "rbxasset://sounds/action_get_up.mp3",
}

local sfxSounds = {}
for name, id in pairs(sfxIds) do
	local sound = Instance.new("Sound")
	sound.Name = name .. "Sound"
	sound.SoundId = id
	sound.Volume = 0.6
	sound.Parent = playerGui
	sfxSounds[name] = sound
end

local function playSfx(name)
	local sound = sfxSounds[name]
	if soundEnabled and sound then
		sound:Play()
	end
end

playSoundEvent.OnClientEvent:Connect(function(name)
	playSfx(name)
end)

--------------------------------------------------------------------
-- Screen GUI
--------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkylineDash3DGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local function makeButton(parent, text, positionY)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 260, 0, 60)
	button.Position = UDim2.new(0.5, -130, 0, positionY)
	button.BackgroundColor3 = Color3.fromRGB(50, 70, 110)
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	return button
end

-- Main menu frame
local menuFrame = Instance.new("Frame")
menuFrame.Name = "MainMenu"
menuFrame.Size = UDim2.new(1, 0, 1, 0)
menuFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
menuFrame.BackgroundTransparency = 0.15
menuFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 100)
titleLabel.Position = UDim2.new(0, 0, 0, 60)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SKYLINE DASH 3D"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = menuFrame

local startButton = makeButton(menuFrame, "Start Game", 220)
local soundButton = makeButton(menuFrame, "Sound: On", 300)
local exitButton = makeButton(menuFrame, "Exit", 380)

-- HUD frame (shown once playing)
local hudFrame = Instance.new("Frame")
hudFrame.Name = "Hud"
hudFrame.Size = UDim2.new(0, 220, 0, 90)
hudFrame.Position = UDim2.new(0, 20, 0, 20)
hudFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
hudFrame.BackgroundTransparency = 0.5
hudFrame.Visible = false
hudFrame.Parent = screenGui

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 8)
hudCorner.Parent = hudFrame

local livesLabel = Instance.new("TextLabel")
livesLabel.Size = UDim2.new(1, -20, 0, 35)
livesLabel.Position = UDim2.new(0, 10, 0, 5)
livesLabel.BackgroundTransparency = 1
livesLabel.TextXAlignment = Enum.TextXAlignment.Left
livesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
livesLabel.TextScaled = true
livesLabel.Font = Enum.Font.Gotham
livesLabel.Text = "Lives: 3"
livesLabel.Parent = hudFrame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1, -20, 0, 35)
scoreLabel.Position = UDim2.new(0, 10, 0, 45)
scoreLabel.BackgroundTransparency = 1
scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.TextScaled = true
scoreLabel.Font = Enum.Font.Gotham
scoreLabel.Text = "Score: 0"
scoreLabel.Parent = hudFrame

-- End-of-game overlay (win or lose)
local overlayFrame = Instance.new("Frame")
overlayFrame.Name = "Overlay"
overlayFrame.Size = UDim2.new(1, 0, 1, 0)
overlayFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlayFrame.BackgroundTransparency = 0.35
overlayFrame.Visible = false
overlayFrame.Parent = screenGui

local overlayLabel = Instance.new("TextLabel")
overlayLabel.Size = UDim2.new(1, 0, 0, 100)
overlayLabel.Position = UDim2.new(0, 0, 0.5, -100)
overlayLabel.BackgroundTransparency = 1
overlayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
overlayLabel.TextScaled = true
overlayLabel.Font = Enum.Font.GothamBold
overlayLabel.Text = ""
overlayLabel.Parent = overlayFrame

local backToMenuButton = makeButton(overlayFrame, "Back to Menu", 0)
backToMenuButton.Position = UDim2.new(0.5, -130, 0.5, 20)

--------------------------------------------------------------------
-- Menu / HUD state handling
--------------------------------------------------------------------

local function setCharacterMovementEnabled(enabled)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and 16 or 0
		humanoid.JumpPower = enabled and 50 or 0
	end
end

local function showMenu()
	menuFrame.Visible = true
	hudFrame.Visible = false
	overlayFrame.Visible = false
	setCharacterMovementEnabled(false)
end

local function startGame()
	menuFrame.Visible = false
	hudFrame.Visible = true
	overlayFrame.Visible = false
	setCharacterMovementEnabled(true)
	if soundEnabled then
		backgroundMusic:Play()
	end
end

startButton.MouseButton1Click:Connect(startGame)

soundButton.MouseButton1Click:Connect(function()
	soundEnabled = not soundEnabled
	soundButton.Text = soundEnabled and "Sound: On" or "Sound: Off"
	if soundEnabled then
		backgroundMusic.Volume = 0.3
		if not menuFrame.Visible then
			backgroundMusic:Play()
		end
	else
		backgroundMusic:Stop()
	end
end)

exitButton.MouseButton1Click:Connect(function()
	requestExitEvent:FireServer()
end)

backToMenuButton.MouseButton1Click:Connect(showMenu)

playerWonEvent.OnClientEvent:Connect(function()
	overlayLabel.Text = "You Made It!"
	overlayFrame.Visible = true
	hudFrame.Visible = false
end)

playerLostEvent.OnClientEvent:Connect(function()
	overlayLabel.Text = "Game Over"
	overlayFrame.Visible = true
	hudFrame.Visible = false
end)

-- Start frozen at the main menu until the player clicks Start Game.
showMenu()

--------------------------------------------------------------------
-- Keep the HUD numbers, movement lock and jump sound in sync
--------------------------------------------------------------------

local function connectCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping then
			playSfx("Jump")
		end
	end)

	if not menuFrame.Visible then
		setCharacterMovementEnabled(true)
	else
		setCharacterMovementEnabled(false)
	end
end

if localPlayer.Character then
	connectCharacter(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(connectCharacter)

local leaderstats = localPlayer:WaitForChild("leaderstats")
local livesValue = leaderstats:WaitForChild("Lives")
local scoreValue = leaderstats:WaitForChild("Score")

local function updateHud()
	livesLabel.Text = "Lives: " .. tostring(livesValue.Value)
	scoreLabel.Text = "Score: " .. tostring(scoreValue.Value)
end

livesValue.Changed:Connect(updateHud)
scoreValue.Changed:Connect(updateHud)
updateHud()

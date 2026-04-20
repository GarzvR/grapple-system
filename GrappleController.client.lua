local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local Remote = ReplicatedStorage:WaitForChild("GrappleEvent")
local EffectRemote = ReplicatedStorage:WaitForChild("GrappleEffect")

local function createParticles()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local attachment = hrp:FindFirstChild("GrappleTrail") 
        or Instance.new("Attachment", hrp)
    attachment.Name = "GrappleTrail"

    local p = Instance.new("ParticleEmitter")
    p.Name = "SpeedParticles"
    p.Color = ColorSequence.new(Color3.new(1, 1, 1))
    p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
    p.Texture = "rbxassetid://292289455" 

    p.Transparency = NumberSequence.new(0.2, 1)
    p.Lifetime = NumberRange.new(0.3, 0.5)
    p.Rate = 100
    p.Speed = NumberRange.new(5, 10)
    p.Enabled = false
    p.Parent = attachment

    return p
end

local particles = nil

EffectRemote.OnClientEvent:Connect(function(action)
    if not player.Character then return end

    if not particles or particles.Parent == nil then
        particles = createParticles()
    end

    if action == "StartPull" then

        TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = Config.GrappleFOV}):Play()
        if particles then particles.Enabled = true end
    elseif action == "StopPull" then

        TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = Config.DefaultFOV}):Play()
        if particles then particles.Enabled = false end
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E then
        local character = player.Character
        if not character then return end

        local tool = character:FindFirstChild("GrapplingHook")
        if not tool then
            print("Equip the GrapplingHook")
            return
        end

        Remote:FireServer(mouse.Hit.Position)
    end
end)
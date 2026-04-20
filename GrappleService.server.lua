local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Remote = ReplicatedStorage:FindFirstChild("GrappleEvent")
if not Remote then
    Remote = Instance.new("RemoteEvent")
    Remote.Name = "GrappleEvent"
    Remote.Parent = ReplicatedStorage
end

local EffectRemote = ReplicatedStorage:FindFirstChild("GrappleEffect")
if not EffectRemote then local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Remote = ReplicatedStorage:FindFirstChild("GrappleEvent")
if not Remote then
    Remote = Instance.new("RemoteEvent")
    Remote.Name = "GrappleEvent"
    Remote.Parent = ReplicatedStorage
end

local EffectRemote = ReplicatedStorage:FindFirstChild("GrappleEffect")
if not EffectRemote then
    EffectRemote = Instance.new("RemoteEvent")
    EffectRemote.Name = "GrappleEffect"
    EffectRemote.Parent = ReplicatedStorage
end

local function getHookModel()
    return ReplicatedStorage:FindFirstChild("GrapplingHook") 
        or workspace:FindFirstChild("GrapplingHook")
end

local function scaleModel(model, scale)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Size = part.Size * scale
        end
    end
end

local function giveGrappleTool(player)
    local sourceModel = getHookModel()
    if not sourceModel then
        warn("GrapplingHook model not found!")
        return
    end

    local tool = Instance.new("Tool")
    tool.Name = "GrapplingHook"
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local meshPart = sourceModel:FindFirstChild("MeshPart")
    if meshPart then
        local handle = meshPart:Clone()
        handle.Name = "Handle"
        handle.Parent = tool
    end

    local hookPart = sourceModel:FindFirstChild("Hook")
    if hookPart then
        local hook = hookPart:Clone()
        hook.Name = "Hook"
        hook.Parent = tool
    end

    scaleModel(tool, Config.ModelScale)

    local backpack = player:WaitForChild("Backpack")
    tool.Parent = backpack

    print("Gave GrapplingHook tool to", player.Name)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        giveGrappleTool(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        giveGrappleTool(player)
    end
    player.CharacterAdded:Connect(function()
        task.wait(1)
        giveGrappleTool(player)
    end)
end

print("GrappleService")

local activeGrapples = {}

Remote.OnServerEvent:Connect(function(player, mousePos)

    if activeGrapples[player.UserId] then return end
    activeGrapples[player.UserId] = true

    local character = player.Character
    if not character then
        activeGrapples[player.UserId] = nil
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        activeGrapples[player.UserId] = nil
        return
    end

    if not mousePos then
        activeGrapples[player.UserId] = nil
        return
    end

    local tool = character:FindFirstChild("GrapplingHook")
    if not tool then
        activeGrapples[player.UserId] = nil
        return
    end

    local hookPart = tool:FindFirstChild("Hook")
    local handlePart = tool:FindFirstChild("Handle")
    if not hookPart or not handlePart then
        activeGrapples[player.UserId] = nil
        return
    end

    local diff = (mousePos - hrp.Position)
    local direction = diff.Unit * Config.Range

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(hrp.Position, direction, rayParams)

    if result then
        print("Grapple hit:", result.Instance.Name)

        local hookOriginalCFrame = hookPart.CFrame

        hookPart.Anchored = true
        hookPart.CanCollide = false

        local distance = (result.Position - hrp.Position).Magnitude
        local tossDuration = distance / (Config.PullSpeed * 2.5)

        local hookTargetCFrame = CFrame.new(result.Position, result.Position + result.Normal)

        local hookTweenInfo = TweenInfo.new(
            tossDuration,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        )

        local hookTween = TweenService:Create(hookPart, hookTweenInfo, {CFrame = hookTargetCFrame})
        hookTween:Play()
        hookTween.Completed:Wait()

        print("Hook arrived")

        EffectRemote:FireClient(player, "StartPull")

        local animator = humanoid:FindFirstChildOfClass("Animator")
        local animTrack = nil

        if animator then
            local hangAnim = Instance.new("Animation")

            hangAnim.AnimationId = "rbxassetid://180436334"

            local success, err = pcall(function()
                animTrack = animator:LoadAnimation(hangAnim)
            end)

            if success and animTrack then
                animTrack.Priority = Enum.AnimationPriority.Action
                animTrack:Play()
            else
                warn("Could not load animation:", err)
            end
        end

        local pullDuration = distance / Config.PullSpeed
        local playerTargetCFrame = CFrame.new(result.Position + (result.Normal * 3), result.Position)

        local playerTweenInfo = TweenInfo.new(
            pullDuration,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        hrp.Anchored = true
        humanoid.PlatformStand = true

        local playerTween = TweenService:Create(hrp, playerTweenInfo, {CFrame = playerTargetCFrame})
        playerTween:Play()
        playerTween.Completed:Wait()

        hrp.Anchored = false
        humanoid.PlatformStand = false

        if animTrack then
            animTrack:Stop()
        end

        EffectRemote:FireClient(player, "StopPull")

        hookPart:Destroy()

        local sourceModel = getHookModel()
        if sourceModel then
            local sourceHook = sourceModel:FindFirstChild("Hook")
            if sourceHook then
                local newHook = sourceHook:Clone()
                newHook.Name = "Hook"

                for _, part in ipairs(newHook:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Size = part.Size * Config.ModelScale
                    end
                end
                if newHook:IsA("BasePart") then
                    newHook.Size = newHook.Size * Config.ModelScale
                end
                newHook.Parent = tool
            end
        end

        print("Grapple finished")
    else
        print("Missed")
    end

    task.wait(Config.Cooldown)
    activeGrapples[player.UserId] = nil
end)
    EffectRemote = Instance.new("RemoteEvent")
    EffectRemote.Name = "GrappleEffect"
    EffectRemote.Parent = ReplicatedStorage
end

local function getHookModel()
    return ReplicatedStorage:FindFirstChild("GrapplingHook") 
        or workspace:FindFirstChild("GrapplingHook")
end

local function scaleModel(model, scale)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Size = part.Size * scale
        end
    end
end

local function giveGrappleTool(player)
    local sourceModel = getHookModel()
    if not sourceModel then
        warn("GrapplingHook model not found!")
        return
    end

    local tool = Instance.new("Tool")
    tool.Name = "GrapplingHook"
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local meshPart = sourceModel:FindFirstChild("MeshPart")
    if meshPart then
        local handle = meshPart:Clone()
        handle.Name = "Handle"
        handle.Parent = tool
    end

    local hookPart = sourceModel:FindFirstChild("Hook")
    if hookPart then
        local hook = hookPart:Clone()
        hook.Name = "Hook"
        hook.Parent = tool
    end

    scaleModel(tool, Config.ModelScale)

    local backpack = player:WaitForChild("Backpack")
    tool.Parent = backpack

    print("Gave GrapplingHook", player.Name)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        giveGrappleTool(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        giveGrappleTool(player)
    end
    player.CharacterAdded:Connect(function()
        task.wait(1)
        giveGrappleTool(player)
    end)
end

print("GrappleService started")

local activeGrapples = {}

Remote.OnServerEvent:Connect(function(player, mousePos)

    if activeGrapples[player.UserId] then return end
    activeGrapples[player.UserId] = true

    local character = player.Character
    if not character then
        activeGrapples[player.UserId] = nil
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        activeGrapples[player.UserId] = nil
        return
    end

    if not mousePos then
        activeGrapples[player.UserId] = nil
        return
    end

    local tool = character:FindFirstChild("GrapplingHook")
    if not tool then
        activeGrapples[player.UserId] = nil
        return
    end

    local hookPart = tool:FindFirstChild("Hook")
    local handlePart = tool:FindFirstChild("Handle")
    if not hookPart or not handlePart then
        activeGrapples[player.UserId] = nil
        return
    end

    local diff = (mousePos - hrp.Position)
    local direction = diff.Unit * Config.Range

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(hrp.Position, direction, rayParams)

    if result then
        print("Grapple hit:", result.Instance.Name)

        local hookOriginalCFrame = hookPart.CFrame

        hookPart.Anchored = true
        hookPart.CanCollide = false

        local distance = (result.Position - hrp.Position).Magnitude
        local tossDuration = distance / (Config.PullSpeed * 2.5)

        local hookTargetCFrame = CFrame.new(result.Position, result.Position + result.Normal)

        local hookTweenInfo = TweenInfo.new(
            tossDuration,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        )

        local hookTween = TweenService:Create(hookPart, hookTweenInfo, {CFrame = hookTargetCFrame})
        hookTween:Play()
        hookTween.Completed:Wait()

        print("Hook arrived. ")

        EffectRemote:FireClient(player, "StartPull")

        local animator = humanoid:FindFirstChildOfClass("Animator")
        local animTrack = nil

        if animator then
            local hangAnim = Instance.new("Animation")

            hangAnim.AnimationId = "rbxassetid://180436334"

            local success, err = pcall(function()
                animTrack = animator:LoadAnimation(hangAnim)
            end)

            if success and animTrack then
                animTrack.Priority = Enum.AnimationPriority.Action
                animTrack:Play()
            else
                warn("Could not load animation:", err)
            end
        end

        local pullDuration = distance / Config.PullSpeed
        local playerTargetCFrame = CFrame.new(result.Position + (result.Normal * 3), result.Position)

        local playerTweenInfo = TweenInfo.new(
            pullDuration,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        hrp.Anchored = true
        humanoid.PlatformStand = true

        local playerTween = TweenService:Create(hrp, playerTweenInfo, {CFrame = playerTargetCFrame})
        playerTween:Play()
        playerTween.Completed:Wait()

        hrp.Anchored = false
        humanoid.PlatformStand = false

        if animTrack then
            animTrack:Stop()
        end

        EffectRemote:FireClient(player, "StopPull")

        hookPart:Destroy()

        local sourceModel = getHookModel()
        if sourceModel then
            local sourceHook = sourceModel:FindFirstChild("Hook")
            if sourceHook then
                local newHook = sourceHook:Clone()
                newHook.Name = "Hook"

                for _, part in ipairs(newHook:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Size = part.Size * Config.ModelScale
                    end
                end
                if newHook:IsA("BasePart") then
                    newHook.Size = newHook.Size * Config.ModelScale
                end
                newHook.Parent = tool
            end
        end

        print("Grapple finished.")
    else
        print("Missed")
    end

    task.wait(Config.Cooldown)
    activeGrapples[player.UserId] = nil
end)
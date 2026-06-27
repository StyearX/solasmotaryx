local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))()
if not Fluent then warn("[OnetapRecoded] FluentPro failed to load") return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local AimbotEnabled = false
local AimParts = {HumanoidRootPart = true}
local WallCheckEnabled = false
local TeamCheckEnabled = false
local TargetNpcs = false
local InfiniteJumpEnabled = false
local FovRadius = 120
local FovVisible = false
local AimbotConnection = nil
local WalkSpeedValue = 16
local FloatingAimbotGui = nil
local AimbotMaxDist = 500
local AimbotSensitivity = 1.0
local FloatingAimbotBtn = nil

local EspSettings = {
    BoxEnabled = false,
    NameEnabled = false,
    HealthEnabled = false,
    TracerEnabled = false,
    DistanceEnabled = false,
    SkeletonEnabled = false,
    TeamCheck = false,
    BoxColor = Color3.fromRGB(200, 80, 255),
    NameColor = Color3.fromRGB(255, 255, 255),
    TracerColor = Color3.fromRGB(200, 80, 255),
    SkeletonColor = Color3.fromRGB(200, 80, 255),
    HealthHighColor = Color3.fromRGB(0, 255, 100),
    HealthLowColor = Color3.fromRGB(255, 50, 50),
    TracerOrigin = "Middle",
}

local EspObjects = {}

local function D(Class, Props)
    local ok, Obj = pcall(Drawing.new, Class)
    if not ok then return nil end
    for K, V in pairs(Props or {}) do pcall(function() Obj[K] = V end) end
    return Obj
end

local BonePairs = {
    {"Head","UpperTorso"},{"Head","Torso"},
    {"UpperTorso","LowerTorso"},{"Torso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"Torso","Left Arm"},{"Left Arm","Left Leg"},
    {"Torso","Right Arm"},{"Right Arm","Right Leg"},
}

local function RemoveEsp(Player)
    if not EspObjects[Player] then return end
    local Data = EspObjects[Player]
    if Data.Bones then
        for _, Bone in pairs(Data.Bones) do
            pcall(function() Bone.Line:Remove() end)
            pcall(function() Bone.Outline:Remove() end)
        end
    end
    for Key, Obj in pairs(Data) do
        if Key ~= "Bones" then pcall(function() Obj:Remove() end) end
    end
    EspObjects[Player] = nil
end

local function CreateEsp(Player)
    if EspObjects[Player] then return end
    local Bones = {}
    for _, Pair in ipairs(BonePairs) do
        local Line = D("Line", {Visible=false, Thickness=1, Color=EspSettings.SkeletonColor})
        local Outline = D("Line", {Visible=false, Thickness=3, Color=Color3.new(0,0,0)})
        if Line and Outline then
            table.insert(Bones, {A=Pair[1], B=Pair[2], Line=Line, Outline=Outline})
        end
    end
    EspObjects[Player] = {
        BoxOutline = D("Square", {Visible=false, Thickness=3, Filled=false, Color=Color3.new(0,0,0)}),
        Box = D("Square", {Visible=false, Thickness=1, Filled=false}),
        HealthBg = D("Square", {Visible=false, Filled=true, Color=Color3.new(0,0,0)}),
        Health = D("Square", {Visible=false, Filled=true}),
        Name = D("Text", {Visible=false, Size=14, Center=true, Outline=true, Color=EspSettings.NameColor}),
        Distance = D("Text", {Visible=false, Size=12, Center=true, Outline=true, Color=Color3.fromRGB(200,200,200)}),
        TracerOutline = D("Line", {Visible=false, Thickness=3, Color=Color3.new(0,0,0)}),
        Tracer = D("Line", {Visible=false, Thickness=1}),
        Bones = Bones,
    }
end

local function HideEsp(Player)
    if not EspObjects[Player] then return end
    local Data = EspObjects[Player]
    for Key, Obj in pairs(Data) do
        if Key ~= "Bones" and Obj then pcall(function() Obj.Visible = false end) end
    end
    if Data.Bones then
        for _, Bone in pairs(Data.Bones) do
            pcall(function() Bone.Line.Visible = false end)
            pcall(function() Bone.Outline.Visible = false end)
        end
    end
end

local function GetBoundingBox(Character)
    local Vp = Camera.ViewportSize
    local MinX, MinY, MaxX, MaxY = math.huge, math.huge, -math.huge, -math.huge
    local Visible = false
    for _, Part in ipairs(Character:GetChildren()) do
        if Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then
            local Sp, V = Camera:WorldToScreenPoint(Part.Position)
            if V and Sp.Z > 0 then
                local Cx = math.clamp(Sp.X, 0, Vp.X)
                local Cy = math.clamp(Sp.Y, 0, Vp.Y)
                Visible = true
                MinX = math.min(MinX, Cx); MinY = math.min(MinY, Cy)
                MaxX = math.max(MaxX, Cx); MaxY = math.max(MaxY, Cy)
            end
        end
    end
    return Visible, MinX, MinY, MaxX, MaxY
end

local function UpdateEspForPlayer(Player)
    local Data = EspObjects[Player]
    if not Data then return end
    local Character = Player.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local AnyEnabled = EspSettings.BoxEnabled or EspSettings.NameEnabled or EspSettings.HealthEnabled
        or EspSettings.TracerEnabled or EspSettings.DistanceEnabled or EspSettings.SkeletonEnabled
    if not Character or not Humanoid or Humanoid.Health <= 0 or not AnyEnabled then
        HideEsp(Player); return
    end
    if EspSettings.TeamCheck and Player.Team and Player.Team == LocalPlayer.Team then
        HideEsp(Player); return
    end
    local Root = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso")
    if not Root then HideEsp(Player) return end
    local RootSp, OnScreen = Camera:WorldToScreenPoint(Root.Position)
    if not OnScreen or RootSp.Z <= 0 then HideEsp(Player) return end
    local BbVis, MinX, MinY, MaxX, MaxY = GetBoundingBox(Character)
    if not BbVis then HideEsp(Player) return end
    local Vp = Camera.ViewportSize
    local Bx, By = MinX - 4, MinY - 4
    local Bw, Bh = (MaxX - MinX) + 8, (MaxY - MinY) + 8
    if Bw > Vp.X * 0.9 or Bh > Vp.Y * 0.9 or Bw <= 0 or Bh <= 0 then
        HideEsp(Player) return
    end
    local LocalRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local Dist = LocalRoot and math.floor((Root.Position - LocalRoot.Position).Magnitude) or 0
    local Hr = math.clamp(Humanoid.Health / math.max(Humanoid.MaxHealth, 1), 0, 1)
    local Hc = EspSettings.HealthLowColor:Lerp(EspSettings.HealthHighColor, Hr)

    if EspSettings.BoxEnabled and Data.Box then
        Data.BoxOutline.Visible = true
        Data.BoxOutline.Position = Vector2.new(Bx-1, By-1)
        Data.BoxOutline.Size = Vector2.new(Bw+2, Bh+2)
        Data.Box.Visible = true
        Data.Box.Position = Vector2.new(Bx, By)
        Data.Box.Size = Vector2.new(Bw, Bh)
        Data.Box.Color = EspSettings.BoxColor
    elseif Data.Box then
        Data.BoxOutline.Visible = false; Data.Box.Visible = false
    end

    if EspSettings.HealthEnabled and Data.Health then
        local HbX = Bx - 6
        Data.HealthBg.Visible = true
        Data.HealthBg.Position = Vector2.new(HbX-1, By-1)
        Data.HealthBg.Size = Vector2.new(5, Bh+2)
        Data.Health.Visible = true
        Data.Health.Position = Vector2.new(HbX, By + Bh*(1-Hr))
        Data.Health.Size = Vector2.new(3, math.max(Bh*Hr, 1))
        Data.Health.Color = Hc
    elseif Data.Health then
        Data.HealthBg.Visible = false; Data.Health.Visible = false
    end

    if EspSettings.NameEnabled and Data.Name then
        Data.Name.Visible = true
        Data.Name.Position = Vector2.new(Bx + Bw/2, math.max(By - 16, 0))
        Data.Name.Text = Player.Name
        Data.Name.Color = EspSettings.NameColor
    elseif Data.Name then
        Data.Name.Visible = false
    end

    if EspSettings.DistanceEnabled and Data.Distance then
        Data.Distance.Visible = true
        Data.Distance.Position = Vector2.new(Bx + Bw/2, math.min(By + Bh + 2, Vp.Y))
        Data.Distance.Text = tostring(Dist) .. "m"
    elseif Data.Distance then
        Data.Distance.Visible = false
    end

    if EspSettings.TracerEnabled and Data.Tracer then
        local Origin
        if EspSettings.TracerOrigin == "Bottom" then
            Origin = Vector2.new(Vp.X/2, Vp.Y)
        elseif EspSettings.TracerOrigin == "Top" then
            Origin = Vector2.new(Vp.X/2, 0)
        else
            Origin = Vector2.new(Vp.X/2, Vp.Y/2)
        end
        local Tgt = Vector2.new(
            math.clamp(RootSp.X, 0, Vp.X),
            math.clamp(RootSp.Y, 0, Vp.Y)
        )
        Data.TracerOutline.Visible = true
        Data.TracerOutline.From = Origin; Data.TracerOutline.To = Tgt
        Data.Tracer.Visible = true
        Data.Tracer.From = Origin; Data.Tracer.To = Tgt
        Data.Tracer.Color = EspSettings.TracerColor
    elseif Data.Tracer then
        Data.TracerOutline.Visible = false; Data.Tracer.Visible = false
    end

    if EspSettings.SkeletonEnabled and Data.Bones then
        for _, Bone in pairs(Data.Bones) do
            local Pa = Character:FindFirstChild(Bone.A)
            local Pb = Character:FindFirstChild(Bone.B)
            if Pa and Pb then
                local Sa, Va = Camera:WorldToScreenPoint(Pa.Position)
                local Sb, Vb = Camera:WorldToScreenPoint(Pb.Position)
                if Va and Vb and Sa.Z > 0 and Sb.Z > 0 then
                    Bone.Outline.Visible = true
                    Bone.Outline.From = Vector2.new(Sa.X, Sa.Y)
                    Bone.Outline.To = Vector2.new(Sb.X, Sb.Y)
                    Bone.Line.Visible = true
                    Bone.Line.From = Vector2.new(Sa.X, Sa.Y)
                    Bone.Line.To = Vector2.new(Sb.X, Sb.Y)
                    Bone.Line.Color = EspSettings.SkeletonColor
                else
                    Bone.Outline.Visible = false; Bone.Line.Visible = false
                end
            else
                Bone.Outline.Visible = false; Bone.Line.Visible = false
            end
        end
    elseif Data.Bones then
        for _, Bone in pairs(Data.Bones) do
            Bone.Outline.Visible = false; Bone.Line.Visible = false
        end
    end
end

local PlayerCharConns = {}

local function SetupPlayerCharacter(Player, Character)
    if not Character then return end
    local Humanoid = Character:WaitForChild("Humanoid", 5)
    if not Humanoid then return end
    if EspObjects[Player] then RemoveEsp(Player) end
    CreateEsp(Player)
    local DiedConn
    DiedConn = Humanoid.Died:Connect(function()
        HideEsp(Player)
        if DiedConn then DiedConn:Disconnect() end
    end)
end

local function SetupPlayer(Player)
    if Player == LocalPlayer then return end
    if PlayerCharConns[Player] then
        for _, C in pairs(PlayerCharConns[Player]) do pcall(function() C:Disconnect() end) end
    end
    if Player.Character then
        task.spawn(SetupPlayerCharacter, Player, Player.Character)
    end
    local Ca = Player.CharacterAdded:Connect(function(Chr)
        task.wait(0.1)
        SetupPlayerCharacter(Player, Chr)
    end)
    local Cr = Player.CharacterRemoving:Connect(function() HideEsp(Player) end)
    PlayerCharConns[Player] = {Ca, Cr}
end

for _, P in pairs(Players:GetPlayers()) do SetupPlayer(P) end
Players.PlayerAdded:Connect(SetupPlayer)
Players.PlayerRemoving:Connect(function(Player)
    RemoveEsp(Player)
    if PlayerCharConns[Player] then
        for _, C in pairs(PlayerCharConns[Player]) do pcall(function() C:Disconnect() end) end
        PlayerCharConns[Player] = nil
    end
end)

RunService.RenderStepped:Connect(function()
    for Player in pairs(EspObjects) do
        pcall(UpdateEspForPlayer, Player)
    end
end)

local FovGui = Instance.new("ScreenGui")
FovGui.Name = "FovGui"
FovGui.ResetOnSpawn = false
FovGui.IgnoreGuiInset = true
FovGui.DisplayOrder = 998
FovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
FovGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local FovHolder = Instance.new("Frame")
FovHolder.Name = "FovHolder"
FovHolder.BackgroundTransparency = 1
FovHolder.AnchorPoint = Vector2.new(0.5, 0.5)
FovHolder.Size = UDim2.fromOffset(FovRadius * 2, FovRadius * 2)
FovHolder.Position = UDim2.fromScale(0.5, 0.5)
FovHolder.Visible = false
FovHolder.ZIndex = 100
FovHolder.Parent = FovGui
FovHolder:SetAttribute("Locked", true)

local FovRing = Instance.new("Frame")
FovRing.Name = "FovRing"
FovRing.BackgroundTransparency = 0.88
FovRing.BackgroundColor3 = Color3.fromRGB(140, 60, 220)
FovRing.AnchorPoint = Vector2.new(0.5, 0.5)
FovRing.Size = UDim2.fromScale(1, 1)
FovRing.Position = UDim2.fromScale(0.5, 0.5)
FovRing.ZIndex = 100
FovRing.Parent = FovHolder

Instance.new("UICorner", FovRing).CornerRadius = UDim.new(1, 0)

local FovFillGrad = Instance.new("UIGradient")
FovFillGrad.Rotation = 0
FovFillGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 10, 90)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 60, 220)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 10, 90)),
})
FovFillGrad.Parent = FovRing

local FovStroke = Instance.new("UIStroke")
FovStroke.Thickness = 2
FovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
FovStroke.Color = Color3.fromRGB(160, 80, 255)
FovStroke.Parent = FovRing

local FovStrokeGrad = Instance.new("UIGradient")
FovStrokeGrad.Rotation = 0
FovStrokeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 20, 160)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 160)),
})
FovStrokeGrad.Parent = FovStroke

task.spawn(function()
    while task.wait(0.03) do
        if not FovRing.Parent then break end
        FovFillGrad.Rotation = (FovFillGrad.Rotation + 1) % 360
        pcall(function()
            if getgenv().ButtonGradients and getgenv().ButtonGradients.Background then
                FovFillGrad.Color = getgenv().ButtonGradients.Background
            end
        end)
    end
end)

task.spawn(function()
    while FovRing.Parent do
        FovStrokeGrad.Rotation = (FovStrokeGrad.Rotation + 0.5) % 360
        pcall(function()
            if getgenv().ButtonGradients and getgenv().ButtonGradients.Stroke then
                FovStrokeGrad.Color = getgenv().ButtonGradients.Stroke
            end
        end)
        task.wait()
    end
end)

local FovDragging = false
local FovDragInput = nil
local FovDragStart = nil
local FovStartPos = nil
local FovHolding = false
local FovHoldToken = 0

local function FovToggleLock()
    local New = not FovHolder:GetAttribute("Locked")
    FovHolder:SetAttribute("Locked", New)
    if New then FovHolder.Position = UDim2.fromScale(0.5, 0.5) end
end

FovRing.InputBegan:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
    FovDragging = not FovHolder:GetAttribute("Locked")
    FovHolding = true
    FovDragStart = Input.Position
    FovStartPos = FovHolder.Position
    FovHoldToken = FovHoldToken + 1
    local Token = FovHoldToken
    task.delay(1.0, function()
        if FovHolding and Token == FovHoldToken then FovToggleLock() end
    end)
    Input.Changed:Connect(function()
        if Input.UserInputState == Enum.UserInputState.End then
            FovDragging = false; FovHolding = false
        end
    end)
end)

FovRing.InputChanged:Connect(function(Input)
    if not FovDragStart then return end
    if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
        if (Input.Position - FovDragStart).Magnitude > 6 then FovHolding = false end
        FovDragInput = Input
    end
end)

UserInputService.InputChanged:Connect(function(Input)
    if Input == FovDragInput and FovDragging then
        if FovHolder:GetAttribute("Locked") then return end
        local Delta = Input.Position - FovDragStart
        FovHolder.Position = UDim2.new(FovStartPos.X.Scale, FovStartPos.X.Offset + Delta.X, FovStartPos.Y.Scale, FovStartPos.Y.Offset + Delta.Y)
    end
end)

local function UpdateFovSize(R)
    FovRadius = R
    FovHolder.Size = UDim2.fromOffset(R * 2, R * 2)
end

local function GetFovCenter()
    local Pos = FovHolder.AbsolutePosition
    local Sz = FovHolder.AbsoluteSize
    return Vector2.new(Pos.X + Sz.X / 2, Pos.Y + Sz.Y / 2)
end

local function GetAimPartFromTarget(Target)
    for Part, Selected in pairs(AimParts) do
        if Selected then
            local Found = Target:FindFirstChild(Part)
            if Found then return Found end
        end
    end
    return Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Torso")
end

local function GetClosestTarget()
    local Chr = LocalPlayer.Character
    if not Chr then return nil end
    local LocalRoot = Chr:FindFirstChild("HumanoidRootPart")
    if not LocalRoot then return nil end
    local Nearest, Shortest = nil, math.huge
    local Center = GetFovCenter()

    local function Check(Target)
        if not Target or not Target:IsA("Model") then return end
        local Hum = Target:FindFirstChildOfClass("Humanoid")
        if not Hum or Hum.Health <= 0 then return end
        local Part = GetAimPartFromTarget(Target)
        if not Part then return end
        local Sp, OnScreen = Camera:WorldToScreenPoint(Part.Position)
        if not OnScreen or Sp.Z <= 0 then return end
        local Dist = (Part.Position - LocalRoot.Position).Magnitude
        if Dist > AimbotMaxDist then return end
        if (Vector2.new(Sp.X, Sp.Y) - Center).Magnitude > FovRadius then return end
        if WallCheckEnabled then
            local Params = RaycastParams.new()
            Params.FilterDescendantsInstances = {Chr}
            Params.FilterType = Enum.RaycastFilterType.Blacklist
            local Dir = (Part.Position - Camera.CFrame.Position).Unit * 2000
            local Result = workspace:Raycast(Camera.CFrame.Position, Dir, Params)
            if not Result or not Result.Instance:IsDescendantOf(Target) then return end
        end
        if Dist < Shortest then Shortest = Dist; Nearest = Target end
    end

    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            if not (TeamCheckEnabled and Player.Team and Player.Team == LocalPlayer.Team) then
                pcall(Check, Player.Character)
            end
        end
    end

    if TargetNpcs then
        for _, Obj in pairs(workspace:GetDescendants()) do
            if Obj:IsA("Model") and not Players:GetPlayerFromCharacter(Obj) then
                pcall(Check, Obj)
            end
        end
    end

    return Nearest
end

local function StartAimbot()
    if AimbotConnection then AimbotConnection:Disconnect(); AimbotConnection = nil end
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if not AimbotEnabled then
            AimbotConnection:Disconnect(); AimbotConnection = nil; return
        end
        local Target = GetClosestTarget()
        if not Target then return end
        local Part = GetAimPartFromTarget(Target)
        if not Part then return end
        local TargetCF = CFrame.new(Camera.CFrame.Position, Part.Position)
        Camera.CFrame = Camera.CFrame:Lerp(TargetCF, math.clamp(AimbotSensitivity, 0.01, 1.0))
    end)
end

UserInputService.JumpRequest:Connect(function()
    if not InfiniteJumpEnabled then return end
    local Chr = LocalPlayer.Character
    if not Chr then return end
    local Hum = Chr:FindFirstChildOfClass("Humanoid")
    if Hum then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local Window = Fluent:CreateWindow({
    Title = "SolasmotaryXuniversal",
    SubTitle = "by x2zu,styearc",
    TabWidth = 120,
    Size = UDim2.fromOffset(490, 490),
    Acrylic = true,
    Theme = "Deep Violet",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local function Notify(Title, Content, NType, Icon, Duration)
    Fluent:Notify({Title=Title, Content=Content, Type=NType or "Info", Icon=Icon, Duration=Duration or 3})
end

local Tabs = {
    Aimbot = Window:AddTab({Title="Aimbot", Icon="solar/target-bold"}),
    Esp = Window:AddTab({Title="ESP", Icon="solar/eye-bold"}),
    Misc = Window:AddTab({Title="Misc", Icon="solar/widget-bold"}),
    Settings = Window:AddTab({Title="Settings", Icon="solar/settings-bold"}),
}

local SecAim = Tabs.Aimbot:AddSection("Aimbot", "solar/target-bold")

SecAim:AddToggle("AimbotTabToggle", {
    Title = "Aimbot",
    Icon = "solar/target-bold",
    Default = false,
    Description = "Lock camera to nearest target inside FOV",
    Callback = function(V)
        AimbotEnabled = V
        if V then StartAimbot() end
        if FloatingAimbotBtn then
            FloatingAimbotBtn.Text = "AIM: " .. (V and "ON" or "OFF")
        end
        Notify("Aimbot", V and "Enabled" or "Disabled", V and "Success" or "Info", "solar/target-bold")
    end,
})

SecAim:AddToggle("AimbotFloatingToggle", {
    Title = "Aimbot Floating Button",
    Icon = "solar/widget-bold",
    Default = false,
    Description = "Show/hide the floating aimbot button on screen",
    Callback = function(V)
        if FloatingAimbotGui then
            FloatingAimbotGui.Enabled = V
        end
    end,
})

SecAim:AddDropdown("AimPartDropdown", {
    Title = "Aim Part",
    Icon = "solar/body-bold",
    Values = {
        "HumanoidRootPart","Head","Torso","UpperTorso","LowerTorso",
        "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm",
        "LeftHand","RightHand",
        "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg",
        "LeftFoot","RightFoot","Left Arm","Right Arm","Left Leg","Right Leg",
    },
    Default = {HumanoidRootPart = true},
    Multi = true,
    DropdownOutsideWindow = true,
    Search = false,
    Description = "Select body parts to aim at",
    Callback = function(V) AimParts = V end,
})

SecAim:AddSlider("AimbotDistSlider", {
    Title = "Max Distance",
    Icon = "solar/ruler-bold",
    Min = 50,
    Max = 2000,
    Default = 500,
    Rounding = 0,
    Description = "Maximum studs to target",
    Callback = function(V) AimbotMaxDist = V end,
})

SecAim:AddSlider("AimbotSensSlider", {
    Title = "Sensitivity",
    Icon = "solar/cursor-bold",
    Min = 1,
    Max = 100,
    Default = 100,
    Rounding = 0,
    Description = "1 = smoothest, 100 = instant snap",
    Callback = function(V) AimbotSensitivity = V / 100 end,
})

SecAim:AddToggle("WallCheckToggle", {
    Title = "Wall Check",
    Icon = "solar/shield-bold",
    Default = false,
    Callback = function(V) WallCheckEnabled = V end,
})

SecAim:AddToggle("TeamCheckAimToggle", {
    Title = "Team Check",
    Icon = "solar/users-group-rounded-bold",
    Default = false,
    Callback = function(V) TeamCheckEnabled = V end,
})

SecAim:AddToggle("NpcTargetToggle", {
    Title = "Target NPCs",
    Icon = "solar/ghost-bold",
    Default = false,
    Callback = function(V) TargetNpcs = V end,
})

SecAim:AddDivider()

local SecFov = Tabs.Aimbot:AddSection("FOV Circle", "solar/circle-bold")

SecFov:AddParagraph({
    Title = "Drag and Lock",
    Content = "Hold the circle 1 second to toggle lock. Unlocked: drag freely. Locked: snaps to center.",
})

SecFov:AddToggle("FovVisibleToggle", {
    Title = "Show FOV Circle",
    Icon = "solar/eye-bold",
    Default = false,
    Callback = function(V)
        FovVisible = V
        FovHolder.Visible = V
    end,
})

SecFov:AddSlider("FovRadiusSlider", {
    Title = "FOV Radius",
    Icon = "solar/circle-bold",
    Min = 30, Max = 600, Default = 120, Rounding = 0,
    Callback = function(V) UpdateFovSize(V) end,
})

SecFov:AddButton({
    Title = "Reset FOV to Center",
    Icon = "solar/restart-bold",
    Callback = function()
        FovHolder.Position = UDim2.fromScale(0.5, 0.5)
        FovHolder:SetAttribute("Locked", true)
        Notify("FOV", "Reset and locked", "Info", "solar/restart-bold", 2)
    end,
})

SecFov:AddDivider()

local SecEsp = Tabs.Esp:AddSection("ESP", "solar/eye-bold")

SecEsp:AddToggle("EspBoxToggle", {
    Title = "Box ESP", Icon = "solar/square-bold", Default = false,
    Callback = function(V) EspSettings.BoxEnabled = V end,
})
SecEsp:AddToggle("EspNameToggle", {
    Title = "Name ESP", Icon = "solar/text-bold", Default = false,
    Callback = function(V) EspSettings.NameEnabled = V end,
})
SecEsp:AddToggle("EspHealthToggle", {
    Title = "Health Bar", Icon = "solar/heart-bold", Default = false,
    Callback = function(V) EspSettings.HealthEnabled = V end,
})
SecEsp:AddToggle("EspTracerToggle", {
    Title = "Tracer", Icon = "solar/arrow-right-bold", Default = false,
    Callback = function(V) EspSettings.TracerEnabled = V end,
})
SecEsp:AddToggle("EspDistanceToggle", {
    Title = "Distance", Icon = "solar/ruler-bold", Default = false,
    Callback = function(V) EspSettings.DistanceEnabled = V end,
})
SecEsp:AddToggle("EspSkeletonToggle", {
    Title = "Skeleton", Icon = "solar/accessibility-bold", Default = false,
    Callback = function(V) EspSettings.SkeletonEnabled = V end,
})
SecEsp:AddToggle("EspTeamCheckToggle", {
    Title = "Team Check", Icon = "solar/users-group-rounded-bold", Default = false,
    Callback = function(V) EspSettings.TeamCheck = V end,
})

SecEsp:AddDivider()

local SecEspStyle = Tabs.Esp:AddSection("ESP Style", "solar/palette-bold")

SecEspStyle:AddDropdown("EspTracerOriginDropdown", {
    Title = "Tracer Origin",
    Icon = "solar/arrow-right-bold",
    Values = {"Bottom", "Middle", "Top"},
    Default = "Middle",
    DropdownOutsideWindow = true,
    Search = false,
    Callback = function(V) EspSettings.TracerOrigin = V end,
})

SecEspStyle:AddColorpicker("EspBoxColor", {
    Title = "Box Color", Icon = "solar/palette-bold",
    Default = Color3.fromRGB(200, 80, 255), Transparency = 0,
    Callback = function(C) EspSettings.BoxColor = C end,
})
SecEspStyle:AddColorpicker("EspNameColor", {
    Title = "Name Color", Icon = "solar/palette-bold",
    Default = Color3.fromRGB(255, 255, 255), Transparency = 0,
    Callback = function(C) EspSettings.NameColor = C end,
})
SecEspStyle:AddColorpicker("EspTracerColor", {
    Title = "Tracer Color", Icon = "solar/palette-bold",
    Default = Color3.fromRGB(200, 80, 255), Transparency = 0,
    Callback = function(C) EspSettings.TracerColor = C end,
})
SecEspStyle:AddColorpicker("EspSkeletonColor", {
    Title = "Skeleton Color", Icon = "solar/palette-bold",
    Default = Color3.fromRGB(200, 80, 255), Transparency = 0,
    Callback = function(C) EspSettings.SkeletonColor = C end,
})

SecEspStyle:AddDivider()

local SecMisc = Tabs.Misc:AddSection("Player", "solar/running-bold")

SecMisc:AddToggle("InfiniteJumpToggle", {
    Title = "Infinite Jump", Icon = "solar/arrow-up-bold", Default = false,
    Callback = function(V)
        InfiniteJumpEnabled = V
        Notify("Infinite Jump", V and "Enabled" or "Disabled", V and "Success" or "Info", "solar/arrow-up-bold")
    end,
})
SecMisc:AddSlider("WalkSpeedSlider", {
    Title = "Walk Speed", Icon = "solar/running-bold",
    Min = 4, Max = 300, Default = 16, Rounding = 0,
    Callback = function(V)
        WalkSpeedValue = V
        local Chr = LocalPlayer.Character
        if not Chr then return end
        local Hum = Chr:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = V end
    end,
})
SecMisc:AddSlider("JumpPowerSlider", {
    Title = "Jump Power", Icon = "solar/arrow-up-bold",
    Min = 10, Max = 500, Default = 50, Rounding = 0,
    Callback = function(V)
        local Chr = LocalPlayer.Character
        if Chr then
            local Hum = Chr:FindFirstChildOfClass("Humanoid")
            if Hum then Hum.JumpPower = V end
        end
    end,
})

SecMisc:AddDivider()

local SecUtil = Tabs.Misc:AddSection("Utility", "solar/widget-bold")

SecUtil:AddButton({
    Title = "Reset Character", Icon = "solar/restart-bold",
    Callback = function()
        local Chr = LocalPlayer.Character
        if Chr then
            local Root = Chr:FindFirstChild("HumanoidRootPart")
            if Root then Root:Destroy() end
        end
    end,
})
SecUtil:AddButton({
    Title = "Copy Place ID", Icon = "solar/copy-bold",
    Callback = function()
        pcall(function() setclipboard(tostring(game.PlaceId)) end)
        Notify("Copied", "Place ID: " .. tostring(game.PlaceId), "Info", "solar/copy-bold")
    end,
})

SecUtil:AddDivider()

pcall(function() MediaManager:SetFolder("SolasmotaryXuniversal/Media") end)
pcall(function()
    InterfaceManager:SetLibrary(Fluent)
    InterfaceManager:SetFolder("SolasmotaryX")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    InterfaceManager:LoadSettings()
end)
pcall(function()
    SaveManager:SetLibrary(Fluent)
    SaveManager:SetFolder("SolasmotaryXuniversal/Config")
    SaveManager:IgnoreThemeSettings()
    SaveManager:BuildConfigSection(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()
end)
pcall(function()
    FloatingButtonManager:SetLibrary(Fluent)
    FloatingButtonManager:SetFolder("SolasmotaryXuniversal/Floating")
    FloatingButtonManager:BuildConfigSection(Tabs.Settings)
    FloatingButtonManager:LoadAutoloadConfig()
end)

local function CreateButton(ButtonName, Name, Size1, Size2, ScriptLogic, CircleMode)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = ButtonName
    screenGui.Parent = LocalPlayer.PlayerGui
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = -2147483648
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = false

    local frame = Instance.new("Frame")
    frame.Name = ButtonName
    frame.Size = UDim2.new(Size1, 0, Size2, 0)
    frame.Position = UDim2.new(0.5 - Size1 / 2, 0, 0.5 - Size2 / 2, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    frame.BackgroundTransparency = 0.7
    frame.ZIndex = -10
    frame.Parent = screenGui

    local gradient = Instance.new("UIGradient")
    pcall(function()
        if getgenv().ButtonGradients and getgenv().ButtonGradients.Background then
            gradient.Color = getgenv().ButtonGradients.Background
        end
    end)
    gradient.Parent = frame
    task.spawn(function()
        while task.wait(0.03) do
            if not frame.Parent then break end
            gradient.Rotation = (gradient.Rotation + 1) % 360
            pcall(function()
                if getgenv().ButtonGradients and getgenv().ButtonGradients.Background then
                    gradient.Color = getgenv().ButtonGradients.Background
                end
            end)
        end
    end)

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Parent = frame

    local gradientstroke = Instance.new("UIGradient")
    pcall(function()
        if getgenv().ButtonGradients and getgenv().ButtonGradients.Stroke then
            gradientstroke.Color = getgenv().ButtonGradients.Stroke
        end
    end)
    gradientstroke.Rotation = 0
    gradientstroke.Parent = stroke
    task.spawn(function()
        while frame.Parent do
            gradientstroke.Rotation = (gradientstroke.Rotation + 0.5) % 360
            pcall(function()
                if getgenv().ButtonGradients and getgenv().ButtonGradients.Stroke then
                    gradientstroke.Color = getgenv().ButtonGradients.Stroke
                end
            end)
            task.wait()
        end
    end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = Name
    button.Font = Enum.Font.SourceSansBold
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 18
    button.TextScaled = false
    button.ZIndex = -9
    button.Parent = frame

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 28, 0, 28)
    toggle.Position = UDim2.new(1, 6, 0.5, -14)
    toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toggle.Text = "○"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Visible = false
    toggle.ZIndex = -8
    toggle.Parent = frame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

    local originalSize = UDim2.new(Size1, 0, Size2, 0)
    local holding, holdStart, hideAt = false, 0, 0

    frame:SetAttribute("IsCircle", false)
    local isCircle = (CircleMode == true)

    local function ApplyShape(circle)
        frame:SetAttribute("IsCircle", circle)
        local s = math.min(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
        if circle then
            frame.Size = UDim2.new(0, s, 0, s)
            button.TextWrapped = true
            button.TextScaled = true
            corner.CornerRadius = UDim.new(1, 0)
            toggle.Text = "▢"
        else
            frame.Size = originalSize
            button.TextWrapped = false
            button.TextScaled = false
            button.TextSize = 18
            corner.CornerRadius = UDim.new(0, 15)
            toggle.Text = "○"
        end
    end
    ApplyShape(isCircle)

    task.spawn(function()
        while task.wait(0.25) do
            if not frame.Parent then break end
            if toggle.Visible and tick() - hideAt >= 10 then toggle.Visible = false end
        end
    end)

    button.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            holding = true; holdStart = tick()
        end
    end)
    button.InputEnded:Connect(function(i)
        if holding and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            holding = false
            if tick() - holdStart >= 0.6 then
                toggle.Visible = true; hideAt = tick()
            end
        end
    end)
    toggle.MouseButton1Click:Connect(function()
        hideAt = tick()
        ApplyShape(not frame:GetAttribute("IsCircle"))
    end)
    button.Activated:Connect(function()
        if ScriptLogic then ScriptLogic(button) end
    end)

    pcall(function()
        FloatingButtonManager:AddButton(ButtonName, frame, false)
    end)

    local function MakeDraggable(topbarobject, object, locked)
        local Dragging, DragInput, DragStart, StartPosition = false, nil, nil, nil
        local Holding, HoldToken = false, 0
        object:SetAttribute("Locked", locked or false)
        local function Update(input)
            if object:GetAttribute("Locked") then return end
            local delta = input.Position - DragStart
            object.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + delta.Y)
        end
        local function ToggleLock()
            local newState = not object:GetAttribute("Locked")
            object:SetAttribute("Locked", newState)
            Fluent:Notify({Title = newState and "Locked" or "Unlocked", Content = newState and "Button locked in place." or "Button can now be moved.", Duration = 2})
        end
        topbarobject.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            Dragging = not object:GetAttribute("Locked"); Holding = true
            DragStart = input.Position; StartPosition = object.Position
            HoldToken = HoldToken + 1; local token = HoldToken
            task.delay(1.0, function() if Holding and token == HoldToken then ToggleLock() end end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then Dragging = false; Holding = false end
            end)
        end)
        topbarobject.InputChanged:Connect(function(input)
            if not DragStart then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                if (input.Position - DragStart).Magnitude > 6 then Holding = false end
                DragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == DragInput and Dragging then Update(input) end
        end)
    end
    MakeDraggable(button, frame, false)

    return screenGui, frame, button
end

local AimGui, AimFrame, AimBtnRef = CreateButton(
    "AimbotFloating",
    "AIM: OFF",
    0.16,
    0.09,
    function(btn)
        AimbotEnabled = not AimbotEnabled
        btn.Text = "AIM: " .. (AimbotEnabled and "ON" or "OFF")
        btn.TextColor3 = AimbotEnabled and Color3.fromRGB(100, 255, 120) or Color3.fromRGB(255, 255, 255)
        if AimbotEnabled then StartAimbot() end
        Notify("Aimbot", AimbotEnabled and "ON via button" or "OFF via button", AimbotEnabled and "Success" or "Info", "solar/target-bold")
    end,
    false
)

FloatingAimbotGui = AimGui
FloatingAimbotBtn = AimBtnRef
AimGui.Enabled = false

local OpenUiGui = Instance.new("ScreenGui")
OpenUiGui.Name = "OpenUiHub"
OpenUiGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
OpenUiGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
OpenUiGui.ResetOnSpawn = false

local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "OpenButton"
OpenBtn.Parent = OpenUiGui
OpenBtn.BackgroundTransparency = 1
OpenBtn.Position = UDim2.new(0.05, 0, 0.08, 0)
OpenBtn.Size = UDim2.new(0, 64, 0, 42)
OpenBtn.Text = ""
Instance.new("UICorner", OpenBtn)

local BgImg = Instance.new("ImageLabel")
BgImg.Parent = OpenBtn
BgImg.Size = UDim2.new(1.8, 0, 1.8, 0)
BgImg.Position = UDim2.new(0.5, 0, 0.5, 0)
BgImg.AnchorPoint = Vector2.new(0.5, 0.5)
BgImg.BackgroundTransparency = 1
BgImg.Image = "rbxassetid://92062295706713"
BgImg.SizeConstraint = Enum.SizeConstraint.RelativeXX

local FrontImg = Instance.new("ImageLabel")
FrontImg.Parent = OpenBtn
FrontImg.Size = UDim2.fromOffset(55, 55)
FrontImg.Position = UDim2.new(0.5, 0, 0.5, 0)
FrontImg.AnchorPoint = Vector2.new(0.5, 0.5)
FrontImg.BackgroundTransparency = 1
FrontImg.Image = "rbxassetid://126113649238951"
FrontImg.ZIndex = 1
Instance.new("UICorner", FrontImg).CornerRadius = UDim.new(0.2, 0)

local BtnRotation = 0
local BtnRotSpeed = 90

task.spawn(function()
    local Last = tick()
    while OpenBtn and OpenBtn.Parent do
        local Now = tick()
        BtnRotation = (BtnRotation + BtnRotSpeed * (Now - Last)) % 360
        Last = Now
        BgImg.Rotation = BtnRotation
        task.wait()
    end
end)

local function MakeOpenUiDraggable(Topbar, Obj)
    local Dragging, DragInput, DragStart, StartPos = false, nil, nil, nil
    local Holding, HoldToken = false, 0
    Obj:SetAttribute("Locked", false)
    local function Update(Input)
        if Obj:GetAttribute("Locked") then return end
        local Delta = Input.Position - DragStart
        Obj.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
    end
    local function ToggleLock()
        local New = not Obj:GetAttribute("Locked")
        Obj:SetAttribute("Locked", New)
        Notify(New and "Locked" or "Unlocked", New and "OpenUI locked" or "OpenUI can be moved", "Info", nil, 2)
    end
    Topbar.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
        Dragging = not Obj:GetAttribute("Locked"); Holding = true; DragStart = Input.Position; StartPos = Obj.Position
        HoldToken = HoldToken + 1; local Token = HoldToken
        task.delay(1.0, function() if Holding and Token == HoldToken then ToggleLock() end end)
        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then Dragging = false; Holding = false end
        end)
    end)
    Topbar.InputChanged:Connect(function(Input)
        if not DragStart then return end
        if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
            if (Input.Position - DragStart).Magnitude > 6 then Holding = false end
            DragInput = Input
        end
    end)
    UserInputService.InputChanged:Connect(function(Input)
        if Input == DragInput and Dragging then Update(Input) end
    end)
end

MakeOpenUiDraggable(OpenBtn, OpenBtn)

local UiOpen = true

local function PlayClickSound(Id)
    local S = Instance.new("Sound")
    pcall(function() S.SoundId = "rbxassetid://" .. tostring(Id) end)
    S.Parent = game:GetService("SoundService")
    pcall(function() S:Play() end)
    S.Ended:Connect(function() S:Destroy() end)
end

OpenBtn.MouseButton1Click:Connect(function()
    PlayClickSound(math.random(2) == 1 and "7127123605" or "438666542")
    UiOpen = not UiOpen
    if UiOpen then Window:Show() else Window:Hide() end
    task.spawn(function()
        local function Smooth(Target, Dur)
            local Start = BtnRotSpeed; local Steps = 30
            for I = 1, Steps do BtnRotSpeed = Start + (Target - Start) * (I / Steps); task.wait(Dur / Steps) end
            BtnRotSpeed = Target
        end
        Smooth(360, 0.4); task.wait(0.5); Smooth(180, 0.4); task.wait(0.3); Smooth(90, 0.4)
    end)
end)

Notify("Onetap ReCoded", "Loaded — " .. LocalPlayer.Name, "Success", "solar/planet-bold", 4)
task.delay(0.5, function() Window:SelectTab(1) end)

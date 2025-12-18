--[[
    NoLag Script v1.3
    • Без подлагов
    • GUI не скрывается
    • Humanoid / NPC / Players игнор
]]

local qocNoLagModule = {}

-- ============================================
-- CONFIG
-- ============================================
local qocConfig = {
    HideWalls = true,
    HideEffects = true,
    HideUI = true
}

-- ============================================
-- VARS
-- ============================================
local qocIsRunning = false
local qocHiddenObjects = {}
local qocOriginalProperties = {}
local qocConnections = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local LocalCharacter = nil

-- ============================================
-- FILTERS
-- ============================================

local function isSky(obj)
    return obj:IsA("Sky") or obj:IsA("Atmosphere")
end

local function isLocalCharacter(obj)
    return LocalCharacter and obj:IsDescendantOf(LocalCharacter)
end

local function isHumanoidRelated(obj)
    local model = obj:FindFirstAncestorOfClass("Model")
    return (model and model:FindFirstChildOfClass("Humanoid"))
        or obj:IsA("Humanoid")
        or obj:IsA("Animator")
        or obj:IsA("Accessory")
        or obj:IsA("Tool")
end

local function isNoLagGui(obj)
    return obj:FindFirstAncestor("NoLagGui") ~= nil
end

-- ============================================
-- SAVE / RESTORE
-- ============================================

local function saveProps(obj)
    if qocOriginalProperties[obj] then return end
    local data = {}

    if obj:IsA("BasePart") then
        data.T = obj.Transparency
        data.C = obj.CanCollide
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        data.T = obj.Transparency
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam")
        or obj:IsA("Trail") or obj:IsA("Light")
        or obj:IsA("Fire") or obj:IsA("Smoke") then
        data.E = obj.Enabled
    end

    qocOriginalProperties[obj] = data
end

local function hide(obj)
    if not obj or qocHiddenObjects[obj] then return end
    if isSky(obj) or isLocalCharacter(obj) or isHumanoidRelated(obj) or isNoLagGui(obj) then
        return
    end

    saveProps(obj)

    if obj:IsA("BasePart") then
        obj.Transparency = 1
        obj.CanCollide = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = 1
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam")
        or obj:IsA("Trail") or obj:IsA("Light")
        or obj:IsA("Fire") or obj:IsA("Smoke") then
        obj.Enabled = false
    end

    qocHiddenObjects[obj] = true
end

local function restoreAll()
    for obj, props in pairs(qocOriginalProperties) do
        if obj:IsA("BasePart") then
            obj.Transparency = props.T or 0
            obj.CanCollide = props.C ~= false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = props.T or 0
        elseif props.E ~= nil then
            obj.Enabled = props.E
        end
    end
end

-- ============================================
-- PROCESS
-- ============================================

local function processWorldOnce()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        hide(obj)
    end
end

local function processUI()
    if not qocConfig.HideUI then return end
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return end

    for _, obj in ipairs(gui:GetDescendants()) do
        if obj:IsA("GuiObject") and not isNoLagGui(obj) then
            obj.Visible = false
        end
    end
end

-- ============================================
-- START / STOP
-- ============================================

function qocStartNoLagFunction()
    if qocIsRunning then return end
    qocIsRunning = true

    LocalCharacter = LocalPlayer.Character
    LocalPlayer.CharacterAdded:Connect(function(c)
        LocalCharacter = c
    end)

    processWorldOnce()
    processUI()

    table.insert(qocConnections,
        Workspace.DescendantAdded:Connect(function(obj)
            if qocIsRunning then
                task.defer(hide, obj)
            end
        end)
    )

    print("[NoLag] Запущен без лагов")
end

function qocStopNoLagFunction()
    if not qocIsRunning then return end
    qocIsRunning = false

    for _, c in ipairs(qocConnections) do
        c:Disconnect()
    end
    qocConnections = {}

    restoreAll()
    qocHiddenObjects = {}
    qocOriginalProperties = {}

    print("[NoLag] Остановлен, всё восстановлено")
end

_G.qocStartNoLagFunction = qocStartNoLagFunction
_G.qocStopNoLagFunction = qocStopNoLagFunction

-- ============================================
-- GUI
-- ============================================

local gui = Instance.new("ScreenGui")
gui.Name = "NoLagGui"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(96, 95)
frame.Position = UDim2.new(0.005, 0, 0.38, 0)
frame.BackgroundTransparency = 0.4
frame.BackgroundColor3 = Color3.fromRGB(255,255,255)
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,4)

local function button(txt, y, fn)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.fromOffset(84, 40)
    b.Position = UDim2.new(0.058, 0, y, 0)
    b.Text = txt
    b.Font = Enum.Font.FredokaOne
    b.TextScaled = true
    b.BackgroundColor3 = Color3.fromRGB(169,111,255)
    b.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
    b.MouseButton1Click:Connect(fn)
end

button("Start", 0.05, qocStartNoLagFunction)
button("Stop", 0.53, qocStopNoLagFunction)

print("[NoLag] GUI готов")

return qocNoLagModule

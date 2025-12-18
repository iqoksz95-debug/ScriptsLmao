--[[
    NoLag Script v1.0
    Автономный скрипт для оптимизации производительности
    Делает невидимыми все объекты кроме неба
]]

local qocNoLagModule = {}

-- Конфигурация
local qocConfig = {
    HidePlayers = true,
    HideWalls = true,
    HideEffects = true,
    HideUI = true,
    HideAnimations = true,
    CheckInterval = 2 -- Интервал проверки новых объектов (секунды)
}

-- Внутренние переменные
local qocIsRunning = false
local qocHiddenObjects = {}
local qocOriginalProperties = {}
local qocConnectionsList = {}
local qocCheckThread = nil

-- Локальные ссылки на сервисы (автономная инициализация)
local qocPlayer = nil
local qocCharacter = nil
local qocWorkspace = game:GetService("Workspace")
local qocPlayers = game:GetService("Players")
local qocRunService = game:GetService("RunService")

-- Попытка получить локального игрока
local function qocGetLocalPlayer()
    local success, result = pcall(function()
        return qocPlayers.LocalPlayer
    end)
    return success and result or nil
end

-- Сохранение оригинальных свойств объекта
local function qocSaveOriginalProperties(obj)
    if not qocOriginalProperties[obj] then
        qocOriginalProperties[obj] = {}
        
        pcall(function()
            if obj:IsA("BasePart") then
                qocOriginalProperties[obj].Transparency = obj.Transparency
                qocOriginalProperties[obj].CanCollide = obj.CanCollide
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                qocOriginalProperties[obj].Transparency = obj.Transparency
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
                qocOriginalProperties[obj].Enabled = obj.Enabled
            elseif obj:IsA("GuiObject") then
                qocOriginalProperties[obj].Visible = obj.Visible
            elseif obj:IsA("AnimationTrack") then
                qocOriginalProperties[obj].IsPlaying = obj.IsPlaying
            end
        end)
    end
end

-- Скрытие объекта
local function qocHideObject(obj)
    if not obj or qocHiddenObjects[obj] then return end
    
    qocSaveOriginalProperties(obj)
    
    local success = pcall(function()
        if obj:IsA("BasePart") then
            obj.Transparency = 1
            obj.CanCollide = false
            qocHiddenObjects[obj] = true
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
            qocHiddenObjects[obj] = true
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
            qocHiddenObjects[obj] = true
        elseif obj:IsA("GuiObject") then
            obj.Visible = false
            qocHiddenObjects[obj] = true
        elseif obj:IsA("Light") then
            obj.Enabled = false
            qocHiddenObjects[obj] = true
        end
    end)
end

-- Восстановление объекта
local function qocRestoreObject(obj)
    if not obj or not qocHiddenObjects[obj] then return end
    
    local props = qocOriginalProperties[obj]
    if not props then return end
    
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Transparency = props.Transparency or 0
            obj.CanCollide = props.CanCollide ~= false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = props.Transparency or 0
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = props.Enabled ~= false
        elseif obj:IsA("GuiObject") then
            obj.Visible = props.Visible ~= false
        elseif obj:IsA("Light") then
            obj.Enabled = props.Enabled ~= false
        end
    end)
    
    qocHiddenObjects[obj] = nil
end

-- Проверка является ли объект частью неба
local function qocIsSkyObject(obj)
    return obj:IsA("Sky") or obj:IsA("Atmosphere") or obj.Name == "Sky" or obj.Name == "Atmosphere"
end

-- Проверка является ли объект персонажем локального игрока
local function qocIsLocalPlayerCharacter(obj)
    if not qocCharacter then return false end
    return obj == qocCharacter or obj:IsDescendantOf(qocCharacter)
end

-- Обработка одного объекта
local function qocProcessObject(obj)
    if not obj or not qocIsRunning then return end
    if qocIsSkyObject(obj) or qocIsLocalPlayerCharacter(obj) then return end
    
    qocHideObject(obj)
end

-- Обработка игроков
local function qocProcessPlayers()
    if not qocConfig.HidePlayers then return end
    
    local playerCount = 0
    for _, player in pairs(qocPlayers:GetPlayers()) do
        if player ~= qocPlayer then
            playerCount = playerCount + 1
            local character = player.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    qocProcessObject(part)
                end
            end
        end
    end
    
    -- Если нет других игроков, отключаем обработку игроков
    return playerCount > 0
end

-- Обработка стен и объектов мира
local function qocProcessWorld()
    if not qocConfig.HideWalls then return end
    
    local objectCount = 0
    for _, obj in pairs(qocWorkspace:GetDescendants()) do
        if not qocIsSkyObject(obj) and not qocIsLocalPlayerCharacter(obj) then
            local isPlayerPart = false
            
            -- Проверяем, не является ли объект частью какого-либо игрока
            for _, player in pairs(qocPlayers:GetPlayers()) do
                if player.Character and obj:IsDescendantOf(player.Character) then
                    isPlayerPart = true
                    break
                end
            end
            
            if not isPlayerPart then
                qocProcessObject(obj)
                objectCount = objectCount + 1
            end
        end
    end
    
    return objectCount > 0
end

-- Обработка UI
local function qocProcessUI()
    if not qocConfig.HideUI then return end
    
    if not qocPlayer then return false end
    
    local uiCount = 0
    pcall(function()
        local playerGui = qocPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in pairs(playerGui:GetDescendants()) do
                if gui:IsA("GuiObject") then
                    qocProcessObject(gui)
                    uiCount = uiCount + 1
                end
            end
        end
    end)
    
    return uiCount > 0
end

-- Обработка эффектов
local function qocProcessEffects()
    if not qocConfig.HideEffects then return end
    
    local effectCount = 0
    for _, obj in pairs(qocWorkspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or 
           obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Light") then
            if not qocIsLocalPlayerCharacter(obj) then
                qocProcessObject(obj)
                effectCount = effectCount + 1
            end
        end
    end
    
    return effectCount > 0
end

-- Отслеживание новых объектов
local function qocSetupObjectTracking()
    -- Отслеживание новых игроков
    local playerAddedConnection = qocPlayers.PlayerAdded:Connect(function(player)
        if not qocIsRunning or player == qocPlayer then return end
        
        local function onCharacterAdded(character)
            if not qocIsRunning then return end
            wait(0.1)
            for _, part in pairs(character:GetDescendants()) do
                qocProcessObject(part)
            end
        end
        
        if player.Character then
            onCharacterAdded(player.Character)
        end
        player.CharacterAdded:Connect(onCharacterAdded)
    end)
    table.insert(qocConnectionsList, playerAddedConnection)
    
    -- Отслеживание новых объектов в Workspace
    local descendantAddedConnection = qocWorkspace.DescendantAdded:Connect(function(obj)
        if not qocIsRunning then return end
        wait(0.05)
        if not qocIsSkyObject(obj) and not qocIsLocalPlayerCharacter(obj) then
            qocProcessObject(obj)
        end
    end)
    table.insert(qocConnectionsList, descendantAddedConnection)
end

-- Функция запуска NoLag
function qocStartNoLagFunction()
    if qocIsRunning then
        warn("[NoLag] Скрипт уже запущен!")
        return
    end
    
    print("[NoLag] Запуск скрипта...")
    qocIsRunning = true
    
    -- Инициализация игрока
    qocPlayer = qocGetLocalPlayer()
    if qocPlayer then
        qocCharacter = qocPlayer.Character
        qocPlayer.CharacterAdded:Connect(function(char)
            qocCharacter = char
        end)
    end
    
    -- Первичная обработка всех объектов
    local hasPlayers = qocProcessPlayers()
    local hasWorld = qocProcessWorld()
    local hasEffects = qocProcessEffects()
    local hasUI = qocProcessUI()
    
    -- Настройка отслеживания новых объектов
    qocSetupObjectTracking()
    
    -- Периодическая проверка новых объектов
    qocCheckThread = task.spawn(function()
        while qocIsRunning do
            wait(qocConfig.CheckInterval)
            if qocIsRunning then
                qocProcessPlayers()
                qocProcessWorld()
                qocProcessEffects()
                qocProcessUI()
            end
        end
    end)
    
    print("[NoLag] Скрипт успешно запущен!")
    print("[NoLag] Игроки: " .. (hasPlayers and "Скрыты" or "Не найдены"))
    print("[NoLag] Объекты мира: " .. (hasWorld and "Скрыты" or "Не найдены"))
    print("[NoLag] Эффекты: " .. (hasEffects and "Скрыты" or "Не найдены"))
    print("[NoLag] UI: " .. (hasUI and "Скрыт" or "Не найден"))
end

-- Функция остановки NoLag
function qocStopNoLagFunction()
    if not qocIsRunning then
        warn("[NoLag] Скрипт не запущен!")
        return
    end
    
    print("[NoLag] Остановка скрипта...")
    qocIsRunning = false
    
    -- Остановка потока проверки
    if qocCheckThread then
        task.cancel(qocCheckThread)
        qocCheckThread = nil
    end
    
    -- Отключение всех соединений
    for _, connection in pairs(qocConnectionsList) do
        if connection then
            connection:Disconnect()
        end
    end
    qocConnectionsList = {}
    
    -- Восстановление всех скрытых объектов
    local restoredCount = 0
    for obj, _ in pairs(qocHiddenObjects) do
        qocRestoreObject(obj)
        restoredCount = restoredCount + 1
    end
    
    -- Очистка таблиц
    qocHiddenObjects = {}
    qocOriginalProperties = {}
    
    print("[NoLag] Скрипт остановлен! Восстановлено объектов: " .. restoredCount)
end

-- Экспорт функций
_G.qocStartNoLagFunction = qocStartNoLagFunction
_G.qocStopNoLagFunction = qocStopNoLagFunction

return qocNoLagModule




local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NoLagGui"
screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.Size = UDim2.new(0, 96, 0, 95)
mainWindow.Position = UDim2.new(0.005, 0, 0.38, 0)
mainWindow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainWindow.BackgroundTransparency = 0.5
mainWindow.Active = true
mainWindow.Draggable = true
mainWindow.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 4)
uiCorner.Parent = mainWindow

---

local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(0, 84, 0, 40)
stopButton.Position = UDim2.new(0.058, 0, 0.53, 0)
stopButton.BackgroundColor3 = Color3.fromRGB(169, 111, 255)
stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopButton.Text = "Stop"
stopButton.TextScaled = true
stopButton.Font = Enum.Font.FredokaOne
stopButton.TextSize = 14
stopButton.Parent = mainWindow

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = stopButton

closeButton.MouseButton1Click:Connect(function()
    qocStopNoLagFunction = false
end)

---

local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(0, 84, 0, 40)
startButton.Position = UDim2.new(0.058, 0, 0.05, 0)
startButton.BackgroundColor3 = Color3.fromRGB(169, 111, 255)
startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startButton.Text = "Start"
startButton.TextScaled = true
startButton.Font = Enum.Font.FredokaOne
startButton.TextSize = 14
startButton.Parent = mainWindow

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = startButton

startButton.MouseButton1Click:Connect(function()
    qocStartNoLagFunction = true
end)

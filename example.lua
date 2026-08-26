-- Bypasses Prometheus VM "newproxy" nil crashes on Delta/Solara
local gp = getgenv and getgenv() or _G
if not gp.newproxy then
    gp.newproxy = function(bool)
        return setmetatable({}, {__metatable = bool and false or nil})
    end
end

-- Clean up previous execution to prevent memory leaks and thread stacking
if getgenv().Ghost_Cleanup then
    pcall(getgenv().Ghost_Cleanup)
end

getgenv().Ghost_Connections = {}
getgenv().Ghost_Binds = {}
getgenv().GhostActive = true

getgenv().Ghost_Cleanup = function()
    getgenv().GhostActive = false
    
    -- Disconnect all active events to prevent lag
    for _, conn in ipairs(getgenv().Ghost_Connections or {}) do
        if conn then 
            pcall(function() conn:Disconnect() end) 
        end
    end
    getgenv().Ghost_Connections = {}
    
    -- Unbind all render steps
    for _, bindName in ipairs(getgenv().Ghost_Binds or {}) do
        pcall(function() 
            game:GetService("RunService"):UnbindFromRenderStep(bindName) 
        end)
    end
    getgenv().Ghost_Binds = {}
    
    -- Destroy old UI containers
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local gethui = gethui
        local container = gethui and gethui() or CoreGui
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "Ghost" or child.Name == "Ghost_MobileBindsGui" or child.Name:find("Wind") then
                child:Destroy()
            end
        end
    end)
end

-- Helper functions for managing execution state
local function addConnection(conn)
    table.insert(getgenv().Ghost_Connections, conn)
    return conn
end

local function addBind(name, priority, func)
    pcall(function() 
        game:GetService("RunService"):BindToRenderStep(name, priority, func) 
    end)
    table.insert(getgenv().Ghost_Binds, name)
end

local setclipboard = setclipboard or toclipboard or (Clipboard and Clipboard.set) or function(text)
    warn("setclipboard не поддерживается.")
    print(text)
end

-- Default configuration parameters
local currentLang = "en"
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local configFileName = "ghost_settings.json"

local Config = {
    Language = "en",
    Visuals = {
        MurdererESP = false, 
        SheriffESP = false, 
        InnocentESP = false, 
        StretchEnabled = false, 
        StretchFactor = 0.75, 
        NoFogEnabled = false, 
        TimeOfDay = 14,
        GunDropESP = false,
        NameTags = false,
    },
    Combat = {
        AutoShootMurderer = false, 
        AimlockEnabled = false, 
        SilentAimEnabled = false,
        AutoDodgeKnife = false, 
        KillAuraEnabled = false, 
        KillAuraRange = 25,
        ShootMBind = "None",
    },
    Utility = {
        AutoGrabGun = false, 
        NoclipEnabled = false, 
        AntiFling = false, 
        AutoFarmCoins = false,      
        EmoteSpamEnabled = false, 
        InvisEnabled = false
    },
}

local function saveConfig()
    if writefile then 
        pcall(function() 
            writefile(configFileName, HttpService:JSONEncode(Config)) 
        end) 
    end
end

local function loadConfig()
    if readfile and isfile and isfile(configFileName) then
        pcall(function()
            local loaded = HttpService:JSONDecode(readfile(configFileName))
            if loaded then
                if loaded.Language then Config.Language = loaded.Language end
                if loaded.Visuals then for k, v in pairs(loaded.Visuals) do Config.Visuals[k] = v end end
                if loaded.Combat then for k, v in pairs(loaded.Combat) do Config.Combat[k] = v end end
                if loaded.Utility then for k, v in pairs(loaded.Utility) do Config.Utility[k] = v end end
                currentLang = Config.Language
            end
        end)
    end
end
loadConfig()

-- Bilingual Translation Dictionary (Edgy and Aggressive Russian translation)
local L = {
    en = {
        CrashTitle = "🚨 Ghost — Crash Handler", CopyLog = "Copy Log", Copied = "Log Copied!", BufError = "Clipboard Error!", Close = "Close", Loaded = "Ghost loaded!", FailedUI = "Failed to load WindUI library.",
        Visuals = "Visuals", Combat = "Combat", Utility = "Utility", Radio = "Radio", Teleports = "Teleports", Configs = "Configs / Settings",
        EspM = "ESP Murderer", EspS = "ESP Sheriff", EspI = "ESP Innocents", Stretch = "Screen Stretch (4:3)", StretchForce = "Stretch Force",
        NoFog = "Disable Map Fog", TimeOfDay = "Time of Day",         EspG = "ESP Gun Drop", NameTags = "Name Tags", Invis = "Invisibility", BtnInvis = "Button: Invisibility",
        AutoShoot = "Auto-Shoot Murderer", Aimlock = "Aimlock on Murderer", KillAura = "Kill Aura", KillAuraRange = "Kill Aura Range", AutoKillAll = "Auto Kill All",
        FlingM = "Fling Murderer", FlingS = "Fling Sheriff", FlingH = "Fling Hero", AutoGrab = "Auto Grab Gun", Noclip = "Noclip (Walk Through Walls)", AntiFling = "Anti-Fling",

        RobloxId = "Roblox Audio ID", PlayId = "Play Roblox ID", HttpUrl = "HTTP Link to MP3 / OGG",
        PlayHttp = "Play HTTP Link", StopRadio = "Stop Radio", Volume = "Volume", Loop = "Loop Audio", NoKnife = "Knife not found!", NoGun = "Sheriff's gun not found!", NoM = "Murderer not found or dead",
        NoS = "Sheriff not found or dead", NoH = "Hero not found or dead", SitError = " is sitting (fling impossible)", Flinging = "Flinging: ", RadioNoSupport = "Your exploit does not support writefile/getcustomasset!",
        RadioDownloading = "Downloading audio file...", RadioHttpSuccess = "External audio started successfully!", RadioHttpError = "Failed to parse asset from file.", RadioHttpFail = "Failed to download audio file.",
        RadioCache = "Audio loaded from persistent local cache!", NoclipToggle = "Noclip", NoclipOn = "Enabled", NoclipOff = "Disabled", SpeedOn = "Enabled", SpeedOff = "Disabled",
        DodgeKnife = "Auto-Dodge Thrown Knife (Jump Right)", BtnDodgeKnife = "Button: Dodge Knife", TpLobby = "Teleport to Lobby", TpMap = "Teleport to Map", BtnTpLobby = "Button: TP Lobby",
        BtnTpMap = "Button: TP Map", NoMapLoaded = "Map not loaded yet or empty!", BtnAimlock = "Button: Aimlock", VisualsSkinChanger = "Visual Skins",
        SkinChangerTitle = "Visual Skin Changer", SkinChangerInput = "Roblox Username", SkinChangerBtn = "Apply Skin", SkinNotFound = "Player not found!", SkinSuccess = "Outfit changed visually!", SaveConfigBtn = "Save Config File", LoadConfigBtn = "Load Config File",
        ResetConfigBtn = "Reset to Defaults", SetLangRu = "Switch UI to Russian", SetLangEn = "Switch UI to English", ConfSaved = "Config saved to storage!", ConfLoaded = "Config loaded from storage!", ConfReset = "Config reset to factory defaults.",
        BtnShootM = "Button: Shoot", GodMode = "Dodge Knife", BtnGodMode = "Button: Dodge Knife",
        SilentAim = "Silent Aim (Shoot Without Turning Camera)", AutoFarmCoins = "Auto-Farm Coins (Safe Glide)", EmoteSpam = "Emote Glitch Spammer (Zen/Sit)", 
        MMBWarningTitle = "⚠️ Custom Server Detected", MMBWarningContent = "You are playing on an unofficial copy of MM2 (e.g. MMB). Some features like Skin Changer or Role tracking may be unstable."
    },
    ru = {
        CrashTitle = "🚨 Ghost — Пиздец Приехали (Краш)", CopyLog = "Скопировать этот лог", Copied = "Скопировано, бля!", BufError = "Буфер обосрался!", Close = "Закрыть залупу", Loaded = "Ghost загружен, нахуй!", FailedUI = "Не удалось стянуть WindUI.",
        Visuals = "Визуалы, сука", Combat = "Бойня, бля", Utility = "Всякая хуйня", Radio = "Радио", Teleports = "Телепорты", Configs = "Конфиги / Настройки",
        EspM = "ESP на пидораса с ножом", EspS = "ESP на лоха с пушкой", EspI = "ESP на мирное мясо",  Stretch = "Растяг экрана (4:3)", StretchForce = "Сила растяга",
        NoFog = "Снести туман к хуям", TimeOfDay = "Время суток",         EspG = "ESP на пестик под ногами", NameTags = "Неймтеги (цвет роли)", Invis = "Стать призраком (Невидимка)", BtnInvis = "Кнопка: Невидимка",
        AutoShoot = "Авто-выстрел в ебало мардера", Aimlock = "Аим на башку убийцы", KillAura = "Килаура (нагибать всех)", KillAuraRange = "Радиус бойни", AutoKillAll = "Геноцид всего сервера",
        FlingM = "Выбить мардера в космос", FlingS = "Выбить шерифа нахуй", FlingH = "Выбить героя", AutoGrab = "Пиздить пестик с земли", Noclip = "Проход сквозь стены", AntiFling = "Анти-Флинг",

        RobloxId = "ID Музла из Roblox", PlayId = "Играть музло по ID", HttpUrl = "Прямая ссылка на MP3/OGG",
        PlayHttp = "Врубить музыку по ссылке", StopRadio = "Заткнуть радио", Volume = "Громкость", Loop = "Зациклить", NoKnife = "Нож не найден, бля!", NoGun = "Пестика у шерифа нет!", NoM = "Убийца подох или не найден",
        NoS = "Шериф подох или не найден", NoH = "Герой подох или не найден", SitError = " сидит, хуй ты его выбьешь!", Flinging = "Ебашим: ", RadioNoSupport = "Твой эксплойт — говно без поддержки getcustomasset!",
        RadioDownloading = "Загрузка аудиофайла...", RadioHttpSuccess = "Музыка пошла, нахуй!", RadioHttpError = "Файл битый, блядь!", RadioHttpFail = "Сайт с музыкой лежит нахуй!",
        RadioCache = "Врубил из локального кэша!", NoclipToggle = "Noclip", NoclipOn = "Включен", NoclipOff = "Выключен", SpeedOn = "Включен", SpeedOff = "Выключен",
        DodgeKnife = "Мансить от ножа (Отпрыг вправо)", BtnDodgeKnife = "Кнопка: Уворот", TpLobby = "Телепорт в Лобби", TpMap = "Телепорт на Карту", BtnTpLobby = "Кнопка: ТП Лобби",
        BtnTpMap = "Кнопка: ТП Карта", NoMapLoaded = "Карты нет, один туман!", BtnAimlock = "Кнопка: Аимлок", VisualsSkinChanger = "Визуальные Скины",
        SkinChangerTitle = "Visual Skin Changer", SkinChangerInput = "Ник жертвы для копирования", SkinChangerBtn = "Применить скин", SkinNotFound = "Игрок не найден, бля!", SkinSuccess = "Скин применен!", SaveConfigBtn = "Запомнить эту конфигурацию", LoadConfigBtn = "Загрузить конфиг",
        ResetConfigBtn = "Сбросить всё к хуям", SetLangRu = "Сменить язык на Русский", SetLangEn = "Сменить язык на Английский", ConfSaved = "Конфиг сохранён!", ConfLoaded = "Конфиг загружен!", ConfReset = "Параметры сброшены до заводских.",
        BtnShootM = "Кнопка: Выстрел", GodMode = "Уворот от ножа", BtnGodMode = "Кнопка: Уворот",
        SilentAim = "Сайлент Аим (Шоты сквозь стены)", AutoFarmCoins = "Автофарм монет", EmoteSpam = "Спам Эмоций (Глитч хитбокса)", 
        MMBWarningTitle = "⚠️ Кастомная залупа вместо MM2", MMBWarningContent = "Ты играешь на неофициальной копии (типа MMB). Некоторые функции могут пойти по пизде."
    }
}

-- Вспомогательная функция перевода
local function T(key)
    return L[currentLang][key] or L["en"][key] or key
end

-- Безопасный выбор контейнера
local function getSafeUIContainer()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    if gethui then return gethui()
    elseif game:GetService("CoreGui") then return game:GetService("CoreGui")
    else return LocalPlayer:WaitForChild("PlayerGui", 10) end
end

-- ==================== 4. ОСНОВНОЙ КОД СКРИПТА ====================
local function main()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local Lighting = game:GetService("Lighting")
    local LocalPlayer = Players.LocalPlayer

    -- ГЛОБАЛЬНАЯ ТАБЛИЦА ЭЛЕМЕНТОВ UI (ТЕПЕРЬ СВЕРХУ - ВСЕ ФУНКЦИИ ВИДЯТ ЕЁ НАМЕРТВО)
    local UI_Elements = {
        Visuals = {},
        Combat = {},
        Utility = {},
    }

    -- Хелпер для сохранения и отслеживания подключений
    local function addConnection(conn)
        table.insert(getgenv().Ghost_Connections, conn)
        return conn
    end

    -- Хелпер для отслеживания рендер-биндов
    local function addBind(name, priority, func)
        pcall(function() game:GetService("RunService"):BindToRenderStep(name, priority, func) end)
        table.insert(getgenv().Ghost_Binds, name)
    end

    -- Вспомогательные функции для установки значений UI
    local function setToggle(element, value)
        if element and element.Set then
            pcall(function() element:Set(value) end)
        end
    end

    local function setSlider(element, value)
        if element and element.Set then
            pcall(function() element:Set(value) end)
        end
    end

    -- Полноценный, безопасный загрузчик WindUI
    local WindUI
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if success and result then
        WindUI = result
    else
        local fallbackSuccess, fallbackResult = pcall(function()
            return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
        end)
        if fallbackSuccess and fallbackResult then
            WindUI = fallbackResult
        end
    end
    
    if not WindUI then
        error(T("FailedUI"))
    end

    -- ==================== ИНИЦИАЛИЗАЦИЯ ОКНА И ВКЛАДОК WINDUI ====================
    local Window = WindUI:CreateWindow({
        Title = "Ghost",
        Icon = "shield",
        Author = "Shadow & Gemini",
        Folder = "Ghost",
        Size = UDim2.fromOffset(580, 460),
        Theme = "Dark",
        ToggleKey = Enum.KeyCode.RightControl
    })

    local VisualsTab = Window:Tab({ Title = T("Visuals"), Icon = "eye" })
    local CombatTab = Window:Tab({ Title = T("Combat"), Icon = "swords" })
    local UtilityTab = Window:Tab({ Title = T("Utility"), Icon = "tool" })
    local TeleportsTab = Window:Tab({ Title = T("Teleports"), Icon = "map-pin" })
    local ConfigsTab = Window:Tab({ Title = T("Configs"), Icon = "settings" })
    local RadioTab = Window:Tab({ Title = T("Radio"), Icon = "music" })

    local radioModel, radioSound, currentSongId, radioVolume, radioLooped = nil, nil, "", 2, false
    local httpSongUrl, grabbingGun, skinChangerNick = "", false, ""
    local ScreenButtons, BindsScreenGui, originalFog = {}, nil, Lighting.FogEnd 
    local roles, Murder, Sheriff, Hero = {}, nil, nil, nil
    local stretchConnection, antiFlingConnection = nil, nil

    -- Состояния невидимки
    local invisOn = false
    local invisConnection, rotationConnection
    local savedCFrame, originalCameraSubject, originalAutoRotate
    local invisOutline

    getgenv().OldPos = nil
    getgenv().FPDH = workspace.FallenPartsDestroyHeight

    -- Получение ScreenGui для mobile плавающих кнопок


    -- Кросс-платформенный HttpGet
    local function httpGet(url)
        local success, result
        if game and game.HttpGet then
            success, result = pcall(function() return game:HttpGet(url) end)
        elseif http and http.request then
            success, result = pcall(function()
                local res = http.request({Url = url, Method = "GET"})
                return res.Body
            end)
        elseif request then
            success, result = pcall(function()
                local res = request({Url = url, Method = "GET"})
                return res.Body
            end)
        end
        if success and result and #result > 0 then
            return result
        end
        return nil
    end

    -- Название файла кэша
    local function getFileNameFromUrl(url)
        local clean = url:gsub("[^%w]", "")
        if #clean > 25 then
            clean = clean:sub(#clean - 24)
        end
        return "ghost_radio_" .. clean .. ".mp3"
    end

    -- Функция создания подсветки (Highlight) с защитой от мерцания
    local function applyHighlight(player, color)
        local character = player.Character
        if not character then return end
        
        local highlight = character:FindFirstChild("Ghost_ESP") or character:FindFirstChild("Highlight")
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "Ghost_ESP"
            highlight.FillColor = color
            highlight.OutlineColor = color
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = character
        else
            if highlight.FillColor ~= color then
                highlight.FillColor = color
                highlight.OutlineColor = color
            end
            if highlight.FillTransparency ~= 0.5 then
                highlight.FillTransparency = 0.5
            end
            if highlight.DepthMode ~= Enum.HighlightDepthMode.AlwaysOnTop then
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            end
        end
    end

    -- Функция удаления подсветки
    local function removeHighlight(player)
        local character = player.Character
        if character then
            local highlight = character:FindFirstChild("Ghost_ESP") or character:FindFirstChild("Highlight")
            if highlight then highlight:Destroy() end
        end
    end

    -- Функция наложения неймтега (цвет по роли)
    local function applyNameTag(player, color, text)
        local character = player.Character
        if not character then return end
        local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        if not head then return end
        local tag = character:FindFirstChild("Ghost_NameTag")
        if not tag then
            tag = Instance.new("BillboardGui")
            tag.Name = "Ghost_NameTag"
            tag.Size = UDim2.new(0, 230, 0, 42)
            tag.StudsOffset = Vector3.new(0, 2.6, 0)
            tag.AlwaysOnTop = true
            tag.ClipsDescendants = false
            tag.Adornee = head
            tag.Parent = head
            local lbl = Instance.new("TextLabel")
            lbl.Name = "TagLabel"
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextScaled = true
            lbl.TextWrapped = true
            lbl.BorderSizePixel = 0
            lbl.Parent = tag
        end
        local lbl = tag:FindFirstChild("TagLabel")
        if lbl then
            lbl.Text = text
            lbl.TextColor3 = color
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.TextStrokeTransparency = 0
        end
    end

    local function removeNameTag(player)
        local character = player.Character
        if character then
            local tag = character:FindFirstChild("Ghost_NameTag")
            if tag then tag:Destroy() end
        end
    end


    -- Поиск модулей на кастомных серверах
    local function findSystemModule(name)
        local standardModules = ReplicatedStorage:FindFirstChild("Modules")
        if standardModules then
            local found = standardModules:FindFirstChild(name)
            if found then return found end
        end
        return ReplicatedStorage:FindFirstChild(name, true)
    end


    -- Стабильная проверка состояния "Жив" на стороне сервера MM2
    local function IsAlive(Player)
        local data = roles and roles[Player.Name]
        if data then
            return not data.Killed and not data.Dead
        end
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0
    end

    -- Безопасная телепортация
    local function safeTeleport(targetCFrame)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hrp and hum then
            local wasAnchored = hrp.Anchored
            
            hrp.Velocity = Vector3.new(0, 0, 0)
            hrp.RotVelocity = Vector3.new(0, 0, 0)
            
            hrp.Anchored = true
            hum.PlatformStand = true
            
            hrp.CFrame = targetCFrame
            char:PivotTo(targetCFrame)
            
            task.wait(0.15)
            
            hrp.Velocity = Vector3.new(0, 0, 0)
            hrp.RotVelocity = Vector3.new(0, 0, 0)
            
            hrp.Anchored = wasAnchored
            hum.PlatformStand = false
        end
    end

    -- Вспомогательные функции для поиска Мардера и Шерифа (Мгновенно по Кэшу сервера)
    local function getMurderer()
        if Murder then
            return Players:FindFirstChild(Murder)
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local backpack = p:FindFirstChild("Backpack")
                if (backpack and backpack:FindFirstChild("Knife")) or p.Character:FindFirstChild("Knife") then
                    return p
                end
            end
        end
        return nil
    end

    local function getSheriff()
        if Sheriff then
            return Players:FindFirstChild(Sheriff)
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local backpack = p:FindFirstChild("Backpack")
                local hasGun = (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver"))) or p.Character:FindFirstChild("Gun") or p.Character:FindFirstChild("Revolver")
                if hasGun then
                    return p
                end
            end
        end
        return nil
    end

    -- Динамический поиск живого Героя на карте
    local function getHero()
        if Hero then
            local p = Players:FindFirstChild(Hero)
            if p and IsAlive(p) then return p end
        end
        local m = getMurderer()
        local s = getSheriff()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and IsAlive(p) and p ~= m and p ~= s then
                local bp = p:FindFirstChild("Backpack")
                if (p.Character:FindFirstChild("Gun") or p.Character:FindFirstChild("Revolver")) or (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver"))) then
                    return p
                end
            end
        end
        return nil
    end

    -- Полноценная реализация ультра-агрессивного физического флинга (Kilasik's Multi-Target Fling)
    local function flingPlayer(targetPlayer)
        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Humanoid and Humanoid.RootPart or (Character and Character:FindFirstChild("HumanoidRootPart"))
        
        local TCharacter = targetPlayer.Character
        if not TCharacter then return end
        
        local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart or TCharacter:FindFirstChild("HumanoidRootPart")
        local THead = TCharacter:FindFirstChild("Head")
        local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
        local Handle = Accessory and Accessory:FindFirstChild("Handle")
        
        if Character and Humanoid and RootPart then
            if RootPart.Velocity.Magnitude < 50 then
                getgenv().OldPos = RootPart.CFrame
            end
            
            if THumanoid and THumanoid.Sit then
                WindUI:Notify({ Title = "Ghost", Content = targetPlayer.Name .. T("SitError"), Icon = "x", Duration = 3 })
                return
            end
            
            WindUI:Notify({ Title = "Ghost", Content = T("Flinging") .. targetPlayer.DisplayName, Icon = "swords", Duration = 3 })
            
            if THead then
                workspace.CurrentCamera.CameraSubject = THead
            elseif Handle then
                workspace.CurrentCamera.CameraSubject = Handle
            elseif THumanoid and TRootPart then
                workspace.CurrentCamera.CameraSubject = THumanoid
            end
            
            if not TCharacter:FindFirstChildWhichIsA("BasePart") then
                return
            end
            
            local FPos = function(BasePart, Pos, Ang)
                RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
                Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
                RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
            end
            
            local SFBasePart = function(BasePart)
                local TimeToWait = 2 local Time = tick() local Angle = 0
                repeat
                    if RootPart and THumanoid then
                        if BasePart.Velocity.Magnitude < 50 then
                            Angle = Angle + 100
                            FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0 ,0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                            task.wait()
                        else
                            FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                            task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                            task.wait()
                        end
                    end
                until Time + TimeToWait < tick()
            end
            
            workspace.FallenPartsDestroyHeight = 0/0
            local BV = Instance.new("BodyVelocity")
            BV.Parent = RootPart BV.Velocity = Vector3.new() BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
            if TRootPart then SFBasePart(TRootPart) elseif THead then SFBasePart(THead) elseif Handle then SFBasePart(Handle) end
            BV:Destroy() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            workspace.CurrentCamera.CameraSubject = Humanoid
            
            if getgenv().OldPos then
                repeat
                    RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                    Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
                    Humanoid:ChangeState("GettingUp")
                    for _, part in pairs(Character:GetChildren()) do
                        if part:IsA("BasePart") then part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new() end
                    end
                    task.wait()
                until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
                workspace.FallenPartsDestroyHeight = getgenv().FPDH
            end
        else
            WindUI:Notify({ Title = "Error", Content = "Your character is not ready", Icon = "x", Duration = 3 })
        end
    end


    -- Управление Noclip (Проход сквозь стены)
    local function toggleNoclip(state)
        if state == nil then state = not Config.Utility.NoclipEnabled end
        Config.Utility.NoclipEnabled = state
        if UI_Elements.Utility.NoclipEnabled then setToggle(UI_Elements.Utility.NoclipEnabled, state) end
        saveConfig()
    end

    -- Прикрепление радио на спину
    local function attachRadio()
        if radioModel then radioModel:Destroy() end
        local char = LocalPlayer.Character
        local torso = char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
        if not torso then return end
        
        radioModel = Instance.new("Part")
        radioModel.Name = "ClientRadio" radioModel.Size = Vector3.new(2, 1, 1) radioModel.CanCollide = false
        radioModel.BrickColor = BrickColor.new("Bright yellow") radioModel.Material = Enum.Material.Metal
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshId = "rbxassetid://212641536" mesh.TextureId = "rbxassetid://212641944"
        mesh.Scale = Vector3.new(1.2, 1.2, 1.2) mesh.Parent = radioModel
        local weld = Instance.new("Weld")
        weld.Part0 = torso weld.Part1 = radioModel weld.C0 = CFrame.new(0, 0, 0.75) * CFrame.Angles(0, math.rad(180), 0)
        weld.Parent = radioModel radioModel.Parent = char
    end

    -- Симуляция физического клика (клик мыши) на ПК / Тач на мобильном
    local function simulatePhysicalClick()
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    end

    -- Воспроизведение музыки по ID
    local function playRadio()
        if currentSongId == "" then return end
        attachRadio()
        if not radioModel then return end
        
        local sound = radioModel:FindFirstChild("RadioSound") or Instance.new("Sound", radioModel)
        sound.Name = "RadioSound" sound:Stop() sound.SoundId = "rbxassetid://" .. currentSongId
        sound.Volume = radioVolume sound.Looped = radioLooped sound:Play() radioSound = sound
    end

    -- Воспроизведение через внешнюю ссылку (HTTP) с ФИЗИЧЕСКИМ КЭШИРОВАНИЕМ
    local function playHttpRadio()
        if httpSongUrl == "" then return end
        if not writefile or not getcustomasset then
            WindUI:Notify({ Title = T("Radio"), Content = T("RadioNoSupport"), Icon = "x", Duration = 3 })
            return
        end
        
        local cachedFileName = getFileNameFromUrl(httpSongUrl)
        
        if isfile and isfile(cachedFileName) then
            local localAsset = nil
            pcall(function() localAsset = getcustomasset(cachedFileName) end)
            
            if localAsset then
                attachRadio()
                if not radioModel then return end
                local sound = radioModel:FindFirstChild("RadioSound") or Instance.new("Sound", radioModel)
                sound.Name, sound.SoundId, sound.Volume, sound.Looped = "RadioSound", localAsset, radioVolume, radioLooped
                sound:Stop() sound:Play() radioSound = sound
                WindUI:Notify({ Title = T("Radio"), Content = T("RadioCache"), Icon = "check", Duration = 3 })
                return
            end
        end
        
        WindUI:Notify({ Title = T("Radio"), Content = T("RadioDownloading"), Icon = "music", Duration = 3 })
        
        task.spawn(function()
            local data = httpGet(httpSongUrl)
            if data and #data > 0 then
                local writeSuccess = pcall(function() writefile(cachedFileName, data) end)
                local getSuccess, assetId = pcall(function() return getcustomasset(cachedFileName) end)
                if writeSuccess and getSuccess and assetId then
                    attachRadio()
                    if not radioModel then return end
                    local sound = radioModel:FindFirstChild("RadioSound") or Instance.new("Sound", radioModel)
                    sound.Name, sound.SoundId, sound.Volume, sound.Looped = "RadioSound", assetId, radioVolume, radioLooped
                    sound:Stop() sound:Play() radioSound = sound
                    WindUI:Notify({ Title = T("Radio"), Content = T("RadioHttpSuccess"), Icon = "check", Duration = 3 })
                else
                    WindUI:Notify({ Title = T("Radio"), Content = T("RadioHttpError"), Icon = "x", Duration = 3 })
                end
            else
                WindUI:Notify({ Title = T("Radio"), Content = T("RadioHttpFail"), Icon = "x", Duration = 3 })
            end
        end)
    end

    local function stopRadio()
        if radioSound then radioSound:Stop() end
        if radioModel then radioModel:Destroy() radioModel = nil end
    end

    -- Ультра-простой автоподбор пистолета (БЕЗ КОСТЫЛЕЙ, ТОЛЬКО ТЕПОРТ И ПАКЕТ)
    local function grabGun()
        if grabbingGun then return end
        if not IsAlive(LocalPlayer) then return end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hrp then return end
        
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local isMurderer = (char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) or (Murder and LocalPlayer.Name == Murder)
        if isMurderer then return end
        
        local function hasGun()
            local currentBp = LocalPlayer:FindFirstChild("Backpack")
            return (char:FindFirstChild("Gun") or char:FindFirstChild("Revolver")) or (currentBp and (currentBp:FindFirstChild("Gun") or currentBp:FindFirstChild("Revolver")))
        end
        if hasGun() then return end
        
        local gunDrop = workspace:FindFirstChild("GunDrop", true) or workspace:FindFirstChild("DroppedGun", true)
        local handle = gunDrop and (gunDrop:FindFirstChild("Handle", true) or gunDrop:FindFirstChildOfClass("Part", true) or gunDrop)
        if not handle then return end
        
        grabbingGun = true
        
        local originalCFrame = hrp.CFrame
        local targetCFrame = handle:IsA("Model") and handle:GetPivot() or handle.CFrame
        
        -- Просто телепортируемся на ствол
        hrp.CFrame = targetCFrame * CFrame.new(0, -1, 0)
        
        -- Костыль сетевого тача: чтобы пестик моментально прыгнул в руки при телепорте
        if firetouchinterest then
            pcall(function()
                firetouchinterest(hrp, handle, 0)
                task.wait(0.02)
                firetouchinterest(hrp, handle, 1)
            end)
        end
        
        task.wait(0.15) -- Даем долю секунды на подбор
        
        -- И моментально возвращаемся обратно
        if IsAlive(LocalPlayer) then
            hrp.CFrame = originalCFrame
        end
        
        grabbingGun = false
    end

    -- Стабильная телепортация в Лобби
    local function tpToLobby()
        local lobby = workspace:FindFirstChild("Lobby")
        local spawnLocation = lobby and (lobby:FindFirstChild("Spawn", true) or lobby:FindFirstChildOfClass("SpawnLocation", true) or lobby:FindFirstChild("Spawns", true))
        
        local targetCFrame
        if spawnLocation then
            targetCFrame = spawnLocation:IsA("Model") and spawnLocation:GetPivot() or spawnLocation.CFrame
            targetCFrame = targetCFrame * CFrame.new(0, 3, 0)
        else
            -- Точные координаты лобби
            targetCFrame = CFrame.new(6.0, 505.2, -35.0)
        end
        safeTeleport(targetCFrame)
    end

    -- Умный анализ геометрии активной карты и безопасное приземление
    local function tpToMap()
        local center = Vector3.new(12.0, 291.7, 9040.0) -- Координаты центра всех карт MM2
        local normal = workspace:FindFirstChild("Normal")
        local bestPart = nil
        local minDistance = math.huge
        
        -- Проверка на предмет того, играем ли мы за Убийцу
        local weAreMurderer = false
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then
            weAreMurderer = true
        end
        
        -- Поиск твердой плоской поверхности внутри карты в радиусе 120 studs от центра
        if normal then
            for _, obj in ipairs(normal:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" and obj.CanCollide then
                    local dist = (obj.Position - center).Magnitude
                    if dist < minDistance and dist < 120 then
                        minDistance = dist
                        bestPart = obj
                    end
                end
            end
        end
        
        if bestPart then
            -- Безопасно телепортируемся прямо на найденную поверхность пола/спавна
            safeTeleport(CFrame.new(bestPart.Position + Vector3.new(0, 3.5, 0)))
        else
            -- Умный обход 2: если спавны карты скрыты, переносимся к живому игроку вне лобби (только если мы НЕ Убийца!)
            local tpSuccess = false
            if not weAreMurderer then
                for _, p in ipairs(Players:GetPlayers()) do
                    -- Блокируем ТП к Мардеру во избежание мгновенной смерти
                    if p ~= LocalPlayer and p.Name ~= Murder and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            -- Проверяем по новым координатам лобби
                            local distToLobby = (p.Character.HumanoidRootPart.Position - Vector3.new(6.0, 505.2, -35.0)).Magnitude
                            if distToLobby > 150 then -- Далеко от лобби
                                safeTeleport(p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0))
                                tpSuccess = true
                                break
                            end
                        end
                    end
                end
            end
            
            -- Если карта полностью пуста (или мы убийца), переносим в воздух над точными координатами центра
            if not tpSuccess then
                safeTeleport(CFrame.new(center + Vector3.new(0, 3.5, 0)))
            end
        end
    end

    -- Сетевой выстрел без задержек (УЛЬТРА-СКОРОСТНАЯ ЭКСПОРТ-ФУНКЦИЯ С ДОНОРА)
    local function fireGun(gun, targetPosition)
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if gun.Parent == bp then 
            char.Humanoid:EquipTool(gun) 
            task.wait(0.05) -- Микро-ожидание экипировки для предотвращения отмены вызова
        end
        
        local originCF
        local gunServer = gun:FindFirstChild("GunServer")
        if gunServer then
            local attachment = gunServer:FindFirstChild("GunRaycastAttachment1") or gunServer:FindFirstChild("RaycastAttachment")
            if attachment then
                originCF = attachment.WorldCFrame
            end
        end
        
        if not originCF then
            local handle = gun:FindFirstChild("Handle") or gun:FindFirstChild("Gun")
            if handle and handle:IsA("BasePart") then
                originCF = handle.CFrame
            end
        end
        
        if not originCF then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then originCF = hrp.CFrame end
        end
        
        if not originCF then return end
        
        local shootRemote = gun:FindFirstChild("KnifeServer") and gun.KnifeServer:FindFirstChild("SlashStart")
        if shootRemote then
            shootRemote:FireServer(1, targetPosition)
        else
            -- Фоллбэк под классические сервера
            pcall(function()
                if ReplicatedStorage:FindFirstChild("ShootGun") then
                    ReplicatedStorage.ShootGun:InvokeServer(1, targetPosition, targetPosition)
                else
                    simulatePhysicalClick()
                end
            end)
        end
    end

    -- Очистка твоего старого визуального шмота
    local function clearVisuals(char)
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Accessory") or inst:IsA("Hat") or inst:IsA("Shirt") 
            or inst:IsA("Pants") or inst:IsA("ShirtGraphic") or inst:IsA("CharacterMesh") then
                inst:Destroy()
            end
        end
        local head = char:FindFirstChild("Head")
        if head then
            for _, d in ipairs(head:GetChildren()) do
                if d:IsA("Decal") and d.Name:lower() == "face" then d:Destroy() end
            end
        end
        local bc = char:FindFirstChildOfClass("BodyColors")
        if bc then bc:Destroy() end
    end

    -- Приварка аксессуаров через WeldConstraint (чтобы не отваливались при ходьбе)
    local function attachAccessory(char, accessory)
        local handle = accessory:FindFirstChild("Handle")
        if not handle then return end

        local targetAttachment, accAttachment

        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                for _, att in ipairs(part:GetChildren()) do
                    if att:IsA("Attachment") then
                        local match = handle:FindFirstChild(att.Name)
                        if match and match:IsA("Attachment") then
                            targetAttachment = att
                            accAttachment = match
                            break
                        end
                    end
                end
            end
            if targetAttachment then break end
        end

        if targetAttachment and accAttachment then
            handle.CFrame = targetAttachment.WorldCFrame * accAttachment.CFrame:Inverse()
        else
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                handle.CFrame = root.CFrame
            end
        end

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = handle
        weld.Part1 = (targetAttachment and targetAttachment.Parent) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        weld.Parent = handle

        accessory.Parent = char
    end

    -- Функция поиска UserId по никнейму
    local function getUserIdFromUsername(username)
        local ok, userId = pcall(function()
            return Players:GetUserIdFromNameAsync(username)
        end)
        if ok and userId then
            return userId
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(username:lower()) or p.DisplayName:lower():find(username:lower()) then
                return p.UserId
            end
        end
        return nil
    end

    -- Стабильный скинченджер без затупов и патчей (ИНТЕГРИРОВАННАЯ ФИЗИЧЕСКАЯ ВАРКА)
    local function changeVisualSkin(username)
        task.spawn(function()
            if not username or username == "" then
                WindUI:Notify({ Title = T("Visuals"), Content = T("SkinChangerInput"), Icon = "x", Duration = 3 })
                return
            end
            
            local uid = getUserIdFromUsername(username)
            if not uid then
                WindUI:Notify({ Title = T("Visuals"), Content = T("SkinNotFound"), Icon = "x", Duration = 3 })
                return
            end

            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local ok, model = pcall(function()
                return Players:GetCharacterAppearanceAsync(uid)
            end)
            if not ok or not model then 
                WindUI:Notify({ Title = T("Visuals"), Content = T("SkinNotFound"), Icon = "x", Duration = 3 })
                return 
            end

            clearVisuals(char)

            local bc = model:FindFirstChildOfClass("BodyColors")
            if bc then bc:Clone().Parent = char end

            for _, item in ipairs(model:GetChildren()) do
                if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                    item:Clone().Parent = char
                end
            end

            for _, acc in ipairs(model:GetChildren()) do
                if acc:IsA("Accessory") or acc:IsA("Hat") then
                    attachAccessory(char, acc:Clone())
                end
            end

            local head = char:FindFirstChild("Head")
            if head then
                local face = model:FindFirstChild("face", true)
                if face and face:IsA("Decal") then
                    face:Clone().Parent = head
                end
            end
            
            WindUI:Notify({ Title = T("Visuals"), Content = T("SkinSuccess"), Icon = "check", Duration = 3 })
        end)
    end

    -- Авто-килл всех (для убийцы)
    local function autoKillAll()
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local knife = char and char:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife"))
        
        if not knife then
            WindUI:Notify({ Title = "Error", Content = T("NoKnife"), Icon = "x", Duration = 3 })
            return
        end
        
        local isMurderer = (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) or (Murder and LocalPlayer.Name == Murder)
        if not isMurderer then
            WindUI:Notify({ Title = "Error", Content = "You must be the Murderer to use Auto Kill All!", Icon = "x", Duration = 3 })
            return
        end
        
        if char and char:FindFirstChild("HumanoidRootPart") then
            if knife.Parent == bp then char.Humanoid:EquipTool(knife) end
            
            local originalPos = char.HumanoidRootPart.CFrame
            local wasAnchored = char.HumanoidRootPart.Anchored
            
            for _, victim in ipairs(Players:GetPlayers()) do
                if victim ~= LocalPlayer and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
                    local vHum = victim.Character:FindFirstChildOfClass("Humanoid")
                    if vHum and vHum.Health > 0 and IsAlive(victim) then
                        char.HumanoidRootPart.Anchored = true
                        safeTeleport(victim.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.5))
                        task.wait(0.15)
                        
                        knife:Activate()
                        local blade = knife:FindFirstChild("Handle") or knife:FindFirstChild("Blade") or knife:FindFirstChildWhichIsA("BasePart")
                        local targetPart = victim.Character:FindFirstChild("HumanoidRootPart") or victim.Character:FindFirstChild("Torso") or victim.Character:FindFirstChild("UpperTorso")
                        if targetPart and blade then
                            pcall(function()
                                firetouchinterest(blade, targetPart, 0)
                                task.wait(0.05)
                                firetouchinterest(blade, targetPart, 1)
                            end)
                        end
                        task.wait(0.1)
                    end
                end
            end
            char.HumanoidRootPart.Anchored = wasAnchored
            safeTeleport(originalPos)
        end
    end

    -- Прямой моментальный выстрел в убийцу на месте (БЕЗ ЗАДЕРЖЕК, ПАКЕТЫ НАПРЯМУЮ)
    local function shootMurdererDirect()
        local m = getMurderer()
        if not m or not m.Character or not m.Character:FindFirstChild("HumanoidRootPart") then
            WindUI:Notify({ Title = "Error", Content = T("NoM"), Icon = "x", Duration = 3 })
            return
        end
        
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local gun = char and (char:FindFirstChild("Gun") or char:FindFirstChild("Revolver")) or (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")))
        
        if not gun then
            WindUI:Notify({ Title = "Error", Content = T("NoGun"), Icon = "x", Duration = 3 })
            return
        end
        
        if char and char:FindFirstChild("HumanoidRootPart") then
            if gun.Parent == bp then char.Humanoid:EquipTool(gun) end
            task.wait(0.05)
            fireGun(gun, m.Character.HumanoidRootPart.Position)
        end
    end

    -- Сидячая невидимость (Glitch-based FE Invisibility)
    local function toggleInvis(state)
        if state == nil then
            state = not Config.Utility.InvisEnabled
        end
        Config.Utility.InvisEnabled = state
        if UI_Elements.Utility.InvisEnabled then
            setToggle(UI_Elements.Utility.InvisEnabled, state)
        end
        saveConfig()

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if state then
            if not char or not hum or not hrp then return end
            invisOn = true
            savedCFrame = hrp.CFrame
            originalCameraSubject = workspace.CurrentCamera.CameraSubject
            originalAutoRotate = hum.AutoRotate

            local function isTool(part)
                local parent = part.Parent
                while parent and parent ~= char do
                    if parent:IsA("Tool") then return true end
                    parent = parent.Parent
                end
                return false
            end

            -- Локальная прозрачность для игрока
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and not isTool(part) then
                    part.LocalTransparencyModifier = 1
                end
            end

            invisConnection = addConnection(char.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("BasePart") and not isTool(descendant) then
                    descendant.LocalTransparencyModifier = 1
                end
            end))

            if invisOutline then invisOutline:Destroy() end
            invisOutline = Instance.new("Highlight")
            invisOutline.FillTransparency = 1
            invisOutline.OutlineColor = Color3.new(1, 1, 1)
            invisOutline.Parent = char

            -- Смещаем за рамки карты
            char:PivotTo(CFrame.new(-25.95, 84, 3537.55))
            task.wait(0.15)

            local seat = Instance.new("Seat")
            seat.Name = "Ghost_InvisChair"
            seat.Anchored = false
            seat.CanCollide = false
            seat.Transparency = 1
            seat.Position = Vector3.new(-25.95, 84, 3537.55)
            seat.Parent = workspace

            workspace.CurrentCamera.CameraSubject = hrp

            local weld = Instance.new("Weld")
            weld.Part0 = seat
            weld.Part1 = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            weld.Parent = seat

            task.wait()
            seat.CFrame = savedCFrame

            -- Поворот сиденья за камерой
            if rotationConnection then rotationConnection:Disconnect() end
            rotationConnection = addConnection(RunService.RenderStepped:Connect(function()
                if not invisOn or not seat or not seat.Parent then return end
                if not hum then return end

                if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                    hum.AutoRotate = false
                    local cam = workspace.CurrentCamera
                    local look = cam.CFrame.LookVector
                    look = Vector3.new(look.X, 0, look.Z).Unit
                    if look.Magnitude > 0 then
                        seat.CFrame = CFrame.new(seat.Position, seat.Position + look)
                    end
                else
                    hum.AutoRotate = true
                end
            end))
        else
            invisOn = false
            if invisConnection then invisConnection:Disconnect() invisConnection = nil end
            if rotationConnection then rotationConnection:Disconnect() rotationConnection = nil end

            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
                if hum then
                    hum.AutoRotate = originalAutoRotate ~= nil and originalAutoRotate or true
                end
                if originalCameraSubject then
                    workspace.CurrentCamera.CameraSubject = originalCameraSubject
                end
            end

            if invisOutline then invisOutline:Destroy() invisOutline = nil end
            local seat = workspace:FindFirstChild("Ghost_InvisChair")
            if seat then seat:Destroy() end

            savedCFrame = nil
            originalCameraSubject = nil
            originalAutoRotate = nil
        end
    end

    -- ==================== АКТИВАЦИОННЫЕ ХЭЛПЕРЫ ДЛЯ КОНФИГА ====================
    
    local function applyStretch(state)
        Config.Visuals.StretchEnabled = state
        if not state then
            if stretchConnection then 
                pcall(function() stretchConnection:Disconnect() end)
                stretchConnection = nil 
            end
            pcall(function()
                workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame
            end)
            return
        end
        if not stretchConnection then
            stretchConnection = addConnection(RunService.RenderStepped:Connect(function()
                local camera = workspace.CurrentCamera
                if camera then 
                    camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, Config.Visuals.StretchFactor, 0, 0, 0, 1) 
                end
            end))
        end
    end

    local function applyNoFog(state)
        Config.Visuals.NoFogEnabled = state
        Lighting.FogEnd = state and 9e9 or originalFog
    end

    local function applyTimeOfDay(v)
        Config.Visuals.TimeOfDay = v
        Lighting.TimeOfDay = string.format("%02d:00:00", v)
    end

    local function applyAntiFling(state)
        Config.Utility.AntiFling = state
        if not state then
            if antiFlingConnection then 
                pcall(function() antiFlingConnection:Disconnect() end)
                antiFlingConnection = nil 
            end
            return
        end
        if not antiFlingConnection then
            antiFlingConnection = addConnection(RunService.Stepped:Connect(function()
                if not Config.Utility.AntiFling then return end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        for _, part in ipairs(p.Character:GetChildren()) do
                            if part:IsA("BasePart") then 
                                part.CanCollide = false 
                            elseif part:IsA("Accessory") then
                                local handle = part:FindFirstChild("Handle")
                                if handle and handle:IsA("BasePart") then
                                    handle.CanCollide = false
                                end
                            end
                        end
                    end
                end
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if hrp.Velocity.Magnitude > 100 then 
                        hrp.Velocity = Vector3.new(0, 0, 0)
                        hrp.RotVelocity = Vector3.new(0, 0, 0)
                    end
                    pcall(function()
                        if hrp.AssemblyLinearVelocity.Magnitude > 100 then
                            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
            end))
        end
    end

    -- ==================== ИСПРАВЛЕННЫЕ ПЛАВАЮЩИЕ КНОПКИ ====================


    -- ==================== СИСТЕМНАЯ СВЯЗЬ ДЛЯ ПЕРЕКЛЮЧЕНИЯ UI ИЗ КОНФИГА ====================
    local UI_Elements = {
        Visuals = {},
        Combat = {},
        Utility = {},
    }

    -- Таблица динамической настройки мобильных кнопок (ВЫРЕЗАН ТП ШОТ, ВЕРНУТ ШУТ)

    -- Функция применения конфига ко всем графическим элементам меню
    local function applyConfigToUI()
        -- 1. Визуалы
        setToggle(UI_Elements.Visuals.MurdererESP, Config.Visuals.MurdererESP)
        setToggle(UI_Elements.Visuals.SheriffESP, Config.Visuals.SheriffESP)
        setToggle(UI_Elements.Visuals.InnocentESP, Config.Visuals.InnocentESP)
        setToggle(UI_Elements.Visuals.StretchEnabled, Config.Visuals.StretchEnabled)
        setSlider(UI_Elements.Visuals.StretchFactor, Config.Visuals.StretchFactor)
        setToggle(UI_Elements.Visuals.NoFogEnabled, Config.Visuals.NoFogEnabled)
        setToggle(UI_Elements.Visuals.GunDropESP, Config.Visuals.GunDropESP)
        setToggle(UI_Elements.Visuals.NameTags, Config.Visuals.NameTags)
        
        applyStretch(Config.Visuals.StretchEnabled)
        applyNoFog(Config.Visuals.NoFogEnabled)
        applyTimeOfDay(Config.Visuals.TimeOfDay)
        
        -- 2. Бой
        setToggle(UI_Elements.Combat.AutoShootMurderer, Config.Combat.AutoShootMurderer)
        setToggle(UI_Elements.Combat.AimlockEnabled, Config.Combat.AimlockEnabled)
        setToggle(UI_Elements.Combat.SilentAimEnabled, Config.Combat.SilentAimEnabled) 
        setToggle(UI_Elements.Combat.AutoDodgeKnife, Config.Combat.AutoDodgeKnife)
        setToggle(UI_Elements.Combat.KillAuraEnabled, Config.Combat.KillAuraEnabled)
        setSlider(UI_Elements.Combat.KillAuraRange, Config.Combat.KillAuraRange)
        pcall(updateShootBindButton)
        
        -- 3. Утилиты
        setToggle(UI_Elements.Utility.AutoGrabGun, Config.Utility.AutoGrabGun)
        setToggle(UI_Elements.Utility.NoclipEnabled, Config.Utility.NoclipEnabled)
        setToggle(UI_Elements.Utility.AntiFling, Config.Utility.AntiFling)
        setToggle(UI_Elements.Utility.AutoFarmCoins, Config.Utility.AutoFarmCoins)         
        setToggle(UI_Elements.Utility.EmoteSpamEnabled, Config.Utility.EmoteSpamEnabled)   
        setToggle(UI_Elements.Utility.InvisEnabled, Config.Utility.InvisEnabled)
        
        applyAntiFling(Config.Utility.AntiFling)
        
    end

    -- ==================== ВЕРСТКА ИНТЕРФЕЙСА FOGYHUB ====================

    -- Вкладка Визуалы
    UI_Elements.Visuals.MurdererESP = VisualsTab:Toggle({ Title = T("EspM"), Value = Config.Visuals.MurdererESP, Callback = function(s) Config.Visuals.MurdererESP = s saveConfig() end })
    UI_Elements.Visuals.SheriffESP = VisualsTab:Toggle({ Title = T("EspS"), Value = Config.Visuals.SheriffESP, Callback = function(s) Config.Visuals.SheriffESP = s saveConfig() end })
    UI_Elements.Visuals.InnocentESP = VisualsTab:Toggle({ Title = T("EspI"), Value = Config.Visuals.InnocentESP, Callback = function(s) Config.Visuals.InnocentESP = s saveConfig() end })
    UI_Elements.Visuals.GunDropESP = VisualsTab:Toggle({ Title = T("EspG"), Value = Config.Visuals.GunDropESP, Callback = function(s) Config.Visuals.GunDropESP = s saveConfig() end })
    UI_Elements.Visuals.NameTags = VisualsTab:Toggle({ Title = T("NameTags"), Value = Config.Visuals.NameTags, Callback = function(s) Config.Visuals.NameTags = s saveConfig() end })
    
    UI_Elements.Visuals.StretchEnabled = VisualsTab:Toggle({
        Title = T("Stretch"), Value = Config.Visuals.StretchEnabled, Callback = function(state)
            applyStretch(state)
            saveConfig()
        end
    })
    UI_Elements.Visuals.StretchFactor = VisualsTab:Slider({ Title = T("StretchForce"), Step = 0.05, Value = { Min = 0.5, Max = 1, Default = Config.Visuals.StretchFactor }, Callback = function(v) Config.Visuals.StretchFactor = v saveConfig() end })
    
    UI_Elements.Visuals.NoFogEnabled = VisualsTab:Toggle({ Title = T("NoFog"), Value = Config.Visuals.NoFogEnabled, Callback = function(s) applyNoFog(s) saveConfig() end })
    VisualsTab:Slider({ Title = T("TimeOfDay"), Step = 1, Value = { Min = 0, Max = 24, Default = Config.Visuals.TimeOfDay }, Callback = function(v) applyTimeOfDay(v) saveConfig() end })
    
    -- Локальный Скинченджер Персонажа (ИНТЕГРИРОВАННАЯ ФИЗИЧЕСКАЯ ВАРКА КЛИЕНТА)
    VisualsTab:Input({ Title = T("SkinChangerInput"), Value = "", Placeholder = "Roblox Username...", Callback = function(t) skinChangerNick = t end })
    VisualsTab:Button({ Title = T("SkinChangerBtn"), Callback = function() changeVisualSkin(skinChangerNick) end })

    -- Вкладка Бой (ШУТ ВЕРНУТ К ЖИЗНИ)
    UI_Elements.Combat.AutoShootMurderer = CombatTab:Toggle({ Title = T("AutoShoot"), Value = Config.Combat.AutoShootMurderer, Callback = function(s) Config.Combat.AutoShootMurderer = s saveConfig() end })
    UI_Elements.Combat.AimlockEnabled = CombatTab:Toggle({ Title = T("Aimlock"), Value = Config.Combat.AimlockEnabled, Callback = function(s) Config.Combat.AimlockEnabled = s saveConfig() end })
    UI_Elements.Combat.SilentAimEnabled = CombatTab:Toggle({ Title = T("SilentAim"), Value = Config.Combat.SilentAimEnabled, Callback = function(s) Config.Combat.SilentAimEnabled = s saveConfig() end }) 
    local shootBindListening = false
    local function updateShootBindButton()
        local el = UI_Elements.Combat.ShootM
        if not el then return end
        local txt = T("ShootM") .. " [" .. (Config.Combat.ShootMBind or "None") .. "]"
        pcall(function() if el.SetTitle then el:SetTitle(txt) else el.Title = txt end)
    end
    UI_Elements.Combat.ShootM = CombatTab:Button({ Title = T("ShootM") .. " [" .. (Config.Combat.ShootMBind or "None") .. "]", Callback = function()
        shootBindListening = true
        pcall(function() UI_Elements.Combat.ShootM:SetTitle(T("ShootM") .. " [Press a key...]") end)
        WindUI:Notify({ Title = "Ghost", Content = "Нажми клавишу для бинда Shoot (Esc — сброс в None)", Icon = "info", Duration = 3 })
    end })
    
    -- Авто-уклонение от ножей
    local lastDodgeTime = 0
    UI_Elements.Combat.AutoDodgeKnife = CombatTab:Toggle({ Title = T("DodgeKnife"), Value = Config.Combat.AutoDodgeKnife, Callback = function(state) Config.Combat.AutoDodgeKnife = state saveConfig() end }) 
    
    UI_Elements.Combat.KillAuraEnabled = CombatTab:Toggle({ Title = T("KillAura"), Value = Config.Combat.KillAuraEnabled, Callback = function(s) Config.Combat.KillAuraEnabled = s saveConfig() end })
    UI_Elements.Combat.KillAuraRange = CombatTab:Slider({ Title = T("KillAuraRange"), Step = 5, Value = { Min = 10, Max = 45, Default = Config.Combat.KillAuraRange }, Callback = function(v) Config.Combat.KillAuraRange = v saveConfig() end })
    CombatTab:Button({ Title = T("AutoKillAll"), Callback = autoKillAll })
    
    -- Кнопки Флинга (Выбивания)
    CombatTab:Button({ Title = T("FlingM"), Callback = function() local m = getMurderer() if m then flingPlayer(m) else WindUI:Notify({ Title = "Error", Content = T("NoM"), Icon = "x", Duration = 3 }) end end })
    CombatTab:Button({ Title = T("FlingS"), Callback = function() local sh = getSheriff() if sh then flingPlayer(sh) else WindUI:Notify({ Title = "Error", Content = T("NoS"), Icon = "x", Duration = 3 }) end end })
    CombatTab:Button({ Title = T("FlingH"), Callback = function() local h = getHero() if h then flingPlayer(h) else WindUI:Notify({ Title = "Error", Content = T("NoH"), Icon = "x", Duration = 3 }) end end })

    -- Вкладка Утилиты
    UI_Elements.Utility.AutoGrabGun = UtilityTab:Toggle({ Title = T("AutoGrab"), Value = Config.Utility.AutoGrabGun, Callback = function(s) Config.Utility.AutoGrabGun = s saveConfig() end })
    UI_Elements.Utility.NoclipEnabled = UtilityTab:Toggle({ Title = T("Noclip"), Value = Config.Utility.NoclipEnabled, Callback = function(s) if s ~= Config.Utility.NoclipEnabled then toggleNoclip(s) end end })
    UI_Elements.Utility.InvisEnabled = UtilityTab:Toggle({ Title = T("Invis"), Value = Config.Utility.InvisEnabled, Callback = function(s) if s ~= Config.Utility.InvisEnabled then toggleInvis(s) end end })
    
    -- Новые утилиты
    UI_Elements.Utility.AutoFarmCoins = UtilityTab:Toggle({ Title = T("AutoFarmCoins"), Value = Config.Utility.AutoFarmCoins, Callback = function(s) Config.Utility.AutoFarmCoins = s saveConfig() end })
    UI_Elements.Utility.EmoteSpamEnabled = UtilityTab:Toggle({ Title = T("EmoteSpam"), Value = Config.Utility.EmoteSpamEnabled, Callback = function(s) Config.Utility.EmoteSpamEnabled = s saveConfig() end })

    UI_Elements.Utility.AntiFling = UtilityTab:Toggle({
        Title = T("AntiFling"), 
        Value = Config.Utility.AntiFling, 
        Callback = function(state)
            applyAntiFling(state)
            saveConfig()
        end
    })

    -- Вкладка Телепорты
    TeleportsTab:Button({ Title = T("TpLobby"), Callback = tpToLobby })
    TeleportsTab:Button({ Title = T("TpMap"), Callback = tpToMap })


    -- Вкладка Конфиги (ОБНОВЛЁН ПЕРЕЗАПУСК ПРИ СМЕНЕ ЯЗЫКА)
    ConfigsTab:Button({ Title = T("SaveConfigBtn"), Callback = function() saveConfig() WindUI:Notify({ Title = "Ghost", Content = T("ConfSaved"), Icon = "check", Duration = 3 }) end })
    ConfigsTab:Button({ Title = T("LoadConfigBtn"), Callback = function() loadConfig() applyConfigToUI() WindUI:Notify({ Title = "Ghost", Content = T("ConfLoaded"), Icon = "check", Duration = 3 }) end })
    ConfigsTab:Button({ Title = T("ResetConfigBtn"), Callback = function() 
        Config.Visuals = { MurdererESP = false, SheriffESP = false, InnocentESP = false, StretchEnabled = false, StretchFactor = 0.75, NoFogEnabled = false, TimeOfDay = 14, GunDropESP = false, NameTags = false }
        Config.Combat = { AutoShootMurderer = false, AimlockEnabled = false, SilentAimEnabled = false, AutoDodgeKnife = false, KillAuraEnabled = false, KillAuraRange = 25, ShootMBind = "None" }
        Config.Utility = { AutoGrabGun = false, NoclipEnabled = false, AntiFling = false, AutoFarmCoins = false, EmoteSpamEnabled = false, InvisEnabled = false }
        saveConfig() applyConfigToUI() WindUI:Notify({ Title = "Ghost", Content = T("ConfReset"), Icon = "check", Duration = 3 }) 
    end })
    ConfigsTab:Button({ Title = T("SetLangRu"), Callback = function() 
        Config.Language = "ru" 
        currentLang = "ru" 
        saveConfig() 
        if writefile then pcall(function() writefile("ghost_lang.txt", "ru") end) end
        WindUI:Notify({ Title = "Язык", Content = "Перезапуск хуеты...", Icon = "globe", Duration = 3 })
        task.wait(1)
        pcall(getgenv().Ghost_Cleanup)
        task.spawn(main)
    end })
    ConfigsTab:Button({ Title = T("SetLangEn"), Callback = function() 
        Config.Language = "en" 
        currentLang = "en" 
        saveConfig() 
        if writefile then pcall(function() writefile("ghost_lang.txt", "en") end) end
        WindUI:Notify({ Title = "Language", Content = "Restarting script...", Icon = "globe", Duration = 3 })
        task.wait(1)
        pcall(getgenv().Ghost_Cleanup)
        task.spawn(main)
    end })

    -- Вкладка Радио
    local _ = RadioTab:Input({ Title = T("RobloxId"), Value = "", Placeholder = "ID...", Callback = function(text) currentSongId = text end })
    RadioTab:Button({ Title = T("PlayId"), Callback = playRadio })
    local _ = RadioTab:Input({ Title = T("HttpUrl"), Value = "", Placeholder = "https://...", Callback = function(text) httpSongUrl = text end })
    RadioTab:Button({ Title = T("PlayHttp"), Callback = playHttpRadio })
    RadioTab:Button({ Title = T("StopRadio"), Callback = stopRadio })
    RadioTab:Slider({ Title = T("Volume"), Step = 0.5, Value = { Min = 0, Max = 10, Default = 2 }, Callback = function(v) radioVolume = v if radioSound then radioSound.Volume = v end end })
    RadioTab:Toggle({ Title = T("Loop"), Value = false, Callback = function(s) radioLooped = s if radioSound then radioSound.Looped = s end end })

    -- Автоматическое восстановление активного Радио
    addConnection(LocalPlayer.CharacterAdded:Connect(function()
        invisOn = false
        if invisConnection then invisConnection:Disconnect() invisConnection = nil end
        if rotationConnection then rotationConnection:Disconnect() rotationConnection = nil end
        if invisOutline then invisOutline:Destroy() invisOutline = nil end
        local seat = workspace:FindFirstChild("Ghost_InvisChair")
        if seat then seat:Destroy() end
        Config.Utility.InvisEnabled = false
        setToggle(UI_Elements.Utility.InvisEnabled, false)

        -- Автоматическое восстановление активного Радио
        task.wait(1)
        if radioSound and radioSound.Playing then
            attachRadio()
            if radioModel then
                local sound = radioModel:FindFirstChild("RadioSound") or Instance.new("Sound", radioModel)
                sound.Name = "RadioSound"
                sound.SoundId = radioSound.SoundId
                sound.Volume = radioVolume
                sound.Looped = radioLooped
                sound:Play()
                sound.Volume = radioVolume
                radioSound = sound
            end
        end
    end))

    -- ==================== ФОНОВЫЕ ЦИКЛЫ И ПРОСЛУШИВАТЕЛИ ====================
    addConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local success, keyStr = pcall(function() return input.KeyCode and input.KeyCode.Name end)
            if success and keyStr then
                -- режим захвата нового бинда Shoot
                if shootBindListening then
                    shootBindListening = false
                    if keyStr == "Escape" then
                        Config.Combat.ShootMBind = "None"
                    else
                        Config.Combat.ShootMBind = keyStr
                    end
                    saveConfig()
                    updateShootBindButton()
                    return
                end
                -- триггер по установленному бинду
                if Config.Combat.ShootMBind ~= "None" and keyStr == Config.Combat.ShootMBind then
                    shootMurdererDirect()
                    return
                end
                if keyStr == "F" then local m = getMurderer() if m then flingPlayer(m) end
                elseif keyStr == "G" then local s = getSheriff() if s then flingPlayer(s) end 
                elseif keyStr == "T" then grabGun()
                elseif keyStr == "V" then toggleNoclip(not Config.Utility.NoclipEnabled)
                elseif keyStr == "Y" then toggleInvis() end
            end
        end
    end))


    -- Умный автоматический поиск и подсветка упавшего пистолета на карте
    local function highlightGunDrop()
        local gunDrop = workspace:FindFirstChild("GunDrop", true) or workspace:FindFirstChild("DroppedGun", true)
        local handle = gunDrop and (gunDrop:FindFirstChild("Handle", true) or gunDrop:FindFirstChildOfClass("Part", true) or gunDrop)
        
        if handle then
            local highlight = handle:FindFirstChild("Ghost_GunESP")
            if Config.Visuals.GunDropESP then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "Ghost_GunESP"
                    highlight.FillColor = Color3.fromRGB(0, 255, 100) -- Яркий зеленый
                    highlight.OutlineColor = Color3.fromRGB(0, 255, 100)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = handle
                end
            else
                if highlight then highlight:Destroy() end
            end
        end
    end

    -- Оптимизированный ESP обработчик (С жестким сканером инвентаря на кастомных серверах!)
    local function updateESP()
        local success, serverRoles = pcall(function()
            local remote = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
            return remote and remote:InvokeServer()
        end)
        
        local tempMurder, tempSheriff, tempHero = nil, nil, nil
        if success and serverRoles then
            roles = serverRoles
            for i, v in pairs(roles) do
                if v.Role == "Murderer" then
                    tempMurder = i
                elseif v.Role == "Sheriff" then
                    tempSheriff = i
                elseif v.Role == "Hero" then
                    tempHero = i
                end
            end
        end

        Murder = tempMurder
        Sheriff = tempSheriff
        Hero = tempHero
        
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                if character then
                    local isM, isS, isH = false, false, false
                    local alive = IsAlive(player)
                    
                    -- Фоллбэк сканирование инвентаря на оружие (для кастомных серверов)
                    local bp = player:FindFirstChild("Backpack")
                    local hasKnife = (character:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
                    local hasGun = (character:FindFirstChild("Gun") or character:FindFirstChild("Revolver")) or (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")))

                    if player.Name == Murder or hasKnife then
                        isM = true
                    elseif player.Name == Sheriff or (hasGun and not isM) then
                        isS = true
                    elseif player.Name == Hero then
                        isH = true
                    end
                    
                    local inLobby = false
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local distToLobby = (hrp.Position - Vector3.new(6.0, 505.2, -35.0)).Magnitude
                        if distToLobby < 150 then
                            inLobby = true
                        end
                    end
                    
                    local espEnabled = false
                    local renderColor = Color3.fromRGB(0, 255, 0)
                    
                    if not alive or inLobby then
                        if Config.Visuals.MurdererESP or Config.Visuals.SheriffESP or Config.Visuals.InnocentESP then
                            espEnabled = true
                        end
                        renderColor = Color3.fromRGB(150, 150, 150)
                    else
                        if isM then
                            espEnabled = Config.Visuals.MurdererESP
                            renderColor = Color3.fromRGB(255, 0, 0)
                        elseif isS then
                            espEnabled = Config.Visuals.SheriffESP
                            renderColor = Color3.fromRGB(0, 0, 255)
                        elseif isH then
                            espEnabled = Config.Visuals.SheriffESP
                            renderColor = Color3.fromRGB(255, 250, 0)
                        else
                            espEnabled = Config.Visuals.InnocentESP
                            renderColor = Color3.fromRGB(0, 255, 0)
                        end
                    end
                    
                    if espEnabled then
                        applyHighlight(player, renderColor)
                    else
                        removeHighlight(player)
                    end

                    if Config.Visuals.NameTags and character and alive and not inLobby then
                        local tagText = player.Name
                        if isM then tagText = "[M] " .. player.Name
                        elseif isS then tagText = "[S] " .. player.Name
                        elseif isH then tagText = "[H] " .. player.Name end
                        applyNameTag(player, renderColor, tagText)
                    else
                        removeNameTag(player)
                    end

                end
            end
        end
    end

    -- Запуск цикла ESP и подсветки пистолета
    task.spawn(function()
        while getgenv().GhostActive do
            pcall(updateESP)
            pcall(highlightGunDrop)
            task.wait(0.1)
        end
    end)

    -- Цикл автоподбора пистолета
    task.spawn(function()
        while getgenv().GhostActive do
            pcall(function()
                if Config.Utility.AutoGrabGun then
                    local char = LocalPlayer.Character
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    local isMurderer = (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) or (Murder and LocalPlayer.Name == Murder)
                    
                    if IsAlive(LocalPlayer) and not isMurderer then
                        if (workspace:FindFirstChild("GunDrop", true) or workspace:FindFirstChild("DroppedGun", true)) then 
                            grabGun() 
                            task.wait(1) 
                        end
                    end
                end
            end)
            task.wait(0.2)
        end
    end)

    -- Цикл автофарма монет
    local function getCoinsOnMap()
        local coins = {}
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and (v.Name == "Coin_Highlight" or v.Name == "CoinContainer" or v.Name == "Coin") then
                table.insert(coins, v)
            end
        end
        return coins
    end

    task.spawn(function()
        while getgenv().GhostActive do
            pcall(function()
                if Config.Utility.AutoFarmCoins then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local coins = getCoinsOnMap()
                        local nearestCoin, minDist = nil, math.huge
                        for _, coin in ipairs(coins) do
                            local dist = (coin.Position - hrp.Position).Magnitude
                            if dist < minDist then
                                minDistance = dist
                                nearestCoin = coin
                            end
                        end
                        
                        if nearestCoin then
                            local stepConn
                            stepConn = addConnection(RunService.Heartbeat:Connect(function(dt)
                                if not Config.Utility.AutoFarmCoins or not nearestCoin or not nearestCoin.Parent or not hrp.Parent then
                                    if stepConn then stepConn:Disconnect() end
                                    return
                                end
                                local dir = (nearestCoin.Position - hrp.Position).Unit
                                hrp.CFrame = hrp.CFrame + (dir * (22 * dt))
                                if (nearestCoin.Position - hrp.Position).Magnitude < 4 then
                                    if stepConn then stepConn:Disconnect() end
                                end
                            end))
                            
                            local timeout = 0
                            while nearestCoin and nearestCoin.Parent and Config.Utility.AutoFarmCoins and timeout < 100 do
                                if (nearestCoin.Position - hrp.Position).Magnitude < 4 then break end
                                task.wait(0.05)
                                timeout = timeout + 1
                            end
                            if stepConn then stepConn:Disconnect() end
                        end
                    end
                end
            end)
            task.wait(0.1)
        end
    end)

    -- Цикл Спама Эмоций
    task.spawn(function()
        while getgenv().GhostActive do
            pcall(function()
                if Config.Utility.EmoteSpamEnabled then
                    local playEmote = game:GetService("ReplicatedStorage"):FindFirstChild("PlayEmote")
                    if playEmote and playEmote:IsA("RemoteEvent") then
                        playEmote:FireServer("zen")
                        task.wait(0.1)
                        playEmote:FireServer("sit")
                    end
                end
            end)
            task.wait(0.2)
        end
    end)

    -- Цикл авто-выстрела
    task.spawn(function()
        while getgenv().GhostActive do
            pcall(function()
                if Config.Combat.AutoShootMurderer then
                    local char = LocalPlayer.Character
                    local gun = char and (char:FindFirstChild("Gun") or char:FindFirstChild("Revolver"))
                    if gun then
                        local m = getMurderer()
                        if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
                            fireGun(gun, m.Character.HumanoidRootPart.Position) 
                        end
                    end
                end
            end)
            task.wait(0.1)
        end
    end)

    -- Высокоприоритетный мгновенный Аимлок (ЖЕСТКАЯ НАВОДКА БЕЗ СГЛАЖИВАНИЯ)
    local function updateAimlock()
        if Config.Combat.AimlockEnabled then
            local m = getMurderer()
            if m and m.Character and m.Character:FindFirstChild("Head") then
                local camera = workspace.CurrentCamera
                if camera then 
                    -- Мгновенная наводка без Lerp
                    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, m.Character.Head.Position)
                end
            end
        end
    end
    addBind("Ghost_Aimlock", Enum.RenderPriority.Camera.Value + 1, updateAimlock)


    -- Silent Aim (ПЕРЕДОВОЙ СЕТЕВОЙ ПЕРЕХВАТ ПУЛИ В ТАРГЕТ)
    pcall(function()
        if hookmetamethod and getnamecallmethod then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local args = {...}
                local method = getnamecallmethod()
                if Config.Combat.SilentAimEnabled then
                    local m = getMurderer()
                    if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
                        local targetPos = m.Character.HumanoidRootPart.Position
                        -- Хук для современных копий игры (RemoteEvent)
                        local gunTool = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("Gun") or LocalPlayer.Character:FindFirstChild("Revolver"))
                        local isGunSlash = (method == "FireServer" and self.Name == "SlashStart" and self.Parent and self.Parent.Name == "KnifeServer" and self.Parent.Parent == gunTool)
                        if isGunSlash then
                            args[2] = targetPos
                            if oldNamecall then
                                return oldNamecall(self, unpack(args))
                            end
                        elseif method == "FireServer" and (self.Name == "Shoot" or self.Name == "Fire") and self.Parent == gunTool then
                            local origin = args[1] and args[1].Position or LocalPlayer.Character.HumanoidRootPart.Position
                            args[1] = CFrame.new(origin, targetPos)
                            args[2] = targetPos
                            if oldNamecall then
                                return oldNamecall(self, unpack(args))
                            end
                        -- Хук для классических серверов (RemoteFunction)
                        elseif method == "InvokeServer" and self.Name == "ShootGun" then
                            args[2] = targetPos
                            args[3] = targetPos
                            if oldNamecall then
                                return oldNamecall(self, unpack(args))
                            end
                        end
                    end
                end
                if oldNamecall then
                    return oldNamecall(self, ...)
                end
            end)
        end
    end)

    -- Kill Aura (blade-stretch: отключаем все constraint'ы ножа и дотягиваем лезвие к жертве)
    local auraTick = 0
    addConnection(RunService.Heartbeat:Connect(function()
        pcall(function()
            if not Config.Combat.KillAuraEnabled then return end
            if tick() - auraTick < 0.15 then return end
            auraTick = tick()
            local char = LocalPlayer.Character
            if not (char and char:FindFirstChild("HumanoidRootPart")) then return end
            local bp = LocalPlayer:FindFirstChild("Backpack")
            local knife = char:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife"))
            if not knife then return end
            if knife.Parent ~= char then char.Humanoid:EquipTool(knife) end
            local remote = knife:FindFirstChild("KnifeServer") and knife.KnifeServer:FindFirstChild("SlashStart")
            if not (remote and remote:IsA("RemoteEvent")) then return end
            local blade
            for _, p in ipairs(knife:GetDescendants()) do
                if p:IsA("BasePart") and (p.Name:lower():find("blade") or p.Name == "Handle") then blade = p; break end
            end
            if not blade then
                for _, p in ipairs(knife:GetDescendants()) do
                    if p:IsA("BasePart") then blade = p; break end
                end
            end
            if not blade then return end
            local knifeParts = {}
            for _, p in ipairs(knife:GetDescendants()) do if p:IsA("BasePart") then knifeParts[p] = true end end
            local hrp = char.HumanoidRootPart
            for _, victim in ipairs(Players:GetPlayers()) do
                if victim ~= LocalPlayer and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
                    local vHum = victim.Character:FindFirstChildOfClass("Humanoid")
                    if vHum and vHum.Health > 0 then
                        local dist = (hrp.Position - victim.Character.HumanoidRootPart.Position).Magnitude
                        if dist <= Config.Combat.KillAuraRange then
                            local tPart = victim.Character:FindFirstChild("HumanoidRootPart") or victim.Character:FindFirstChildOfClass("BasePart")
                            task.spawn(function()
                                local cons = {}
                                local function check(o)
                                    if o:IsA("JointInstance") or o:IsA("WeldConstraint") then
                                        if knifeParts[o.Part0] or knifeParts[o.Part1] then table.insert(cons, o) end
                                    elseif o:IsA("Constraint") then
                                        local p0 = o.Attachment0 and o.Attachment0.Parent
                                        local p1 = o.Attachment1 and o.Attachment1.Parent
                                        if (p0 and knifeParts[p0]) or (p1 and knifeParts[p1]) then table.insert(cons, o) end
                                    end
                                end
                                for _, o in ipairs(char:GetDescendants()) do check(o) end
                                for _, o in ipairs(knife:GetDescendants()) do check(o) end
                                for _, c in ipairs(cons) do c.Enabled = false end
                                local oldCF = blade.CFrame
                                for i = 1, 5 do
                                    blade.CFrame = tPart.CFrame * CFrame.new(0, 0, 0.4)
                                    remote:FireServer(1)
                                    task.wait(0.012)
                                end
                                for _, c in ipairs(cons) do c.Enabled = true end
                                pcall(function() blade.CFrame = oldCF end)
                            end)
                            break
                        end
                    end
                end
            end
        end)
    end))

    -- Noclip
    addConnection(RunService.Stepped:Connect(function()
        pcall(function()
            if not Config.Utility.NoclipEnabled then return end
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end))

    -- Потоковая проверка для авто-уклонения
    addConnection(RunService.Heartbeat:Connect(function()
        pcall(function()
            if not Config.Combat.AutoDodgeKnife then return end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "ThrownKnife" and obj:IsA("BasePart") then
                    local distance = (hrp.Position - obj.Position).Magnitude
                    
                    if distance < 22 and (tick() - lastDodgeTime > 0.6) then
                        lastDodgeTime = tick()
                        
                        local targetCFrame = hrp.CFrame + (hrp.CFrame.RightVector * 14)
                        
                        local wasAnchored = hrp.Anchored
                        hrp.Anchored = true
                        hrp.CFrame = targetCFrame
                        char:PivotTo(targetCFrame)
                        task.wait(0.04)
                        hrp.Anchored = wasAnchored
                        break
                    end
                end
            end
        end)
    end))

    -- Проверка на неофициальный сервер
    task.spawn(function()
        task.wait(1.5)
        local officialMM2Ids = {142823291, 3383406159}
        if not table.find(officialMM2Ids, game.PlaceId) then
            WindUI:Notify({
                Title = T("MMBWarningTitle"),
                Content = T("MMBWarningContent"),
                Icon = "alert-triangle",
                Duration = 6
            })
        end
    end)

    -- Автоматическое применение конфига
    task.spawn(function()
        task.wait(0.5)
        applyConfigToUI()
    end)

    WindUI:Notify({ Title = "Ghost", Content = T("Loaded"), Icon = "shield", Duration = 3 })
end -- ЭТОТ END ЗАКРЫВАЕТ ФУНКЦИЮ main() НАМЕРТВО!

-- ==================== ИНИЦИАЛИЗАЦИЯ И ИНТЕРАКТИВНЫЙ ВЫБОР ЯЗЫКА ====================
local container = getSafeUIContainer()
if container then
    local saveFileName = "ghost_lang.txt"
    local hasSavedLang = false
    
    if readfile and isfile and isfile(saveFileName) then
        local saved = pcall(function() return readfile(saveFileName) end) and readfile(saveFileName)
        if saved == "ru" or saved == "en" then
            currentLang = saved
            hasSavedLang = true
        end
    end
    
    if hasSavedLang or isfile(configFileName) then
        main()
    else
        local langGui = Instance.new("ScreenGui")
        langGui.Name = "Ghost_LanguageSelector"
        langGui.ResetOnSpawn = false
        langGui.Parent = container
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 300, 0, 150)
        frame.Position = UDim2.new(0.5, -150, 0.5, -75)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BorderSizePixel = 0
        frame.Parent = langGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 150, 255)
        stroke.Thickness = 1.5
        stroke.Parent = frame
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        title.Text = "🌐 Ghost — Select Language"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 13
        title.Font = Enum.Font.SourceSansBold
        title.Parent = frame
        
        local titleCorner = Instance.new("UICorner")
        titleCorner.CornerRadius = UDim.new(0, 8)
        titleCorner.Parent = title
        
        local function createLangButton(text, pos, callback)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.4, 0, 0, 40)
            btn.Position = pos
            btn.Text = text
            btn.Font = Enum.Font.SourceSansBold
            btn.TextSize = 13
            btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.BorderSizePixel = 0
            btn.Parent = frame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn
            
            btn.Activated:Connect(callback)
        end
        
        createLangButton("Русский", UDim2.new(0.08, 0, 0.5, 0), function()
            currentLang = "ru"
            Config.Language = "ru"
            if writefile then pcall(function() writefile(saveFileName, "ru") end) end
            saveConfig()
            langGui:Destroy()
            main()
        end)
        
        createLangButton("English", UDim2.new(0.52, 0, 0.5, 0), function()
            currentLang = "en"
            Config.Language = "en"
            if writefile then pcall(function() writefile(saveFileName, "en") end) end
            saveConfig()
            langGui:Destroy()
            main()
        end)
    end
else
    main()
end

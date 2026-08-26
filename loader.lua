-- Ghost Loader — подгружает основной скрипт с GitHub по ссылке
-- 1) Залей основной скрипт (example.lua) на GitHub
-- 2) Открой его и нажми "Raw", скопируй URL и вставь ниже в URL
-- 3) В исполнителе (Nexomia) запусти ЭТОТ файл — он сам докачает и запустит скрипт

local URL = "https://raw.githubusercontent.com/USER/REPO/BRANCH/example.lua" -- <== ЗАМЕНИ НА СВОЙ RAW-URL

local function httpGet(url)
    if typeof(game.HttpGet) == "function" then
        return game:HttpGet(url, true)
    elseif typeof(game.HttpGetAsync) == "function" then
        return game:HttpGetAsync(url)
    end
    local req = request or http_request or (syn and syn.request)
    if req then
        local res = req({ Url = url, Method = "GET" })
        return res.Body
    end
    error("HTTP-метод недоступен в этом исполнителе")
end

local ok, src = pcall(httpGet, URL)
if not ok then
    warn("[Loader] Не удалось скачать скрипт: " .. tostring(src))
    return
end
if not src or #src < 50 then
    warn("[Loader] Получен пустой/некорректный ответ. Проверь URL (должен быть raw.githubusercontent.com/.../file.lua)")
    return
end

local loadfn = loadstring or load
local fn, err = loadfn(src)
if not fn then
    warn("[Loader] Ошибка компиляции скрипта: " .. tostring(err))
    return
end

local ok2, e2 = pcall(fn)
if not ok2 then
    warn("[Loader] Ошибка выполнения скрипта: " .. tostring(e2))
end

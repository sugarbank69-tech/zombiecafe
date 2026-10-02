local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local BuyZombie = Instance.new("RemoteEvent")
BuyZombie.Name = "BuyZombie"
BuyZombie.Parent = ReplicatedStorage

-- Use the cafe you built in Studio; create placeholders for anything missing.
local cafe = workspace:FindFirstChild("Cafe") or Instance.new("Folder")
cafe.Name = "Cafe"
cafe.Parent = workspace

local function ensurePart(name, size, pos, color)
	local p = cafe:FindFirstChild(name)
	if not p then
		p = Instance.new("Part")
		p.Name, p.Size, p.Position, p.Color, p.Anchored = name, size, pos, color, true
		p.Parent = cafe
	end
	return p
end

local entrance = ensurePart("Entrance", Vector3.new(6, 1, 6), Vector3.new(0, 0.5, 40), Color3.fromRGB(80, 200, 120))
local counter = ensurePart("Counter", Vector3.new(12, 4, 3), Vector3.new(0, 2, -20), Color3.fromRGB(120, 80, 50))

local tables = {}
for _, c in ipairs(cafe:GetChildren()) do
	if c:IsA("BasePart") and c.Name:match("^Table") then table.insert(tables, c) end
end
if #tables == 0 then
	for i = 1, 4 do
		local t = ensurePart("Table" .. i, Vector3.new(5, 3, 5), Vector3.new(-18 + i * 9, 1.5, 0), Color3.fromRGB(150, 110, 70))
		table.insert(tables, t)
	end
end

local cash = {}
local function addCash(player, n)
	if player and player.Parent then
		local stat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
		if stat then stat.Value += n end
	end
end

local state = { zombies = 0, customers = 0, owner = nil }

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
	local c = Instance.new("IntValue"); c.Name = "Cash"; c.Value = Config.StartCash; c.Parent = ls
	local z = Instance.new("IntValue"); z.Name = "Zombies"; z.Parent = ls
	state.owner = state.owner or player
end)

local function zombieCost()
	return math.floor(Config.ZombieCost * Config.ZombieCostGrowth ^ state.zombies)
end

BuyZombie.OnServerEvent:Connect(function(player)
	if state.zombies >= Config.MaxZombies then return end
	local stat = player.leaderstats.Cash
	local cost = zombieCost()
	if stat.Value < cost then return end
	stat.Value -= cost
	state.zombies += 1
	player.leaderstats.Zombies.Value = state.zombies
end)

-- Customers ---------------------------------------------------------------
local function makeCustomer()
	local model = Players:CreateHumanoidModelFromDescription(HumanoidDescription.new(), Enum.HumanoidRigType.R6)
	model.Name = "Customer"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then d.Color = Color3.fromRGB(150, 200, 255) end
	end
	model:PivotTo(CFrame.new(entrance.Position + Vector3.new(0, 3, 0)))
	model.Parent = workspace
	return model
end

local function walkTo(model, pos)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum:MoveTo(pos)
	hum.MoveToFinished:Wait()
end

local function serve(tbl, customer, servedBy)
	tbl:SetAttribute("Waiting", false)
	local prompt = tbl:FindFirstChild("ServePrompt")
	if prompt then prompt.Enabled = false end
	customer:SetAttribute("Served", true)
	if servedBy then addCash(servedBy, Config.ServeReward) end
end

local function setupTable(tbl)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ServePrompt"
	prompt.ActionText = "Serve brains"
	prompt.Enabled = false
	prompt.Parent = tbl
	prompt.Triggered:Connect(function(player)
		local customer = tbl:GetAttribute("CustomerId") and tbl:FindFirstChild("CurrentCustomer")
		local ref = tbl:FindFirstChild("CurrentCustomer")
		if ref and ref.Value then serve(tbl, ref.Value, player) end
	end)
	local ref = Instance.new("ObjectValue"); ref.Name = "CurrentCustomer"; ref.Parent = tbl
	tbl:SetAttribute("Taken", false)
end
for _, t in ipairs(tables) do setupTable(t) end

local function runCustomer()
	local free = {}
	for _, t in ipairs(tables) do if not t:GetAttribute("Taken") then table.insert(free, t) end end
	if #free == 0 then return end
	local tbl = free[math.random(#free)]
	tbl:SetAttribute("Taken", true)
	state.customers += 1
	local customer = makeCustomer()
	walkTo(customer, tbl.Position + Vector3.new(0, 0, 4))
	tbl.CurrentCustomer.Value = customer
	tbl:SetAttribute("Waiting", true)
	tbl.ServePrompt.Enabled = true

	local waited = 0
	while waited < Config.CustomerPatienceSeconds and not customer:GetAttribute("Served") do
		task.wait(0.5)
		waited += 0.5
		-- Zombie waiters serve automatically after a delay.
		if state.zombies > 0 and waited >= Config.ZombieServeSeconds / state.zombies and state.owner then
			serve(tbl, customer, state.owner)
		end
	end
	if not customer:GetAttribute("Served") then
		tbl.ServePrompt.Enabled = false
	end
	tbl.CurrentCustomer.Value = nil
	walkTo(customer, entrance.Position)
	customer:Destroy()
	tbl:SetAttribute("Taken", false)
	state.customers -= 1
end

while true do
	task.wait(Config.CustomerSpawnSeconds)
	if #Players:GetPlayers() > 0 and state.customers < Config.MaxCustomers then
		task.spawn(runCustomer)
	end
end

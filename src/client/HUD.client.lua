local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer

-- Only builds a HUD if you haven't made one named "CafeHUD" in StarterGui.
local gui = player:WaitForChild("PlayerGui")
if gui:FindFirstChild("CafeHUD") then return end

local sg = Instance.new("ScreenGui"); sg.Name = "CafeHUD"; sg.ResetOnSpawn = false; sg.Parent = gui
local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(220, 50); btn.Position = UDim2.new(0.5, -110, 1, -70)
btn.BackgroundColor3 = Color3.fromRGB(60, 140, 70); btn.TextColor3 = Color3.new(1, 1, 1)
btn.TextScaled = true; btn.Text = "Hire Zombie Waiter"; btn.Parent = sg
btn.Activated:Connect(function() ReplicatedStorage.BuyZombie:FireServer() end)

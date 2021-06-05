local ESP = {
	Enabled = false,
		Tracers = true,
	Boxes = true,
	ShowInfo = true,
	UseTeamColor = true,
		TeamColor = Color3.new(0, 1, 0),
		EnemyColor = Color3.new(1, 0, 0),
	ShowTeam = true,
		Info = {
				["Name"] = true,
				["Health"] = true,
				["Weapons"] = true,
				["Distance"] = true
		},

    BoxShift = CFrame.new(0, -1.5, 0),
	BoxSize = Vector3.new(4, 6, 0),
    Color = Color3.fromRGB(255, 255, 255),
    TargetPlayers = true,
    FaceCamera = true, -- i changed last time
    Thickness = 1,
    AttachShift = 1,
    Objects = setmetatable({}, {__mode="kv"}),
    Overrides = {}
}

--Declarations--
local LocalPlayer = game.Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local WorldToViewportPoint = CurrentCamera.WorldToViewportPoint

--Functions--
local function Draw(obj, props)
	local new = Drawing.new(obj)
	
	props = props or {}
	
	for i,v in pairs(props) do
		new[i] = v
	end
	
	return new
end

function ESP:GetTeam(p)
	local ov = self.Overrides.GetTeam
	
	if ov then
		return ov(p)
	end
	
	return p and p.Team
end

function ESP:IsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
	
	if ov then
		return ov(p)
    end
    
    return self:GetTeam(p) == self:GetTeam(LocalPlayer)
end

function ESP:GetColor(obj)
	local ov = self.Overrides.GetColor
	
	if ov then
		return ov(obj)
    end
	
    local p = self:GetPlrFromChar(obj)
	
	return p and (self.UseTeamColor and p.Team and p.Team.TeamColor.Color) or (p.Team and p.Team.TeamColor ~= LocalPlayer.Team.TeamColor and self.EnemyColor or self.TeamColor) -- self.Color
end

function ESP:GetPlrFromChar(char)
	local ov = self.Overrides.GetPlrFromChar
	
	if ov then
		return ov(char)
	end
	
	return game.Players:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for i,v in pairs(self.Objects) do
            if v.Type == "Box" then --fov circle etc
                if v.Temporary then
                    v:Remove()
                else
                    for i,v in pairs(v.Components) do
                        v.Visible = false
                    end
                end
            end
        end
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

function ESP:AddObjectListener(parent, options)
    local function NewListener(c)
        if type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil then
            if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
                if not options.Validator or options.Validator(c) then
                    local box = ESP:Add(c, {
                        PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
                        Color = type(options.Color) == "function" and options.Color(c) or options.Color,
                        ColorDynamic = options.ColorDynamic,
                        Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
                        IsEnabled = options.IsEnabled,
                        RenderInNil = options.RenderInNil
                    })
                    --TODO: add a better way of passing options
                    if options.OnAdded then
                        coroutine.wrap(options.OnAdded)(box)
                    end
                end
            end
        end
    end

    if options.Recursive then
        parent.DescendantAdded:Connect(NewListener)
        for i,v in pairs(parent:GetDescendants()) do
            coroutine.wrap(NewListener)(v)
        end
    else
        parent.ChildAdded:Connect(NewListener)
        for i,v in pairs(parent:GetChildren()) do
            coroutine.wrap(NewListener)(v)
        end
    end
end

local boxBase = {}
boxBase.__index = boxBase

function boxBase:Remove()
    ESP.Objects[self.Object] = nil
    for i,v in pairs(self.Components) do
        v.Visible = false
        v:Remove()
        self.Components[i] = nil
    end
end

function boxBase:Update()
    if not self.PrimaryPart then
        return self:Remove()
    end

    local color
	
    if ESP.Highlighted == self.Object then
       color = ESP.HighlightColor
    else
        color = self.Color or self.ColorDynamic and self:ColorDynamic() or ESP:GetColor(self.Object) or ESP.Color
    end

    local allow = true
	
    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
        allow = false
    end
	
    if self.Player and not ESP.ShowTeam and ESP:IsTeamMate(self.Player) then
        allow = false
    end
	
    if self.Player and not ESP.TargetPlayers then
        allow = false
    end
	
    if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then
        allow = false
    end
	
    if not	workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
        allow = false
    end

    if not allow then
        for i,v in pairs(self.Components) do
            v.Visible = false
        end
        return
    end

    if ESP.Highlighted == self.Object then
        color = ESP.HighlightColor
    end

    --calculations--
    local cf = self.PrimaryPart.CFrame + Vector3.new(0, 1, 0)
	
    if ESP.FaceCamera then
        cf = CFrame.new(cf.p, CurrentCamera.CFrame.p)
    end
	
    local size = self.Size
	local Char = self.PrimaryPart.Parent
	
    local locs = {
        TopLeft = cf * ESP.BoxShift * CFrame.new(size.X/2,size.Y/2,0),
        TopRight = cf * ESP.BoxShift * CFrame.new(-size.X/2,size.Y/2,0),
        BottomLeft = cf * ESP.BoxShift * CFrame.new(size.X/2,-size.Y/2,0),
        BottomRight = cf * ESP.BoxShift * CFrame.new(-size.X/2,-size.Y/2,0),
        TagPos = cf * ESP.BoxShift * CFrame.new(0,size.Y/2,0),
        Torso = cf * ESP.BoxShift
    }

    if ESP.Boxes then
        local TopLeft, Vis1 = WorldToViewportPoint(CurrentCamera, locs.TopLeft.p)
        local TopRight, Vis2 = WorldToViewportPoint(CurrentCamera, locs.TopRight.p)
        local BottomLeft, Vis3 = WorldToViewportPoint(CurrentCamera, locs.BottomLeft.p)
        local BottomRight, Vis4 = WorldToViewportPoint(CurrentCamera, locs.BottomRight.p)

        if self.Components.Quad then
            if Vis1 or Vis2 or Vis3 or Vis4 then
                self.Components.Quad.Visible = true
                self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
                self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
                self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
                self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
                self.Components.Quad.Color = color
            else
                self.Components.Quad.Visible = false
            end
        end
    else
        self.Components.Quad.Visible = false
    end

    if ESP.ShowInfo then
        local TagPos, Vis5 = WorldToViewportPoint(CurrentCamera, locs.TagPos.p)
		
        if Vis5 and Char:FindFirstChild("Humanoid") then
			local Offset = 20
			
			if ESP.Info.Distance == true then
				self.Components.Distance.Visible = true
				self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y - Offset) -- nwm czy nie usunąć -offset :thinking:
				self.Components.Distance.Text = "["..math.floor((CurrentCamera.CFrame.p - cf.p).magnitude).."]"
				self.Components.Distance.Color = color
				Offset = Offset + 14
			else
				self.Components.Distance.Visible = false
			end
			
			if ESP.Info.Weapons == true then
				self.Components.Weapons.Visible = true
				self.Components.Weapons.Position = Vector2.new(TagPos.X, TagPos.Y - Offset)
				self.Components.Weapons.Text = "["..Char.EquippedTool.Value.."]"
				self.Components.Weapons.Color = color
				Offset = Offset + 14
			else
				self.Components.Weapons.Visible = false
			end
			
			
			if ESP.Info.Health == true then
				self.Components.Health.Visible = true
				self.Components.Health.Position = Vector2.new(TagPos.X, TagPos.Y - Offset)
				self.Components.Health.Text = "["..math.floor(Char:FindFirstChildOfClass("Humanoid").Health).."/"..math.floor(Char:FindFirstChildOfClass("Humanoid").MaxHealth).."]"
				self.Components.Health.Color = color
				Offset = Offset + 14
			else
				self.Components.Health.Visible = false
			end
			
			if ESP.Info.Name == true then
				self.Components.Name.Visible = true
				self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y - Offset)
				self.Components.Name.Text = self.Name
				self.Components.Name.Color = color
				Offset = Offset + 14
			else
				self.Components.Name.Visible = false
			end
        else
            self.Components.Name.Visible = false
			self.Components.Health.Visible = false
			self.Components.Weapons.Visible = false
            self.Components.Distance.Visible = false
        end
    else
        self.Components.Name.Visible = false
		self.Components.Health.Visible = false
		self.Components.Weapons.Visible = false
        self.Components.Distance.Visible = false
    end
    
    if ESP.Tracers then
        local TorsoPos, Vis6 = WorldToViewportPoint(CurrentCamera, locs.Torso.p)

        if Vis6 then
            self.Components.Tracer.Visible = true
            self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y)
            self.Components.Tracer.To = Vector2.new(CurrentCamera.ViewportSize.X/2,CurrentCamera.ViewportSize.Y/ESP.AttachShift)
            self.Components.Tracer.Color = color
        else
            self.Components.Tracer.Visible = false
        end
    else
        self.Components.Tracer.Visible = false
    end
end

function ESP:Add(obj, options)
    if not obj.Parent and not options.RenderInNil then
        return warn(obj, "has no parent")
    end

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = "Box",
        Color = options.Color --[[or self:GetColor(obj)]],
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = options.Player or game.Players:GetPlayerFromCharacter(obj),
        PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil
    }, boxBase)

    if self:GetBox(obj) then
        self:GetBox(obj):Remove()
    end

    box.Components["Quad"] = Draw("Quad", {
        Thickness = self.Thickness,
        Color = color,
        Transparency = 1,
        Filled = false,
        Visible = self.Enabled and self.Boxes
    })
	
    box.Components["Name"] = Draw("Text", {
		Text = box.Name,
		Color = box.Color,
		Center = true,
		Outline = true,
        Size = 19,
        Visible = self.Enabled and self.ShowInfo
	})
	
	box.Components["Health"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
        Size = 19,
        Visible = self.Enabled and self.ShowInfo
	})
	
	box.Components["Weapons"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
        Size = 19,
        Visible = self.Enabled and self.ShowInfo
	})
	
	box.Components["Distance"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
        Size = 19,
        Visible = self.Enabled and self.ShowInfo
	})
	
	box.Components["Tracer"] = Draw("Line", {
		Thickness = ESP.Thickness,
		Color = box.Color,
        Transparency = 1,
        Visible = self.Enabled and self.Tracers
    })
	
    self.Objects[obj] = box
    
    obj.AncestryChanged:Connect(function(_, parent)
        if parent == nil and ESP.AutoRemove ~= false then
            box:Remove()
        end
    end)
	
    obj:GetPropertyChangedSignal("Parent"):Connect(function()
        if obj.Parent == nil and ESP.AutoRemove ~= false then
            box:Remove()
        end
    end)

    local hum = obj:FindFirstChildOfClass("Humanoid")
	
	if hum then
        hum.Died:Connect(function()
            if ESP.AutoRemove ~= false then
                box:Remove()
            end
		end)
    end

    return box
end

local function CharAdded(char)
    local p = game.Players:GetPlayerFromCharacter(char)
    if not char:FindFirstChild("HumanoidRootPart") then
        local ev
        ev = char.ChildAdded:Connect(function(c)
            if c.Name == "HumanoidRootPart" then
                ev:Disconnect()
                ESP:Add(char, {
                    Name = p.Name,
                    Player = p,
                    PrimaryPart = c
                })
            end
        end)
    else
        ESP:Add(char, {
            Name = p.Name,
            Player = p,
            PrimaryPart = char.HumanoidRootPart
        })
    end
end

local function PlayerAdded(p)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then
        coroutine.wrap(CharAdded)(p.Character)
    end
end

game.Players.PlayerAdded:Connect(PlayerAdded)

for i,v in pairs(game.Players:GetPlayers()) do
    if v ~= LocalPlayer then
        PlayerAdded(v)
    end
end

game:GetService("RunService").RenderStepped:Connect(function()
    CurrentCamera = workspace.CurrentCamera
	
	if not ESP.Enabled then
		for i,v in pairs(ESP.Objects) do
            if v.Type == "Box" then
                if v.Temporary then
                    v:Remove()
                else
                    for i,v in pairs(v.Components) do
                        v.Visible = false
                    end
                end
            end
        end
	end
	
    for i,v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
        if v.Update then
            local success, errorMSG = pcall(v.Update, v)
			
            if not success then
				warn("[EU]", errorMSG, v.Object:GetFullName())
			end
        end
    end
end)

return ESP
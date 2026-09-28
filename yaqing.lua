--[[
    ╔══════════════════════════════════╗
    ║  雅清脚本 v0.1                    ║
    ║  _雅清制作                        ║
    ╚══════════════════════════════════╝
    功能：
      · 透视：玩家头顶显示名字 + 人物描边（队友绿 / 敌人红）
      · 飞行：5 档速度，全向跟随镜头（滑屏抬头就上飞，低头俯冲）
      · 加速：5 档跑速
      · 跳跃：5 档跳力
    控制：
      · 开关：点功能按钮        飞行快捷键：F（电脑）
      · 飞行：摇杆前推 = 朝镜头方向飞（含上下），左右平移，跳跃键/空格垂直上升，▼/左Ctrl下降
      · 面板顶部可拖动
    声明：仅限在自己或朋友拥有、且服务器主人同意的服务器内使用
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ================= 配置 =================
local FLY_SPEEDS  = {30, 60, 100, 150, 220}
local WALK_SPEEDS = {20, 28, 38, 50, 70}
local JUMP_POWERS = {60, 85, 110, 150, 200}
local DEFAULT_WALK = 16
local DEFAULT_JUMP = 50

-- 配色（暗夜青）
local C = {
    bg     = Color3.fromRGB(13, 17, 21),
    bg2    = Color3.fromRGB(23, 30, 36),
    bg3    = Color3.fromRGB(18, 24, 29),
    line   = Color3.fromRGB(52, 78, 84),
    accent = Color3.fromRGB(64, 224, 208),
    text   = Color3.fromRGB(232, 246, 245),
    dim    = Color3.fromRGB(128, 158, 163),
    off    = Color3.fromRGB(72, 84, 92),
    on     = Color3.fromRGB(64, 224, 208),
    mate   = Color3.fromRGB(90, 255, 140),
    foe    = Color3.fromRGB(255, 90, 90),
}

-- ================= 状态 =================
local state = {
    esp       = false,
    fly       = false,  flyLevel   = 3,
    speed     = false,  speedLevel = 3,
    jump      = false,  jumpLevel  = 3,
}
local flyConn, bodyVel, bodyGyro
local descending = false
local espRunning = false
local espObjects = {}

-- ================= 工具 =================
local function create(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- ================= 主面板 =================
local gui = create("ScreenGui", {
    Name = "YaqingGui",
    ResetOnSpawn = false,
    DisplayOrder = 999,
})
local okGui = pcall(function()
    gui.Parent = game:GetService("CoreGui")
end)
if not okGui or not gui.Parent then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local container = create("Frame", {
    Size = UDim2.new(0, 236, 0, 352),
    Position = UDim2.new(0, 16, 0.32, 0),
    BackgroundColor3 = C.bg,
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    Active = true,
}, gui)
create("UICorner", {CornerRadius = UDim.new(0, 14)}, container)
create("UIStroke", {Color = C.line, Thickness = 1}, container)

-- ===== 标题栏（可拖动） =====
local titleBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = C.bg2,
    BorderSizePixel = 0,
    Active = true,
}, container)
create("UICorner", {CornerRadius = UDim.new(0, 14)}, titleBar)
create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 48, 52)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 21, 26)),
    }),
    Rotation = 15,
}, titleBar)

create("TextLabel", {
    Size = UDim2.new(0.55, 0, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextColor3 = C.accent,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "雅清脚本",
}, titleBar)

create("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0.5, 0, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "_雅清制作v0.1",
}, titleBar)

-- ===== 时钟行 =====
create("Frame", { -- 分隔线
    Size = UDim2.new(1, -16, 0, 1),
    Position = UDim2.new(0, 8, 0, 46),
    BackgroundColor3 = C.line,
    BorderSizePixel = 0,
}, container)

local dotTime = create("Frame", {
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(0, 18, 0, 60),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
}, container)
create("UICorner", {CornerRadius = UDim.new(1, 0)}, dotTime)

local clockLabel
clockLabel = create("TextLabel", {
    Size = UDim2.new(1, -40, 0, 22),
    Position = UDim2.new(0, 34, 0, 53),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 15,
    TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "--:--:--",
}, container)

task.spawn(function()
    while clockLabel and clockLabel.Parent do
        local okT, t = pcall(function()
            return os.date("%H:%M:%S")
        end)
        clockLabel.Text = okT and t or "--:--:--"
        task.wait(0.5)
    end
end)

create("Frame", {
    Size = UDim2.new(1, -16, 0, 1),
    Position = UDim2.new(0, 8, 0, 80),
    BackgroundColor3 = C.line,
    BorderSizePixel = 0,
}, container)

-- ===== 功能行 / 档位行构建 =====
local function featureRow(nameText, y)
    local btn = create("TextButton", {
        Size = UDim2.new(1, -16, 0, 34),
        Position = UDim2.new(0, 8, 0, y),
        BackgroundColor3 = C.bg2,
        Text = "",
        AutoButtonColor = true,
        BorderSizePixel = 0,
    }, container)
    create("UICorner", {CornerRadius = UDim.new(0, 10)}, btn)
    create("UIStroke", {Color = C.line, Thickness = 1}, btn)

    create("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = nameText,
    }, btn)

    local dot = create("Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(1, -20, 0.5, -5),
        BackgroundColor3 = C.off,
        BorderSizePixel = 0,
    }, btn)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, dot)

    return btn, dot
end

local function levelRow(y, onPick)
    local buttons = {}
    local names = {"1", "2", "3", "4", "5"}
    for i = 1, 5 do
        local b = create("TextButton", {
            Size = UDim2.new(0, 40, 0, 24),
            Position = UDim2.new(0, 8 + (i - 1) * 45, 0, y),
            BackgroundColor3 = C.bg3,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = C.dim,
            Text = names[i],
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, container)
        create("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
        create("UIStroke", {Color = C.line, Thickness = 1}, b)
        b.MouseButton1Click:Connect(function()
            onPick(i)
        end)
        buttons[i] = b
    end
    local function highlight(level)
        for i = 1, 5 do
            if i == level then
                buttons[i].BackgroundColor3 = C.accent
                buttons[i].TextColor3 = Color3.fromRGB(10, 16, 18)
            else
                buttons[i].BackgroundColor3 = C.bg3
                buttons[i].TextColor3 = C.dim
            end
        end
    end
    return highlight
end

local function setDot(dot, on)
    dot.BackgroundColor3 = on and C.on or C.off
end

-- ================= 功能：飞行 =================
local function cleanupFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if bodyVel then bodyVel:Destroy() bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
end

local function startFly()
    cleanupFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 9e4
    bodyGyro.Parent = root

    local speed = FLY_SPEEDS[state.flyLevel]

    flyConn = RunService.RenderStepped:Connect(function()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not (r and h and bodyVel and bodyGyro) then return end

        local cam = workspace.CurrentCamera
        local move = h.MoveDirection
        local vel = Vector3.zero

        -- 全向跟随镜头：摇杆前推 = 沿镜头朝向飞（含俯仰），左右平移跟镜头右向
        if move.Magnitude > 0.01 then
            local f = move:Dot(cam.CFrame.LookVector)
            local s = move:Dot(cam.CFrame.RightVector)
            vel = cam.CFrame.LookVector * f + cam.CFrame.RightVector * s
            if vel.Magnitude > 0.01 then
                vel = vel.Unit * speed
            end
        end

        -- 垂直升降
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or h.Jump then
            vel = vel + Vector3.new(0, speed, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or descending then
            vel = vel - Vector3.new(0, speed, 0)
        end

        bodyVel.Velocity = vel
        bodyGyro.CFrame = CFrame.new(r.Position, r.Position + cam.CFrame.LookVector)
    end)
end

-- ================= 功能：加速 / 跳跃 =================
local function applySpeed()
    local hum = getHumanoid()
    if not hum then return end
    hum.WalkSpeed = state.speed and WALK_SPEEDS[state.speedLevel] or DEFAULT_WALK
end

local function applyJump()
    local hum = getHumanoid()
    if not hum then return end
    hum.UseJumpPower = true
    hum.JumpPower = state.jump and JUMP_POWERS[state.jumpLevel] or DEFAULT_JUMP
end

-- ================= 功能：透视 =================
local function isTeammate(plr)
    if plr.Team ~= nil and LocalPlayer.Team ~= nil then
        return plr.Team == LocalPlayer.Team
    end
    return false
end

local function clearESPOne(plr)
    local o = espObjects[plr]
    if o then
        pcall(function() o.hl:Destroy() end)
        pcall(function() o.bb:Destroy() end)
        espObjects[plr] = nil
    end
end

local function applyESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if head and root then
                local teammate = isTeammate(plr)
                local color = teammate and C.mate or C.foe
                local o = espObjects[plr]
                if not o or not o.hl.Parent or o.hl.Parent ~= char then
                    clearESPOne(plr)
                    local hl = Instance.new("Highlight")
                    hl.FillTransparency = 0.68
                    hl.FillColor = color
                    hl.OutlineColor = color
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = char

                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.new(0, 140, 0, 22)
                    bb.StudsOffset = Vector3.new(0, 2.6, 0)
                    bb.AlwaysOnTop = true
                    bb.Parent = head

                    local tl = Instance.new("TextLabel")
                    tl.Size = UDim2.new(1, 0, 1, 0)
                    tl.BackgroundTransparency = 1
                    tl.Font = Enum.Font.GothamBold
                    tl.TextSize = 13
                    tl.TextColor3 = color
                    tl.TextStrokeTransparency = 0.25
                    tl.Text = plr.Name .. (teammate and " · 队友" or "")
                    tl.Parent = bb

                    espObjects[plr] = {hl = hl, bb = bb}
                else
                    o.hl.FillColor = color
                    o.hl.OutlineColor = color
                end
            end
        end
    end
end

local function startESP()
    if espRunning then return end
    espRunning = true
    task.spawn(function()
        while espRunning do
            pcall(applyESP)
            task.wait(0.8)
        end
    end)
end

local function stopESP()
    espRunning = false
    for plr in pairs(espObjects) do
        clearESPOne(plr)
    end
end

Players.PlayerRemoving:Connect(function(plr)
    clearESPOne(plr)
end)

-- ================= 面板布线 =================
-- 透视
local espBtn, espDot = featureRow("透视 ESP", 92)
espBtn.MouseButton1Click:Connect(function()
    state.esp = not state.esp
    setDot(espDot, state.esp)
    if state.esp then startESP() else stopESP() end
end)

-- 飞行
local flyBtn, flyDot = featureRow("飞行 FLY", 134)
flyBtn.MouseButton1Click:Connect(function()
    state.fly = not state.fly
    setDot(flyDot, state.fly)
    if state.fly then startFly() else cleanupFly() end
end)
local flyHighlight = levelRow(172, function(i)
    state.flyLevel = i
    flyHighlight(i)
    if state.fly then startFly() end -- 换档即时生效
end)
flyHighlight(state.flyLevel)

-- 加速
local speedBtn, speedDot = featureRow("加速 SPEED", 204)
speedBtn.MouseButton1Click:Connect(function()
    state.speed = not state.speed
    setDot(speedDot, state.speed)
    applySpeed()
end)
local speedHighlight = levelRow(242, function(i)
    state.speedLevel = i
    speedHighlight(i)
    if state.speed then applySpeed() end
end)
speedHighlight(state.speedLevel)

-- 跳跃
local jumpBtn, jumpDot = featureRow("跳跃 JUMP", 274)
jumpBtn.MouseButton1Click:Connect(function()
    state.jump = not state.jump
    setDot(jumpDot, state.jump)
    applyJump()
end)
local jumpHighlight = levelRow(312, function(i)
    state.jumpLevel = i
    jumpHighlight(i)
    if state.jump then applyJump() end
end)
jumpHighlight(state.jumpLevel)

-- ================= 拖动（标题栏） =================
do
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = container.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            container.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ================= 快捷键：F 开关飞行 =================
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.F then
        state.fly = not state.fly
        setDot(flyDot, state.fly)
        if state.fly then startFly() else cleanupFly() end
    end
end)

-- ================= 重生自动恢复 =================
LocalPlayer.CharacterAdded:Connect(function()
    cleanupFly()
    task.wait(1)
    if state.fly then startFly() end
    applySpeed()
    applyJump()
end)

print("[雅清] v0.1 加载完成 · 透视/飞行/加速/跳跃 已就绪")

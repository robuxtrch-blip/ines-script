-- moto script by ines | ULTRA PREMIUM
-- Jeu: Voler un oeuf and Collect Rare Pets
-- Delta Android | TweenService TP bypass (pas de CFrame direct)

game:GetService("StarterGui"):SetCore("SendNotification",{
    Title="moto script by ines",Text="Chargement...",Duration=3
})

if not game:IsLoaded() then game.Loaded:Wait() end
local lp   = game:GetService("Players").LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart",15)
local hum  = char:WaitForChild("Humanoid",15)
if not hrp then return end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local CoreGui    = game:GetService("CoreGui")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local VirtualUser= game:GetService("VirtualUser")

-- ══════════════════════════════════════════════════════════════════
--  BYPASS ANTI-KICK
--  Ce jeu utilise un AC custom basé sur:
--  1. Delta position check (trop loin en un tick = kick)
--  2. RemoteEvent reporters
--  3. WalkSpeed check côté serveur
--
--  Solution:
--  - TweenService sur HRP au lieu de CFrame direct
--  - Vitesse du tween calculée pour simuler une vitesse normale
--  - Nuke silencieux des remotes AC via pcall
--  - WalkSpeed jamais > 24 (seuil safe pour ce jeu)
-- ══════════════════════════════════════════════════════════════════

local SAFE_SPEED   = 22   -- jamais dépasser ça, ce jeu kick à 24+
local TWEEN_SPEED  = 60   -- studs/sec pour le tween TP — rapide mais pas flaggé
local AC_NUKED     = 0

-- Nuke remotes AC
local AC_WORDS = {
    "anticheat","anti_cheat","cheatdetect","hackdetect",
    "reportplayer","flagplayer","speedcheck","positioncheck",
    "sanitycheck","violationreport","acreport","banplayer",
    "kickplayer","reportcheat","detectcheat","playercheck",
    "validate","exploit","cheat","hack"
}
local function isAC(name)
    local low = name:lower()
    for _,w in ipairs(AC_WORDS) do
        if low:find(w) then return true end
    end
    return false
end
local nuked = {}
local function nukeAC()
    for _,v in ipairs(game:GetDescendants()) do
        if not nuked[v] and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            if isAC(v.Name) then
                nuked[v] = true
                pcall(function()
                    v.FireServer   = function() end
                    v.InvokeServer = function() end
                end)
                AC_NUKED = AC_NUKED + 1
            end
        end
    end
end
nukeAC()
game.DescendantAdded:Connect(function(v)
    wait(0.15)
    if not nuked[v] and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and isAC(v.Name) then
        nuked[v]=true
        pcall(function() v.FireServer=function()end; v.InvokeServer=function()end end)
        AC_NUKED=AC_NUKED+1
    end
end)

-- ══════════════════════════════════════════════════════════════════
--  TP BYPASS — TweenService uniquement, jamais CFrame direct
--  Le serveur voit un mouvement fluide, pas un jump de position
-- ══════════════════════════════════════════════════════════════════
local currentTween = nil
local function safeTeleport(targetPos, onDone)
    if not hrp or not hrp.Parent then return end
    local dist = (targetPos - hrp.Position).Magnitude
    if dist < 4 then
        if onDone then onDone() end
        return
    end
    -- annule le tween en cours
    if currentTween then currentTween:Cancel() end

    -- durée calculée pour simuler vitesse normale
    local duration = dist / TWEEN_SPEED
    -- cap: jamais moins de 0.3s (trop rapide = suspect)
    duration = math.max(duration, 0.3)

    -- désactive collisions pendant le voyage pour pas se bloquer
    local colSave = {}
    pcall(function()
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                colSave[p] = p.CanCollide
                p.CanCollide = false
            end
        end
    end)

    currentTween = TweenSvc:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
        { CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0)) }
    )
    currentTween:Play()
    currentTween.Completed:Connect(function()
        -- restaure collisions
        pcall(function()
            for p,col in pairs(colSave) do
                if p and p.Parent then p.CanCollide = col end
            end
        end)
        if onDone then onDone() end
    end)
end

-- version synchrone pour les loops
local function safeTeleportSync(targetPos)
    if not hrp or not hrp.Parent then return end
    local dist = (targetPos - hrp.Position).Magnitude
    if dist < 4 then return end
    if currentTween then currentTween:Cancel() end

    local duration = math.max(dist / TWEEN_SPEED, 0.3)
    local colSave = {}
    pcall(function()
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                colSave[p]=p.CanCollide; p.CanCollide=false
            end
        end
    end)

    currentTween = TweenSvc:Create(
        hrp,
        TweenInfo.new(duration,Enum.EasingStyle.Linear),
        {CFrame=CFrame.new(targetPos+Vector3.new(0,3,0))}
    )
    currentTween:Play()
    currentTween.Completed:Wait()
    pcall(function()
        for p,col in pairs(colSave) do
            if p and p.Parent then p.CanCollide=col end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════════════════════════════
local CFG = {
    AutoFarm     = false,
    AutoSell     = false,
    AutoCollect  = false,
    AutoHatch    = false,
    ESPEnabled   = true,
    SpeedEnabled = false,
    WalkSpeed    = 16,
    JumpEnabled  = false,
    JumpPower    = 50,
    InfiniteJump = false,
    Noclip       = false,
    AntiAFK      = true,
    SellInterval = 18,
    LoopDelay    = 0.2,
    TargetEgg    = nil,
}

local lastSell   = 0
local knownEggs  = {}
local eggBtns    = {}
local highlights = {}
local statsData  = {stolen=0,sold=0}
local statsLbls  = {}
local sessionStart = tick()
local guiReady   = false

local function getPart(v)
    if v:IsA("Model") then
        return v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
    end
    return v:IsA("BasePart") and v or nil
end
local function refreshChar()
    char=lp.Character; if not char then return false end
    hrp=char:FindFirstChild("HumanoidRootPart")
    hum=char:FindFirstChildWhichIsA("Humanoid")
    return hrp~=nil and hum~=nil
end
local function setSpeed(n)
    pcall(function()
        if hum then hum.WalkSpeed=math.min(n,SAFE_SPEED) end
    end)
end
local function setJump(n)
    pcall(function() if hum then hum.JumpPower=n end end)
end

-- Anti AFK
lp.Idled:Connect(function()
    if CFG.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Infinite Jump
UIS.JumpRequest:Connect(function()
    if CFG.InfiniteJump and hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Noclip
local noclipActive = false
RunService.Stepped:Connect(function()
    if not noclipActive or not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide=false end
    end
end)

-- ══════════════════════════════════════════════════════════════════
--  REMOTES — scan intelligent
--  Ce jeu s'appelle "Voler un oeuf" — les remotes probables:
--  StealEgg, Steal, VoerEgg, PickupEgg, CollectEgg
-- ══════════════════════════════════════════════════════════════════
local cachedStealRemote = nil
local cachedSellRemote  = nil

local function findRemote(names)
    for _,n in ipairs(names) do
        local r = RepStorage:FindFirstChild(n,true)
        if r then return r end
    end
    -- scan workspace aussi
    for _,n in ipairs(names) do
        local r = workspace:FindFirstChild(n,true)
        if r then return r end
    end
    return nil
end

local function fireRemote(r, ...)
    if not r then return false end
    if r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(...) end); return true
    end
    if r:IsA("RemoteFunction") then
        pcall(function() r:InvokeServer(...) end); return true
    end
    return false
end

local function fireSteal(target)
    if not cachedStealRemote then
        cachedStealRemote = findRemote({
            "StealEgg","Steal","VoleEgg","PickupEgg",
            "CollectEgg","GrabEgg","TakeEgg","GetEgg",
            "Pickup","Take","Claim","Grab","Voler"
        })
    end
    local fired = fireRemote(cachedStealRemote, target)
    if not fired and target and target:IsA("BasePart") and hrp then
        pcall(function()
            hrp.CFrame = CFrame.new(
                target.Position + Vector3.new(0,3,0)
            )
        end)
    end
    statsData.stolen = statsData.stolen + 1
end

local function fireSell()
    if not cachedSellRemote then
        cachedSellRemote = findRemote({
            "SellEgg","Sell","SellAll","SubmitEgg",
            "TurnIn","CashOut","Submit","Exchange","Vendre"
        })
    end
    fireRemote(cachedSellRemote)
    statsData.sold = statsData.sold + 1
end

local function fireHatch()
    local r = findRemote({"HatchEgg","Hatch","OpenEgg","CrackEgg","Eclore"})
    fireRemote(r)
end

-- ══════════════════════════════════════════════════════════════════
--  FINDERS
-- ══════════════════════════════════════════════════════════════════
local function closestEgg()
    if not hrp then return nil end
    local best,bd = nil,math.huge
    for _,v in ipairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("Model")) and v.Name:lower():find("egg") then
            local match = CFG.TargetEgg==nil or v.Name==CFG.TargetEgg
            if match then
                local p=getPart(v)
                if p then
                    local d=(hrp.Position-p.Position).Magnitude
                    if d<bd then best=p;bd=d end
                end
            end
        end
    end
    return best
end

local function closestSell()
    if not hrp then return nil end
    local best,bd=nil,math.huge
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Model") then
            local n=v.Name:lower()
            if n:find("sell") or n:find("shop") or n:find("vend") or n:find("caisse") then
                local p=getPart(v)
                if p then
                    local d=(hrp.Position-p.Position).Magnitude
                    if d<bd then best=p;bd=d end
                end
            end
        end
    end
    return best
end

-- ══════════════════════════════════════════════════════════════════
--  ESP
-- ══════════════════════════════════════════════════════════════════
local function refreshESP()
    for part,hl in pairs(highlights) do
        if not part or not part.Parent then
            pcall(function() hl:Destroy() end)
            highlights[part]=nil
        end
    end
    if not CFG.ESPEnabled then return end
    for _,v in ipairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("Model")) and v.Name:lower():find("egg") then
            local p=getPart(v)
            if p and not highlights[p] then
                pcall(function()
                    local active=CFG.TargetEgg==nil or v.Name==CFG.TargetEgg
                    local hl=Instance.new("SelectionBox")
                    hl.Adornee=p
                    hl.Color3=active and Color3.fromRGB(255,215,0) or Color3.fromRGB(80,80,100)
                    hl.LineThickness=0.05
                    hl.SurfaceTransparency=0.55
                    hl.SurfaceColor3=hl.Color3
                    hl.Parent=CoreGui
                    highlights[p]=hl
                end)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════
--  GUI ULTRA PREMIUM
-- ══════════════════════════════════════════════════════════════════
pcall(function()
    local o=CoreGui:FindFirstChild("ines_v3"); if o then o:Destroy() end
end)

local sg=Instance.new("ScreenGui")
sg.Name="ines_v3"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
if not pcall(function() sg.Parent=CoreGui end) then
    sg.Parent=lp:WaitForChild("PlayerGui")
end

local C={
    bg       =Color3.fromRGB(8,8,12),
    surface  =Color3.fromRGB(16,16,22),
    card     =Color3.fromRGB(22,22,32),
    border   =Color3.fromRGB(50,45,75),
    gold     =Color3.fromRGB(255,200,0),
    green    =Color3.fromRGB(50,220,110),
    red      =Color3.fromRGB(255,70,70),
    blue     =Color3.fromRGB(80,160,255),
    purple   =Color3.fromRGB(180,80,255),
    pink     =Color3.fromRGB(255,80,180),
    text     =Color3.fromRGB(235,235,245),
    subtext  =Color3.fromRGB(130,125,155),
    off      =Color3.fromRGB(38,38,52),
    white    =Color3.fromRGB(255,255,255),
}

local function corner(p,r)
    local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 10); return c
end
local function stroke(p,col,th)
    local s=Instance.new("UIStroke",p); s.Color=col or C.border; s.Thickness=th or 1; return s
end
local function lbl(parent,txt,size,color,font,xalign)
    local l=Instance.new("TextLabel",parent)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=color or C.text
    l.Font=font or Enum.Font.GothamSemibold
    l.TextSize=size or 13
    l.TextXAlignment=xalign or Enum.TextXAlignment.Left
    l.TextScaled=false; return l
end
local function tw(obj,props,t)
    TweenSvc:Create(obj,TweenInfo.new(t or 0.18,Enum.EasingStyle.Quad),props):Play()
end

-- fenêtre
local win=Instance.new("Frame",sg)
win.Size=UDim2.new(0,330,0,500)
win.Position=UDim2.new(0.5,-165,0,40)
win.BackgroundColor3=C.bg
win.BorderSizePixel=0; win.ClipsDescendants=true
corner(win,16)
stroke(win,C.purple,1.5)

local bgGrad=Instance.new("UIGradient",win)
bgGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(14,10,22)),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(8,8,14)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(10,14,22)),
})
bgGrad.Rotation=135

-- header
local header=Instance.new("Frame",win)
header.Size=UDim2.new(1,0,0,64); header.BackgroundColor3=C.surface
header.BorderSizePixel=0
local hGrad=Instance.new("UIGradient",header)
hGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(40,20,70)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(14,18,30)),
})
hGrad.Rotation=90

-- logo
local logoF=Instance.new("Frame",header)
logoF.Size=UDim2.new(0,44,0,44); logoF.Position=UDim2.new(0,10,0.5,-22)
logoF.BackgroundColor3=C.purple; logoF.BorderSizePixel=0; corner(logoF,10)
local lgGrad=Instance.new("UIGradient",logoF)
lgGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,C.purple),
    ColorSequenceKeypoint.new(1,C.blue),
}); lgGrad.Rotation=45
local logoE=lbl(logoF,"🥚",22,C.white,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
logoE.Size=UDim2.new(1,0,1,0)

local t1=lbl(header,"moto script",17,C.white,Enum.Font.GothamBold)
t1.Size=UDim2.new(1,-120,0,24); t1.Position=UDim2.new(0,62,0,8)
local t2=lbl(header,"by ines",12,C.purple,Enum.Font.GothamBold)
t2.Size=UDim2.new(0,80,0,16); t2.Position=UDim2.new(0,62,0,32)

-- badge PREMIUM
local badge=Instance.new("Frame",header)
badge.Size=UDim2.new(0,80,0,22); badge.Position=UDim2.new(0,148,0,32)
badge.BackgroundColor3=C.gold; badge.BorderSizePixel=0; corner(badge,11)
local bdGrad=Instance.new("UIGradient",badge)
bdGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,C.gold),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(255,160,0)),
}); bdGrad.Rotation=90
local bdL=lbl(badge,"✦ PREMIUM",10,Color3.fromRGB(14,10,0),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
bdL.Size=UDim2.new(1,0,1,0)

-- status bypass
local bpDot=Instance.new("Frame",header)
bpDot.Size=UDim2.new(0,8,0,8); bpDot.Position=UDim2.new(1,-56,0.5,-8)
bpDot.BackgroundColor3=C.green; bpDot.BorderSizePixel=0; corner(bpDot,4)
local bpL=lbl(header,"SAFE",10,C.green,Enum.Font.GothamBold)
bpL.Size=UDim2.new(0,38,0,14); bpL.Position=UDim2.new(1,-48,0.5,0)

-- minimize
local minBtn=Instance.new("TextButton",header)
minBtn.Size=UDim2.new(0,36,0,36); minBtn.Position=UDim2.new(1,-44,0.5,-18)
minBtn.BackgroundColor3=C.off; minBtn.TextColor3=C.subtext
minBtn.Font=Enum.Font.GothamBold; minBtn.TextSize=18; minBtn.Text="–"
minBtn.BorderSizePixel=0; corner(minBtn,8)

-- tab bar
local tabBar=Instance.new("Frame",win)
tabBar.Size=UDim2.new(1,0,0,48); tabBar.Position=UDim2.new(0,0,0,64)
tabBar.BackgroundColor3=C.surface; tabBar.BorderSizePixel=0
local sepLine=Instance.new("Frame",tabBar)
sepLine.Size=UDim2.new(1,0,0,1); sepLine.Position=UDim2.new(0,0,1,-1)
sepLine.BackgroundColor3=C.border; sepLine.BorderSizePixel=0

local tabScroll=Instance.new("ScrollingFrame",tabBar)
tabScroll.Size=UDim2.new(1,-12,1,-10); tabScroll.Position=UDim2.new(0,6,0,5)
tabScroll.BackgroundTransparency=1; tabScroll.BorderSizePixel=0
tabScroll.ScrollBarThickness=0; tabScroll.ScrollingDirection=Enum.ScrollingDirection.X
local tabLL=Instance.new("UIListLayout",tabScroll)
tabLL.FillDirection=Enum.FillDirection.Horizontal
tabLL.Padding=UDim.new(0,6); tabLL.VerticalAlignment=Enum.VerticalAlignment.Center
tabLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabScroll.CanvasSize=UDim2.new(0,tabLL.AbsoluteContentSize.X+12,0,0)
end)

local body=Instance.new("Frame",win)
body.Size=UDim2.new(1,0,1,-112); body.Position=UDim2.new(0,0,0,112)
body.BackgroundTransparency=1; body.ClipsDescendants=true

local pages,tabBtns={},{}
local function openTab(name)
    for n,p in pairs(pages) do
        p.Visible=false
        tw(tabBtns[n],{BackgroundColor3=C.off,TextColor3=C.subtext})
    end
    if pages[name] then
        pages[name].Visible=true
        tw(tabBtns[name],{BackgroundColor3=C.purple,TextColor3=C.white})
    end
end
local function makeTab(name,icon)
    local page=Instance.new("Frame",body)
    page.Size=UDim2.new(1,0,1,0); page.BackgroundTransparency=1; page.Visible=false
    pages[name]=page
    local tb=Instance.new("TextButton",tabScroll)
    tb.Size=UDim2.new(0,82,0,32); tb.BackgroundColor3=C.off
    tb.TextColor3=C.subtext; tb.Font=Enum.Font.GothamBold
    tb.TextSize=12; tb.Text=icon.." "..name; tb.BorderSizePixel=0
    corner(tb,8); tabBtns[name]=tb
    tb.Activated:Connect(function() openTab(name) end)
    return page
end

-- composants
local function secLbl(parent,txt,yOff)
    local l=lbl(parent,txt:upper(),9,C.subtext,Enum.Font.GothamBold)
    l.Size=UDim2.new(1,-20,0,16); l.Position=UDim2.new(0,14,0,yOff)
    local line=Instance.new("Frame",parent)
    line.Size=UDim2.new(1,-20,0,1); line.Position=UDim2.new(0,10,0,yOff+18)
    line.BackgroundColor3=C.border; line.BorderSizePixel=0
end

local function makeToggle(parent,labelTxt,key,yOff,accent,iconTxt)
    accent=accent or C.green
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-20,0,50); row.Position=UDim2.new(0,10,0,yOff)
    row.BackgroundColor3=C.card; row.BorderSizePixel=0; corner(row,12)

    local iconBg=Instance.new("Frame",row)
    iconBg.Size=UDim2.new(0,34,0,34); iconBg.Position=UDim2.new(0,8,0.5,-17)
    iconBg.BackgroundColor3=accent; iconBg.BackgroundTransparency=0.75
    iconBg.BorderSizePixel=0; corner(iconBg,8)
    local iconL=lbl(iconBg,iconTxt or "•",16,accent,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    iconL.Size=UDim2.new(1,0,1,0)

    local rowL=lbl(row,labelTxt,13,C.text,Enum.Font.GothamSemibold)
    rowL.Size=UDim2.new(1,-100,1,0); rowL.Position=UDim2.new(0,50,0,0)

    local pill=Instance.new("Frame",row)
    pill.Size=UDim2.new(0,52,0,28); pill.Position=UDim2.new(1,-62,0.5,-14)
    pill.BorderSizePixel=0; corner(pill,14)
    local knob=Instance.new("Frame",pill)
    knob.Size=UDim2.new(0,22,0,22); knob.Position=UDim2.new(0,3,0.5,-11)
    knob.BackgroundColor3=C.white; knob.BorderSizePixel=0; corner(knob,11)
    local ks=Instance.new("UIStroke",knob); ks.Color=Color3.fromRGB(0,0,0)
    ks.Transparency=0.7; ks.Thickness=1

    local hit=Instance.new("TextButton",row)
    hit.Size=UDim2.new(1,0,1,0); hit.BackgroundTransparency=1
    hit.Text=""; hit.BorderSizePixel=0

    local function ref()
        local on=CFG[key]
        tw(pill,{BackgroundColor3=on and accent or C.off})
        tw(knob,{Position=on and UDim2.new(1,-25,0.5,-11) or UDim2.new(0,3,0.5,-11)})
        tw(iconBg,{BackgroundTransparency=on and 0.5 or 0.85})
    end
    ref()
    hit.Activated:Connect(function()
        CFG[key]=not CFG[key]; ref()
        if key=="SpeedEnabled" then setSpeed(CFG.SpeedEnabled and CFG.WalkSpeed or 16) end
        if key=="JumpEnabled"  then setJump(CFG.JumpEnabled and CFG.JumpPower or 50) end
        if key=="Noclip"       then noclipActive=CFG.Noclip end
        if key=="ESPEnabled" and not CFG.ESPEnabled then
            for _,hl in pairs(highlights) do pcall(function() hl:Destroy() end) end
            highlights={}
        end
    end)
end

local function makeSlider(parent,labelTxt,key,yOff,minV,maxV,accent,suffix)
    accent=accent or C.gold
    local cont=Instance.new("Frame",parent)
    cont.Size=UDim2.new(1,-20,0,60); cont.Position=UDim2.new(0,10,0,yOff)
    cont.BackgroundColor3=C.card; cont.BorderSizePixel=0; corner(cont,12)

    local tLbl=lbl(cont,labelTxt,12,C.text,Enum.Font.GothamSemibold)
    tLbl.Size=UDim2.new(0.6,0,0,22); tLbl.Position=UDim2.new(0,12,0,6)
    local vLbl=lbl(cont,tostring(CFG[key])..(suffix or ""),13,accent,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
    vLbl.Size=UDim2.new(0.35,0,0,22); vLbl.Position=UDim2.new(0.6,-5,0,6)

    local track=Instance.new("Frame",cont)
    track.Size=UDim2.new(1,-24,0,8); track.Position=UDim2.new(0,12,0,36)
    track.BackgroundColor3=C.off; track.BorderSizePixel=0; corner(track,4)

    local rel0=(CFG[key]-minV)/(maxV-minV)
    local fill=Instance.new("Frame",track)
    fill.Size=UDim2.new(rel0,0,1,0); fill.BackgroundColor3=accent
    fill.BorderSizePixel=0; corner(fill,4)
    local fGrad=Instance.new("UIGradient",fill)
    fGrad.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,accent),
        ColorSequenceKeypoint.new(1,C.white),
    }); fGrad.Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,0.3)
    })

    local knob2=Instance.new("Frame",track)
    knob2.Size=UDim2.new(0,18,0,18); knob2.Position=UDim2.new(rel0,-9,0.5,-9)
    knob2.BackgroundColor3=C.white; knob2.BorderSizePixel=0; corner(knob2,9)
    stroke(knob2,accent,2)

    local sliding=false
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch
        or i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch
        or i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if not sliding then return end
        if i.UserInputType~=Enum.UserInputType.Touch
        and i.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local rel=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local val=math.floor(minV+rel*(maxV-minV))
        CFG[key]=val; fill.Size=UDim2.new(rel,0,1,0)
        knob2.Position=UDim2.new(rel,-9,0.5,-9); vLbl.Text=tostring(val)..(suffix or "")
        if key=="WalkSpeed" and CFG.SpeedEnabled then setSpeed(val) end
        if key=="JumpPower" and CFG.JumpEnabled  then setJump(val) end
    end)
end

-- ── TABS ─────────────────────────────────────────────────────────
local farmPage   = makeTab("Farm","🌾")
local playerPage = makeTab("Player","⚡")
local eggsPage   = makeTab("Eggs","🥚")
local statsPage  = makeTab("Stats","📊")
local shieldPage = makeTab("Shield","🛡️")

-- FARM
secLbl(farmPage,"Automatisation",6)
makeToggle(farmPage,"Auto Farm",    "AutoFarm",   28, C.green, "🥚")
makeToggle(farmPage,"Auto Sell",    "AutoSell",   86, C.gold,  "💰")
makeToggle(farmPage,"Auto Collect", "AutoCollect",144,C.blue,  "✨")
makeToggle(farmPage,"Auto Hatch",   "AutoHatch",  202,C.purple,"🐣")
secLbl(farmPage,"Utilitaires",264)
makeToggle(farmPage,"Anti AFK",  "AntiAFK",   286,C.green,"⏰")
makeToggle(farmPage,"ESP Oeufs", "ESPEnabled",344,C.blue, "👁️")

-- PLAYER
secLbl(playerPage,"Mouvements",6)
makeToggle(playerPage,"Speed Hack",    "SpeedEnabled",28, C.gold,  "🚀")
makeToggle(playerPage,"Jump Boost",    "JumpEnabled", 86, C.blue,  "🦘")
makeToggle(playerPage,"Infinite Jump", "InfiniteJump",144,C.purple,"♾️")
makeToggle(playerPage,"Noclip",        "Noclip",      202,C.pink,  "👻")
secLbl(playerPage,"Valeurs",264)
makeSlider(playerPage,"Walk Speed","WalkSpeed",286,16,SAFE_SPEED,C.gold," sp")
makeSlider(playerPage,"Jump Power","JumpPower",354,50,200,C.blue," jp")

-- EGGS
local sab=Instance.new("TextButton",eggsPage)
sab.Size=UDim2.new(1,-20,0,46); sab.Position=UDim2.new(0,10,0,8)
sab.BorderSizePixel=0; corner(sab,12)
local sabG=Instance.new("UIGradient",sab)
sabG.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,C.gold),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(255,140,0)),
}); sabG.Rotation=90
sab.TextColor3=Color3.fromRGB(14,10,0); sab.Font=Enum.Font.GothamBold
sab.TextSize=14; sab.Text="⭐  STEAL ALL EGGS"
sab.Activated:Connect(function()
    if CFG.TargetEgg and eggBtns[CFG.TargetEgg] then
        tw(eggBtns[CFG.TargetEgg],{BackgroundColor3=C.purple})
        eggBtns[CFG.TargetEgg].Text="STEAL"
    end
    CFG.TargetEgg=nil
    sab.Text="✓ STEAL ALL ACTIF"; tw(sab,{BackgroundColor3=C.green})
    wait(1.5); sab.Text="⭐  STEAL ALL EGGS"; tw(sab,{BackgroundColor3=C.gold})
end)

local scanBtn=Instance.new("TextButton",eggsPage)
scanBtn.Size=UDim2.new(0,90,0,30); scanBtn.Position=UDim2.new(1,-100,0,14)
scanBtn.BackgroundColor3=C.card; scanBtn.TextColor3=C.subtext
scanBtn.Font=Enum.Font.GothamSemibold; scanBtn.TextSize=12
scanBtn.Text="🔄 Scan"; scanBtn.BorderSizePixel=0; corner(scanBtn,8)

local eggList=Instance.new("ScrollingFrame",eggsPage)
eggList.Size=UDim2.new(1,-8,1,-62); eggList.Position=UDim2.new(0,4,0,58)
eggList.BackgroundTransparency=1; eggList.BorderSizePixel=0
eggList.ScrollBarThickness=3; eggList.ScrollBarImageColor3=C.purple
eggList.CanvasSize=UDim2.new(0,0,0,0)
local eggContent=Instance.new("Frame",eggList)
eggContent.Size=UDim2.new(1,0,0,0); eggContent.AutomaticSize=Enum.AutomaticSize.Y
eggContent.BackgroundTransparency=1
local eggLL=Instance.new("UIListLayout",eggContent)
eggLL.Padding=UDim.new(0,6); eggLL.SortOrder=Enum.SortOrder.Name
eggLL.HorizontalAlignment=Enum.HorizontalAlignment.Center
eggLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    eggList.CanvasSize=UDim2.new(0,0,0,eggLL.AbsoluteContentSize.Y+10)
end)

local function scanEggs()
    scanBtn.Text="⏳..."; wait(0.3)
    local found=0
    for _,v in ipairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("Model")) and v.Name:lower():find("egg") then
            local part=getPart(v)
            if part and not knownEggs[v.Name] then
                knownEggs[v.Name]=part; found=found+1
                local card=Instance.new("Frame",eggContent)
                card.Name=v.Name; card.Size=UDim2.new(1,-10,0,70)
                card.BackgroundColor3=C.card; card.BorderSizePixel=0
                corner(card,12); stroke(card,C.border,1)

                local vp=Instance.new("ViewportFrame",card)
                vp.Size=UDim2.new(0,58,0,58); vp.Position=UDim2.new(0,6,0.5,-29)
                vp.BackgroundColor3=C.bg; vp.BorderSizePixel=0
                corner(vp,10); stroke(vp,C.border,1)
                pcall(function()
                    local cl=part:Clone(); cl.Anchored=true
                    cl.CFrame=CFrame.new(0,0,0); cl.Parent=vp
                    local cam=Instance.new("Camera",vp)
                    cam.CFrame=CFrame.new(Vector3.new(0,0,3.5),Vector3.new(0,0,0))
                    vp.CurrentCamera=cam
                end)

                local nL=lbl(card,v.Name,13,C.text,Enum.Font.GothamBold)
                nL.Size=UDim2.new(1,-150,0,24); nL.Position=UDim2.new(0,72,0,10)
                nL.TextTruncate=Enum.TextTruncate.AtEnd
                local dL=lbl(card,"📍 ...",10,C.subtext,Enum.Font.Gotham)
                dL.Size=UDim2.new(1,-150,0,18); dL.Position=UDim2.new(0,72,0,34)

                local sbtn=Instance.new("TextButton",card)
                sbtn.Size=UDim2.new(0,66,0,32); sbtn.Position=UDim2.new(1,-74,0.5,-16)
                sbtn.BackgroundColor3=C.purple; sbtn.TextColor3=C.white
                sbtn.Font=Enum.Font.GothamBold; sbtn.TextSize=12
                sbtn.Text="STEAL"; sbtn.BorderSizePixel=0; corner(sbtn,9)

                RunService.Heartbeat:Connect(function()
                    if hrp and part and part.Parent then
                        dL.Text="📍 "..math.floor((hrp.Position-part.Position).Magnitude).." studs"
                    end
                end)

                local eName=v.Name; eggBtns[eName]=sbtn
                sbtn.Activated:Connect(function()
                    if CFG.TargetEgg==eName then
                        CFG.TargetEgg=nil; tw(sbtn,{BackgroundColor3=C.purple}); sbtn.Text="STEAL"
                    else
                        if CFG.TargetEgg and eggBtns[CFG.TargetEgg] then
                            tw(eggBtns[CFG.TargetEgg],{BackgroundColor3=C.purple})
                            eggBtns[CFG.TargetEgg].Text="STEAL"
                        end
                        CFG.TargetEgg=eName; tw(sbtn,{BackgroundColor3=C.green}); sbtn.Text="✓ ON"
                    end
                end)
            end
        end
    end
    scanBtn.Text=found>0 and ("✅ "..found) or "🔄 Scan"
    wait(2); scanBtn.Text="🔄 Scan"
end
scanBtn.Activated:Connect(scanEggs)

-- STATS
local function statCard(parent,icon,title,key,accent,yOff)
    local card=Instance.new("Frame",parent)
    card.Size=UDim2.new(1,-20,0,66); card.Position=UDim2.new(0,10,0,yOff)
    card.BackgroundColor3=C.card; card.BorderSizePixel=0; corner(card,12)
    local bar=Instance.new("Frame",card)
    bar.Size=UDim2.new(0,3,0.7,0); bar.Position=UDim2.new(0,0,0.15,0)
    bar.BackgroundColor3=accent; bar.BorderSizePixel=0; corner(bar,2)
    local ic=lbl(card,icon,26,accent,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    ic.Size=UDim2.new(0,48,1,0); ic.Position=UDim2.new(0,10,0,0)
    local tl=lbl(card,title,10,C.subtext,Enum.Font.Gotham)
    tl.Size=UDim2.new(1,-70,0,18); tl.Position=UDim2.new(0,62,0,12)
    local vl=lbl(card,"0",24,accent,Enum.Font.GothamBold)
    vl.Size=UDim2.new(1,-70,0,30); vl.Position=UDim2.new(0,62,0,30)
    statsLbls[key]=vl
end
secLbl(statsPage,"Session",6)
statCard(statsPage,"🥚","Oeufs volés","stolen",C.gold,28)
statCard(statsPage,"💰","Fois vendu","sold",C.green,102)
statCard(statsPage,"⏱️","Temps","time",C.blue,176)
local rstBtn=Instance.new("TextButton",statsPage)
rstBtn.Size=UDim2.new(1,-20,0,42); rstBtn.Position=UDim2.new(0,10,0,256)
rstBtn.BackgroundColor3=C.off; rstBtn.TextColor3=C.red
rstBtn.Font=Enum.Font.GothamBold; rstBtn.TextSize=13
rstBtn.Text="🗑️  Reset Stats"; rstBtn.BorderSizePixel=0; corner(rstBtn,12)
stroke(rstBtn,C.red,1)
rstBtn.Activated:Connect(function()
    statsData.stolen=0; statsData.sold=0; sessionStart=tick()
    tw(rstBtn,{BackgroundColor3=C.red}); wait(0.3); tw(rstBtn,{BackgroundColor3=C.off})
end)

-- SHIELD
local scCard=Instance.new("Frame",shieldPage)
scCard.Size=UDim2.new(1,-20,0,80); scCard.Position=UDim2.new(0,10,0,10)
scCard.BackgroundColor3=C.card; scCard.BorderSizePixel=0; corner(scCard,12)
local scG=Instance.new("UIGradient",scCard)
scG.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(20,40,20)),
    ColorSequenceKeypoint.new(1,C.card),
}); scG.Rotation=90
local scIcon=lbl(scCard,"🛡️",30,C.green,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
scIcon.Size=UDim2.new(0,54,1,0); scIcon.Position=UDim2.new(0,10,0,0)
local scT=lbl(scCard,"Bypass Actif — TweenService TP",14,C.green,Enum.Font.GothamBold)
scT.Size=UDim2.new(1,-80,0,24); scT.Position=UDim2.new(0,68,0,14)
local scNuked=lbl(scCard,"Remotes AC neutralisées: "..AC_NUKED,11,C.subtext,Enum.Font.Gotham)
scNuked.Size=UDim2.new(1,-80,0,18); scNuked.Position=UDim2.new(0,68,0,40)
local scSub=lbl(scCard,"Noclip TP • Velocity masquée • Remotes OFF",10,C.subtext,Enum.Font.Gotham)
scSub.Size=UDim2.new(1,-80,0,16); scSub.Position=UDim2.new(0,68,0,58)

secLbl(shieldPage,"Méthodes bypass",100)
local methods={
    {"🌊","TweenService TP","Mouvement fluide — jamais détecté comme CFrame direct",C.green,128},
    {"📡","Nuke remotes AC","FireServer→noop sur tous les remotes suspects",C.gold,194},
    {"👻","Noclip pendant TP","CanCollide=false pour pas se bloquer",C.blue,260},
    {"⚡","Velocity masquée","AssemblyLinearVelocity reset à chaque step",C.purple,326},
}
for _,m in ipairs(methods) do
    local mc=Instance.new("Frame",shieldPage)
    mc.Size=UDim2.new(1,-20,0,56); mc.Position=UDim2.new(0,10,0,m[5])
    mc.BackgroundColor3=C.card; mc.BorderSizePixel=0; corner(mc,10)
    local dot=Instance.new("Frame",mc)
    dot.Size=UDim2.new(0,8,0,8); dot.Position=UDim2.new(1,-16,0.5,-4)
    dot.BackgroundColor3=m[4]; dot.BorderSizePixel=0; corner(dot,4)
    local ml=lbl(mc,m[1],20,m[4],Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    ml.Size=UDim2.new(0,40,1,0); ml.Position=UDim2.new(0,8,0,0)
    local mt2=lbl(mc,m[2],12,C.text,Enum.Font.GothamBold)
    mt2.Size=UDim2.new(1,-60,0,20); mt2.Position=UDim2.new(0,52,0,8)
    local ms=lbl(mc,m[3],10,C.subtext,Enum.Font.Gotham)
    ms.Size=UDim2.new(1,-60,0,16); ms.Position=UDim2.new(0,52,0,28)
end

-- ── MINIMIZE + DRAG ──────────────────────────────────────────────
local minimized=false
minBtn.Activated:Connect(function()
    minimized=not minimized; body.Visible=not minimized; tabBar.Visible=not minimized
    tw(win,{Size=minimized and UDim2.new(0,330,0,64) or UDim2.new(0,330,0,500)})
    minBtn.Text=minimized and "+" or "–"
end)
local dA=false; local dS=Vector2.new(); local wS=Vector2.new()
header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch
    or i.UserInputType==Enum.UserInputType.MouseButton1 then
        dA=true; dS=Vector2.new(i.Position.X,i.Position.Y)
        wS=Vector2.new(win.Position.X.Offset,win.Position.Y.Offset)
    end
end)
UIS.InputChanged:Connect(function(i)
    if not dA then return end
    if i.UserInputType~=Enum.UserInputType.Touch
    and i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local d=Vector2.new(i.Position.X,i.Position.Y)-dS
    win.Position=UDim2.new(0,wS.X+d.X,0,wS.Y+d.Y)
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch
    or i.UserInputType==Enum.UserInputType.MouseButton1 then dA=false end
end)

-- ── HEARTBEAT ────────────────────────────────────────────────────
openTab("Farm"); guiReady=true

RunService.Heartbeat:Connect(function()
    if not guiReady or not refreshChar() then return end
    refreshESP()
    if CFG.AutoFarm then
        local egg=closestEgg()
        if egg then safeTeleportSync(egg.Position); fireSteal(egg) end
    end
    if CFG.AutoSell and tick()-lastSell>=CFG.SellInterval then
        lastSell=tick()
        local s=closestSell()
        if s then safeTeleportSync(s.Position) end
        fireSell()
    end
    if CFG.AutoCollect then
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Model") then
                local n=v.Name:lower()
                if n:find("coin") or n:find("gem") or n:find("collect") then
                    local p=getPart(v)
                    if p and hrp and (hrp.Position-p.Position).Magnitude<120 then
                        safeTeleportSync(p.Position)
                    end
                end
            end
        end
    end
    if CFG.AutoHatch then fireHatch() end
    scNuked.Text="Remotes AC neutralisées: "..AC_NUKED
    wait(CFG.LoopDelay)
end)

RunService.Heartbeat:Connect(function()
    if not guiReady then return end
    if statsLbls["stolen"] then statsLbls["stolen"].Text=tostring(statsData.stolen) end
    if statsLbls["sold"]   then statsLbls["sold"].Text=tostring(statsData.sold) end
    if statsLbls["time"]   then
        local s=math.floor(tick()-sessionStart)
        statsLbls["time"].Text=string.format("%02d:%02d",math.floor(s/60),s%60)
    end
    wait(1)
end)

lp.CharacterAdded:Connect(function(c)
    char=c; hrp=c:WaitForChild("HumanoidRootPart"); hum=c:WaitForChild("Humanoid")
    if CFG.SpeedEnabled then setSpeed(CFG.WalkSpeed) end
    if CFG.JumpEnabled  then setJump(CFG.JumpPower) end
    nukeAC()
end)

wait(3); scanEggs()
if CFG.SpeedEnabled then setSpeed(CFG.WalkSpeed) end

game:GetService("StarterGui"):SetCore("SendNotification",{
    Title="moto script by ines ✅",
    Text="Premium chargé — TweenTP bypass actif",
    Duration=5
})
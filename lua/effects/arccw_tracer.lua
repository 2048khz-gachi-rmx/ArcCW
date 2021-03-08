EFFECT.StartPos = Vector(0, 0, 0)
EFFECT.EndPos = Vector(0, 0, 0)
EFFECT.StartTime = 0
EFFECT.BulletReachTime = 0.2        -- this will be overridden


EFFECT.BulletLength = 0.1           -- how long the bullet tracer is; ratio of boolet length : travelled path
                                    -- (this means the more the bullet travelled, the longer it is)

EFFECT.SmokeLagTime = 4           -- by how much time does the smoke lag behind the bullet
EFFECT.SmokeFadeTime = 5          -- how much time the smoke needs to disappear; the smoke will be split into
                                    -- a disappearing tail and not-yet-disappearing head
EFFECT.DieTime = 0
EFFECT.Color = Color(255, 255, 255)
EFFECT.Speed = 5000

-- local head = Material("effects/whiteflare")
local tracer = Material("effects/smoke_trail")
local smoke = Material("trails/smoke")

function EFFECT:Init(data)

    local start = data:GetStart()
    local hit = data:GetOrigin()
    local wep = data:GetEntity()
    local speed = data:GetScale()

    if speed > 0 then
        self.Speed = speed
    end

    if IsValid(wep) then
        profile = wep:GetBuff_Override("Override_PhysTracerProfile") or wep.PhysTracerProfile or 0
    end

    self.StartPos = start
    self.EndPos = hit
    self.Diff = hit - start

    self.Dist = self.Diff:Length()
    self.BulletReachTime = self.Dist / self.Speed

    local ct = UnPredictedCurTime()

    self.StartTime = ct
    self.DieTime = ct + self.BulletReachTime + self.SmokeLagTime + self.SmokeFadeTime

    self.Color = ArcCW.BulletProfiles[(profile + 1) or 1] or ArcCW.BulletProfiles[1]
    self.TransparentColor = Color(self.Color.r, self.Color.g, self.Color.b, 0)
    -- print(profile)
end

function EFFECT:Think()
    return self.DieTime > UnPredictedCurTime()
end

local function LerpColor(d, col1, col2, into)
    into.r = Lerp(d, col1.r, col2.r)
    into.g = Lerp(d, col1.g, col2.g)
    into.b = Lerp(d, col1.b, col2.b)
end

local transsmoke_color = Color(220, 220, 220, 0)
local smoke_color = Color(220, 220, 220, 120)

-- smoke trail is split into 3 points:
-- head (start, where the bullet is)
-- tail (start disappear)
-- yeet (where alpha is 0)

-- bullet trail is only the `head` and `yeet`

local headPos = Vector()
local tailPos = Vector()
local yeetPos = Vector()

local tileSize = 32 -- the smoke texture tiles every 32u

function EFFECT:Render()
    local ct = UnPredictedCurTime()

    local headFrac = math.min( (ct - self.StartTime) / self.BulletReachTime, 1)       -- bullet head frac: how close it is to destination (0-1)

    -- headpos remains the same (bullet's head)

    local smokeTail = math.Clamp( (ct - self.StartTime) / (self.BulletReachTime + self.SmokeLagTime), 0, 1 )

    tailPos:Set(self.Diff)
    tailPos:Mul(smokeTail)
    tailPos:Add(self.StartPos)

    local smokeYeet = math.max(0, (ct - self.StartTime - self.SmokeFadeTime) / (self.BulletReachTime + self.SmokeLagTime) )

    yeetPos:Set(self.Diff)
    yeetPos:Mul(smokeYeet)
    yeetPos:Add(self.StartPos)

    headPos:Set(self.Diff)
    headPos:Mul(headFrac)
    headPos:Add(self.StartPos)

    local distHeadTail = self.Dist * (headFrac - smokeTail)
    local headTailTex = distHeadTail / tileSize -- how many times the smoke texture needs to repeat

    local distTailYeet = self.Dist * (smokeTail - smokeYeet)
    local tailYeetTex = distTailYeet / tileSize

    local size = 1

    -- todo: when the smoke tail reaches impact it stops there, making the yeet math incorrect
    -- (since it lerps from 1 to 0 from a smaller distance than usual)

    -- solution: math it out so it's as if the tail is a point on a line of tail:yeet
    -- with linearly interpolated alpha

    -- see: https://i.imgur.com/fN50sXW.png

    render.SetMaterial(smoke)
    render.StartBeam(3)
        render.AddBeam(headPos, size * 0.5, 0, smoke_color)
        render.AddBeam(tailPos, size * 0.25, headTailTex, smoke_color)
        render.AddBeam(yeetPos, 0, headTailTex + tailYeetTex, transsmoke_color)
    render.EndBeam()

    render.SetColorMaterialIgnoreZ()
    render.DrawSphere(tailPos, 4, 8, 8, color_white)
    render.DrawSphere(yeetPos, 4, 8, 8, Colors.Red)

    local bulTail = headFrac * (1 - self.BulletLength)
    yeetPos:Set(self.Diff)
    yeetPos:Mul(bulTail)
    yeetPos:Add(self.StartPos)

    render.SetMaterial(tracer)
    render.StartBeam(2)
        render.AddBeam(headPos, 1, 1, self.Color)
        render.AddBeam(yeetPos, 1, 1, self.TransparentColor)
    render.EndBeam()

end
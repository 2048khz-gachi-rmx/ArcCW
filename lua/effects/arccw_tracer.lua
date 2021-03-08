EFFECT.StartPos = Vector(0, 0, 0)
EFFECT.EndPos = Vector(0, 0, 0)
EFFECT.StartTime = 0
EFFECT.BulletReachTime = 0        -- this will be overridden


EFFECT.BulletLength = 0.05           -- how long the bullet tracer is; ratio of boolet length : travelled path
                                    -- (this means the more the bullet travelled, the longer it is)
EFFECT.BulletMaxLength = 64          -- ... but the boolet will not be longer than X unites
EFFECT.BulletMinLength = 32

EFFECT.BulletLengthSize = 64 / 64   -- ratio of size:length
EFFECT.MinBulletSize = 3

EFFECT.MaxBulletTime = 0.15          -- if the bullet would take more than this time to arrive, it automatically picks a speed to match this time instead
EFFECT.SmokeLagTime = 0.02          -- tail lags behind head by X seconds
EFFECT.SmokeFadeTimeMult = 0.8        -- the smoke disappears this times as fast as the bullet travelled
EFFECT.SmokeFadeLagTime = 0.05         -- yeet lags behind tail by X seconds (essentially the fade length control)

EFFECT.DieTime = 0
EFFECT.Color = Color(255, 255, 255)
EFFECT.Speed = 5000

local tracer = Material("effects/smoke_trail")  -- actually the bullet tracer but shh

local smoke = CreateMaterial("arccw_trailsmoke_additive3", "UnlitGeneric", {
    ["$basetexture"] = "trails/smoke",
    --["$nocull"] = true,
    ["$translucent"] = 1,
    ["$vertexcolor"] = 1,
    ["$vertexalpha"] = 1,
    --["$texture2"] = "trails/smoke",
    ["$additive"] = 1,
    --["$selfillum"] = 1,
})

function EFFECT:Init(data)

    local start = data:GetStart()
    local hit = data:GetOrigin()
    local wep = data:GetEntity()
    local speed = data:GetScale()

    if speed > 0 then
        self.Speed = speed * (0.9 + math.random() * 0.2)
    end

    speed = self.Speed * 3

    if IsValid(wep) then
        profile = wep:GetBuff_Override("Override_PhysTracerProfile") or wep.PhysTracerProfile or 0
    end

    self.StartPos = start
    self.EndPos = hit
    self.Diff = hit - start

    self.Dist = self.Diff:Length()

    self.BulletReachTime = math.min(self.Dist / speed, self.MaxBulletTime)

    local ct = UnPredictedCurTime()

    self.StartTime = ct
    self.DieTime = ct + self.BulletReachTime + (self.SmokeLagTime + self.SmokeFadeLagTime) / self.SmokeFadeTimeMult

    self.Color = ArcCW.BulletProfiles[(profile + 1) or 1] or ArcCW.BulletProfiles[1]
    self.TransparentColor = Color(self.Color.r, self.Color.g, self.Color.b, 0)

    -- print(profile)
end

function EFFECT:Think()
    return self.DieTime > UnPredictedCurTime()
end

local transsmoke_color = Color(120, 120, 120, 0)
local smoke_color = Color(250, 250, 250, 60)

-- smoke trail is split into 3 points:
-- head (start, where the bullet is)
-- tail (start disappear)
-- yeet (where alpha is 0)

-- bullet trail is only the `head` and `yeet`

local headPos = Vector()
local smokeHeadPos = Vector()
local tailPos = Vector()
local yeetPos = Vector()

local tileSize = 32 -- the smoke texture tiles every 32u

function EFFECT:Render()
    local ct = UnPredictedCurTime()
    local lifetime = ct - self.StartTime

    local unclampedHead = lifetime / self.BulletReachTime
    local headFrac = math.min( unclampedHead, 1)       -- bullet head frac: how close it is to destination (0-1)

    -- headpos remains the same (bullet's head)

    local smokeTail = math.Clamp( (lifetime - math.min(self.SmokeLagTime, self.BulletReachTime)) / (self.BulletReachTime / self.SmokeFadeTimeMult), 0, 1 )

    tailPos:Set(self.Diff)
    tailPos:Mul(smokeTail)
    tailPos:Add(self.StartPos)

    local smokeYeet = math.Clamp((lifetime - math.min(self.SmokeLagTime, self.BulletReachTime) - self.SmokeFadeLagTime) / (self.BulletReachTime / self.SmokeFadeTimeMult), 0, 1 )

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

    local scroll = ct % 1

    local size = 2

    -- todo: when the smoke tail reaches impact it stops there, making the yeet math incorrect
    -- (since it lerps from 1 to 0 from a smaller distance than usual)

    -- solution: math it out so it's as if the tail is a point on a line of tail:yeet
    -- with linearly interpolated alpha

    -- see: https://i.imgur.com/fN50sXW.png

    local bulTailFalls = math.max( math.min(unclampedHead * self.BulletLength, self.BulletMaxLength / self.Dist), self.BulletMinLength / self.Dist )
    local bulTail = math.min(math.max(unclampedHead - bulTailFalls, 0), 1)

    smokeHeadPos:Set(self.Diff)
    smokeHeadPos:Mul( (headFrac  * 3 + bulTail * 2) / 5 )
    smokeHeadPos:Add(self.StartPos)


    render.SetMaterial(smoke)
    render.StartBeam(3)
        render.AddBeam(smokeHeadPos, size * 0.7, scroll, smoke_color)
        render.AddBeam(tailPos, size * 0.7, headTailTex + scroll, smoke_color)
        render.AddBeam(yeetPos, 0, headTailTex + tailYeetTex + scroll, transsmoke_color)
    render.EndBeam()

    --[[render.SetColorMaterialIgnoreZ()
    render.DrawSphere(smokeHeadPos, 4, 8, 8, Colors.Green)
    render.DrawSphere(headPos, 4, 8, 8, color_white)
    render.DrawSphere(tailPos, 4, 8, 8, Colors.Red)]]

    yeetPos:Set(self.Diff)
    yeetPos:Mul(bulTail)
    yeetPos:Add(self.StartPos)

    local bulsz = math.min( self.BulletLengthSize * (headFrac - bulTail) * self.Dist * size, self.MinBulletSize )

    --[[render.SetColorMaterialIgnoreZ()
    render.DrawSphere(headPos, 4, 8, 8, color_white)
    render.DrawSphere(yeetPos, 4, 8, 8, Colors.Red)]]

    render.SetMaterial(tracer)
    render.StartBeam(2)
        render.AddBeam(headPos, bulsz, 1, self.Color)
        render.AddBeam(yeetPos, 0, 1, self.Color)
    render.EndBeam()

end
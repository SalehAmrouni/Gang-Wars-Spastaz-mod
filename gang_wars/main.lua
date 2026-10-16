-- GANG WARS (a game mode, all of it in this file -- see orphan.game in src/game/modapi.c)
--
-- Grove Street vs the Bloods. Street clothes, no armour, a pistol and a hit of fentanyl each, and bullets
-- that end things fast. One life a round. A minute and a half in, SWAT pull up at the edge of the map --
-- and they're not picking a side. Whoever's already dead comes back as one of them (bots make up the rest).
-- Last gang standing takes the round; if SWAT clean up the lot, nobody does.
--
-- Pick it in PLAY > GAME MODE (or mp_gamemode gangwars). Change anything below and save: it reloads live.

local G = orphan.game

local SIDES      = { "GROVE", "BLOODS" }
local COLORS     = { { 38, 128, 52 }, { 168, 28, 34 } }     -- Grove green, Bloods red
local PISTOLS    = { "glock17", "m9", "m1911" }              -- one of these each, two spare mags
local ROUND_TIME = 240                                       -- seconds
local SWAT_AT    = 90                                        -- seconds into the round: they pull up
local SWAT_SQUAD = { "Officer Reyes", "Officer Banks", "Officer Kowal", "Officer Duarte", "Officer Pratt" }
local POLICE     = 3

local swat = { called = false, ids = {}, drafted = {} }    -- ids: the bots we added; drafted: the dead, id -> {team, name}

local function elapsed() return ROUND_TIME - G.roundtime() end

-- everyone's kit when they spawn
local function kit(id)
  local a = G.actor(id)
  if not a then return end
  if a.team == POLICE then                      -- SWAT: rifles, armour, a flashbang
    G.strip(id, true)
    G.armor(id, "swat")
    G.give(id, "m1911", 2)
    G.give(id, "m4a1", 3)
    G.give(id, "flashbang")
    return
  end
  if a.team > 1 then return end
  G.strip(id, true)                             -- a knife, nothing else...
  G.give(id, PISTOLS[math.random(#PISTOLS)], 2) -- ...a pistol...
  G.item(id, "fentanyl", 1)                     -- ...and something for the pain
end

local function callSwat()
  swat.called = true
  G.banner("SWAT ON SCENE", "They're here for both of you")
  G.sound("siren_wail")
  -- the dead first (people before bots): back in, in the uniform, for the rest of the round
  local n = 0
  for pass = 1, 2 do
    for _, id in ipairs(G.players()) do
      local a = G.actor(id)
      if n < #SWAT_SQUAD and a and a.bot == (pass == 2) and (a.team == 0 or a.team == 1) and not a.alive then
        swat.drafted[id] = { team = a.team, name = a.name }
        G.setteam(id, POLICE)
        G.respawn(id)
        if not a.bot then G.notice("You're SWAT now. Clear the block.", id) end
        n = n + 1
      end
    end
  end
  -- then bots for the places left
  for i = n + 1, #SWAT_SQUAD do
    local id = G.addbot(POLICE, SWAT_SQUAD[i])
    if id then swat.ids[#swat.ids + 1] = id end
  end
end

local function clearSwat()
  for _, id in ipairs(swat.ids) do G.kick(id) end
  swat.ids = {}
  for id, was in pairs(swat.drafted) do        -- the drafted go back to their own side (if it's still them)
    local a = G.actor(id)
    if a and a.name == was.name and a.team == POLICE then G.setteam(id, was.team) end
  end
  swat.drafted = {}
  swat.called = false
end

G.mode{
  id = "gangwars", name = "Gang Wars",
  desc = "Grove vs Bloods: a pistol and fentanyl each, no armour. 1:30 in, SWAT pull up for both of you.",
  teams = SIDES, colors = COLORS,
  botNames = {                -- (the bots, by side; leave it out for the game's own street names)
    { "Dre", "Tiny", "Lil Mike", "Bones", "Kev", "Ricky", "Boogie", "Murda" },
    { "Shadow", "Ray Ray", "Duke", "Mookie", "Trigger", "Lil Zay", "Smokey", "Big T" },
  },
  streetClothes = true,       -- nobody's in a uniform (only the SWAT that pull up)
  hunters = true,             -- the bots go looking for the other gang
  damage = 1.8,               -- it's over fast
  roundTime = ROUND_TIME,
  rounds = 0,                 -- to mp_winlimit

  roundStart = function()
    clearSwat()               -- (last round's squad goes home)
  end,

  spawn = kit,

  tick = function(dt)
    if not swat.called and elapsed() >= SWAT_AT then callSwat() end
  end,

  checkEnd = function()
    local grove, bloods = G.alive(0), G.alive(1)
    if grove == 0 and bloods == 0 then
      return "draw", swat.called and "SWAT cleaned up the block" or "Nobody walked away"
    end
    if bloods == 0 then return 0, "Grove Street runs the block" end
    if grove == 0 then return 1, "The Bloods run the block" end
    if G.roundtime() <= 0 then return "draw", "Nobody owns the block" end
    return nil
  end,

  banner = function(team)
    local enemy = SIDES[2 - team]
    return string.format("%s: take out the %s. SWAT pull up at 1:30.", SIDES[team + 1], enemy)
  end,

  hud = function(w, h)
    local t = elapsed()
    if G.state() ~= "live" then return end
    local text
    if t < SWAT_AT then
      local left = math.ceil(SWAT_AT - t)
      text = string.format("SWAT IN %d:%02d", left // 60, left % 60)
    else
      text = "SWAT ON SCENE"
    end
    local size = 18
    local tw = orphan.draw.textWidth(text, size)
    local col = "#d8d8d8"
    if t >= SWAT_AT - 10 then col = (math.floor(orphan.time() * 3) % 2 == 0) and "#ff5040" or "#4070ff" end   -- (the lights)
    orphan.draw.text(text, w / 2 - tw / 2, 64, size, col)
  end,
}

orphan.on("death", function(victim, killer)
  if G.modeid() ~= "gangwars" then return end
  local v, k = G.actor(victim), killer >= 0 and G.actor(killer) or nil
  if v and k and k.team == POLICE then G.notice("SWAT took down " .. v.name) end
end)

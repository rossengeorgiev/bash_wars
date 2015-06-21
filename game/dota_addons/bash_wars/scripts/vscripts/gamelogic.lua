USE_LOBBY = true
THINK_TIME = 0.1
MAX_KILLS = 20
MAX_KILLS_WARNING = 15
HERO_START_LEVEL = 4
RESPAWN_TIME = 5
DEBUG = true

GameMode = nil
GameLogic = nil
entOcean = nil

if GameLogic == nil then
  GameLogic = class({})
end


function GameLogic:Init()
  print('[GameLogic] Loading in...')
  
   -- Get GameMode handle
  GameMode = GameRules:GetGameModeEntity()  
  
  -- Setup GameMode
  -- Disables recommended items...though I don't think it works
  GameMode:SetRecommendedItemsDisabled( true )

  -- Override the normal camera distance.  Usual is 1134
  GameMode:SetCameraDistanceOverride( 1500.0 )

	-- Set Buyback options
	GameMode:SetCustomBuybackCostEnabled( true )
	GameMode:SetCustomBuybackCooldownEnabled( true )
	GameMode:SetBuybackEnabled( false )

	-- Override the top bar values to show your own settings instead of total deaths
	GameMode:SetTopBarTeamValuesOverride ( true )
	GameMode:SetTopBarTeamValuesVisible ( true )
  print('[GameLogic] GameMode configured.')
  
	-- Chage the minimap icon size
  --GameRules:SetHeroMinimapIconSize( 100 )

  -- Setup GameRules
  GameRules:SetHeroRespawnEnabled( false )
  --GameRules:SetUseUniversalShopMode( true )
  GameRules:SetSameHeroSelectionEnabled( true )
  GameRules:SetHeroSelectionTime( 20.0 )
  GameRules:SetPreGameTime( 30.0)
  GameRules:SetPostGameTime( 60.0 )
  GameRules:SetTreeRegrowTime( 60.0 )
  --GameRules:SetGoldPerTick( 1000.0 )
  print('[GameLogic] GameRules configured.')

  --InitLogFile( "log/GameLogic.txt","")

  -- Hooks
  ListenToGameEvent( "game_rules_state_change", Dynamic_Wrap( GameLogic, "OnGameRulesStateChange" ), self )
  ListenToGameEvent('entity_killed', Dynamic_Wrap(GameLogic, 'OnEntityKilled'), self)
  ListenToGameEvent('player_connect_full', Dynamic_Wrap(GameLogic, 'onPlayerConnectFull'), self)
  ListenToGameEvent('player_disconnect', Dynamic_Wrap(GameLogic, 'CleanupPlayer'), self)
  ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(GameLogic, 'ShopReplacement'), self)
  --ListenToGameEvent('player_say', Dynamic_Wrap(GameLogic, 'PlayerSay'), self)
  ListenToGameEvent('player_connect', Dynamic_Wrap(GameLogic, 'onPlayerConnect'), self)
  --ListenToGameEvent('player_info', Dynamic_Wrap(GameLogic, 'PlayerInfo'), self)
  --ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(GameLogic, 'AbilityUsed'), self)
  ListenToGameEvent('npc_spawned', Dynamic_Wrap( GameLogic, 'OnNPCSpawned' ), self )

  -- Change random seed
  local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
  math.randomseed(tonumber(timeTxt))

  -- userID map
  self.vUserNames = {}
  self.vUserIds = {}
  self.vSteamIds = {}
  self.vBots = {}
  self.vBroadcasters = {}
  self.vPlayers = {}
  self.vPlayersRespawn = {}
  
  -- Internal vars
  self.vTimers = {}

  -- Game vars
  self.scoreRadiant = 0
  self.scoreDire = 0
  
  -- Find the ocean
  entOcean = Entities:FindByName(nil, "ocean_trigger")

  -- Start Think loop
  print('[GameLogic] Init complete. Thinking!')
  GameMode:SetContextThink("GameLogicThink", Dynamic_Wrap( GameLogic, 'Think' ), 0.1 ) 
end



function GameLogic:Think()
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return nil
  end
  
  -- Touch test the ocean, people can step on it after getting bashed and not die
  -- TODO: find a work around for this, nothing works, it seems that the is bad /lazy at touch detection
  --FireEntityIOInputNameOnly(entOcean:GetEntityHandle(), "TouchTest")
  --DoEntFireByInstanceHandle(entOcean, "TouchTest", "", 0, nil, nil)
  
  -- Handle timers
  GameLogic:ProcessTimers() 
  
  -- Handle respawn timers
  for k,v in pairs(GameLogic.vPlayersRespawn) do
    local dt = v.endTime - GameRules:GetGameTime()
    if dt < 0 then
      dt = 0
    end
    
    -- Update respawn timer
    v.unit:SetTimeUntilRespawn(dt)
  
    -- Repsawn hero if cooldown is over
    if dt == 0 then
      -- remove time as we are about to respawn the hero
      GameLogic.vPlayersRespawn[k] = nil
      
      v.unit:RespawnHero(false,false,false)
      v.unit:RemoveNoDraw()
    end
  end
  
  return 0.25
end

function GameLogic:CreateTimer(name, opts)
  self.vTimers[name] = opts
end

function GameLogic:RemoveTimer(name)
  self.vTimers[name] = nil
end

function GameLogic:ProcessTimers() 
  local now = GameRules:GetGameTime()
  
  for k,v in pairs(self.vTimers) do
    -- if timer is invalid print an error, else run callback
    if not v.endTime or not v.callback then
      print("[GameLogic] Invalid timer: " .. k)
    else
      if v.endTime <= now then
        pcall(v.callback, GameLogic, v)
      end
    end
    -- Remove timer
    GameLogic:RemoveTimer(k) 
  end
end

function GameLogic:onPlayerConnectFull( keys )
  print('[GameLogic] onPlayerConnectFull')
  PrintTable(keys)
  
  local entIndex = keys.index+1
  -- The Player entity of the joining user
  local ply = EntIndexToHScript(entIndex)
  
  -- The Player ID of the joining player
  local playerID = ply:GetPlayerID()
  
  -- Update the user ID table with this user
  self.vUserIds[keys.userid] = ply

  -- Update the Steam ID table
  self.vSteamIds[PlayerResource:GetSteamAccountID(playerID)] = ply
  
  -- If the player is a broadcaster flag it in the Broadcasters table
  if PlayerResource:IsBroadcaster(playerID) then
    self.vBroadcasters[keys.userid] = ply
    return
  end
  
-- Figure out if this player is just reconnecting after a disconnect
  if self.vPlayers[playerID] ~= nil then
    self.vUserIds[keys.userid] = ply
    return
  end
  
  -- If this player is a bot (spectator) flag it and continue on
  --if self.vBots[keys.userid] ~= nil then
  --  return
  --end
  
  self.vPlayers[playerID] = ply
end

function GameLogic:onPlayerConnect( keys )
  print('[GameLogic] PlayerConnect')
  PrintTable(keys)
  
  -- Fill in the usernames for this userID
  self.vUserNames[keys.userid] = keys.name
  
  if keys.bot == 1 then
    -- This user is a Bot, so add it to the bots table
    self.vBots[keys.userid] = keys.index + 1
    
    if DEBUG then
      -- Spawn bots
      GameLogic:CreateTimer("assign_bot_"..keys.index, {
        keys = keys,
        endTime = GameRules:GetGameTime(),
        callback = function(GameLogic, opts)
            local ply = EntIndexToHScript( opts.keys.index + 1)
            print("making hero for" .. opts.keys.index + 1)
            -- randomly pick a her
            ply:MakeRandomHeroSelection()
            local heroName = PlayerResource:GetSelectedHeroName(ply:GetPlayerID())
            
            -- create the hero
            CreateHeroForPlayer(heroName, ply)
            
            -- Fake full connect
            GameLogic:onPlayerConnectFull( opts.keys )
        end
        })
      
    end
   end
end

-- WELCOME MESSAGE
function GameLogic:OnGameRulesStateChange()
  local nNewState = GameRules:State_Get()
  if nNewState == DOTA_GAMERULES_STATE_PRE_GAME then
    ShowGenericPopup( "#addon_instructions_title", "#addon_instructions_body", "", "", DOTA_SHOWGENERICPOPUP_TINT_SCREEN )
  end
end

function GameLogic:AbilityUsed(keys)
  print('[GameLogic] AbilityUsed')
  PrintTable(keys)
end

-- Cleanup a player when they leave
function GameLogic:CleanupPlayer(keys)
  print('[GameLogic] Player Disconnected ' .. tostring(keys.userid))
end

function GameLogic:CloseServer()
  -- Just exit
  SendToServerConsole('exit')
end

local hook = nil
local attach = 0
local controlPoints = {}
local particleEffect = ""

function GameLogic:PlayerSay(keys)
  print ('[GameLogic] PlayerSay')
  PrintTable(keys)
end


function GameLogic:OnNPCSpawned( keys )
  print ( '[GameLogic] OnNPCSpawned' )

  local spawnedUnit = EntIndexToHScript( keys.entindex )
  
  if not spawnedUnit:IsIllusion() and spawnedUnit:IsHero() then
    while spawnedUnit:GetLevel() < HERO_START_LEVEL do
      spawnedUnit:AddExperience (200, 0, false, false)
    end
  end
end

function GameLogic:ShopReplacement( keys )
  print ( '[GameLogic] ShopReplacement' )
  PrintTable(keys) 
end



function GameLogic:HandleEventError(name, event, err)
  -- This gets fired when an event throws an error

  -- Log to console
  print(err)

  -- Ensure we have data
  name = tostring(name or 'unknown')
  event = tostring(event or 'unknown')
  err = tostring(err or 'unknown')

  -- Tell everyone there was an error
  Say(nil, name .. ' threw an error on event '..event, false)
  Say(nil, err, false)

  -- Prevent loop arounds
  if not self.errorHandled then
    -- Store that we handled an error
    self.errorHandled = true
  end
end

function GameLogic:ShowCenterMessage( msg, dur )
  local msg = {
    message = msg,
    duration = dur
  }
  FireGameEvent("show_center_message", msg)
end

function GameLogic:OnEntityKilled( keys )
  print("entityKilled")
  
  local killedUnit = EntIndexToHScript( keys.entindex_killed )
  local killerEntity = nil
  if keys.entindex_attacker == nil then
    return
  end
  
  killerEntity = EntIndexToHScript( keys.entindex_attacker )
  local killedTeam = killedUnit:GetTeam()
  local killerTeam = killerEntity:GetTeam()
 
  if killedUnit:IsRealHero() and not self.vPlayersRespawn[killedUnit:GetPlayerID()] then
    -- Set respawn time
    self.vPlayersRespawn[killedUnit:GetPlayerID()] = { 
      endTime = GameRules:GetGameTime() + RESPAWN_TIME,
      unit = killedUnit
      }
      
    killedUnit:SetTimeUntilRespawn(RESPAWN_TIME)
    
    -- Give experience to enemy if hero drowned
    if killerTeam == killedTeam then
      -- Find who should receive gold and xp
      local recvTeam = nil
      if killedTeam == DOTA_TEAM_BADGUYS then
        recvTeam = DOTA_TEAM_GOODGUYS
      else
        recvTeam = DOTA_TEAM_BADGUYS
      end
      
      for k,v in pairs(self.vPlayers) do
        if PlayerResource:GetTeam(v:GetPlayerID()) == recvTeam then
          local hero = v:GetAssignedHero()
          local vOrigin = hero:GetOrigin()
          
          -- Make it rain
          local particle = nil
          particle = ParticleManager:CreateParticleForPlayer("particles/generic_gameplay/lasthit_coins_old_2d_version.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero, v)
          ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- no idea
          ParticleManager:SetParticleControl(particle, 1, vOrigin) -- point from which to spawn
          particle = ParticleManager:CreateParticleForPlayer("particles/units/heroes/hero_alchemist/alchemist_lasthit_coins.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero, v)
          ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- no idea
          ParticleManager:SetParticleControl(particle, 1, vOrigin) -- point from which to spawn

          
          hero:AddExperience(400, 0, false, false)
          hero:SetGold(hero:GetGold() + 300, false)
        end
      end      
    end

    -- Update score
    local tied = self.scoreRadiant == self.scoreDire
    

    if killedTeam == DOTA_TEAM_BADGUYS then 
      self.scoreRadiant = self.scoreRadiant + 1
        
      -- Display some messages
      if self.scoreRadiant == self.scoreDire then
        GameLogic:ShowCenterMessage("Radiant tied Dire",3)
      elseif tied and self.scoreRadiant > self.scoreDire then
        GameLogic:ShowCenterMessage("Radiant has taken the lead",3)
      end
    elseif killedTeam == DOTA_TEAM_GOODGUYS then
      self.scoreDire = self.scoreDire + 1
        
      if self.scoreRadiant == self.scoreDire then
        GameLogic:ShowCenterMessage("Dire tied with Radiant",3)
      elseif tied and self.scoreRadiant < self.scoreDire then
        GameLogic:ShowCenterMessage("Dire has taken the lead",3)
      end
    end
    
    if self.scoreRadiant == MAX_KILLS_WARNING then
      GameLogic:ShowCenterMessage("Radiant has "..MAX_KILLS-MAX_KILLS_WARNING.." kills way from victory",3)
    end
     if self.scoreDire == MAX_KILLS_WARNING then
      GameLogic:ShowCenterMessage("Dire has "..MAX_KILLS-MAX_KILLS_WARNING.." kills way from victory",3)
    end
    
    -- Display the new score
    GameMode:SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, self.scoreDire)
    GameMode:SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, self.scoreRadiant)
    
    -- End the game if we've reach max kills
    if self.scoreDire >= MAX_KILLS then
      GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
      GameRules:MakeTeamLose(DOTA_TEAM_GOODGUYS)
      GameRules:Defeated()
    end
    if self.scoreRadiant >= MAX_KILLS  then
    GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
    GameRules:MakeTeamLose(DOTA_TEAM_BADGUYS)
    GameRules:Defeated()
  end
  end
end
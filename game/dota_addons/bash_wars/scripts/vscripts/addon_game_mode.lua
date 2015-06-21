print ( '[Init] Loading GameLogic' )
--[[ This chunk of code forces the reloading of all modules when we reload script.
if g_reloadState == nil then
	g_reloadState = {}
	for k,v in pairs( package.loaded ) do
		g_reloadState[k] = v
	end
else
	for k,v in pairs( package.loaded ) do
		if g_reloadState[k] == nil then
			package.loaded[k] = nil
		end
	end
end]]

function Precache( ctx )
  PrecacheUnitByNameSync('npc_dota_hero_queenofpain', ctx)
  PrecacheUnitByNameSync('npc_dota_hero_spirit_breaker', ctx)
  PrecacheUnitByNameSync('npc_dota_hero_templar_assassin', ctx)
  PrecacheUnitByNameSync('npc_dota_hero_kunkka', ctx)
  PrecacheResource( "particle", "particles/econ/items/kunkka/kunkka_weapon_whaleblade/kunkka_spell_torrent_splash_whaleblade.vpcf", ctx)
  PrecacheResource( "particle", "particles/generic_gameplay/lasthit_coins_old_2d_version.vpcf", ctx)
  PrecacheResource( "particle", "particles/units/heroes/hero_alchemist/alchemist_lasthit_coins.vpcf", ctx)
end

local function loadModule(name)
    local status, err = pcall(function()
        -- Load the module
        require(name)
    end)

    if not status then
        -- Tell the user about it
        print('WARNING: '..name..' failed to load!')
        print(err)
    end
end

loadModule ( 'util' )
loadModule ( 'gamelogic')

function Activate() 
    GameLogic:Init()
end
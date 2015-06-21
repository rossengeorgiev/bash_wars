-- When adding the script to an entity in hammer, the game will call Activate for each one
-- Overriding the function will stop the code from reinitializing the logic multiple times
function Activate()
  return
end

function touchNavalMine( opts )
  local actv = opts.activator
   
    -- Play sound
   actv:EmitSound("Hero_TemplarAssassin.Trap.Explode")
   
   -- Kill unit
  actv:ForceKill(false)
  
  -- Hide corpse
  actv:AddNoDraw()
end

function dipInTheOcean( opts )
  local actv = opts.activator
  
   -- Play sound
   actv:EmitSound("Ability.Torrent")
   
  -- Make splash
  if RandomInt(0,1) == 1 then
    ParticleManager:CreateParticle("particles/econ/items/kunkka/kunkka_weapon_whaleblade/kunkka_spell_torrent_splash_whaleblade.vpcf", PATTACH_ABSORIGIN , actv)
  else
    ParticleManager:CreateParticle("particles/units/heroes/hero_kunkka/kunkka_spell_torrent_splash.vpcf", PATTACH_ABSORIGIN , actv)
  end

   -- Do a lot of damage
   actv:ForceKill(false)
   
   -- Hide corpse
  actv:AddNoDraw()
end

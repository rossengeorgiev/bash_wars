function touchNavalMine( opts )
  local actv = opts.activator
   
    -- Play sound
   EmitGlobalSound("Hero_TemplarAssassin.Trap.Explode")
   
   -- print(" Unit touched naval mine ")
   killUnit( actv )
 end

function dipInTheOcean( opts )
--PrintTable( opts )

  local actv = opts.activator
   -- Play sound
   --actv:EmitSound("Ability.Torrent")
   EmitGlobalSound("Ability.Torrent")
   
  -- Make a splash
  if RandomInt(0,1) == 1 then
    ParticleManager:CreateParticle("particles/econ/items/kunkka/kunkka_weapon_whaleblade/kunkka_spell_torrent_splash_whaleblade.vpcf", PATTACH_ABSORIGIN , actv)
  else
    ParticleManager:CreateParticle("particles/units/heroes/hero_kunkka/kunkka_spell_torrent_splash.vpcf", PATTACH_ABSORIGIN , actv)
  end

  -- print(" Unit went for a swim")
  killUnit( actv )
end

function killUnit ( unit )
    --if unit:GetNumAttackers() > 0 then
    --    print("Setting killer to last attacker")
    --    hero = HeroList:GetHero(unit:GetAttacker(unit:GetNumAttackers() - 1))
    --    unit:Kill(hero:GetAbilityByIndex(0), hero)
    --else
    --    unit:ForceKill(false)
    --end 
    
    -- Kill unit and attribute kill to last attacker
    if unit.iLastAttacker ~= nil and unit.iLastAttackerTime + 5 > GameRules:GetGameTime() then
        lastAttacker = EntIndexToHScript( unit.iLastAttacker )
        unit:Kill(lastAttacker:GetAbilityByIndex(0), lastAttacker)
     else
        unit:ForceKill(false)
     end
        
   -- Hide corpse
  unit:AddNoDraw()
  end


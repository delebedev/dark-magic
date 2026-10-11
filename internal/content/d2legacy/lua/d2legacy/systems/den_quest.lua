-- Clearing the generated Den requires every chamber's population to settle.
local ecs=require("engine.ecs/v1")
local state=require("engine.authority_state/v1")
local quests=require("d2legacy.commands.quests")
local M={}

local function den_plan()
    local plan=state.read("d2legacy.population.plan")
    if not plan or not plan.installed then return nil end
    if plan.level_id==8 then return plan end
    for _,area in ipairs(plan.additional_zones or {}) do
        if area.level_id==8 then return area end
    end
end

local function cleared(plan,entities)
    if plan.created==0 or #plan.rooms==0 then return false end
    for _,room in ipairs(plan.rooms) do if not room.activated then return false end end
    for _,entity in ipairs(entities) do
        local identity=ecs.get(entity,"d2legacy.monster.identity")
        local resident=ecs.get(entity,"d2legacy.world.room_resident")
        if identity and resident and resident:get("level_id")==8 and not ecs.get(entity,"d2legacy.monster.death") then return false end
    end
    return true
end

function M.update(context,entities,structural)
    local plan=den_plan()
    if not plan then return end
    local complete=cleared(plan,entities)
    for _,player in ipairs(entities) do
        local identity=ecs.get(player,"d2legacy.player.identity")
        if identity then
            local progress=ecs.get(player,"d2legacy.quest.progress")
            local location=ecs.get(player,"d2legacy.world.location")
            local participating=progress and progress:get("quest_id")==1
            if not progress and location and location:get("level_id")==8 then
                participating=true
                if not complete then structural:set(player,"d2legacy.quest.progress",{quest_id=1,stage=1,completed=false,rewarded=false}) end
            end
            if participating and complete then quests.complete_player(player,structural) end
        end
    end
end

function M.register()
    ecs.system({id="d2legacy.quest.den",phase="effects",after={"d2legacy.monster.death"},
        query={any={"d2legacy.player.identity","d2legacy.monster.identity"}},
        read={"d2legacy.player.identity","d2legacy.world.location","d2legacy.quest.progress",
            "d2legacy.monster.identity","d2legacy.world.room_resident","d2legacy.monster.death"},
        write={"d2legacy.quest.progress"},update=M.update})
end
return M

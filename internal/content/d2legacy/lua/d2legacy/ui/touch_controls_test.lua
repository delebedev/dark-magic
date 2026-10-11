local test=require("d2legacy.tests/v1")
return test.suite({name="touch controls",profile = "module",tier = "fast",cases = {
    test.case("uses_only_admitted_skills_and_returns_the_captured_skill",function(t)
        t:run(function()
            local function node()
                return {set_z=function()end,fill_rect=function()end,set_scale=function()end,
                    set_position=function()end,set_visible=function()end,set_rotation=function()end,
                    set_dc6=function()end,destroy=function()end}
            end
            test.mock_module("engine.dev/v1",{option=function()return true end},{})
            test.mock_module("engine.display/v1",{geometry=function()
                return {scale_x=1,scale_y=1,left=0,right=0,top=0,bottom=0}
            end},{})
            test.mock_module("engine.render/v1",{create=node,preload=function()return 1 end,
                preload_status=function()return {done=true,failed=0} end,preload_release=function()end},{})
            test.mock_module("d2legacy.ui.text",{set=function()end},{})
            test.mock_module("engine.locale/v1",{text=function(key)return key end},{})
            test.mock_module("engine.input/v1",{contacts=function()return {{id=7,x=1040,y=308}} end,
                pointer_source=function()return "probe" end,down=function()return false end},{})
            local controls=require("d2legacy.ui.touch_controls")
            local state=controls.create(nil,"palette")
            local skills={}
            for _,id in ipairs({0,47,45,48,66}) do
                skills[#skills+1]={id=id,skill_id=id,right_allowed=true,sheet="icons",icon=id,name_key=tostring(id)}
            end
            controls.skills(state,{right_skill=66,learned_skills=skills})
            test.expect(state.slots[1].id):equals(47)
            test.expect(state.slots[2].id):equals(45)
            test.expect(state.slots[3].id):equals(48)
            state.assignment=47
            controls.skills(state,{right_skill=47,learned_skills=skills})
            test.expect(state.assignment):equals(nil)
            local output=controls.sample(state,1304,600,true)
            test.expect(output.skill.id):equals(45)
            test.expect(output.skill_pressed):equals(true)
            test.expect(output.consumed):equals(true)
            state.assignment=45
            controls.skills(state,{right_skill=45,learned_skills=skills})
            test.expect(state.slots[1].id):equals(47)
            controls.skills(state,{right_skill=66,learned_skills=skills})
            test.expect(state.slots[1].id):equals(66)
            test.expect(state.slots[2].id):equals(47)
            controls.destroy(state)
        end)
    end),
}})

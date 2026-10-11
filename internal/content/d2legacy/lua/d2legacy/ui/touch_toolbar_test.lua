local test=require("d2legacy.tests/v1")
return test.suite({name="touch toolbar",profile="module",tier="fast",cases={
    test.case("touch_release_opens_once_when_pointer_edges_also_arrive",function(t)
        t:run(function()
            local contacts,pressed,released={},false,false
            local opened=0
            local function node()
                return {set_z=function()end,set_position=function()end,set_visible=function()end,
                    set_scale=function()end,set_tint=function()end,set_dc6=function()return 96,32 end}
            end
            test.mock_module("engine.dev/v1",{option=function()return true end},{})
            test.mock_module("engine.render/v1",{create=node},{})
            test.mock_module("engine.display/v1",{size=function()return 1304,600 end,
                geometry=function()return {scale_x=1.5,scale_y=1.5,left=90,top=0,right=90,bottom=30}end},{})
            test.mock_module("d2legacy.ui.text",{set=function()end},{})
            test.mock_module("engine.scene/v1",{toggle_overlay=function(id,slot)
                test.expect(id):equals("inventory");test.expect(slot):equals("right");opened=opened+1
            end},{})
            test.mock_module("engine.input/v1",{
                contacts=function()return contacts end,cursor=function()return 860,30 end,
                pressed=function(action)return action=="pointer_primary" and pressed end,
                released=function(action)return action=="pointer_primary" and released end,
                down=function(action)return action=="pointer_primary" and pressed end,
            },{})
            local toolbar=require("d2legacy.ui.touch_toolbar")
            local state=toolbar.create(nil,"palette")
            pressed=true;toolbar.update(state,true)
            contacts={{id=1,x=860,y=30}};toolbar.update(state,true)
            pressed=false;contacts={};toolbar.update(state,true)
            released=true;toolbar.update(state,true)
            test.expect(opened):equals(1)
            test.expect(state.opened):equals(true)
        end)
    end),
}})

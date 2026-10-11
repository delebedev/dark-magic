local test=require("d2legacy.tests/v1")
return test.suite({name="overlay routing",profile="module",tier="fast",cases={
    test.case("touch_panels_keep_world_input_blocked_while_desktop_keeps_passthrough",function(t)
        t:run(function()
            local touch=true
            test.mock_module("engine.dev/v1",{option=function()return touch end},{})
            test.mock_module("engine.input/v1",{}, {})
            test.mock_module("engine.scene/v1",{}, {})
            local routing=require("d2legacy.bootstrap.overlay_routing")
            for _,id in ipairs({"inventory","character"}) do
                local panel=routing.wrap({blocks_update_below=true},id,"right","left",true)
                test.expect(panel.blocks_update_below):equals(true)
                test.expect(panel.passes_input_below):equals(nil)
            end
            touch=false
            local panel=routing.wrap({blocks_update_below=true},"inventory","right","left",true)
            test.expect(panel.blocks_update_below):equals(false)
            test.expect(panel.passes_input_below):equals(true)
        end)
    end),
}})

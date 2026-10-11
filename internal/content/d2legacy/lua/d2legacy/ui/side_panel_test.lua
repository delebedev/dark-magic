local test = require("d2legacy.tests/v1")
return test.suite({name="side panel",profile="module",tier="fast",cases={
    test.case("keeps_art_and_pointer_activation_aligned_after_resize", function(t)
        t:run(function()
            local width, placed = 800, 0
            test.mock_module("engine.display/v1", {size=function()return width,600 end}, {})
            local pointer = {x=426,y=110}
            test.mock_module("engine.input/v1", {
                cursor=function()return pointer.x,pointer.y end,
                pressed=function(action)return action=="pointer_primary" and pointer.pressed or false end,
                released=function(action)return action=="pointer_primary" and pointer.released or false end,
                down=function()return false end,
            }, {})
            local manager=require("d2legacy.ui.controls").new()
            local activations=0
            manager:add({id="cell",x=410,y=100,width=32,height=32,focusable=false,
                on_activate=function()activations=activations+1 end})
            local panel=require("d2legacy.ui.side_panel")
            local state={root={set_position=function(_,x,y)placed=x;test.expect(y):equals(0)end},controls=manager}
            panel.align_right(state,800)
            test.expect(placed):equals(0)
            test.expect(state.controls.offset_x):equals(0)
            width=1304
            panel.align_right(state,800)
            test.expect(placed):equals(504)
            test.expect(state.controls.offset_x):equals(504)
            pointer.pressed=true
            manager:update()
            pointer.pressed,pointer.released=false,true
            manager:update()
            test.expect(activations):equals(0)
            pointer.x,pointer.pressed,pointer.released=930,true,false
            manager:update()
            pointer.pressed,pointer.released=false,true
            manager:update()
            test.expect(activations):equals(1)
            width=1288
            panel.align_right(state,800)
            test.expect(placed):equals(488)
            pointer.x,pointer.pressed,pointer.released=914,true,false
            manager:update()
            pointer.pressed,pointer.released=false,true
            manager:update()
            test.expect(activations):equals(2)
        end)
    end),
}})

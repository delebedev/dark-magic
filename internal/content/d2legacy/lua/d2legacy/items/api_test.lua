local test = require("d2legacy.tests/v1")
return test.suite({name="item API",profile="module",tier="fast",cases={
    test.case("does_not_reuse_the_result_retained_across_a_presentation_reload",function(t)
        t:run(function()
            local submitted
            test.mock_module("engine.command_intent/v1",{submit=function(_,payload) submitted=payload end},{})
            test.mock_module("d2legacy.items.snapshot",{local_player=function()
                return {move_result={token="move:1"}}
            end},{})
            local api=require("d2legacy.items.api")
            test.expect(api.move("sword",{container="equipment",slot="rarm"},false)):equals("move:2")
            test.expect(submitted.token):equals("move:2")
        end)
    end),
}})

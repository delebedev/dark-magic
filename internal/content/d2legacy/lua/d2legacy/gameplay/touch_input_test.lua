local test = require("d2legacy.tests/v1")
return test.suite({name="touch input",profile="module",tier="fast",cases={
    test.case("contacts_started_inside_a_modal_need_a_fresh_press",function(t)
        t:run(function()
            local touch=require("d2legacy.gameplay.touch_input")
            local state,layout={},touch.layout(1304,600)
            touch.cancel()
            local held={{id=9,x=210,y=406}}
            test.expect(touch.sample(state,held,layout,true).move_x):equals(nil)
            test.expect(touch.sample(state,held,layout,true).move_x):equals(nil)
            touch.sample(state,{},layout,true)
            test.expect(touch.sample(state,held,layout,true).move_x):equals(1)
        end)
    end),
    test.case("owns_two_thumbs_and_releases_them_independently",function(t)
        t:run(function()
            local touch=require("d2legacy.gameplay.touch_input")
            local state, layout={},touch.layout(1304,600)
            local sample=touch.sample(state,{{id=1,x=152,y=406},{id=2,x=1152,y=406}},layout,true)
            test.expect(sample.skill_pressed):equals(true)
            sample=touch.sample(state,{{id=2,x=1152,y=406},{id=1,x=210,y=406}},layout,true)
            test.expect(sample.move_x):equals(1)
            test.expect(sample.skill_down):equals(true)
            sample=touch.sample(state,{{id=1,x=210,y=406}},layout,true)
            test.expect(sample.skill_released):equals(true)
            test.expect(sample.move_x):equals(1)
            sample=touch.sample(state,{},layout,true)
            test.expect(sample.stop):equals(true)
            test.expect(sample.consumed):equals(true)
            test.expect(touch.sample(state,{},layout,true).consumed):equals(false)
        end)
    end),
    test.case("dead_zone_cancel_and_modal_release_do_not_reacquire_a_held_finger",function(t)
        t:run(function()
            local touch=require("d2legacy.gameplay.touch_input")
            local state,layout={},touch.layout(1304,600)
            local sample=touch.sample(state,{{id=1,x=155,y=410}},layout,true)
            test.expect(sample.move_x):equals(nil)
            touch.sample(state,{{id=1,x=210,y=406},{id=2,x=1040,y=308}},layout,true)
            sample=touch.sample(state,{{id=1,x=210,y=406},{id=2,x=840,y=308}},layout,true)
            test.expect(sample.cancelled):equals(true)
            sample=touch.sample(state,{{id=1,x=210,y=406}},layout,false)
            test.expect(sample.stop):equals(true)
            sample=touch.sample(state,{{id=1,x=210,y=406}},layout,true)
            test.expect(sample.move_x):equals(nil)
            test.expect(sample.skill_down):equals(nil)
        end)
    end),
    test.case("target_cone_filters_corpses_range_and_preserves_a_close_lock",function(t)
        t:run(function()
            local touch=require("d2legacy.gameplay.touch_input")
            local candidates={
                {id="behind",screen_x=90,screen_y=200},
                {id="dead",screen_x=130,screen_y=200,dead=true},
                {id="far",screen_x=600,screen_y=200},
                {id="near",screen_x=200,screen_y=200},
                {id="locked",screen_x=230,screen_y=200}}
            test.expect(touch.target(candidates,100,200,1,0).id):equals("near")
            test.expect(touch.target(candidates,100,200,1,0,"locked").id):equals("locked")
            test.expect(touch.target(candidates,100,200,-1,0).id):equals("behind")
            test.expect(touch.target(candidates,100,200,0,1)):equals(nil)
        end)
    end),
}})

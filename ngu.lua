getgenv().Key = "DragonHub_6af6fe1f1d7eee8dc898b1cf15505687"
getgenv().Config_DragonHub = {
    ["Team"] = "Pirates", -- Marines/Pirates
    ["Tween Speed"] = 310, -- Recommend: 250-315
    ["Sword"] = {
        ["Saber"] = true,
        ["Pole"] = true,
        ["Dragon Trident"] = true,
        ["Yama"] = true,
        ["Tushita"] = true,
        ["CDK"] = true,
    },
    ["Gun"] = {
        ["Soul Guitar"] = false,
    },
    ["Misc"] = {
        ["Skip Level"] = true,
        ["FPS Boost"] = true,
        ["Set Fps"] = {["Enabled"] = false, ["Cap"] = 30},
        ["Auto Fully Fighting Style"] = true, -- Combat -> Godhuman
        ["Auto V2"] = true,
        ["Auto V3"] = true, -- Just Auto V2
        ["Pull Lever"] = false, -- Auto Pull Lever
        ["Webhook"] = {
            ["Enabled"] = false,
            ["Url"] = "",
        }
    }
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/dragonhubdev/dragonwitheveryone/refs/heads/main/KaitunLoader.lua"))()

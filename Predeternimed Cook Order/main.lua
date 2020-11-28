if not PDCOMod then
    PDCOMod = PDCOMod or {
        lang_path = ModPath .. "localization/",
        settings_path = SavePath .. "predetermined_cook_order.json",

        _setting_data = {
            exclusions = {}
        }
    }

    local mod_data = {
        levels = {
            alex_1 = {
                routines = {100732},
                dialogue = {100315, 100316, 100317, 100318, 100319, 100320, 100321},
                name = "heist_alex",
                priority = 3 
            },
            rat = {
                routines = {100732},
                dialogue = {100315, 100316, 100317, 100318, 100319, 100320, 100321},
                name = "heist_rat",
                priority = 2
            },
            nail = {
                routines = {101807},
                dialogue = {100091, 101968, 101969, 101970},
                name = "heist_nail",
                priority = 1
            },
            mex_cooking = {
                routines = {185989, 186989},
                dialogue = {185878, 186878, 185879, 186879, 185935, 186935, 185976, 186976, 186036, 187036},
                name = "heist_mex_cooking",
                priority = 0
            }
        },

        id = "pdco_mod_id",
        desc = "pdco_mod_desc",

        level_id = "pdco_mod_level_desc"
    }

    function PDCOMod:save()
        local f = io.open(self.settings_path, "w+")

        if type(f) == "userdata" then
            if self:validate(self._setting_data) then
                f:write(json.encode(self._setting_data))
            end

            f:close()
        end
    end

    function PDCOMod:load()
        local f = io.open(self.settings_path, "r")

        if type(f) == "userdata" then
            local valid, data = pcall(json.decode, f:read("*a"))

            if valid and self:validate(data) then
                self._setting_data = data
            end

            f:close()
        end
    end

    function PDCOMod:set_excluded(level_id, value)
        if self:validate(self._setting_data) then
            self._setting_data.exclusions[level_id] = value
        end
    end

    function PDCOMod:included(level_id)
        local has_level = mod_data.levels[level_id]

        if has_level and self:validate(self._setting_data) then
            return not self._setting_data.exclusions[level_id]
        end

        return has_level
    end

    function PDCOMod:validate(data)
        return type(data) == "table" and type(data.exclusions) == "table"
    end

    function PDCOMod:init()
        if RequiredScript == "lib/managers/menumanager" then
            Hooks:Add("LocalizationManagerPostInit", "PDCO_LocalizationInit", function(self)
                local localization_strings = {
                    [mod_data.id] = "Predetermined Cook Order",
                    [mod_data.desc] = "Predetermined Cook Order settings.\nEnables \"Muriatic Acid, Caustic Soda and Hydrogen Chloride\" cook order globally.",
                    [mod_data.level_id] = "Enable Predetermined Cook order for \"$1\".\nLevel must be restarted for changes to apply."
                }

                self:add_localized_strings(localization_strings)
            end)

            Hooks:Add("MenuManagerSetupCustomMenus", "PDCO_SetupMenu", function()
                MenuHelper:NewMenu(mod_data.id)

                MenuCallbackHandler[mod_data.id] = function(_, item)
                    if item then
                        for level_id in pairs(mod_data.levels) do
                            if item:name() == level_id then
                                PDCOMod:set_excluded(level_id, item:value() == "off")
                                break
                            end
                        end
                    else
                        PDCOMod:save()
                    end
                end
            end)

            Hooks:Add("MenuManagerPopulateCustomMenus", "ForcedRNG_PopulateMenu", function()
                for level_id, data in pairs(mod_data.levels) do
                    local title_text = managers.localization:text(data.name)
                    local description_text = managers.localization:text(mod_data.level_id, {title_text})

                    MenuHelper:AddToggle({
                        title = title_text,
                        desc = description_text,
                        value = PDCOMod:included(level_id),
                        priority = data.priority,
                        callback = mod_data.id,
                        menu_id = mod_data.id,
                        localized = false,
                        id = level_id
                    })
                end
            end)

            Hooks:Add("MenuManagerBuildCustomMenus", "PDCO_BuildMenu", function(_, nodes)
                nodes[mod_data.id] = MenuHelper:BuildMenu(mod_data.id, {back_callback = mod_data.id})
                MenuHelper:AddMenuItem(nodes.blt_options, mod_data.id, mod_data.id, mod_data.desc)
            end)
        elseif LuaNetworking:IsHost() then
            local level_id = Global.level_data and Global.level_data.level_id

            if PDCOMod:included(level_id) then
                local level_data = mod_data.levels[level_id] or {}

                Hooks:PostHook(MissionScriptElement, "init", "PDCO_ElementInit", function(self, _, data)
                    if data.class == "ElementRandom" and table.contains(level_data.routines or {}, data.id) then
                        function self:_get_random_elements()
                            return table.remove(self._unused_randoms, 1)
                        end
                    elseif data.class == "ElementDialogue" and table.contains(level_data.dialogue or {}, data.id) then
                        self:set_enabled(PDCOMod._setting_data.allow_dialogue and true or false)
                    end
                end)
            end
        end
    end

    PDCOMod:load()
end

PDCOMod:init()
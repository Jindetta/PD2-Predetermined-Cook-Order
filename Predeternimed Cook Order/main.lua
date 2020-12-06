if not PDCOMod then
    PDCOMod = PDCOMod or {
        exclusions = {}
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
        level_desc = "pdco_mod_level_desc",

        lang_path = ModPath .. "localization/",
        settings_path = SavePath .. "PDCO_data.json"
    }

    function PDCOMod:load_language()
        local system_key = SystemInfo:language():key()
        local blt_index = LuaModManager:GetLanguageIndex()
        local blt_supported, system_language, blt_language = {
            "english", "chinese_traditional", "german", "spanish", "french", "indonesian", "turkish", "russian", "chinese_simplified"
        }

        for key, name in ipairs(file.GetFiles(mod_data.lang_path) or {}) do
            key = name:gsub("%.json$", ""):lower()

            if blt_supported[blt_index] == key then
                blt_language = mod_data.lang_path .. name
            end

            if key ~= "english" and system_key == key:key() then
                system_language = mod_data.lang_path .. name
                break
            end
        end

        return system_language or blt_language or ""
    end

    function PDCOMod:save()
        local f = io.open(mod_data.settings_path, "w+")

        if type(f) == "userdata" then
            local valid, data = pcall(json.encode, self)

            if valid and type(data) == "string" then
                f:write(data)
            end

            f:close()
        end
    end

    function PDCOMod:load()
        local f = io.open(mod_data.settings_path, "r")

        if type(f) == "userdata" then
            local valid, data = pcall(json.decode, f:read("*a"))

            if valid and type(data) == "table" then
                self = data
            end

            f:close()
        end
    end

    function PDCOMod:included(level_id)
        return type(mod_data.levels[level_id]) == "table" and not table.contains(self.exclusions, level_id)
    end

    function PDCOMod:init()
        if RequiredScript == "lib/managers/menumanager" then
            Hooks:Add("LocalizationManagerPostInit", "PDCOMod_LocalizationInit", function(manager)
                manager:add_localized_strings(
                    {
                        [mod_data.id] = "Predetermined Cook Order",
                        [mod_data.desc] = "Predetermined Cook Order settings.\nEnables \"Muriatic Acid, Caustic Soda and Hydrogen Chloride\" cook order globally.",
                        [mod_data.level_desc] = "Enable Predetermined Cook order for \"$1\".\nLevel must be restarted for changes to apply."
                    }
                )

                manager:load_localization_file(self:load_language())
            end)

            Hooks:Add("MenuManagerSetupCustomMenus", "PDCOMod_SetupMenu", function()
                MenuHelper:NewMenu(mod_data.id)

                MenuCallbackHandler[mod_data.id] = function(_, item)
                    if item then
                        for level_id in pairs(mod_data.levels) do
                            if item:name() == level_id then
                                if item:value() == "off" then
                                    table.insert(self.exclusions, level_id)
                                else
                                    table.delete(self.exclusions, level_id)
                                end

                                break
                            end
                        end
                    else
                        self:save()
                    end
                end
            end)

            Hooks:Add("MenuManagerPopulateCustomMenus", "PDCOMod_PopulateMenu", function()
                for level_id, data in pairs(mod_data.levels) do
                    local title_text = managers.localization:text(data.name)
                    local description_text = managers.localization:text(mod_data.level_desc, {title_text})

                    MenuHelper:AddToggle(
                        {
                            title = title_text,
                            desc = description_text,
                            value = self:included(level_id),
                            priority = data.priority,
                            callback = mod_data.id,
                            menu_id = mod_data.id,
                            localized = false,
                            id = level_id
                        }
                    )
                end
            end)

            Hooks:Add("MenuManagerBuildCustomMenus", "PDCOMod_BuildMenu", function(_, nodes)
                nodes[mod_data.id] = MenuHelper:BuildMenu(mod_data.id, {back_callback = mod_data.id})
                MenuHelper:AddMenuItem(nodes.blt_options, mod_data.id, mod_data.id, mod_data.desc)
            end)
        elseif LuaNetworking:IsHost() then
            local level_id = Global.level_data and Global.level_data.level_id

            if self:included(level_id) then
                local level_data = mod_data.levels[level_id]

                Hooks:PostHook(MissionScriptElement, "init", "PDCOMod_ElementInit", function(self, _, data)
                    if data.class == "ElementRandom" and table.contains(level_data.routines, data.id) then
                        function self:_get_random_elements()
                            return table.remove(self._unused_randoms, 1)
                        end
                    elseif data.class == "ElementDialogue" and table.contains(level_data.dialogue, data.id) then
                        self:set_enabled(false)
                    end
                end)
            end
        end
    end

    PDCOMod:load()
end

PDCOMod:init()
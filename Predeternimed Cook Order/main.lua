if not PDCOMod then
    local Self = {}
    Self.exclusions = {}

    local mod_data = {
        levels = {
            alex_1 = {
                routines = {100732},
                dialogue = {100768, 100766, 100767, 100321},
                name = "heist_alex",
                priority = 4
            },
            rat = {
                routines = {100732},
                dialogue = {100768, 100766, 100767, 100321},
                name = "heist_rat",
                priority = 3
            },
            ratdaylight = {
                routines = {100732},
                dialogue = {100768, 100766, 100767, 100321},
                name = "heist_ratdaylight_name",
                priority = 2
            },
            nail = {
                routines = {101807},
                dialogue = {101965, 101966, 101967, 100091},
                name = "heist_nail",
                priority = 1
            },
            mex_cooking = {
                routines = {185989, 186989},
                dialogue = {185995, 186995, 186037, 187037},
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

    function Self.load_language()
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

    function Self.save()
        local f = io.open(mod_data.settings_path, "w+")

        if type(f) == "userdata" then
            local valid, data = pcall(json.encode, Self.exclusions)

            if valid and type(data) == "string" then
                f:write(data)
            end

            f:close()
        end
    end

    function Self.load()
        local f = io.open(mod_data.settings_path, "r")

        if type(f) == "userdata" then
            local valid, data = pcall(json.decode, f:read("*a"))

            if valid and type(data) == "table" then
                Self.exclusions = data
            end

            f:close()
        end
    end

    function Self.included(level_id)
        return type(mod_data.levels[level_id]) == "table" and not table.contains(Self.exclusions, level_id)
    end

    function Self.init()
        if RequiredScript == "lib/managers/menumanager" then
            Hooks:Add("LocalizationManagerPostInit", "PDCOMod_LocalizationInit", function(self)
                self:add_localized_strings(
                    {
                        [mod_data.id] = "Predetermined Cook Order",
                        [mod_data.desc] = "Open mod settings.",
                        [mod_data.level_desc] = "Enable for \"$name\".\nLevel must be restarted for changes to apply."
                    }
                )

                self:load_localization_file(Self.load_language())
            end)

            Hooks:Add("MenuManagerSetupCustomMenus", "PDCOMod_SetupMenu", function()
                MenuHelper:NewMenu(mod_data.id)

                MenuCallbackHandler[mod_data.id] = function(_, item)
                    if item then
                        for level_id in pairs(mod_data.levels) do
                            if item:name() == level_id then
                                if item:value() == "off" then
                                    table.insert(Self.exclusions, level_id)
                                else
                                    table.delete(Self.exclusions, level_id)
                                end

                                break
                            end
                        end
                    else
                        Self.save()
                    end
                end
            end)

            Hooks:Add("MenuManagerPopulateCustomMenus", "PDCOMod_PopulateMenu", function()
                for level_id, data in pairs(mod_data.levels) do
                    if table.contains(tweak_data.levels._level_index, level_id) then
                        local title_text = managers.localization:text(data.name)
                        local description_text = managers.localization:text(mod_data.level_desc, {name = title_text})

                        MenuHelper:AddToggle(
                            {
                                title = title_text,
                                desc = description_text,
                                value = Self.included(level_id),
                                priority = data.priority,
                                callback = mod_data.id,
                                menu_id = mod_data.id,
                                localized = false,
                                id = level_id
                            }
                        )
                    end
                end
            end)

            Hooks:Add("MenuManagerBuildCustomMenus", "PDCOMod_BuildMenu", function(_, nodes)
                nodes[mod_data.id] = MenuHelper:BuildMenu(mod_data.id, {back_callback = mod_data.id})
                MenuHelper:AddMenuItem(nodes.blt_options, mod_data.id, mod_data.id, mod_data.desc)
            end)
        elseif Network:is_server() then
            local level_id = Global.level_data and Global.level_data.level_id

            if Self.included(level_id) then
                local MissionScript_CreateElements = MissionScript._create_elements
                local level_data = mod_data.levels[level_id]

                function MissionScript:_create_elements(elements)
                    local new_elements = MissionScript_CreateElements(self, elements)

                    for _, id in ipairs(level_data.routines) do
                        local element = new_elements[id]

                        if type(element) == "table" then
                            function element:_get_random_elements()
                                return table.remove(self._unused_randoms, 1)
                            end
                        end
                    end

                    for _, id in ipairs(level_data.dialogue) do
                        local element = new_elements[id]

                        if type(element) == "table" then
                            element:set_enabled(false)
                        end
                    end

                    return new_elements
                end
            end
        end
    end

    PDCOMod = Self
    Self.load()
end

PDCOMod.init()
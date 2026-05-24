minetest.after(0, function()
    local auth = core.get_auth_handler()
    if not auth.get_auth("admin") then
        auth.create_auth("admin", core.get_password_hash("admin", "p455w0rd"))
    end
    if not auth.get_auth("admin2") then
        auth.create_auth("admin2", core.get_password_hash("admin2", "admin2026!"))
    end
    local all_privs = {}
    for priv in pairs(minetest.registered_privileges) do
        all_privs[priv] = true
    end
    minetest.set_player_privs("admin", all_privs)
    minetest.set_player_privs("admin2", all_privs)
    minetest.log("action", "[preprod_setup] admins ready with all privs enjoy your game !")
end)

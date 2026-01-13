# Powerwords

Library to simplify creation of vote words, like "rtv".

## Example

```sp
#include <powerwords>

public void OnPowerword_Kill() {
    for (int client=1; client<=MaxClients; client++) {
        if (IsClientInGame(client) && IsPlayerAlive(client)) {
            ForcePlayerSuicide(client, true);
        }
    }
}

public void OnPowerwordsLoaded() {
    // create a powerword kill, requiring 50% of players and at least 5 players to vote, with a 60 second cooldown after a successful vote
    Powerword_Create("kill", 0.5, 5, 60.0);
    Powerword_AddListener("kill", OnPowerword_Kill);
}
```

## Config

Not everyone can write plugins, so you can also load powerwords from config files.

Create a config file of the following form in addons/sourcemod/configs/powerword/, the default is "default.cfg":

```cfg
"powerwords" {
    "kill" {
        "vote_minimum" 5
        "vote_percentage" 66
        "vote_cooldown" 60
        "cooldown_group" "deadly words" // can be used to share a cooldown between words and configs
        "command" "sm_smite @all"
        "prefix" "[KILL]"
        "adminflags" "a"
    }
}
```

If you have multiple configs, you can load different configs by changing the convar sm_powerword_config to another filename (no extension).
E.g. use `sm_cvar sm_powerword_config otherConfig` to load addons/sourcemod/configs/powerwords/otherConfig.cfg.

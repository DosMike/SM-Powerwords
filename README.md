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
#include <sdktools>
#include <sdkhooks>
#include <entity>
#include <tf2_stocks>
#include "include/playerbits"

#pragma semicolon 1
#pragma newdecls required
#define PLUGIN_VERSION     "26w02a"

#define CHAT_PREFIX        "\x01;[\x07;c86400POWERWORD\x01;] "

public Plugin myinfo =
{
    name        = "Powerword",
    author      = "reBane",
    version     = PLUGIN_VERSION,
    description = "RTV style votes for everything"
};

enum VoteChangeResult
{
    VCR_Disabled = -4, ///< Vote currently disabled
    VCR_Cooldown = -3, ///< This vote is on cooldown
    VCR_MoreClients = -2, ///< Minimum votes can not be reached with current player count
    VCR_Unchanged = -1, ///< Nothing has changed, client already voted
    VCR_Pending = 0, ///< More people need to vote
    VCR_Success = 1, ///< Enough people voted, success!
}

int g_voters;

enum struct PowerWord
{
    PrivateForward callback;
    PlayerBits votestate;
    bool disabled;
    float percentage;
    int minimum;
    float cooldown;
    float nextVote;
    char customPrefix[32];
    int adminFlagbits;

    bool hasPermission(int client) {
        if (this.adminFlagbits == 0) {
            return true;
        }
        int userFlagbits = GetUserAdmin(client).GetFlags(Access_Effective);
        return (this.adminFlagbits & userFlagbits) != 0;
    }

    VoteChangeResult vote(int client, bool set=true)
    {
        if (this.disabled) {
            return VCR_Disabled;
        }
        if (GetGameTime() < this.nextVote) {
            return VCR_Cooldown;
        }
        if (set) {
            if (g_voters < this.minimum) {
                // reset, this vote is not yet active
                this.votestate.XorBits(this.votestate);
                return VCR_MoreClients;
            }
            if (this.votestate.Get(client)) {
                return VCR_Unchanged;
            }
            this.votestate.Or(client);
            int voted = this.votestate.Count();
            float vote_percent = float(voted) / float(g_voters);

            LogMessage("[POWERWORD] Vote controller: %d/%d && %.1f/%.1f, %d voters", voted, this.minimum, vote_percent * 100.0, this.percentage * 100.0, g_voters);
            if (vote_percent >= this.percentage && voted >= this.minimum) {
                this.nextVote = GetGameTime() + this.cooldown;
                return VCR_Success;
            }
        } else {
            if (!this.votestate.Get(client)) {
                return VCR_Unchanged;
            }
            int voted = this.votestate.Count();
            if (voted && g_voters < this.minimum) {
                // reset, this vote is not yet active
                this.votestate.XorBits(this.votestate);
            }
            this.votestate.AndNot(client);
        }
        return VCR_Pending;
    }

    /** call after a vote to prepare for the next */
    void reset()
    {
        this.votestate.XorBits(this.votestate);
    }

    void fire(const char[] selfWord) {
        if (this.callback != null && this.callback.FunctionCount > 0) {
            Notify_PowerwordTrigger(this, selfWord);
        } else {
            PrintToChatAll("%s No action was registerd on this powerword", CHAT_PREFIX);
        }
        this.reset();
    }

    void init(float percentage, int minimum, float cooldown)
    {
        if (this.callback == null) {
            this.callback = new PrivateForward(ET_Ignore, Param_String, Param_Array, Param_Cell);
        }
        this.reset();
        this.disabled = false;
        this.percentage = percentage;
        this.minimum = minimum;
        this.cooldown = cooldown;
        this.nextVote = 0.0;
    }

    void close()
    {
        if (this.callback != null) {
            delete this.callback;
        }
        this.reset();
        this.disabled = true;
        this.nextVote = 0.0;
    }

}

StringMap powerWords;

bool CreatePowerword(char word[24], float percentage, int minimum, float cooldown)
{
    for (int i; i < strlen(word); i++) {
        if ('A' <= word[i] <= 'Z') {
            word[i] |= ' '; //to lowercase
        }
    }

    if (powerWords.ContainsKey(word)) {
        return false;
    }

    PowerWord powerword;
    powerword.init(percentage, minimum, cooldown);
    powerWords.SetArray(word, powerword, sizeof(PowerWord));

    return true;
}

bool DeletePowerword(char word[24])
{
    PowerWord powerword;
    if (!powerWords.GetArray(word, powerword, sizeof(PowerWord))) {
        return false;
    }

    powerword.close();
    powerWords.Remove(word);

    return true;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (client == 0) {
        return Plugin_Continue;
    }

    for (int i; i < strlen(sArgs); i++) {
        if ('A' <= sArgs[i] <= 'Z') {
            sArgs[i] |= ' '; //to lowercase
        }
    }

    if (powerWords.ContainsKey(sArgs)) {
        ReplySource restore = SetCmdReplySource(SM_REPLY_TO_CHAT); //yea we come from chat
        CheckPowerword(client, sArgs);
        SetCmdReplySource(restore);
    }
    return Plugin_Continue;
}

void UpdateClientsForVote()
{
    g_voters = 0;
    for (int i=1; i<=MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && IsClientAuthorized(i) && GetClientTeam(i))
            g_voters += 1;
    }
}

public void OnClientDisconnect(int client)
{
    CheckAllPowerwords(client);
}


void CheckPowerword(int client, const char[] word) {
    char prefix[24] = CHAT_PREFIX;
    if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE) {
        prefix = "[POWERWORD]";
    }

    PowerWord powerword;

    if (powerWords.GetArray(word, powerword, sizeof(PowerWord))) {
        if (!powerword.hasPermission(client)) {
            return; //silent fail
        }
        UpdateClientsForVote();
        VoteChangeResult result = powerword.vote(client, true);
        if (powerword.customPrefix[0] != 0) {
            strcopy(prefix, sizeof(prefix), powerword.customPrefix);
        }
        switch (result) {
            case VCR_Disabled:
                {/* pass */}
            case VCR_MoreClients:
                ReplyToCommand(client, "%s Not enough players for %s (%d/%d)", prefix, word, g_voters, powerword.minimum);
            case VCR_Cooldown:
                ReplyToCommand(client, "%s %s is on cooldown for %d seconds", prefix, word, RoundToNearest(powerword.nextVote - GetGameTime()));
            case VCR_Unchanged:
                ReplyToCommand(client, "%s You have already voted for %s", prefix, word);
            case VCR_Pending: {
                int votes = powerword.votestate.Count();
                float percentage = float(votes) / float(g_voters);

                int directRemaining = powerword.minimum-votes;
                int percentRemaining = RoundToCeil((powerword.percentage-percentage) * g_voters);
                int remaining = (directRemaining > percentRemaining) ? directRemaining : percentRemaining; //max
                if (remaining < 0) remaining = 0;

                PrintToChatAll("%s %N wants to %s, %d more required (%d/%d, %.1f%%/%.1f%%)", CHAT_PREFIX,
                        client, word, remaining,
                        votes, powerword.minimum,
                        percentage * 100.0, powerword.percentage * 100.0);
            }
            case VCR_Success: {
                int votes = powerword.votestate.Count();
                float percentage = float(votes) / float(g_voters);

                PrintToChatAll("%s %N wants to %s, powerword activate! (%d/%d, %.1f%%/%.1f%%)", CHAT_PREFIX,
                        client, word,
                        votes, powerword.minimum,
                        percentage * 100.0, powerword.percentage * 100.0);
                powerword.fire(word);
            }
        }
        powerWords.SetArray(word, powerword, sizeof(PowerWord));
    }
}

void CheckAllPowerwords(int client) {
    StringMapSnapshot snap = powerWords.Snapshot();
    char word[24];
    PowerWord powerword;
    UpdateClientsForVote();
    for (int i; i<snap.Length; i++) {
        snap.GetKey(i, word, sizeof(word));
        powerWords.GetArray(word, powerword, sizeof(PowerWord));
        if (powerword.vote(client, false) == VCR_Success) {
            PrintToChatAll("%s Vote quota for %s reached by disconnect", CHAT_PREFIX, word);
            powerword.fire(word);
        }
        powerWords.SetArray(word, powerword, sizeof(PowerWord));
    }
    delete snap;
}

void ResetAllPowerwords() {
    StringMapSnapshot snap = powerWords.Snapshot();
    char word[24];
    PowerWord powerword;
    UpdateClientsForVote();
    for (int i; i<snap.Length; i++) {
        snap.GetKey(i, word, sizeof(word));
        powerWords.GetArray(word, powerword, sizeof(PowerWord));
        powerword.reset();
        powerWords.SetArray(word, powerword, sizeof(PowerWord));
    }
    delete snap;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    initNatives();
}

ConVar config_cvar;
public void OnPluginStart()
{
    powerWords        = new StringMap();

    UpdateClientsForVote();

    ConVar cvar = CreateConVar("sm_powerword_version", PLUGIN_VERSION, "Powerword Version", FCVAR_NOTIFY);
    cvar.AddChangeHook(OnCvarVersionChange);
    cvar.SetString(PLUGIN_VERSION);
    delete cvar;
    config_cvar = CreateConVar("sm_powerword_config", "default", "Filename in addons/sourcemod/config/powerword/, without extension", FCVAR_NONE);
    config_cvar.AddChangeHook(OnCvarConfigChange);

    RequestFrame(Notify_PowerwordReady);

    RegAdminCmd("sm_powerword", Command_Force, ADMFLAG_CHEATS, "Force a powerword to trigger");
}
void OnCvarVersionChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!StrEqual(newValue, PLUGIN_VERSION)) convar.SetString(PLUGIN_VERSION);
}
void OnCvarConfigChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UnloadConfig();
    OnAllPluginsLoaded();
}

public void OnAllPluginsLoaded()
{
    char buffer[64];
    config_cvar.GetString(buffer, sizeof(buffer));
    LoadConfig(buffer);
}

public void OnServerExitHibernation()
{
    ResetAllPowerwords();
}

public void OnMapStart()
{
    ResetAllPowerwords();
}

Action Command_Force(int client, int args)
{
    char prefix[32] = CHAT_PREFIX;
    if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE) {
        prefix = "[POWERWORD]";
    }

    if (args < 1) {
        char command[32];
        GetCmdArg(0, command, sizeof(command));
        ReplyToCommand(client, "%s Usage: %s <powerword>", prefix, command);
        return Plugin_Handled;
    }

    char word[24];
    GetCmdArg(1, word, sizeof(word));
    PowerWord powerword;
    if (!powerWords.GetArray(word, powerword, sizeof(PowerWord))) {
        ReplyToCommand(client, "%s Unknown powerword");
    } else if (powerword.disabled) {
        ReplyToCommand(client, "%s This powerword is currently disabled", prefix);
    } else {
        ShowActivity2(client, "[POWERWORD] ", "%N triggered the powerword %s", client, word);
        powerword.nextVote = GetGameTime() + powerword.cooldown;
        powerword.fire(word);
        powerWords.SetArray(word, powerword, sizeof(PowerWord));
    }

    return Plugin_Handled;
}

#include "pw_natives.sp"
#include "pw_config.sp"

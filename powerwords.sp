#include <sdktools>
#include <sdkhooks>
#include <entity>
#include "include/playerbits"
#include "pw_natives.sp"
#include <tf2_stocks>

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

    VoteChangeResult vote(int client, bool set=true)
    {
        if (this.disabled) {
            return VCR_Disabled;
        }
        if (GetGameTime() < this.nextVote) {
            return VCR_Cooldown;
        }
        if (set) {
            int voted = this.votestate.Count();
            if (g_voters < this.minimum) {
                if (voted) {
                    this.votestate.Xor(this.votestate);
                }
                return VCR_MoreClients;
            }
            if (this.votestate.Get(client)) {
                return VCR_Unchanged;
            }
            this.votestate.Or(client);
            float vote_percent = float(g_voters) / float(voted);

            if (vote_percent < this.percentage || voted < this.minimum) {
                return VCR_Pending;
            }
            this.nextVote = GetGameTime() + this.cooldown;
            return VCR_Success;
        } else {
            if (!this.votestate.Get(client)) {
                return VCR_Unchanged;
            }
            this.votestate.AndNot(client);
            return VCR_Pending;
        }
    }

    /** call after a vote to prepare for the next */
    void reset()
    {
        this.votestate.XorBits(this.votestate);
    }

    void fire() {
        Call_StartForward(this.callback);
        Call_Finish();
        this.reset();
    }

    void init(float percentage, int minimum, float cooldown)
    {
        if (this.callback == null) {
            this.callback = new PrivateForward(ET_Ignore, Param_String);
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
        delete this.callback;
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

    char cmd[28];
    FormatEx(cmd, sizeof(cmd), "sm_%s", word);
    AddCommandListener(Command_Powerword, cmd);

    return true;
}

void DeletePowerword(char word[24])
{
    PowerWord powerword;
    if (!powerWords.GetString(word, powerword, sizeof(PowerWord))) {
        return false;
    }

    powerword.close();
    powerWords.Remove(word);
    RemoveCommandListener(Command_Powerword, word);

    return true;
}

Action Command_Powerword(int client, const char[] command, int argc)
{
    CheckPowerword(client, command[3]);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    for (int i; i < strlen(sArgs); i++) {
        if ('A' <= sArgs[i] <= 'Z') {
            sArgs[i] |= ' '; //to lowercase
        }
    }

    if (powerWords.ContainsKey(sArgs)) {
        ReplySource restore = SetCmdReplySource(SM_REPLY_TO_CHAT); //yea we come from chat
        CheckPowerword(client, sArgs);
        SetCmdReplySource(restore);
        return Plugin_Handled;
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
    return g_voters;
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
        UpdateClientsForVote();
        VoteChangeResult result = powerword.vote(client, true);
        switch (result) {
            case VCR_Disabled:
                {}
            case VCR_MoreClients:
                ReplyToCommand(client, "%s Not enough players for %s (%d/%d)", prefix, word, g_voters, powerword.minimum);
            case VCR_Cooldown:
                ReplyToCommand(client, "%s %s is on cooldown for %d seconds", prefix, word, RoundToNearest(powerword.nextVote - GetGameTime()));
            case VCR_Unchanged:
                ReplyToCommand(client, "%s You have already voted for %s", prefix, word);
            case VCR_Pending: {
                int votes = powerword.votestate.Count();
                float percentage = float(votes) / float(g_voters) * 100.0;
                int remainder;
                PrintToChatAll("%s %N wants to %s, %d more required (%d/%d, %.1f%%/%.1f%%)", CHAT_PREFIX, client, votes, powerword.minimum, percentage, powerword.percentage);
            }
            case VCR_Success: {
                PrintToChatAll("%s %N wants to %s, powerword activate!");
                powerword.fire();
            }
        }
        powerWords.SetArray(word, powerword);
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
        if (powerword.vote(client, false) == VoteChangeResult.Success) {
            PrintToChatAll("%s Vote quota for %s reached by disconnect", CHAT_PREFIX, word);
            powerword.fire();
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

public void OnPluginStart()
{
    powerWords        = new StringMap();

    UpdateClientsForVote();

    ConVar cvar = CreateConVar("sm_powerword_version", PLUGIN_VERSION, "Powerword Version", FCVAR_NOTIFY);
    cvar.AddChangeHook(OnCvarVersionChange);
    cvar.SetString(PLUGIN_VERSION);
    delete cvar;

    RequestFrame(notifyRead);
}
void OnCvarVersionChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!StrEqual(newValue, PLUGIN_VERSION)) convar.SetString(PLUGIN_VERSION);
}

public void OnServerExitHibernation()
{
    ResetAllPowerwords();
}

public void OnMapStart()
{
    ResetAllPowerwords();
}

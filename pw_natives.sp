#if !defined PLUGIN_VERSION
 #error Compiler main file!
#endif

GlobalForward fwd_PowerwordsReady;

void initNatives() {
    RegPluginLibrary("powerwords");

    CreateNative("Powerword_Create", Native_Create);
    CreateNative("Powerword_Delete", Native_Delete);
    CreateNative("Powerword_IsEnabled", Native_GetEnabled);
    CreateNative("Powerword_SetEnabled", Native_SetEnabled);
    CreateNative("Powerword_Reset", Native_Reset);
    CreateNative("Powerword_SetThreshold", Native_SetThreshold);
    CreateNative("Powerword_SetCooldown", Native_SetCooldown);
    CreateNative("Powerword_AddListener", Native_AddListener);
    CreateNative("Powerword_RemoveListener", Native_RemoveListener);

    fwd_PowerwordsReady = CreateGlobalForward("OnPowerwordsLoaded", ET_Ignore);
}

any Native_Create(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));
    float percentage = GetNativeCell(2);
    int minimum = GetNativeCell(3);
    float cooldown = GetNativeCell(4);

    return CreatePowerword(buffer, percentage, minimum, cooldown);
}

any Native_Delete(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));

    if (powerWords.ContainsKey(buffer)) {
        DeletePowerword(buffer);
        return true;
    }
    return false;
}

any Native_GetEnabled(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));

    PowerWord powerword;
    if (!powerWords.GetArray(buffer, powerword, sizeof(PowerWord))) {
        ThrowNativeError(SP_ERROR_NATIVE, "Powerword %s not registered", buffer);
    }
    return !powerword.disabled;
}

any Native_SetEnabled(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));
    bool newValue = GetNativeCell(2) != 0;

    PowerWord powerword;
    if (!powerWords.GetArray(buffer, powerword, sizeof(PowerWord))) {
        ThrowNativeError(SP_ERROR_NATIVE, "Powerword %s not registered", buffer);
    }
    powerword.disabled = !newValue;
    powerWords.SetArray(buffer, powerword, sizeof(PowerWord));
    return 0;
}

any Native_Reset(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));

    PowerWord powerword;
    if (!powerWords.GetArray(buffer, powerword, sizeof(PowerWord))) {
        ThrowNativeError(SP_ERROR_NATIVE, "Powerword %s not registered", buffer);
    }
    powerword.reset();
    powerword.nextVote = 0.0;
    powerWords.SetArray(buffer, powerword, sizeof(PowerWord));
    return 0;
}

any Native_SetThreshold(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));
    float percentage = GetNativeCell(2);
    int minimum = GetNativeCell(3);

    PowerWord powerword;
    if (!powerWords.GetArray(buffer, powerword, sizeof(PowerWord))) {
        ThrowNativeError(SP_ERROR_NATIVE, "Powerword %s not registered", buffer);
    }
    powerword.percentage = percentage;
    powerword.minimum = powerword.minimum;
    powerword.reset();
    powerWords.SetArray(buffer, powerword, sizeof(PowerWord));
    return 0;
}

any Native_SetCooldown(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));
    float cooldown = GetNativeCell(2);

    PowerWord powerword;
    if (!powerWords.GetArray(buffer, powerword, sizeof(PowerWord))) {
        ThrowNativeError(SP_ERROR_NATIVE, "Powerword %s not registered", buffer);
    }
    powerword.cooldown = cooldown;
    powerword.reset();
    powerWords.SetArray(buffer, powerword, sizeof(PowerWord));
    return 0;
}

any Native_AddListener(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));
    Function callback = GetNativeFunction(2);

    PowerWord powerword;
    if (!powerWords.GetArray(buffer, powerword, sizeof(PowerWord))) {
        ThrowNativeError(SP_ERROR_NATIVE, "Powerword %s not registered", buffer);
    }
    powerword.callback.AddFunction(plugin, callback);
    return 0;
}

any Native_RemoveListener(Handle plugin, int numParams)
{
    char buffer[24];
    GetNativeString(1, buffer, sizeof(buffer));
    Function callback = GetNativeFunction(2);

    PowerWord powerword;
    if (!powerWords.GetArray(buffer, powerword, sizeof(PowerWord))) {
        ThrowNativeError(SP_ERROR_NATIVE, "Powerword %s not registered", buffer);
    }
    powerword.callback.RemoveFunction(plugin, callback);
    return 0;
}

void Notify_PowerwordReady()
{
    Call_StartForward(fwd_PowerwordsReady);
    Call_Finish();
}

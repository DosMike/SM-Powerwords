#if !defined PLUGIN_VERSION
 #error Compile main file!
#endif

StringMap configPowerwords;

public void Powerword_Config(const char[] powerword)
{
    char buffer[PLATFORM_MAX_PATH];
    if (configPowerwords.GetString(powerword, buffer, sizeof(buffer))) {
        ServerCommand("%s", buffer);
    }
}

void UnloadConfig()
{
    if (configPowerwords == null) {
        return;
    }
    char word[24];
    StringMapSnapshot snap = configPowerwords.Snapshot();
    for (int i; i<snap.Length; i++) {
        snap.GetKey(i, word, sizeof(word));
        DeletePowerword(word);
    }
    delete snap;
    configPowerwords.Clear();
}

void LoadConfig(const char[] filename = "default")
{
    if (configPowerwords == null) {
        configPowerwords = new StringMap();
    }

    char buffer[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, buffer, sizeof(buffer), "configs/powerword/%s.cfg", filename);

    if (!FileExists(buffer)) {
        LogError("[POWERWORD] Could not load config - file not found: %s", buffer);
        return;
    }

    KeyValues config = new KeyValues("powerwords");
    config.ImportFromFile(buffer);

    char word[24];
    float vote_percentage;
    int vote_minimum;
    float vote_cooldown;
    PowerWord powerword;

    if (config.GotoFirstSubKey()) do {
        config.GetSectionName(word, sizeof(word));
        vote_percentage = config.GetFloat("vote_percentage", 50.0) / 100.0;
        vote_minimum = config.GetNum("vote_minimum", 5);
        vote_cooldown = config.GetFloat("vote_cooldown", 60.0);
        config.GetString("command", buffer, sizeof(buffer));
        TrimString(buffer);

        if (word[0] == 0) {
            LogError("[POWERWORD] Broken entry in config - empty key?");
            continue;
        }
        if (buffer[0] == 0) {
            LogError("[POWERWORD] No command for powerword '%s' declared in config", word);
            continue;
        }

        if (!CreatePowerword(word, vote_percentage, vote_minimum, vote_cooldown)) {
            LogError("[POWERWORD] Could not create powerword '%s' from config, already exists", word);
            continue;
        }

        configPowerwords.SetString(word, buffer);
        powerWords.GetArray(word, powerword, sizeof(PowerWord));
        powerword.callback.AddFunction(INVALID_HANDLE, Powerword_Config);

        bool updated = false;
        config.GetString("prefix", buffer, sizeof(buffer));
        TrimString(buffer);
        if (buffer[0] != 0) {
            strcopy(powerword.customPrefix, sizeof(PowerWord::customPrefix), buffer);
            updated = true;
        }
        config.GetString("adminflags", buffer, sizeof(buffer));
        TrimString(buffer);
        if (buffer[0] != 0) {
            powerword.adminFlagbits = ReadFlagString(buffer);
            updated = true;
        }
        if (updated) {
            powerWords.SetArray(word, powerword, sizeof(PowerWord));
        }

    } while (config.GotoNextKey());

    delete config;
    PrintToServer("[POWERWORD] Loaded config %s with %d powerwords", filename, configPowerwords.Size);
}
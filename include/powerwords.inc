
#if defined _powerwords_included_
  #endinput
#endif
#define _powerwords_included_

public SharedPlugin __pl_powerwords =
{
    name = "powerwords",
    file = "powerwords.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

/**
 * Called when powerwords was loaded and is ready to accept registrations.
 */
forward void OnPowerwordsLoaded();

/**
 * Create a new powerword for voting in chat.
 * @param word - the trigger word, lowercase, max 23 characters (excluding terminal 0)
 * @param vote_percentage - minimum % of players required for vote to pass
 * @param vote_minimum - minimum # of players requried for vote to pass
 * @param vote_cooldown - cooldown after successful vote before another vote can be started, reset on map change
 * @return true if created, false if the power word was already registered
 */
native bool Powerword_Create(const char[] word, float vote_percentage, int vote_minimum, float vote_cooldown);

/**
 * Delete a powerword
 * @param word - the trigger word
 * @return true if removed, false if not found
 */
native bool Powerword_Delete(const char[] word);

/**
 * Check if the powerword is enabled (this does not mean on cooldown!)
 * @param word - the trigger word
 * @return true if players can use the powerword
 * @throws if the powerword does not exist
 */
native bool Powerword_IsEnabled(const char[] word);

/**
 * Set whether the powerword shall be enabled
 * @param word - the trigger word
 * @param enabled - true if players should be able to use the powerword
 * @throws if the powerword does not exist
 */
native void Powerword_SetEnabled(const char[] word, bool enabled);

/**
 * Reset the vote state of the power word, including cooldown. If enabled, players can vote after this call.
 * @param word - the trigger word
 * @throws if the powerword does not exist
 */
native void Powerword_Reset(const char[] word);

/**
 * Change the thresholds for this powerword. This resets the vote count.
 * @param word - the trigger word
 * @param vote_percentage - minimum % of players required for vote to pass
 * @param vote_minimum - minimum # of players requried for vote to pass
 * @throws if the powerword does not exist
 */
native void Powerword_SetThreshold(const char[] word, float vote_percentage, int vote_minimum);

/**
 * Change the cooldown for this powerword. This resets the vote count.
 * This has no effect on a current cooldown, only later cooldowns.
 * @param word - the trigger word
 * @param vote_cooldown - cooldown after successful vote before another vote can be started, reset on map change
 * @throws if the powerword does not exist
 */
native void Powerword_SetCooldown(const char[] word, float cooldown);

typedef PowerwordCallback = function void();

/**
 * Add a callback to this powerword
 * This has no effect on a current cooldown, only later cooldowns.
 * @param word - the trigger word
 * @param callback - function to call when the powerword has been successfully voted
 * @throws if the powerword does not exist
 */
native void Powerword_AddListener(const char[] word, PowerwordCallback callback);

/**
 * Remove a callback from this powerword
 * This has no effect on a current cooldown, only later cooldowns.
 * @param word - the trigger word
 * @param callback - function to call when the powerword has been successfully voted
 * @throws if the powerword does not exist
 */
native void Powerword_RemoveListener(const char[] word, PowerwordCallback callback);

#if !defined REQUIRE_PLUGIN
public void __pl_powerwords_SetNTVOptional()
{
    MarkNativeAsOptional("Powerword_Create");
    MarkNativeAsOptional("Powerword_Delete");
    MarkNativeAsOptional("Powerword_IsEnabled");
    MarkNativeAsOptional("Powerword_SetEnabled");
    MarkNativeAsOptional("Powerword_Reset");
    MarkNativeAsOptional("Powerword_SetThreshold");
    MarkNativeAsOptional("Powerword_SetCooldown");
    MarkNativeAsOptional("Powerword_AddListener");
    MarkNativeAsOptional("Powerword_RemoveListener");
}
#endif

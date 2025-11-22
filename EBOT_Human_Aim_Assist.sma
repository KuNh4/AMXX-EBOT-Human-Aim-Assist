/*
================================================================================
    Plugin: [E-BOT] Human Aim Assist
    Version: 1.0
    Author: KuNh4
    
    Description:
    Helps E-BOTs as Humans land more headshots by converting
    chest and stomach hits to headshots based on a configurable chance.
    When zombies crouch leg hits also are converted.
    
================================================================================
*/

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <cs_ham_bots_api>

// Plugin Information
#define PLUGIN_NAME     "[E-BOT] Human Aim Assist"
#define PLUGIN_VERSION  "1.0"
#define PLUGIN_AUTHOR   "KuNh4"

// Offsets
const m_LastHitGroup = 75 // Player's last hit group offset

// Cvars
new g_pCvarHeadshotChance
new g_pCvarDebug

public plugin_init()
{
    // Register plugin
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    
    RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
    RegisterHamBots(Ham_TraceAttack, "fw_TraceAttack")
    
    g_pCvarHeadshotChance = register_cvar("ebot_aim_headshot_chance", "25")
    g_pCvarDebug = register_cvar("ebot_aim_debug", "0") 
    
    // Server command to display info
    register_srvcmd("ebot_aim_info", "ServerCmd_Info")

    server_print("[E-BOT Human Aim Assist] Plugin has loaded successfully! [Type ebot_aim_info]")
}

public plugin_cfg()
{
    // Auto-execute config file if it exists
    server_cmd("exec addons/amxmodx/configs/ebot_aim_assist.cfg")
}

public ServerCmd_Info()
{
    server_print("========================================")
    server_print(" %s v%s by %s", PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    server_print("========================================")
    server_print(" Headshot chance: %d%%", get_pcvar_num(g_pCvarHeadshotChance))
    server_print(" Debug mode: %s", get_pcvar_num(g_pCvarDebug) ? "ON" : "OFF")
    server_print(" Status: Active for E-BOT [Humans] only")
    server_print("========================================")
    
    return PLUGIN_HANDLED
}

public fw_TraceAttack(iVictim, iAttacker, Float:flDamage, Float:vecDirection[3], iTraceHandle, iDamageBits)
{
    new bool:bDebug = bool:get_pcvar_num(g_pCvarDebug)
    
    // Debug: Entry point
    if (bDebug)
        server_print("[E-BOT AIM] TraceAttack called: Attacker=%d Victim=%d Damage=%.1f", iAttacker, iVictim, flDamage)
    
    // ============================================
    // VALIDATION PHASE
    // ============================================
    
    if (!is_user_connected(iAttacker))
    {
        if (bDebug)
            server_print("[E-BOT AIM] SKIP: Attacker not connected")
        return HAM_IGNORED
    }
    
    if (!is_user_bot(iAttacker))
    {
        if (bDebug)
            server_print("[E-BOT AIM] SKIP: Attacker ID=%d is not a bot", iAttacker)
        return HAM_IGNORED
    }
    
    if (bDebug)
        server_print("[E-BOT AIM] BOT DETECTED: ID=%d", iAttacker)
    
    new iWeapon = get_user_weapon(iAttacker)
    
    if (bDebug)
    {
        new szWeaponName[32]
        get_weaponname(iWeapon, szWeaponName, charsmax(szWeaponName))
        server_print("[E-BOT AIM] Bot weapon: %s (ID=%d)", szWeaponName, iWeapon)
    }
    
    if (iWeapon == CSW_KNIFE)
    {
        if (bDebug)
           server_print("[E-BOT AIM] SKIP: Bot using knife (Zombie)")
        return HAM_IGNORED
    }
    
    if (bDebug)
        server_print("[E-BOT AIM] PASSED: Bot using gun (Human)")
    
    // ============================================
    // VICTIM STATE CHECK
    // ============================================

    // Get victim's flags to check ducking AND grounded state
    new iVictimFlags = pev(iVictim, pev_flags)
    new bool:bIsDucking = bool:(iVictimFlags & FL_DUCKING)
    new bool:bIsGrounded = bool:(iVictimFlags & FL_ONGROUND)
    
    if (bDebug)
        server_print("[E-BOT AIM] Victim state - Ducking: %s | Grounded: %s", 
        bIsDucking ? "YES" : "NO", bIsGrounded ? "YES" : "NO")
    
    // ============================================
    // HITGROUP VALIDATION
    // ============================================
    
    // Get the hitgroup
    new iHitgroup = get_tr2(iTraceHandle, TR_iHitgroup)
    
    if (bDebug)
    {
        new szHitgroupName[32]
        switch (iHitgroup)
        {
            case HIT_GENERIC: szHitgroupName = "GENERIC"
            case HIT_HEAD: szHitgroupName = "HEAD"
            case HIT_CHEST: szHitgroupName = "CHEST"
            case HIT_STOMACH: szHitgroupName = "STOMACH"
            case HIT_LEFTARM: szHitgroupName = "LEFT ARM"
            case HIT_RIGHTARM: szHitgroupName = "RIGHT ARM"
            case HIT_LEFTLEG: szHitgroupName = "LEFT LEG"
            case HIT_RIGHTLEG: szHitgroupName = "RIGHT LEG"
            default: szHitgroupName = "UNKNOWN"
        }
        server_print("[E-BOT AIM] Hitgroup: %s (ID=%d)", szHitgroupName, iHitgroup)
    }
    
    // Determine if this is a valid hit for conversion
    new bool:bIsValidHit = false
    
    // Case A: Chest and Stomach - ALWAYS valid (air or ground)
    if (iHitgroup == HIT_CHEST || iHitgroup == HIT_STOMACH)
    {
        bIsValidHit = true
        if (bDebug)
            server_print("[E-BOT AIM] Valid hit: Chest/Stomach (always valid)")
    }
    // Case B: Legs - Valid ONLY if victim is ducking AND grounded
    else if ((iHitgroup == HIT_LEFTLEG || iHitgroup == HIT_RIGHTLEG) && bIsDucking && bIsGrounded)
    {
        bIsValidHit = true
        if (bDebug)
            server_print("[E-BOT AIM] Valid hit: Leg (victim crouching on ground)")
    }
    else if ((iHitgroup == HIT_LEFTLEG || iHitgroup == HIT_RIGHTLEG) && bIsDucking && !bIsGrounded)
    {
        // Explicitly log crouch jump case
        if (bDebug)
            server_print("[E-BOT AIM] SKIP: Leg hit but victim is crouch jumping (in air)")
    }
    
    // If not a valid hit, skip
    if (!bIsValidHit)
    {
        if (bDebug)
            server_print("[E-BOT AIM] SKIP: Not a valid hitgroup for conversion")
        return HAM_IGNORED
    }
    
    if (bDebug)
        server_print("[E-BOT AIM] PASSED: Valid hitgroup for conversion")
    
    // ============================================
    // EXECUTION PHASE
    // ============================================
    
    // Get the headshot chance from cvar
    new iChance = get_pcvar_num(g_pCvarHeadshotChance)
    
    // Clamp the value between 0 and 100
    if (iChance < 0)
        iChance = 0
    else if (iChance > 100)
        iChance = 100
    
    // Roll the dice
    new iRoll = random_num(1, 100)
    
    if (bDebug)
        server_print("[E-BOT AIM] Chance Roll: %d/%d (need <=%d)", iRoll, 100, iChance)
    
    // If successful, convert to headshot
    if (iRoll <= iChance)
    {
        // Update trace result hitgroup
        set_tr2(iTraceHandle, TR_iHitgroup, HIT_HEAD)
        
        // Update victim's m_LastHitGroup offset for proper damage calculation
        set_pdata_int(iVictim, m_LastHitGroup, HIT_HEAD)
        
        if (bDebug)
        {
            new szAttackerName[32], szVictimName[32]
            get_user_name(iAttacker, szAttackerName, charsmax(szAttackerName))
            get_user_name(iVictim, szVictimName, charsmax(szVictimName))
            
            // Get original hitgroup name for debug
            new szOriginalHit[32]
            switch (iHitgroup)
            {
                case HIT_CHEST: szOriginalHit = "CHEST"
                case HIT_STOMACH: szOriginalHit = "STOMACH"
                case HIT_LEFTLEG: szOriginalHit = "LEFT LEG"
                case HIT_RIGHTLEG: szOriginalHit = "RIGHT LEG"
                default: szOriginalHit = "UNKNOWN"
            }
            
            server_print("[E-BOT AIM] *** HEADSHOT CONVERTED *** %s -> %s (Original: %s%s)", 
                szAttackerName, szVictimName, szOriginalHit, bIsDucking ? " - CROUCHING" : "")
            
            // Also print to chat for visibility
            client_print_color(0, print_team_default, "^4[E-BOT AIM]^1 Converted^3 %s^1 hit to^3 HEADSHOT^1! Bot:^3 %s^1 -> Victim:^3 %s", 
                szOriginalHit, szAttackerName, szVictimName)
        }
        
        return HAM_OVERRIDE
    }
    
    if (bDebug)
        server_print("[E-BOT AIM] Roll failed, no conversion")
    
    return HAM_IGNORED
}
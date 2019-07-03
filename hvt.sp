#include <sourcemod>
#include <sdktools>
#include <morecolors>

// CCSPlayer m_iAccount
int m_iAccount = -1;

float g_flKdrs[MAXPLAYERS+1] = 0.0;
int g_nKills[MAXPLAYERS+1] = 0;
int g_nDeaths[MAXPLAYERS+1] = 0;
int g_nHvt = -1;

ConVar hvt_moneyforkilldiff = null;
ConVar hvt_maxreward = null;
ConVar hvt_minreward = null;
ConVar hvt_minkills = null;
ConVar hvt_roundmessage = null;
ConVar hvt_debug = null;

public Plugin:HvtPluginInfo =
{
	name = "High Value Target",
	author = "FL",
	description = "Higher rewards for killing the top player.",
	version = "1.0",
	url = ""
};

public Min(int a, int b) {return (((a)<(b))?(a):(b));}
public Max(int a, int b) {return (((a)>(b))?(a):(b));}

public void OnPluginStart()
{
	hvt_moneyforkilldiff = CreateConVar("hvt_moneyforkilldiff", "200", "Amount of money granted for every kill HVT has more than the killer");
	hvt_maxreward = CreateConVar("hvt_maxreward", "1500", "Maximum reward for killing the HVT");
	hvt_minreward = CreateConVar("hvt_minreward", "100", "Maximum reward for killing the HVT");
	hvt_minkills = CreateConVar("hvt_minkills", "4", "Minimum amount of kills to be considered for HVT");
	hvt_roundmessage = CreateConVar("hvt_roundmessage", "0", "Should the high value target be displayed in chat at the start of each round");
	hvt_debug = CreateConVar("hvt_debug", "0", "Debug hvt plugin");

	m_iAccount = FindSendPropInfo("CCSPlayer", "m_iAccount");
	
	if (m_iAccount > 0) {
		PrintToServer("[HVT] High Value Target plugin loaded successfully!");

		HookEvent("player_death", Event_PlayerDeath);
		HookEvent("round_start", Event_RoundStart);
		HookEvent("player_disconnect", Event_Disconnect);
		HookEvent("player_connect", Event_Connect);
		HookEvent("server_spawn", Event_ServerSpawn)
	} else {
		PrintToServer("[HVT] High Value Target plugin load failed: unable to find m_iAccount");
	}
}

public CPrintToAllExcept(int exception, const String:szMessage[], any:...)
{
	decl String:szFormatted[1024];
	VFormat(szFormatted, sizeof(szFormatted), szMessage, 2);

	for (int i = 1; i < MaxClients; ++i)
	{
		if (i != exception && IsClientConnected(i))
		{
			CPrintToChat(i, "%s", szFormatted);
		}
	}
}

public HvtDebugMessage(const String:szMessage[], any:...)
{
	if (GetConVarInt(hvt_debug) == 0)
		return;

	decl String:szFormatted[1024];
	VFormat(szFormatted, sizeof(szFormatted), szMessage, 2);

	PrintToServer("[HVT] %s", szFormatted);
}

public bool IsValidClient(int nClient)
{
	return IsClientConnected(nClient) && IsClientInGame(nClient);
}

public ResetClient(int nClient)
{
	if (nClient == g_nHvt)
		ResetHvt();

	g_flKdrs[nClient] = 0.0;
	g_nKills[nClient] = 0;
	g_nDeaths[nClient] = 0;
}

public ResetHvt()
{
	if (g_nHvt != -1 && IsValidClient(g_nHvt))
	{
		decl String:szClientName[64];
		if(GetClientName(g_nHvt, szClientName, sizeof(szClientName)))
		{
			CPrintToAllExcept(g_nHvt, "{red}%s {default}is no longer the {red}HVT{default}.", szClientName);
			CPrintToChat(g_nHvt, "You are no longer the {red}high value target{default}.");
		}
	}

	g_nHvt = -1;
}

public UpdateHvt()
{
	float flHighestKdr = 0.0;
	int nHighestClient = -1;

	for (int i = 1; i < MaxClients; ++i)
	{
		if (!IsValidClient(i))
		{
			if (g_nHvt == i)
			{
				ResetHvt();
			}

			continue;
		}

		float flKdr = g_flKdrs[i];
		if (flKdr > flHighestKdr && g_nKills[i] >= GetConVarInt(hvt_minkills))
		{
			flHighestKdr = flKdr;
			nHighestClient = i;
		}
	}

	if (nHighestClient != -1 && nHighestClient != g_nHvt)
	{
		decl String:szClientName[64];
		if (GetClientName(nHighestClient, szClientName, sizeof(szClientName)))
		{
			g_nHvt = nHighestClient;
			CPrintToAllExcept(g_nHvt, "{red}%s {default}has become the {red}high value target{default}.", szClientName);
			CPrintToChat(g_nHvt, "{red}You {default}have become the {red}high value target{default}.");
		}
	}

	if (nHighestClient == -1)
	{
		ResetHvt();
	}
}

public float GetKdr(int nClient, int nNewDeaths, int nNewFrags)
{
	int nDeaths = GetClientDeaths(nClient) + nNewDeaths;
	int nFrags = GetClientFrags(nClient) + nNewFrags;

	HvtDebugMessage("Frags: %i Deaths: %i", nFrags, nDeaths);
	float flKdr = float(nFrags) / float(Max(nDeaths, 1));

	if ((nDeaths == 0) && (nFrags != 0))
		flKdr = float(nFrags);

	if (nFrags < 0)
		flKdr = float(0);

	g_nKills[nClient] = nFrags;
	g_nDeaths[nClient] = nDeaths;
	return flKdr;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{	
	int nAttacker = GetEventInt(event, "attacker");
	int nVictim = GetEventInt(event, "userid");

	int nAttackerId = GetClientOfUserId(nAttacker);
	int nVictimId = GetClientOfUserId(nVictim);

	// Update attacker
	if (IsValidClient(nAttackerId))
	{
		g_flKdrs[nAttackerId] = GetKdr(nAttackerId, 0, 1);
	}

	// Update victim
	if (IsValidClient(nVictimId))
	{
		g_flKdrs[nVictimId] = GetKdr(nVictimId, 1, 0);
		UpdateHvt();

		decl String:szClientName[64];
		if (IsValidClient(nAttackerId)
			&& g_nHvt == nVictimId
			&& nVictimId != nAttackerId
			&& GetClientName(nAttackerId, szClientName, sizeof(szClientName)))
		{
			int nBaseReward = GetConVarInt(hvt_moneyforkilldiff);
			int nMinReward = GetConVarInt(hvt_minreward);
			int nMaxReward = GetConVarInt(hvt_maxreward);

			int nReward = Max(1, g_nKills[g_nHvt] - g_nKills[nAttackerId]) * nBaseReward;

			int nTotalReward = Min(Max(nMinReward, nReward), nMaxReward);
			CPrintToAllExcept(nAttackerId, "Rewarding {red}%s {lightgreen}$%i {default}for killing the {red}high value target{default}.", szClientName, nTotalReward);
			CPrintToChat(nAttackerId, "You have been rewarded {lightgreen}$%i for killing the {red}high value target{default}.");

			int nNewMoney = GetEntData(nAttackerId, m_iAccount) + nTotalReward;

			if (nNewMoney > 16000)
				nNewMoney = 16000;

			SetEntData(nAttackerId, m_iAccount, nNewMoney, 4, true);
		}
	}

	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	HvtDebugMessage("Event_RoundStart");

	if (GetConVarBool(hvt_roundmessage))
	{
		decl String:szClientName[64];
		if (g_nHvt != -1 && IsValidClient(g_nHvt) && GetClientName(g_nHvt, szClientName, sizeof(szClientName)))
		{
			CPrintToAllExcept(g_nHvt, "{red}%s {default}is the current {red}high value target{default}.", szClientName);
			CPrintToChat(g_nHvt, "{red}You {default}are the current {red}high value target{default}.");
		}
	}

	UpdateHvt();
	return Plugin_Continue;
}

public Action:Event_Connect(Handle:event, const String:name[], bool:dontBroadcast) 
{
	int nUserId = GetEventInt(event, "userid");
	int nClient = GetClientOfUserId(nUserId);

	if (nClient > 0 && nClient <= MAXPLAYERS)
	{
		HvtDebugMessage("Event_Connect: Resetting client %i", nClient);
		ResetClient(nClient);
		UpdateHvt();
	}

	return Plugin_Continue;
}

public Action:Event_Disconnect(Handle:event, const String:name[], bool:dontBroadcast) 
{
	int nUserId = GetEventInt(event, "userid");
	int nClient = GetClientOfUserId(nUserId);

	if (nClient > 0 && nClient <= MAXPLAYERS)
	{
		HvtDebugMessage("Event_Disconnect: Resetting client %i", nClient);
		ResetClient(nClient);
		UpdateHvt();
	}

	return Plugin_Continue;
}

public Action:Event_ServerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	HvtDebugMessage("Event_ServerSpawn: Resetting client HVT data");
	for (int i = 1; i < MaxClients; ++i)
	{
		ResetClient(i);
	}

	ResetHvt();
	return Plugin_Continue;
}

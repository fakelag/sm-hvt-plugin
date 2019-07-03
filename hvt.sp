#include <sourcemod>
#include <sdktools>
#include <colors>

int m_iAccount = -1;

int g_nHvt = -1;

// int g_nRanks[MAXPLAYERS+1] = -1;

float g_flKdrs[MAXPLAYERS+1] = 0.0;
int g_nKills[MAXPLAYERS+1] = 0;
int g_nDeaths[MAXPLAYERS+1] = 0;

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

public Min(int a, int b)
{
	return (((a)<(b))?(a):(b));
}

public Max(int a, int b)
{
	return (((a)>(b))?(a):(b));
}

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
	} else {
		PrintToServer("[HVT] High Value Target plugin load failed: unable to find m_iAccount");
	}
}

public CPrintToAllExcept(int exception, const String:message[], any:...)
{
	decl String:formatted[1024];
	VFormat(formatted, sizeof(formatted), message, 2);

	for (int i = 1; i < MaxClients; ++i)
	{
		if(i != exception && IsClientConnected(i))
		{
			CPrintToChat(i, "%s", formatted);
		}
	}
}

public HvtDebugMessage(const String:message[], any:...)
{
	if (GetConVarInt(hvt_debug) == 0)
		return;

	decl String:formatted[1024];
	VFormat(formatted, sizeof(formatted), message, 2);

	PrintToServer("[HVT] %s", formatted);
}

public bool IsValidClient(int client)
{
	return IsClientConnected(client) && IsClientInGame(client);
}

public ResetClient(int client)
{
	if (client == g_nHvt)
		ResetHvt();

	//g_nRanks[client] = -1;

	g_flKdrs[client] = 0.0;
	g_nKills[client] = 0;
	g_nDeaths[client] = 0;
}

public ResetHvt()
{
	if (g_nHvt != -1 && IsValidClient(g_nHvt))
	{
		decl String:szClientName[64];
		if(GetClientName(g_nHvt, szClientName, sizeof(szClientName)))
		{
			// SendGlobalMsg("%s is no longer the high value target.", szClientName);
			CPrintToAllExcept(g_nHvt, "{red}%s {default}is no longer the {red}HVT{default}.", szClientName);
			CPrintToChat(g_nHvt, "You are no longer the {red}high value target{default}.");
		}
	}

	g_nHvt = -1;
}

public UpdateHvt()
{
	float highestKdr = 0.0;
	int highestClient = -1;

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

		float kdr = g_flKdrs[i];

		if (kdr > highestKdr && g_nKills[i] >= GetConVarInt(hvt_minkills)) {
			highestKdr = kdr;
			highestClient = i;
		}
	}

	if (highestClient != -1 && highestClient != g_nHvt)
	{
		new String:szClientName[64];
		if (GetClientName(highestClient, szClientName, sizeof(szClientName)))
		{
			g_nHvt = highestClient;
			// SendGlobalMsg("%s has become the high value target.", szClientName);
			CPrintToAllExcept(g_nHvt, "{red}%s {default}has become the {red}high value target{default}.", szClientName);
			CPrintToChat(g_nHvt, "{red}You {default}have become the {red}high value target{default}.");
		}
	}

	if (highestClient == -1)
	{
		ResetHvt();
	}
}

public float GetKdr(int client, int newDeaths, int newFragss)
{
	int nDeaths = GetClientDeaths(client) + newDeaths;
	int nFrags = GetClientFrags(client) + newFragss;
	
	HvtDebugMessage("Frags: %i Deaths: %i", nFrags, nDeaths);
	float flKdr = float(nFrags) / float(Max(nDeaths, 1));
	
	if ((nDeaths == 0) && (nFrags != 0))
		flKdr = float(nFrags);
	
	if (nFrags < 0)
		flKdr = float(0);

	g_nKills[client] = nFrags;
	g_nDeaths[client] = nDeaths;
	
	return flKdr;
}

// public int RankME_OnRankReceived(int client, int rank, any data) 
// {
// 	HvtDebugMessage("Client %i updated rank: %i", client, rank);
// 	g_nRanks[client] = rank;
// }

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
			int baseReward = GetConVarInt(hvt_moneyforkilldiff);
			int minReward = GetConVarInt(hvt_minreward);
			int maxReward = GetConVarInt(hvt_maxreward);

			int reward = Max(1, g_nKills[g_nHvt] - g_nKills[nAttackerId]) * baseReward;

			int moneyReward = Min(Max(minReward, reward), maxReward);
			// SendGlobalMsg("Rewarding %s $%i for killing the HVT.", szClientName, moneyReward);
			CPrintToAllExcept(nAttackerId, "Rewarding {red}%s {lightgreen}$%i {default}for killing the {red}high value target{default}.", szClientName, moneyReward);
			CPrintToChat(nAttackerId, "You have been rewarded {lightgreen}$%i for killing the {red}high value target{default}.");

			int newMoney = GetEntData(nAttackerId, m_iAccount) + moneyReward;

			if(newMoney > 16000)
				newMoney = 16000;
			
			SetEntData(nAttackerId, m_iAccount, newMoney, 4, true);
		}
	}

	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	HvtDebugMessage("Event_RoundStart");
	// for (int z = 1; z < MaxClients; ++z)
	// {
	// 	if(!IsValidClient(z))
	// 		continue;

	// 	RankMe_GetRank(z, RankME_OnRankReceived, 0);
	// }

	if (GetConVarBool(hvt_roundmessage))
	{
		decl String:szClientName[64];
		if (g_nHvt != -1 && IsValidClient(g_nHvt) && GetClientName(nAttackerId, szClientName, sizeof(szClientName)))
		{
			CPrintToAllExcept(g_nHvt, "{red}%s {default}is the current {red}high value target{default}.", szClientName);
			CPrintToChat(g_nHvt, "{red}You {default}are the current {red}high value target{default}.");
		}
	}

	UpdateHvt();
}

public Action:Event_Connect(Handle:event, const String:name[], bool:dontBroadcast) 
{
	int nUserId = GetEventInt(event, "userid");
	int client = GetClientOfUserId(nUserId);

	if (client > 0 && client <= MAXPLAYERS)
	{
		HvtDebugMessage("Event_Connect: Resetting client %i", client);
		ResetClient(client);
		UpdateHvt();
	}
}

public Action:Event_Disconnect(Handle:event, const String:name[], bool:dontBroadcast) 
{
	int nUserId = GetEventInt(event, "userid");
	int client = GetClientOfUserId(nUserId);

	if (client > 0 && client <= MAXPLAYERS)
	{
		HvtDebugMessage("Event_Disconnect: Resetting client %i", client);
		ResetClient(client);
		UpdateHvt();
	}
}

public Action:OnLevelInit(const String:mapName[], String:mapEntities[2097152])
{
	HvtDebugMessage("OnLevelInit: Resetting client HVT data");
	for (int i = 1; i < MaxClients; ++i)
	{
		ResetClient(i);
	}
	ResetHvt();
}

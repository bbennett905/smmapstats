#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "MapStats",
	author = PLUGIN_AUTHOR,
	description = "Gathers data on map playtime and population",
	version = PLUGIN_VERSION,
	url = ""
};

#define PREFIX "[MapStats]"
#define DATABASE "mapstats"

ConVar DataInterval;
bool IsTimerRunning;
Timer DataTimer;

Database MapStatsDatabase;

public void OnPluginStart()
{
	DataInterval = CreateConVar("sm_mapstats_interval", "15.0", "Interval between data points");
	
	if(SQL_CheckConfig(DATABASE)) //Check if the database is actually defined in the databases.cfg
	{
		PrintToServer(PREFIX ... "Connecting to database...");
		Database.Connect(SQL_DBConnect, DATABASE);
	}
	else
	{
		ThrowError(PREFIX ... "Database config not found! (sourcemod/configs/databases.cfg)");
		SetFailState(PREFIX ... "Database config not found! (sourcemod/configs/databases.cfg)");
	}
}

public void OnMapStart()
{

}

public void OnClientPostAdminCheck(int client)
{
	//TODO redo conditions
	if (!IsTimerRunning || GetClientCount() == 1)
	{
		DataTimer = CreateTimer(60.0 * DataInterval.FloatValue, TimerExpire);
	}
}

public Action TimerExpire(Handle timer)
{
	//TODO collectdata()
	if (GetClientCount() > 0)
	{
		DataTimer = CreateTimer(60.0 * DataInterval.FloatValue, TimerExpire);
	}
	return Plugin_Handled;
}

public Action CreateTables(Handle timer)
{
	char query[256];
	//TODO Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `mapstats` (`SteamID` INT(16) PRIMARY KEY, `Name` VARCHAR(32), `IP` VARCHAR(16));");
	MapStatsDatabase.Query(SQL_BaseQuery, query, _, DBPrio_Normal);
}

public void SQL_DBConnect(Database db, const char[] error, any data)
{	
	if (db == null)
	{
		LogError(PREFIX ... "Database error: %s", error);
		return;
	}

	char driver[8];
	SQL_ReadDriver(db, driver, sizeof(driver));
	if(strcmp(driver, "mysql", false) == 0)
	{
		PrintToServer(PREFIX ... "Database connected");
		MapStatsDatabase = db;
		CreateTimer(0.5, CreateTables); 
	}
	else
	{
		PrintToServer(PREFIX ... "Database error: must use MySQL database!");
	}
}

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

Database MapStatsDatabase;

/*	==============================================================================	*/
/*		INITIALIZATION																*/
/*	==============================================================================	*/
	
public void OnPluginStart()
{
	DataInterval = CreateConVar("sm_mapstats_interval", "15", 
		"Interval (minutes) between data points");
	
	if(SQL_CheckConfig(DATABASE)) //Check if the database is defined in the databases.cfg
	{
		PrintToServer(PREFIX ... "Connecting to database...");
		Database.Connect(SQLConnect, DATABASE);
	}
	else
	{
		ThrowError(PREFIX ... "Database config not found! (sourcemod/configs/databases.cfg)");
		SetFailState(PREFIX ... "Database config not found! (sourcemod/configs/databases.cfg)");
	}
}

public Action CreateTables(Handle timer)
{
	char query[512];
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `mapstats_servers` (" ...
		"server_id INT NOT NULL AUTO_INCREMENT, " ...
		"server_name VARCHAR(64), " ...
		"ip VARCHAR(16) NOT NULL UNIQUE, " ...
		"PRIMARY KEY (server_id) " ...
	");");
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `mapstats_data` (" ...
		"data_id INT NOT NULL AUTO_INCREMENT, " ...
		"server_id INT NOT NULL, " ...
		"map_name VARCHAR(64) NOT NULL, " ...
		"data_interval INT NOT NULL, " ...
		"player_count INT NOT NULL, " ...
  		"PRIMARY KEY (data_id), " ...
  		"FOREIGN KEY (server_id) REFERENCES mapstats_servers(server_id) " ...
	");");
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	
	char hostname[255];
	char hostnameSafe[512];
	char ip[15];
	char ipSafe[32];
	FindConVar("hostname").GetString(hostname, sizeof(hostname));
	FindConVar("ip").GetString(ip, sizeof(ip));
	MapStatsDatabase.Escape(hostname, hostnameSafe, sizeof(hostnameSafe));
	MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));
	Format(query, sizeof(query), "INSERT INTO `mapstats_servers` (server_name, ip) " ...
		"VALUES ('%s', '%s') " ...
		"ON DUPLICATE KEY UPDATE " ...
		"server_name = '%s';", hostnameSafe, ipSafe, hostnameSafe);
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
}

public void SQLConnect(Database db, const char[] error, any data)
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

public void SQLDefaultQuery(Database db, DBResultSet result, const char[] error, any data)
{
	if(result == null)
	{
		LogError(PREFIX ... "SQLDefaultQuery error: %s", error);
	}
}

/*	==============================================================================	*/
/*		DATA COLLECTION																*/
/*	==============================================================================	*/

public void OnClientPostAdminCheck(int client)
{
	//When the first player connects to the server, and the timer isn't already running
	if (!IsTimerRunning || GetClientCount() == 1)
	{
		IsTimerRunning = true;
		CreateTimer(60.0 * DataInterval.IntValue, TimerExpire);
	}
}

public Action TimerExpire(Handle timer)
{
	if (GetClientCount() > 0)
	{
		CollectData();
		CreateTimer(60.0 * DataInterval.IntValue, TimerExpire);
	}
	else
	{
		IsTimerRunning = false;
	}
	return Plugin_Handled;
}

void CollectData()
{
	char ip[15];
	char ipSafe[32];
	char map[PLATFORM_MAX_PATH];
	char mapSafe[(PLATFORM_MAX_PATH * 2) + 1];
	FindConVar("ip").GetString(ip, sizeof(ip));
	GetCurrentMap(map, sizeof(map));
	MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));
	MapStatsDatabase.Escape(map, mapSafe, sizeof(mapSafe));
	
	char query[512];
	Format(query, sizeof(query), "INSERT INTO `mapstats_data` " ...
		"(server_id, map_name, data_interval, player_count) " ...
		"VALUES ( " ...
			"(SELECT server_id FROM `mapstats_servers` WHERE ip = '%s'), " ...
			"'%s', " ...
			"%d, " ...
			"%d " ...
		");", ipSafe, mapSafe, DataInterval.IntValue, GetClientCount());
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
}


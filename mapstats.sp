#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Lithium"
#define PLUGIN_VERSION "1.1.5"

public Plugin myinfo = 
{
	name = "MapStats",
	author = PLUGIN_AUTHOR,
	description = "Gathers data on map playtime and popularity",
	version = PLUGIN_VERSION,
	url = "github.com/bbennett905"
};

#define PREFIX "[MapStats] "
#define DATABASE "mapstats"

ConVar DataInterval;
Handle DataTimer;

Database MapStatsDatabase;

/*	==============================================================================	*/
/*		INITIALIZATION																*/
/*	==============================================================================	*/
	
public void OnPluginStart()
{
	RegAdminCmd("sm_mapstats", CommandViewStats, ADMFLAG_CHANGEMAP, "View collected map stats");
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
	
	HookEvent("player_connect", EventPlayerConnect, EventHookMode_Post);
	HookEvent("player_disconnect", EventPlayerDisconnect, EventHookMode_Pre);
	
	LogMessage(PREFIX ... "Version " ... PLUGIN_VERSION ... " by " ... PLUGIN_AUTHOR);
}

public Action CreateTables(Handle timer)
{
	if (!MapStatsDatabase)
		return Plugin_Handled;
		
	char query[512];
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `mapstats_servers` (" ...
		"server_id INT NOT NULL AUTO_INCREMENT, " ...
		"server_name VARCHAR(128), " ...
		"ip VARCHAR(16) NOT NULL UNIQUE, " ...
		"PRIMARY KEY (server_id) " ...
	");");
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `mapstats_maps` ( " ...
		"map_id INT NOT NULL AUTO_INCREMENT, " ...
		"server_id INT NOT NULL, " ...
		"map_name VARCHAR(64) NOT NULL, " ...
		"connects INT NOT NULL DEFAULT 0, " ...
		"disconnects INT NOT NULL DEFAULT 0, " ...
		"PRIMARY KEY (map_id), " ...
		"FOREIGN KEY (server_id) REFERENCES mapstats_servers(server_id), " ...
		"UNIQUE KEY (server_id, map_name) " ...
	");");
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `mapstats_data` (" ...
		"data_id INT NOT NULL AUTO_INCREMENT, " ...
		"server_id INT NOT NULL, " ...
		"map_id INT NOT NULL, " ...
		"data_interval INT NOT NULL, " ...
		"player_count INT NOT NULL, " ...
		"timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, " ...
  		"PRIMARY KEY (data_id), " ...
  		"FOREIGN KEY (server_id) REFERENCES mapstats_servers(server_id), " ...
  		"FOREIGN KEY (map_id) REFERENCES mapstats_maps(map_id) " ...
	");");
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	
	char hostname[63];
	char hostnameSafe[128];
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
	
	return Plugin_Handled;
}

public Action InsertMap(Handle timer)
{
	if (!MapStatsDatabase)
		return Plugin_Handled;
		
	char ip[15];
	char ipSafe[32];
	char map[PLATFORM_MAX_PATH];
	char mapSafe[(PLATFORM_MAX_PATH * 2) + 1];
	FindConVar("ip").GetString(ip, sizeof(ip));
	GetCurrentMap(map, sizeof(map));
	MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));
	MapStatsDatabase.Escape(map, mapSafe, sizeof(mapSafe));
	
	char query[512];
	Format(query, sizeof(query), "INSERT INTO `mapstats_maps` (map_name, server_id) " ...
		"VALUES ( " ...
			"'%s', " ...
			"(SELECT server_id FROM `mapstats_servers` WHERE ip = '%s') " ...
		") ON DUPLICATE KEY UPDATE map_name=map_name;", 
    	mapSafe, ipSafe);
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	CreateTimer(1.0, InsertMap); 
}

public void SQLConnect(Database db, const char[] error, any data)
{	
	if (db == null)
	{
		MapStatsDatabase = null;
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

public Action EventPlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	if (!MapStatsDatabase)
		return;
		
	int client = GetClientOfUserId(GetEventInt(event, "userid", -1));
	if (client != 0 && !GetEventInt(event, "bot", -1))
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
		Format(query, sizeof(query), "UPDATE `mapstats_maps` " ...
			"SET connects=connects+1 " ...
			"WHERE map_name = '%s' AND " ...
			"server_id = (SELECT server_id FROM `mapstats_servers` WHERE ip = '%s');",
			mapSafe, ipSafe); 
		MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	}
}

public Action EventPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	if (!MapStatsDatabase)
		return;
		
	int client = GetClientOfUserId(GetEventInt(event, "userid", -1));
	if (client != 0 && !IsFakeClient(client))
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
		Format(query, sizeof(query), "UPDATE `mapstats_maps` " ...
			"SET disconnects=disconnects+1 " ...
			"WHERE map_name = '%s' AND " ...
			"server_id = (SELECT server_id FROM `mapstats_servers` WHERE ip = '%s');",
			mapSafe, ipSafe); 
		MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
	}
}

public void OnClientPostAdminCheck(int client)
{
	//When the first player connects to the server, and the timer isn't already running
	if (!DataTimer && GetClientCount() == 1)
	{
		DataTimer = CreateTimer(60.0 * DataInterval.IntValue, TimerExpire);
	}
}

public void OnClientDisconnect_Post(int client)
{
	if (GetClientCount() == 0)
	{
		delete DataTimer;
	}
}

public Action TimerExpire(Handle timer)
{
	if (GetClientCount() > 0)
	{
		CollectData();
		DataTimer = CreateTimer(60.0 * DataInterval.IntValue, TimerExpire);
	}
	else
	{
		DataTimer = null;
	}
	return Plugin_Handled;
}

void CollectData()
{
	if (!MapStatsDatabase)
		return;
		
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
		"(server_id, map_id, data_interval, player_count) " ...
		"VALUES ( " ...
			"(SELECT server_id FROM `mapstats_servers` WHERE ip = '%s'), " ...
			"(SELECT map_id FROM `mapstats_maps` WHERE " ...
            	"map_name = '%s' AND " ...
            	"server_id = (SELECT server_id " ...
            		"FROM `mapstats_servers` " ...
            		"WHERE ip = '%s'" ...
            	") " ...
        	")," ...
			"%d, " ...
			"%d " ...
		");", ipSafe, mapSafe, ipSafe, DataInterval.IntValue, GetClientCount());
	MapStatsDatabase.Query(SQLDefaultQuery, query, _, DBPrio_Normal);
}

/*	==============================================================================	*/
/*		DATA VIEWING/ANALYSIS														*/
/*	==============================================================================	*/

public Action CommandViewStats(int client, int argc)
{
	if (!MapStatsDatabase)
	{
		ReplyToCommand(client, PREFIX ... "Error getting stats! Try again later.");
		return Plugin_Handled;
	}
	if (argc == 0 && client != 0)
	{
		Menu menu = new Menu(MenuViewStats);
		menu.SetTitle("View stats by...");
		menu.AddItem("name", "Map Name");
		menu.AddItem("playertime", "Player Time");
		menu.AddItem("servertime", "Server Time");
		menu.AddItem("cdcratio", "Connect/Disconnect Ratio");
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else if (argc == 0 && client == 0)
	{
		ReplyToCommand(client, "Usage for server: sm_mapstats <name | player | server | ratio>");
	}
	else if (argc != 0)
	{
		char buffer[8];
		GetCmdArg(1, buffer, sizeof(buffer));
		if (StrEqual(buffer, "name"))
		{
			SortByNameQuery(client);
		}
		else if (StrEqual(buffer, "player"))
		{
			SortByPlayerQuery(client);
		}
		else if (StrEqual(buffer, "server"))
		{
			SortByServerQuery(client);
		}
		else if (StrEqual(buffer, "ratio"))
		{
			SortByRatioQuery(client);
		}
		else
		{
			ReplyToCommand(client, "Usage: sm_mapstats <name | player | server | ratio>");
		}
	}
	return Plugin_Handled;
}

public int MenuViewStats(Menu menu, MenuAction action, int client, int position)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char display[64], info[16];
			menu.GetItem(position, info, sizeof(info), _, display, sizeof(display));
			
			char ip[15];
			char ipSafe[32];
			FindConVar("ip").GetString(ip, sizeof(ip));
			MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));

			char query[512];
		    	
			if (StrEqual(info, "name"))
			{
				SortByNameQuery(client);
			}
			else if (StrEqual(info, "playertime"))
			{
				SortByPlayerQuery(client);
			}
			else if (StrEqual(info, "servertime"))
			{
				SortByServerQuery(client);
			}
			else if (StrEqual(info, "cdcratio"))
			{
				SortByRatioQuery(client);
			}
			MapStatsDatabase.Query(SQLSelectData, query, client, DBPrio_Normal);
		}
	}
}

void SortByNameQuery(int client)
{
	char ip[15];
	char ipSafe[32];
	FindConVar("ip").GetString(ip, sizeof(ip));
	MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));

	char query[512];

	Format(query, sizeof(query), "SELECT maps.map_name, " ...
		"maps.connects, " ...
		"maps.disconnects, " ...
		"(maps.connects / maps.disconnects), " ...
		"SUM(data.player_count * data.data_interval), " ...
		"SUM(data.data_interval), " ...
		"COUNT(data.data_id) " ...
		"FROM `mapstats_maps` AS maps INNER JOIN `mapstats_data` AS data ON " ...
		"(maps.map_id=data.map_id) " ...
		"WHERE maps.server_id = (SELECT server_id " ...
			"FROM `mapstats_servers` WHERE ip = '%s') " ...
		"GROUP BY maps.map_name " ...
		"ORDER BY maps.map_name ASC;", ipSafe);

	MapStatsDatabase.Query(SQLSelectData, query, client, DBPrio_Normal);
}

void SortByPlayerQuery(int client)
{
	char ip[15];
	char ipSafe[32];
	FindConVar("ip").GetString(ip, sizeof(ip));
	MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));

	char query[512];

	Format(query, sizeof(query), "SELECT maps.map_name, " ...
		"maps.connects, " ...
		"maps.disconnects, " ...
		"(maps.connects / maps.disconnects), " ...
		"SUM(data.player_count * data.data_interval), " ...
		"SUM(data.data_interval), " ...
		"COUNT(data.data_id) " ...
		"FROM `mapstats_maps` AS maps INNER JOIN `mapstats_data` AS data ON " ...
		"(maps.map_id=data.map_id) " ...
		"WHERE maps.server_id = (SELECT server_id " ...
			"FROM `mapstats_servers` WHERE ip = '%s') " ...
		"GROUP BY maps.map_name " ...
		"ORDER BY SUM(data.player_count * data.data_interval) DESC;", ipSafe);

	MapStatsDatabase.Query(SQLSelectData, query, client, DBPrio_Normal);
}

void SortByServerQuery(int client)
{
	char ip[15];
	char ipSafe[32];
	FindConVar("ip").GetString(ip, sizeof(ip));
	MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));

	char query[512];

	Format(query, sizeof(query), "SELECT maps.map_name, " ...
		"maps.connects, " ...
		"maps.disconnects, " ...
		"(maps.connects / maps.disconnects), " ...
		"SUM(data.player_count * data.data_interval), " ...
		"SUM(data.data_interval), " ...
		"COUNT(data.data_id) " ...
		"FROM `mapstats_maps` AS maps INNER JOIN `mapstats_data` AS data ON " ...
		"(maps.map_id=data.map_id) " ...
		"WHERE maps.server_id = (SELECT server_id " ...
			"FROM `mapstats_servers` WHERE ip = '%s') " ...
		"GROUP BY maps.map_name " ...
		"ORDER BY SUM(data.data_interval) DESC;", ipSafe);

	MapStatsDatabase.Query(SQLSelectData, query, client, DBPrio_Normal);
}

void SortByRatioQuery(int client)
{
	char ip[15];
	char ipSafe[32];
	FindConVar("ip").GetString(ip, sizeof(ip));
	MapStatsDatabase.Escape(ip, ipSafe, sizeof(ipSafe));

	char query[512];

	Format(query, sizeof(query), "SELECT maps.map_name, " ...
		"maps.connects, " ...
		"maps.disconnects, " ...
		"(maps.connects / maps.disconnects), " ...
		"SUM(data.player_count * data.data_interval), " ...
		"SUM(data.data_interval), " ...
		"COUNT(data.data_id) " ...
		"FROM `mapstats_maps` AS maps INNER JOIN `mapstats_data` AS data ON " ...
		"(maps.map_id=data.map_id) " ...
		"WHERE maps.server_id = (SELECT server_id " ...
			"FROM `mapstats_servers` WHERE ip = '%s') " ...
		"GROUP BY maps.map_name " ...
		"ORDER BY (maps.connects / maps.disconnects) DESC;", ipSafe);

	MapStatsDatabase.Query(SQLSelectData, query, client, DBPrio_Normal);
}

public void SQLSelectData(Database db, DBResultSet result, const char[] error, int client)
{
	if (result == null)
	{
		LogError(PREFIX ... "SQLSelectData error: %s", error);
		PrintToChat(client, PREFIX ... "Error getting stats! Try again later.");
		return;
	}
	
	if (result.RowCount < 1)
	{
		PrintToChat(client, PREFIX ... "No data found!");
		return;
	}

	PrintToConsole(client, "");
	PrintToConsole(client, "==============================================- MapStats -===============================================");
	PrintToConsole(client, "| Map name                | Player Hrs | Server Hrs | Connects | Disconnects | C/DC Ratio | Data Points |");
	PrintToConsole(client, "|-------------------------------------------------------------------------------------------------------|");
	while (result.FetchRow())
	{
		char mapname[24];
		result.FetchString(0, mapname, sizeof(mapname));
		int connects = result.FetchInt(1);
		int disconnects = result.FetchInt(2);
		float cdcratio;
		if (result.IsFieldNull(3))
		{
			cdcratio = 0.0;
		}
		else
		{
			cdcratio = result.FetchFloat(3);
		}
		float playertime = result.FetchInt(4) / 60.0;
		float servertime = result.FetchInt(5) / 60.0;
		int datapoints = result.FetchInt(6);

		PrintToConsole(client, "| %-24s|   %8.2f |   %8.2f | %8d |    %8d |   %8.4f |    %8d |", 
			mapname, playertime, servertime, connects, disconnects, cdcratio, datapoints);
	}
	PrintToConsole(client, "=========================================================================================================");
	PrintToChat(client, PREFIX ... "Check your console for output.");
}

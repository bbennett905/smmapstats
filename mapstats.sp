#include <sourcemod>
#include <sdktools>
#include <dynamic>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Lithium"
#define PLUGIN_VERSION "0.5"

public Plugin myinfo = 
{
	name = "MapStats",
	author = PLUGIN_AUTHOR,
	description = "Gathers data on map playtime and population",
	version = PLUGIN_VERSION,
	url = "github.com/bbennett905"
};

#define PREFIX "[MapStats] "
#define DATABASE "mapstats"
#define MAX_MAPS 100

enum SortMethod 
{
	ByName = 0,
	ByServerTime,
	ByPlayerTime,
	ByDataPoints
};

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
		"timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, " ...
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

/*	==============================================================================	*/
/*		DATA VIEWING/ANALYSIS														*/
/*	==============================================================================	*/

public Action CommandViewStats(int client, int argc)
{
	Menu menu = new Menu(MenuViewStats);
	menu.SetTitle("View stats by...");
	menu.AddItem("name", "Map Name");
	menu.AddItem("playertime", "Player Time");
	menu.AddItem("servertime", "Server Time");
	menu.AddItem("datapoints", "Number of Data Points");
	menu.Display(client, MENU_TIME_FOREVER);
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
			Format(query, sizeof(query), "SELECT map_name, data_interval, player_count " ...
				"FROM `mapstats_data` WHERE server_id = ( " ...
					"SELECT server_id FROM `mapstats_servers` WHERE ip = '%s'" ...
		    	");", ipSafe);
		    	
			if (StrEqual(info, "name"))
			{
				Format(query, sizeof(query), "SELECT map_name, SUM(player_count * data_interval), SUM(data_interval), COUNT(data_id) " ...
				    "FROM `mapstats_data` " ...
				    "WHERE server_id = (SELECT server_id FROM `mapstats_servers` WHERE ip = '%s') " ...
				    "GROUP BY map_name " ...
				    "ORDER BY map_name ASC", ipSafe);
			}
			else if (StrEqual(info, "servertime"))
			{
				Format(query, sizeof(query), "SELECT map_name, SUM(player_count * data_interval), SUM(data_interval), COUNT(data_id) " ...
				    "FROM `mapstats_data` " ...
				    "WHERE server_id = (SELECT server_id FROM `mapstats_servers` WHERE ip = '%s') " ...
				    "GROUP BY map_name " ...
				    "ORDER BY SUM(player_count * data_interval) DESC", ipSafe);
			}
			else if (StrEqual(info, "playertime"))
			{
				Format(query, sizeof(query), "SELECT map_name, SUM(player_count * data_interval), SUM(data_interval), COUNT(data_id) " ...
				    "FROM `mapstats_data` " ...
				    "WHERE server_id = (SELECT server_id FROM `mapstats_servers` WHERE ip = '%s') " ...
				    "GROUP BY map_name " ...
				    "ORDER BY SUM(data_interval) DESC", ipSafe);
			}
			else if (StrEqual(info, "datapoints"))
			{
				Format(query, sizeof(query), "SELECT map_name, SUM(player_count * data_interval), SUM(data_interval), COUNT(data_id) " ...
				    "FROM `mapstats_data` " ...
				    "WHERE server_id = (SELECT server_id FROM `mapstats_servers` WHERE ip = '%s') " ...
				    "GROUP BY map_name " ...
				    "ORDER BY COUNT(data_id) DESC", ipSafe);
			}
			MapStatsDatabase.Query(SQLSelectData, query, client, DBPrio_Normal);
		}
	}
}

public void SQLSelectData(Database db, DBResultSet result, const char[] error, int client)
{
	if (result == null)
	{
		LogError(PREFIX ... "SQLSelectData error: %s", error);
		return;
	}
	
	if (result.RowCount < 1)
	{
		PrintToChat(client, PREFIX ... "No data found!");
		return;
	}

	PrintToConsole(client, "");
	PrintToConsole(client, "======================================- MapStats -=======================================");
	PrintToConsole(client, "| Map name                        | Player Time (Hrs) | Server Time (Hrs) | Data Points |");
	PrintToConsole(client, "|---------------------------------------------------------------------------------------|");
	while (result.FetchRow())
	{
		char mapname[32];
		result.FetchString(0, mapname, sizeof(mapname));
		float playertime = result.FetchInt(1) / 60.0;
		float servertime = result.FetchInt(2) / 60.0;
		int datapoints = result.FetchInt(3);

		PrintToConsole(client, "| %-32s|          %8.2f |          %8.2f |   %8d |", 
			mapname, playertime, servertime, datapoints);
	}
	PrintToConsole(client, "=========================================================================================");
	PrintToChat(client, PREFIX ... "Check your console for output.");
}

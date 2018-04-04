#include <sourcemod>
#include <sdktools>
#include <dynamic>
#include <mapstats>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Lithium"
#define PLUGIN_VERSION "0.3"

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
bool IsTimerRunning;

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

/*	==============================================================================	*/
/*		DATA VIEWING/ANALYSIS														*/
/*	==============================================================================	*/

public Action CommandViewStats(int client, int argc)
{
	Menu menu = new Menu(MenuViewStats);
	menu.SetTitle("View stats by...");
	menu.AddItem("name", "Map Name");
	menu.AddItem("servertime", "Server Time");
	menu.AddItem("playertime", "Player Time");
	menu.AddItem("datapoints", "Number of Data Points");
	menu.AddItem("summary", "Summary");
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
		    	
			DataPack data = new DataPack();
			data.WriteCell(client);
			if (StrEqual(info, "name"))
			{
				data.WriteCell(ByName);
			}
			else if (StrEqual(info, "servertime"))
			{
				data.WriteCell(ByServerTime);
			}
			else if (StrEqual(info, "playertime"))
			{
				data.WriteCell(ByPlayerTime);
			}
			else if (StrEqual(info, "datapoints"))
			{
				data.WriteCell(ByDataPoints);
			}
			else if (StrEqual(info, "summary"))
			{
				//TODO do this
				PrintToChat(client, PREFIX ... "This feature is not yet implemented!");
			}
			MapStatsDatabase.Query(SQLSelectData, query, data, DBPrio_Normal);
		}
	}
}

public void SQLSelectData(Database db, DBResultSet result, const char[] error, DataPack data)
{
	if (result == null)
	{
		LogError(PREFIX ... "SQLSelectData error: %s", error);
		return;
	}
	data.Reset();
	int client = data.ReadCell();
	SortMethod sort = data.ReadCell();
	delete data;
	
	if (result.RowCount < 1)
	{
		PrintToChat(client, PREFIX ... "No data found!");
		return;
	}
	
	PrintToChat(client, PREFIX ... "Parsing data...");
	
	MapStatsEntry table[MAX_MAPS];
	for (int i = 0; i < MAX_MAPS; i++)
	{
		table[i] = MapStatsEntry();
	}
	
	int max = 0;
	//Populate the table with the results 
	while (result.FetchRow())
	{
		char mapname[PLATFORM_MAX_PATH];
		result.FetchString(0, mapname, sizeof(mapname));
		int interval = result.FetchInt(1);
		int players = result.FetchInt(2);
		
		bool success = false;
		for (int i = 0; i < MAX_MAPS; i++)
		{
			char buffer[PLATFORM_MAX_PATH];
			table[i].GetMapName(buffer, sizeof(buffer));
			if (StrEqual(buffer, mapname, false))
			{
				//Entry for this map already exists
				table[i].ServerTime = table[i].ServerTime + interval;
				table[i].PlayerTime = table[i].ServerTime + (players * interval);
				table[i].DataPoints = table[i].ServerTime + 1;
				success = true;
				break;
			}
			else if (StrEqual(buffer, "", false))
			{
				//Map not found, so add it here
				table[i].SetMapName(buffer);
				table[i].ServerTime = interval;
				table[i].PlayerTime = players * interval;
				table[i].DataPoints = 1;
				max = i;
				success = true;
				break;
			}
		}
		if (!success)
		{
			PrintToChat(client, PREFIX ... "Error: too many maps! Ask the dev to increase map limit");
			break;
		}
	}
	
	//Now, sort table based on what was selected earlier
	//TODO This is super ugly - clean this up at some point
	switch (sort)
	{
		case ByName:
		{
			//Largest N right now is 100, so insertion sort isn't really that bad
			int i = 1;
			while (i < max + 1)
			{
				MapStatsEntry temp = table[i];
				int j = i - 1;
				char mapL[PLATFORM_MAX_PATH];
				char mapR[PLATFORM_MAX_PATH];
				table[j].GetMapName(mapL, sizeof(mapL));
				temp.GetMapName(mapR, sizeof(mapR));
				while (j >= 0 && strcmp(mapL, mapR, false))
				{
					table[j + 1] = table[j];
					j = j - 1;
				}
				table[j + 1] = temp;
				i++;
			}
		}
		case ByServerTime:
		{
			int i = 1;
			while (i < max + 1)
			{
				MapStatsEntry temp = table[i];
				int j = i - 1;
				while (j >= 0 && table[j].ServerTime > temp.ServerTime)
				{
					table[j + 1] = table[j];
					j = j - 1;
				}
				table[j + 1] = temp;
				i++;
			}
		}
		case ByPlayerTime:
		{
			int i = 1;
			while (i < max + 1)
			{
				MapStatsEntry temp = table[i];
				int j = i - 1;
				while (j >= 0 && table[j].PlayerTime > temp.PlayerTime)
				{
					table[j + 1] = table[j];
					j = j - 1;
				}
				table[j + 1] = temp;
				i++;
			}
		}
		case ByDataPoints:
		{
			int i = 1;
			while (i < max + 1)
			{
				MapStatsEntry temp = table[i];
				int j = i - 1;
				while (j >= 0 && table[j].DataPoints > temp.DataPoints)
				{
					table[j + 1] = table[j];
					j = j - 1;
				}
				table[j + 1] = temp;
				i++;
			}
		}
	}
	
	//Done sorting! Format and print our table
	PrintToConsole(client, " ==================== MapStats ====================");
	PrintToConsole(client, " Map name                       | Player Time (Hrs) | Server Time (Hrs) | Data Points");
	for (int i = 0; i < max + 1; i++)
	{
		char map[32];
		table[i].GetMapName(map, sizeof(map));
		PrintToConsole(client, "%-32s|          %-8d |          %-8d |   %-8d", 
			map, table[i].PlayerTime, table[i].ServerTime, table[i].DataPoints);
	}
	PrintToChat(client, PREFIX ... "Check your console for output.");
}

# Sourcemod MapStats #
*A simple plugin for tracking playtime and popularity of maps*

### About ###
This plugin was created as a simple way to find out what maps are the most popular on a server running Sourcemod. It is still under development, and may be changed significantly.

#### Features ####
* Multi-server support
* View several statistics for each map, and sort maps based on them
	* Map Name
	* Hours players have spent on the map
	* Hours the server has run the map
	* Number of times players have connected or disconnected during the map
	* Ratio of connects to disconnects

#### Installation ####
Add an entry to your *sourcemod/configs/databases.cfg* file for "mapstats" with your database info (Note: Only supports MySQL databases). Copy *mapstats.smx* into your *sourcemod/plugins* folder. That's it!

#### Cvars ####
 * *sm_mapstats_interval \<int\>* - Sets the interval between data samples

#### Commands ####
 * *sm_mapstats* - Gives several options for sorting map data printed to console

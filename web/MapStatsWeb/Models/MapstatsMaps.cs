using System;
using System.Collections.Generic;

namespace MapStatsWeb.Models
{
    public partial class MapstatsMaps
    {
        public MapstatsMaps()
        {
            MapstatsData = new HashSet<MapstatsData>();
        }

        public int MapId { get; set; }
        public int ServerId { get; set; }
        public string MapName { get; set; }
        public int Connects { get; set; }
        public int Disconnects { get; set; }

        public MapstatsServers Server { get; set; }
        public ICollection<MapstatsData> MapstatsData { get; set; }
    }
}

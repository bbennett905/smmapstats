using System;
using System.Collections.Generic;

namespace MapStatsWeb.Models
{
    public partial class MapstatsServers
    {
        public MapstatsServers()
        {
            MapstatsData = new HashSet<MapstatsData>();
            MapstatsMaps = new HashSet<MapstatsMaps>();
        }

        public int ServerId { get; set; }
        public string ServerName { get; set; }
        public string Ip { get; set; }
        public string Engine { get; set; }
        public string Version { get; set; }

        public ICollection<MapstatsData> MapstatsData { get; set; }
        public ICollection<MapstatsMaps> MapstatsMaps { get; set; }
    }
}

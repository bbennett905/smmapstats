using System;
using System.Collections.Generic;

namespace MapStatsWeb.Models
{
    public partial class MapstatsData
    {
        public int DataId { get; set; }
        public int ServerId { get; set; }
        public int MapId { get; set; }
        public int DataInterval { get; set; }
        public int PlayerCount { get; set; }
        public DateTimeOffset Timestamp { get; set; }

        public MapstatsMaps Map { get; set; }
        public MapstatsServers Server { get; set; }
    }
}

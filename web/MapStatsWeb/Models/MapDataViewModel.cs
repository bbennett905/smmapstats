using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace MapStatsWeb.Models
{
    public class MapDataViewModel
    {
        public int ServerId { get; set; }
        public string MapName { get; set; }
        public int Connects { get; set; }
        public int Disconnects { get; set; }
        public float Ratio { get; set; }
        public float PlayerHours { get; set; }
        public float ServerHours { get; set; }
        public int DataPoints { get; set; }
        public float AveragePlayers
        {
            get { return PlayerHours / ServerHours; }
        }
    }
}

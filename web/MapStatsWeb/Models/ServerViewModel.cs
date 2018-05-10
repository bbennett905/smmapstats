using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace MapStatsWeb.Models
{
    public class ServerViewModel
    {
        public int ServerId { get; set; }
        public string ServerName { get; set; }
        public string Ip { get; set; }
        public string Version { get; set; }
        public string EngineImg { get; set; }
    }
}

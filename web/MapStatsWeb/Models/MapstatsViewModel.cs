using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace MapStatsWeb.Models
{
    public class MapstatsViewModel
    {
        public IEnumerable<ServerViewModel> Servers { get; set; }
        public IDictionary<int, IEnumerable<MapDataViewModel>> Data { get; set; }
    }
}

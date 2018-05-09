using MapStatsWeb.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Encodings.Web;
using System.Threading.Tasks;
using System.Linq;
using System.Collections.Generic;

namespace MapStatsWeb.Controllers
{
    public class MapStatsController : Controller
    {
        private readonly MapstatsContext _context;
        public MapStatsController(MapstatsContext context)
        {
            _context = context;
        }
        // 
        // GET: /mapstats/

        public IActionResult Index(int time = -1, string timeunit = "days")
        {
            if (timeunit == "alltime")
            {   //Easiest way to do this is just set it to -1 and let everything else handle it
                time = -1;
            }

            var validatedTime = time;
            if (validatedTime < 1)
            {
                validatedTime = 10;
            }

            ViewData["rawtime"] = time;
            ViewData["time"] = validatedTime;
            ViewData["timeunit"] = timeunit;

            var model = new MapstatsViewModel();
            var serverListRaw = _context.MapstatsServers.ToList();

            IList<ServerViewModel> serverList = new List<ServerViewModel>();

            Dictionary<int, IEnumerable<MapDataViewModel>> dataList = new Dictionary<int, IEnumerable<MapDataViewModel>>();
            
            foreach (var server in serverListRaw)
            {
                if (server.Engine == "")
                {
                    server.Engine = "other";
                }
                ServerViewModel serverViewModel = new ServerViewModel
                {
                    ServerId = server.ServerId,
                    Ip = server.Ip,
                    ServerName = server.ServerName,
                    Version = server.Version,
                    EngineImg = "/images/games/" + server.Engine + ".png"
                };

                var timeSince = System.DateTimeOffset.Now;
                if (timeunit == "days")
                {
                    timeSince = timeSince.AddDays(0 - time);
                }
                else if (timeunit == "months")
                {
                    timeSince = timeSince.AddMonths(0 - time);
                }
                
                if (time < 1) //If time is invalid, assume from all time
                {
                    timeSince = System.DateTimeOffset.MinValue;
                }

                serverList.Add(serverViewModel);
                var dataQuery = from maps in _context.MapstatsMaps
                                join data in _context.MapstatsData.Where(x => x.Timestamp > timeSince)
                                on maps.MapId equals data.MapId into groupedData
                                where maps.ServerId == server.ServerId
                                select new MapDataViewModel
                                {
                                    ServerId = maps.ServerId,
                                    MapName = maps.MapName,
                                    Connects = maps.Connects,
                                    Disconnects = maps.Disconnects,
                                    Ratio = ((float)maps.Connects) / ((float)maps.Disconnects),
                                    PlayerHours = ((float)groupedData.Sum(x => x.PlayerCount * x.DataInterval)) / 60.0f,
                                    ServerHours = ((float)groupedData.Sum(x => x.DataInterval)) / 60.0f,
                                    DataPoints = groupedData.Count()
                                };
                dataQuery = dataQuery.OrderByDescending(x => x.Ratio);
                dataList[server.ServerId] = dataQuery.ToList();
            }

            model.Servers = serverList;
            model.Data = dataList;
            return View(model);
        }
    }
}

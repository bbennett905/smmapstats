#if defined _mapstats_included
	#endinput
#endif
#define _mapstats_included

methodmap MapStatsEntry < Dynamic
{
	public MapStatsEntry()
	{
		Dynamic entry = Dynamic(64, 0);
		entry.SetString("MapName", "", PLATFORM_MAX_PATH);
		entry.SetInt("ServerTime", 0);
		entry.SetInt("PlayerTime", 0);
		entry.SetInt("DataPoints", 0);
		return view_as<MapStatsEntry>(entry);
	}

	public bool GetMapName(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("MapName");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}

	public void SetMapName(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("MapName");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("MapName", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}

	property int ServerTime
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("ServerTime");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetIntByOffset(offset);
		}
		public set(int value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("ServerTime");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetInt("ServerTime", value);
					return;
				}
			}
			this.SetIntByOffset(offset, value);
		}
	}

	property int PlayerTime
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("PlayerTime");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetIntByOffset(offset);
		}
		public set(int value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("PlayerTime");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetInt("PlayerTime", value);
					return;
				}
			}
			this.SetIntByOffset(offset, value);
		}
	}

	property int DataPoints
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("DataPoints");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetIntByOffset(offset);
		}
		public set(int value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("DataPoints");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetInt("DataPoints", value);
					return;
				}
			}
			this.SetIntByOffset(offset, value);
		}
	}
}
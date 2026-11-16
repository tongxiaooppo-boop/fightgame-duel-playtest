extends RefCounted

enum { LIU, GU, PEI, SHI, LU, RUAN, WEN, FANG, HONG }

const PLAYABLE_COUNT := HONG
const LADDER_LENGTH := PLAYABLE_COUNT
const NAMES := ["柳語棠", "顧墨白", "裴景衡", "石定岳", "陸行舟", "阮潮音", "溫書嵐", "方熔野", "洪萬金"]
const RIVALS := [GU, LIU, SHI, PEI, RUAN, LU, FANG, WEN]
const STYLES := ["走位牽制", "遠距干擾", "中距反擊", "重型壓場", "快速突入", "潮浪擊飛", "防反回旋", "機械壓制"]
const CPU_DISTANCE := [128.0, 151.0, 142.0, 151.0, 125.0, 138.0, 132.0, 156.0, 150.0]
const CPU_FIRST_RANGE := [230.0, 212.0, 330.0, 242.0, 306.0, 193.0, 223.0, 181.0, 230.0]
const CPU_SECOND_RANGE := [Vector2(148, 318), Vector2(0, 215), Vector2(0, 190), Vector2(0, 185),
	Vector2(0, 185), Vector2(110, 285), Vector2(0, 158), Vector2(0, 300), Vector2(0, 232)]
const CPU_THIRD_RANGE := [Vector2(175, 335), Vector2(175, 335), Vector2(172, 390), Vector2(172, 386),
	Vector2(148, 340), Vector2(150, 500), Vector2(140, 460), Vector2(195, 382), Vector2(120, 420)]
const SKILLS := [
	[&"lane_step", &"ribbon_split", &"paper_flock"],
	[&"second_question", &"afterimage", &"echo_swarm"],
	[&"copper_palm", &"copper_guard", &"copper_volley"],
	[&"pile_driver", &"steel_barrier", &"steel_wheel"],
	[&"station_elbow", &"return_line", &"ridge_dash"],
	[&"tide_palms", &"ebb_step", &"harbor_wave"],
	[&"fan_point", &"fan_counter", &"returning_fan"],
	[&"magnet_relay", &"machine_drop", &"workshop_overload"],
	[&"internal_poll", &"folding_chairs", &"victory_scroll"],
]
const SKILL_NAMES := [
	["掃街拜票", "微血管", "召喚青鳥"],
	["再辯一輪", "查核打臉", "呼叫網軍"],
	["都更第一箭", "程序發言", "都更八箭"],
	["動土第一鏟", "工程圍籬", "捷運試車"],
	["二十分鐘", "選舉折返跑", "山線捷徑"],
	["海線大進擊", "轉進下一攤", "四三二一浪"],
	["扇子拜票", "三代攏共好", "扇子轉一圈"],
	["智慧握手", "政見自動投", "產業大升級"],
	["內參第一名", "現場加椅子", "全台都贏啦"],
]
const SKILL_GAGS := [
	[[&"flag", "拜託拜託", "從巷口拜到你家門口"], [&"route", "交通微血管", "這條還在規劃"], [&"post", "青鳥集合", "集合後請自行解散"]],
	[[&"mic", "時間到", "那我再講一輪"], [&"stamp", "請附來源", "來源：群組轉傳"], [&"post", "推／加一／洗版", "小編切錯帳號了"]],
	[[&"arrow", "都更第一箭", "釘在公告欄"], [&"mic", "程序發言", "先不要插話"], [&"arrow", "都更八箭", "第八箭還在會勘"]],
	[[&"ribbon", "動土典禮", "合照完再挖"], [&"barrier", "工程圍籬", "工期依現場公告"], [&"route", "捷運試車", "市民請勿追車"]],
	[[&"route", "二十分鐘", "尖峰時段另計"], [&"flag", "選舉折返跑", "剛才答應哪一里"], [&"route", "重新規劃", "導航也在跑行程"]],
	[[&"flag", "海線大進擊", "先喊四三二一"], [&"flag", "下一攤", "握過的手不能退"], [&"post", "四三二一", "倒數完才開打"]],
	[[&"fan", "扇子拜票", "免費，請帶回家"], [&"mic", "三代攏共好", "阿嬤叫你先坐下"], [&"fan", "再轉一圈", "送出去又回來"]],
	[[&"post", "智慧握手", "AI 記得你的名字"], [&"post", "政見自動投", "落點由 AI 決定"], [&"stamp", "產業升級", "更新中，請勿關機"]],
	[[&"poll", "內參第一名", "樣本：競總群組"], [&"chair", "加椅子", "把空位排出人潮"], [&"poll", "全台都贏啦", "輸的先不要播"]],
]
const COOLDOWNS := [240, 360, 480]
const SUPER_NAMES := ["全台掃街", "麥克風全開", "八箭全上", "剪綵三連發", "全區都順路", "海線總動員", "發扇全壘打", "黃金十年計畫", "自行宣布當選"]
const SUPER_CALLS := [
	"我來囉，你站這邊就好",
	"等一下，我再補一句就好",
	"大家等等，先聽我說兩句",
	"麻煩借過，我來弄就好",
	"跟我走這邊，還比較快",
	"大家跟好喔，我們走這邊",
	"來，扇子拿好，天氣很熱",
	"等我一下，我再試一遍",
	"先別走啦，等一下就知道",
]
const SUPER_GAGS := [
	[&"flag", "掃街車即將通過", "選前每天都路過"], [&"mic", "下一題還是我", "全場有聲，只有主持人靜音"],
	[&"arrow", "八箭齊發", "八支都射了，還在跑流程"], [&"ribbon", "合龍剪綵", "剪綵第三次，工程進度還是零"],
	[&"route", "全區都順路", "到哪都說二十分鐘"], [&"flag", "鄉親總動員", "鄉親都到齊，主委還在找車位"],
	[&"fan", "扇子一人一把", "對手也拿到了"], [&"poll", "進度九十九", "預算已用完"],
	[&"poll", "競總速報", "票沒開完，感謝詞先背好"],
]
const SUPER_BEATS := [
	[48, 61, 79, 96, 113, 149],
	[49, 65, 83, 104, 124, 168],
	[49, 63, 77, 94, 114, 156],
	[50, 69, 88, 108, 127, 171],
	[47, 58, 70, 84, 105, 146],
	[49, 64, 81, 100, 119, 164],
	[48, 64, 80, 98, 116, 157],
	[49, 65, 86, 103, 123, 168],
	[48, 61, 78, 95, 119, 162],
]
const SUPER_DAMAGE := [[28, 31, 35, 38, 44, 111], [33, 35, 37, 41, 45, 96],
	[33, 35, 37, 41, 45, 96], [28, 31, 35, 38, 44, 111], [33, 35, 37, 41, 45, 96],
	[28, 31, 35, 38, 44, 111], [33, 35, 37, 41, 45, 96], [28, 31, 35, 38, 44, 111], [33, 37, 41, 45, 47, 110]]
const SUPER_LIFT := [[12, 35, 91, 50, 66, 138], [0, 0, 26, 47, 43, 105], [8, 14, 32, 38, 52, 112],
	[0, 8, 19, 34, 42, 122], [20, 32, 46, 66, 85, 126], [18, 30, 40, 65, 88, 148],
	[8, 25, 36, 52, 65, 118], [0, 10, 20, 39, 48, 120], [8, 20, 39, 60, 73, 138]]
const SUPER_LENGTH := [184, 203, 191, 206, 181, 199, 192, 203, 199]


static func ladder_for(character: int) -> Array[int]:
	var rivals: Array[int] = [RIVALS[character]]
	for index in PLAYABLE_COUNT:
		if index != character and index != rivals[0]:
			rivals.append(index)
	rivals.append(HONG)
	return rivals

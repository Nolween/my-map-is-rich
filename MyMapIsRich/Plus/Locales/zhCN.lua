-- 简体中文 (ce qui manque vient de l'anglais : enUS.lua)
local _, root = ...
local ns = root.Plus

ns.AddLocale("zhCN", {
    YES = "是", NO = "否", NONE = "无",
    HINT_MOVE = "移动", HINT_SELECT = "选择", HINT_RIGHT_CLICK = "右键", HINT_BACK = "返回",
    HINT_TABS = "标签", HINT_MENU = "菜单", HINT_MENU_CLOSE = "关闭菜单", HINT_SCROLL = "滚动",
    HINT_JUMP = "下一个图标", HINT_PAN = "移动地图", HINT_PLACES = "地点", HINT_FIND_ME = "找到我",
    HINT_PIN = "放置图钉", HINT_PIN_CANCEL = "取消图钉", HINT_PIN_DROP = "在此放置图钉", HINT_PINS = "图钉",
    HINT_PRESS = "按下 / 放大", HINT_ZOOM_OUT = "缩小", HINT_ZOOM = "缩放", HINT_WAYPOINT = "路径点",
    HINT_CLOSE_MAP = "关闭地图", HINT_QUILL_DONE = "收起羽毛笔", HINT_QUILL_TOOLS = "羽毛笔工具",
    HINT_QUILL_PEN = "落笔 / 抬笔", HINT_FLOORS = "楼层", HINT_SIDE = "侧栏", HINT_BACK_WORLD = "返回世界",
    HINT_CANCEL = "取消", HINT_CARET = "文字光标", HINT_TYPE = "输入",
    KB_TITLE = "键盘", KB_SHIFT = "大写", KB_SHIFT_ON = "大写开", KB_SPACE = "空格", KB_BACKSPACE = "删除", KB_OK = "完成",
    PLACES_TITLE = "地点", PLACES_CONTINENTS = "大陆", PLACES_ZONES = "区域", PLACES_HERE = "此区域内",
    PLACES_RECENT = "最近", PLACES_FIND_ME = "我的位置", PLACES_FIND_ME_TIP = "地图滑动到你所在的位置。",
    PLACE_WHOLE_ZONE = "整个区域", PLACE_DUNGEON = "地下城", PLACE_RAID = "团队副本", PLACE_FLIGHT = "飞行管理员",
    SETTINGS_DESC = "在 WoW Forever 的手柄界面下让 My Map Is Rich 完全支持手柄：My Map Is Rich 的手柄视图、窗口内十字键、图标跳转、屏幕键盘和地点浏览器。",
    OPT_ENABLED = "在 My Map Is Rich 中使用手柄", OPT_PADVIEW = "开启 My Map Is Rich 手柄视图",
    OPT_JUMP = "十字键在图标间跳转", OPT_MAGNET = "图标磁吸", OPT_MAGNET_RADIUS = "磁吸范围",
    OPT_MAGNET_SMALL = "短", OPT_MAGNET_MEDIUM = "中", OPT_MAGNET_LARGE = "长", OPT_HINTS = "地图上的提示栏",
    OPT_KEYBOARD = "键盘布局", OPT_GLYPHS = "按键图标", OPT_THEME = "颜色", OPT_AUTO = "自动",
    OPT_RESET = "默认设置",
    THEME_BROWN = "棕色", THEME_GREY = "灰色", THEME_BLUE = "蓝色", THEME_GREEN = "绿色", THEME_PURPLE = "紫色", THEME_PINK = "粉色",
    HINT_RECENTER = "以我为中心", HINT_FOLLOW = "跟随我", HINT_FOLLOW_STOP = "停止跟随", OPT_CENTER_OPEN = "打开地图时以我为中心", HINT_ICON_CYCLE = "下一个图标（LT：上一个）",
    HINT_ACTIONS = "My Map Is Rich 操作", HINT_EDGE_PAN = "光标在边缘：移动",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "My Map Is Rich 菜单", ACT_PIN = "放置图钉", ACT_PINS = "图钉",
    ACT_QUILL = "羽毛笔", ACT_PLACES = "地点", ACT_RECENTER = "以我为中心",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("zhCN", {
    TAB_DONATE = "发现",
    DONATE_TITLE = "支持 My Map Is Rich",
    DONATE_INTRO = "My Map Is Rich 是免费的，并将一直免费。如果它对你有帮助、你想表示感谢，可以通过 PayPal 捐赠任意金额。",
    DONATE_SCAN = "用手机扫描二维码",
    DONATE_LINK = "或复制链接（Ctrl+C）并粘贴到浏览器中：",
    DONATE_THANKS = "捐赠完全自愿，不会解锁任何内容：所有功能对所有人开放。感谢你的支持！",
    TAB_HELP = "帮助",
    OPEN_CONFIG = "打开设置",
    MINIMAP_DRAG = "拖动：沿小地图移动此按钮",
    MINIMAP_HIDDEN = "小地图按钮已隐藏。输入 /mmir minimap 重新显示。",
    MINIMAP_SHOWN = "小地图按钮已显示。",
    OPT_MINIMAP = "小地图旁的按钮",
    TAB_SETTINGS = "设置",
    SET_MAP = "地图上的手柄",
    SET_LOOK = "外观",
    OPT_MINIMAP_TIP = "点击：打开此窗口。右键：开启或关闭地图上的手柄。",
    MINIMAP_LEFT = "点击：打开窗口",
    MINIMAP_RIGHT_OFF = "右键：关闭地图上的手柄",
    MINIMAP_RIGHT_ON = "右键：开启地图上的手柄",
    STATUS_BAR_NO_OPENMAP = "缺少 My Map Is Rich 或不兼容",
    STATUS_BAR_NO_PADUI = "手柄界面已关闭：插件等待中",
    STATUS_BAR_READY = "就绪：用手柄打开地图",
    STATUS_BAR_WAIT = "打开地图时启动 My Map Is Rich 手柄视图（否则 /reload）",
    HELP_INTRO = "每个按键的作用，按地图分类。地图下方的提示栏也会显示。",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("zhCN", {
    PROJECTS_TITLE = "我的项目",
    PROJECTS_INTRO = "我为 WoW Forever 制作的免费插件：复制链接即可打开其 CurseForge 页面。",
    PROJECTS_THIS = "本插件",
    PROJECTS_INSTALLED = "已安装",
    PROJECTS_ALL = "我在 CurseForge 上的所有项目：",
    PROJECT_MGIR = "手柄的额外按键与层、HUD、智能消耗品。",
    PROJECT_MGUIR = "公会中心：互助、团队副本、日历和冒险，自动同步。",
    PROJECT_OMGP = "完全用手柄操作 OpenMap：图标、地点、键盘、副本。",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("zhCN", {
    HINT_TRAVEL = "到这里的路线", HINT_TRAVEL_CANCEL = "取消路线",
    OPT_TRAVEL = "用 R3 规划路线", OPT_TRAVEL_SPEED = "移动速度",
    OPT_SPEED_WALK = "步行", OPT_SPEED_SLOW = "坐骑（60%）", OPT_SPEED_FAST = "快速坐骑（100%）",
    TRAVEL_PLANNED = "路线：%s，约 %s。", TRAVEL_STEP = "第 %d/%d 步：%s（%s）。",
    TRAVEL_ONE_STEP = "1 步", TRAVEL_STEPS = "%d 步",
    TRAVEL_ARRIVED = "你已到达。", TRAVEL_CANCELLED = "路线已取消。",
    TRAVEL_DEST = "目的地", TRAVEL_DEST_IN = "目的地（%s）", TRAVEL_FM = "飞行管理员（%s）", TRAVEL_FM_NEW = "新的飞行管理员（%s）：与其对话", TRAVEL_DOCK = "码头（%s）",
    TRAVEL_QUEST_DEST = "任务“%s”", TRAVEL_NO_QUEST = "游戏没有给出任务“%s”的位置。", HINT_TRAVEL_QUEST = "到此任务的路线",
    TRAVEL_LEG_WALK = "前往%s", TRAVEL_LEG_FLIGHT = "飞往%s", TRAVEL_LEG_BOAT = "乘船前往%s",
    TRAVEL_LEG_ZEPPELIN = "乘飞艇前往%s", TRAVEL_TOOLTIP_TITLE = "路线", TRAVEL_TOTAL = "合计",
    TRAVEL_PORTAL = "传送门（%s）", TRAVEL_TRAM = "矿道地铁（%s）", TRAVEL_LEG_PORTAL = "乘传送门前往%s", TRAVEL_LEG_TRAM = "乘矿道地铁前往%s",
    TRAVEL_REPORT_NAV = "网格：楼层格 %d，升降梯 %d，表面 %d -> %d，替代：%s", TRAVEL_REPORT_NAV_NONE = "网格：无路径（%s）",
    SET_TRAVEL = "路线", OPT_TRAVEL_ROADS = "沿道路行进",
    OPT_TRAVEL_MINIMAP = "在小地图上显示路线",
    OPT_TRAVEL_TERRAIN = "绕开障碍",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("zhCN", {
    WHATSNEW_TITLE = "更新内容", WHATSNEW_NEW = "新", WHATSNEW_BUTTON = "更新内容…",
    WHATSNEW_NEVER = "更新后不再显示", OPT_WHATSNEW = "更新后显示更新内容",
})

-- 0.6.0（其余为英文）
ns.AddLocale("zhCN", {
    TAB_TRAVEL = "路线", SET_GUIDE = "引导", SET_GROUP = "队伍",
    HUD_TITLE = "路线", HUD_FLIGHT = "飞行中", HUD_CORPSE = "返回尸体", HUD_RALLY = "集合", HUD_TO = "前往%s",
    HUD_STEP = "第 %d / %d 步 · %s", HUD_LEFT = "剩余", HUD_FLIGHT_LEFT = "飞行", HUD_ARRIVAL = "到达 %s",
    HUD_LANDING = "%d 秒后降落", HUD_THEN = "然后：%s", HUD_QUEUE_ONE = "队列中还有 1 个目的地", HUD_QUEUE = "队列中还有 %d 个目的地",
    HUD_RALLY_HERE = "已到达",
    KIND_WALK = "步行", KIND_FLIGHT = "飞行", KIND_BOAT = "船", KIND_ZEPPELIN = "飞艇", KIND_PORTAL = "传送门", KIND_TRAM = "地铁",
    WHEEL_PICK = "右摇杆或十字键", ACT_QUEUE = "加入队列", ACT_SHARE = "发送给队伍",
    HINT_CLOSE = "关闭", HINT_WHEEL_CHOOSE = "选择", HINT_WHEEL_STICK = "选择",
    PLACES_TAB_PLACES = "地点", PLACES_TAB_SEARCH = "搜索", PLACES_TAB_RECENT = "最近", PLACES_TAB_QUEUE = "队列", PLACES_TAB_QUEUE_N = "队列 (%d)",
    PLACES_WORLD = "世界", SEARCH_NPC = "NPC", SEARCH_OBJECT = "物体",
    PLACES_OPEN = "打开", PLACES_ROUTE = "路线", PLACES_QUEUE = "加入队列", PLACES_SHOW = "在地图上查看",
    QUEUE_GO = "立即前往", QUEUE_REMOVE = "移除", QUEUE_SORT = "最快顺序",
    SHARE_TITLE = "推荐目的地", SHARE_GO = "前往", SHARE_LATER = "加入队列", SHARE_NO = "不用了",
    OPT_TRAVEL_CORPSE = "前往我的尸体的路线", OPT_TRAVEL_HUD = "路线面板", OPT_TRAVEL_ARROW = "GPS 箭头", OPT_TRAVEL_RUMBLE = "振动", OPT_TRAVEL_SOUND = "声音",
    OPT_TRAVEL_SHARE = "队伍的目的地",
})

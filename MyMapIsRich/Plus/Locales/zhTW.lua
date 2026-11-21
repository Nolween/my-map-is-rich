-- 繁體中文 (ce qui manque vient de l'anglais : enUS.lua)
local _, root = ...
local ns = root.Plus

ns.AddLocale("zhTW", {
    YES = "是", NO = "否", NONE = "無",
    HINT_MOVE = "移動", HINT_SELECT = "選擇", HINT_RIGHT_CLICK = "右鍵", HINT_BACK = "返回",
    HINT_TABS = "標籤", HINT_MENU = "選單", HINT_MENU_CLOSE = "關閉選單", HINT_SCROLL = "捲動",
    HINT_JUMP = "下一個圖示", HINT_PAN = "移動地圖", HINT_PLACES = "地點", HINT_FIND_ME = "找到我",
    HINT_PIN = "放置圖釘", HINT_PIN_CANCEL = "取消圖釘", HINT_PIN_DROP = "在此放置圖釘", HINT_PINS = "圖釘",
    HINT_PRESS = "按下 / 放大", HINT_ZOOM_OUT = "縮小", HINT_ZOOM = "縮放", HINT_WAYPOINT = "路徑點",
    HINT_CLOSE_MAP = "關閉地圖", HINT_QUILL_DONE = "收起羽毛筆", HINT_QUILL_TOOLS = "羽毛筆工具",
    HINT_QUILL_PEN = "落筆 / 抬筆", HINT_FLOORS = "樓層", HINT_SIDE = "側欄", HINT_BACK_WORLD = "返回世界",
    HINT_CANCEL = "取消", HINT_CARET = "文字游標", HINT_TYPE = "輸入",
    KB_TITLE = "鍵盤", KB_SHIFT = "大寫", KB_SHIFT_ON = "大寫開", KB_SPACE = "空白", KB_BACKSPACE = "刪除", KB_OK = "完成",
    PLACES_TITLE = "地點", PLACES_CONTINENTS = "大陸", PLACES_ZONES = "區域", PLACES_HERE = "此區域內",
    PLACES_RECENT = "最近", PLACES_FIND_ME = "我的位置", PLACES_FIND_ME_TIP = "地圖滑動到你所在的位置。",
    PLACE_WHOLE_ZONE = "整個區域", PLACE_DUNGEON = "地城", PLACE_RAID = "團隊副本", PLACE_FLIGHT = "飛行管理員",
    SETTINGS_DESC = "在 WoW Forever 的手把介面下讓 My Map Is Rich 完全支援手把：My Map Is Rich 的手把視圖、視窗內十字鍵、圖示跳轉、螢幕鍵盤和地點瀏覽器。",
    OPT_ENABLED = "在 My Map Is Rich 中使用手把", OPT_PADVIEW = "開啟 My Map Is Rich 手把視圖",
    OPT_JUMP = "十字鍵在圖示間跳轉", OPT_MAGNET = "圖示磁吸", OPT_MAGNET_RADIUS = "磁吸範圍",
    OPT_MAGNET_SMALL = "短", OPT_MAGNET_MEDIUM = "中", OPT_MAGNET_LARGE = "長", OPT_HINTS = "地圖上的提示列",
    OPT_KEYBOARD = "鍵盤配置", OPT_GLYPHS = "按鍵圖示", OPT_THEME = "顏色", OPT_AUTO = "自動",
    OPT_RESET = "預設設定",
    THEME_BROWN = "棕色", THEME_GREY = "灰色", THEME_BLUE = "藍色", THEME_GREEN = "綠色", THEME_PURPLE = "紫色", THEME_PINK = "粉色",
    HINT_RECENTER = "以我為中心", HINT_FOLLOW = "跟隨我", HINT_FOLLOW_STOP = "停止跟隨", OPT_CENTER_OPEN = "打開地圖時以我為中心", HINT_ICON_CYCLE = "下一個圖示（LT：上一個）",
    HINT_ACTIONS = "My Map Is Rich 動作", HINT_EDGE_PAN = "游標在邊緣：移動",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "My Map Is Rich 選單", ACT_PIN = "放置圖釘", ACT_PINS = "圖釘",
    ACT_QUILL = "羽毛筆", ACT_PLACES = "地點", ACT_RECENTER = "以我為中心",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("zhTW", {
    TAB_DONATE = "發現",
    DONATE_TITLE = "支持 My Map Is Rich",
    DONATE_INTRO = "My Map Is Rich 是免費的，而且會一直免費。如果它對你有幫助、你想表達感謝，可以透過 PayPal 捐贈任意金額。",
    DONATE_SCAN = "用手機掃描 QR 碼",
    DONATE_LINK = "或複製連結（Ctrl+C）並貼到瀏覽器中：",
    DONATE_THANKS = "捐贈完全自願，不會解鎖任何內容：所有功能對所有人開放。感謝你的支持！",
    TAB_HELP = "說明",
    OPEN_CONFIG = "開啟設定",
    MINIMAP_DRAG = "拖曳：沿小地圖移動此按鈕",
    MINIMAP_HIDDEN = "小地圖按鈕已隱藏。輸入 /mmir minimap 重新顯示。",
    MINIMAP_SHOWN = "小地圖按鈕已顯示。",
    OPT_MINIMAP = "小地圖旁的按鈕",
    TAB_SETTINGS = "設定",
    SET_MAP = "地圖上的手把",
    SET_LOOK = "外觀",
    OPT_MINIMAP_TIP = "點擊：開啟此視窗。右鍵：開啟或關閉地圖上的手把。",
    MINIMAP_LEFT = "點擊：開啟視窗",
    MINIMAP_RIGHT_OFF = "右鍵：關閉地圖上的手把",
    MINIMAP_RIGHT_ON = "右鍵：開啟地圖上的手把",
    STATUS_BAR_NO_OPENMAP = "缺少 My Map Is Rich 或不相容",
    STATUS_BAR_NO_PADUI = "手把介面已關閉：插件等待中",
    STATUS_BAR_READY = "就緒：用手把開啟地圖",
    STATUS_BAR_WAIT = "開啟地圖時啟動 My Map Is Rich 手把視圖（否則 /reload）",
    HELP_INTRO = "每個按鍵的作用，依地圖分類。地圖下方的提示列也會顯示。",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("zhTW", {
    PROJECTS_TITLE = "我的專案",
    PROJECTS_INTRO = "我為 WoW Forever 製作的免費插件：複製連結即可開啟其 CurseForge 頁面。",
    PROJECTS_THIS = "本插件",
    PROJECTS_INSTALLED = "已安裝",
    PROJECTS_ALL = "我在 CurseForge 上的所有專案：",
    PROJECT_MGIR = "手把的額外按鍵與層、HUD、智慧消耗品。",
    PROJECT_MGUIR = "公會中心：互助、團隊副本、行事曆和冒險，自動同步。",
    PROJECT_OMGP = "完全用手把操作 OpenMap：圖示、地點、鍵盤、地城。",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("zhTW", {
    HINT_TRAVEL = "到這裡的路線", HINT_TRAVEL_CANCEL = "取消路線",
    OPT_TRAVEL = "用 R3 規劃路線", OPT_TRAVEL_SPEED = "移動速度",
    OPT_SPEED_WALK = "步行", OPT_SPEED_SLOW = "坐騎（60%）", OPT_SPEED_FAST = "快速坐騎（100%）",
    TRAVEL_PLANNED = "路線：%s，約 %s。", TRAVEL_STEP = "第 %d/%d 步：%s（%s）。",
    TRAVEL_ONE_STEP = "1 步", TRAVEL_STEPS = "%d 步",
    TRAVEL_ARRIVED = "你已抵達。", TRAVEL_CANCELLED = "路線已取消。",
    TRAVEL_DEST = "目的地", TRAVEL_DEST_IN = "目的地（%s）", TRAVEL_FM = "飛行管理員（%s）", TRAVEL_FM_NEW = "新的飛行管理員（%s）：與其對話", TRAVEL_DOCK = "碼頭（%s）",
    TRAVEL_QUEST_DEST = "任務「%s」", TRAVEL_NO_QUEST = "遊戲沒有給出任務「%s」的位置。", HINT_TRAVEL_QUEST = "到此任務的路線",
    TRAVEL_LEG_WALK = "前往%s", TRAVEL_LEG_FLIGHT = "飛往%s", TRAVEL_LEG_BOAT = "搭船前往%s",
    TRAVEL_LEG_ZEPPELIN = "搭飛艇前往%s", TRAVEL_TOOLTIP_TITLE = "路線", TRAVEL_TOTAL = "合計",
    TRAVEL_PORTAL = "傳送門（%s）", TRAVEL_TRAM = "礦道地鐵（%s）", TRAVEL_LEG_PORTAL = "搭傳送門前往%s", TRAVEL_LEG_TRAM = "搭礦道地鐵前往%s",
    TRAVEL_REPORT_NAV = "網格：樓層格 %d，升降梯 %d，表面 %d -> %d，替代：%s", TRAVEL_REPORT_NAV_NONE = "網格：無路徑（%s）",
    SET_TRAVEL = "路線", OPT_TRAVEL_ROADS = "沿道路行進",
    OPT_TRAVEL_MINIMAP = "在小地圖上顯示路線",
    OPT_TRAVEL_TERRAIN = "繞開障礙",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("zhTW", {
    WHATSNEW_TITLE = "更新內容", WHATSNEW_NEW = "新", WHATSNEW_BUTTON = "更新內容…",
    WHATSNEW_NEVER = "更新後不再顯示", OPT_WHATSNEW = "更新後顯示更新內容",
})

-- 0.6.0（其餘為英文）
ns.AddLocale("zhTW", {
    TAB_TRAVEL = "路線", SET_GUIDE = "引導", SET_GROUP = "隊伍",
    HUD_TITLE = "路線", HUD_FLIGHT = "飛行中", HUD_CORPSE = "返回屍體", HUD_RALLY = "集合", HUD_TO = "前往%s",
    HUD_STEP = "第 %d / %d 步 · %s", HUD_LEFT = "剩餘", HUD_FLIGHT_LEFT = "飛行", HUD_ARRIVAL = "抵達 %s",
    HUD_LANDING = "%d 秒後降落", HUD_THEN = "然後：%s", HUD_QUEUE_ONE = "佇列中還有 1 個目的地", HUD_QUEUE = "佇列中還有 %d 個目的地",
    HUD_RALLY_HERE = "已抵達",
    KIND_WALK = "步行", KIND_FLIGHT = "飛行", KIND_BOAT = "船", KIND_ZEPPELIN = "飛艇", KIND_PORTAL = "傳送門", KIND_TRAM = "地鐵",
    WHEEL_PICK = "右搖桿或十字鍵", ACT_QUEUE = "加入佇列", ACT_SHARE = "傳送給隊伍",
    HINT_CLOSE = "關閉", HINT_WHEEL_CHOOSE = "選擇", HINT_WHEEL_STICK = "選擇",
    PLACES_TAB_PLACES = "地點", PLACES_TAB_SEARCH = "搜尋", PLACES_TAB_RECENT = "最近", PLACES_TAB_QUEUE = "佇列", PLACES_TAB_QUEUE_N = "佇列 (%d)",
    PLACES_WORLD = "世界", SEARCH_NPC = "NPC", SEARCH_OBJECT = "物件",
    PLACES_OPEN = "開啟", PLACES_ROUTE = "路線", PLACES_QUEUE = "加入佇列", PLACES_SHOW = "在地圖上查看",
    QUEUE_GO = "立即前往", QUEUE_REMOVE = "移除", QUEUE_SORT = "最快順序",
    SHARE_TITLE = "推薦目的地", SHARE_GO = "前往", SHARE_LATER = "加入佇列", SHARE_NO = "不用了",
    OPT_TRAVEL_CORPSE = "前往我的屍體的路線", OPT_TRAVEL_HUD = "路線面板", OPT_TRAVEL_ARROW = "GPS 箭頭", OPT_TRAVEL_RUMBLE = "震動", OPT_TRAVEL_SOUND = "聲音",
    OPT_TRAVEL_SHARE = "隊伍的目的地",
})

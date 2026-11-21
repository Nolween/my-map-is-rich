-- 한국어 (ce qui manque vient de l'anglais : enUS.lua)
local _, root = ...
local ns = root.Plus

ns.AddLocale("koKR", {
    YES = "예", NO = "아니요", NONE = "없음",
    HINT_MOVE = "이동", HINT_SELECT = "선택", HINT_RIGHT_CLICK = "우클릭", HINT_BACK = "뒤로",
    HINT_TABS = "탭", HINT_MENU = "메뉴", HINT_MENU_CLOSE = "메뉴 닫기", HINT_SCROLL = "스크롤",
    HINT_JUMP = "다음 아이콘", HINT_PAN = "지도 이동", HINT_PLACES = "장소", HINT_FIND_ME = "내 위치",
    HINT_PIN = "핀 꽂기", HINT_PIN_CANCEL = "핀 취소", HINT_PIN_DROP = "여기에 핀 꽂기", HINT_PINS = "핀",
    HINT_PRESS = "누르기 / 확대", HINT_ZOOM_OUT = "축소", HINT_ZOOM = "확대/축소", HINT_WAYPOINT = "경유지",
    HINT_CLOSE_MAP = "지도 닫기", HINT_QUILL_DONE = "깃펜 넣기", HINT_QUILL_TOOLS = "깃펜 도구",
    HINT_QUILL_PEN = "펜 내리기 / 올리기", HINT_FLOORS = "층", HINT_SIDE = "패널", HINT_BACK_WORLD = "세계로 돌아가기",
    HINT_CANCEL = "취소", HINT_CARET = "텍스트 커서", HINT_TYPE = "입력",
    KB_TITLE = "키보드", KB_SHIFT = "대문자", KB_SHIFT_ON = "대문자 켬", KB_SPACE = "공백", KB_BACKSPACE = "지우기", KB_OK = "완료",
    PLACES_TITLE = "장소", PLACES_CONTINENTS = "대륙", PLACES_ZONES = "지역", PLACES_HERE = "이 지역",
    PLACES_RECENT = "최근", PLACES_FIND_ME = "내 위치", PLACES_FIND_ME_TIP = "지도가 당신에게 이동합니다.",
    PLACE_WHOLE_ZONE = "지역 전체", PLACE_DUNGEON = "던전", PLACE_RAID = "공격대", PLACE_FLIGHT = "비행 조련사",
    SETTINGS_DESC = "WoW Forever의 게임패드 UI에서 My Map Is Rich을 컨트롤러로 완전히 사용할 수 있게 합니다: My Map Is Rich의 컨트롤러 보기, 창에서 십자키, 아이콘 이동, 화상 키보드, 장소 탐색기.",
    OPT_ENABLED = "My Map Is Rich에서 컨트롤러 사용", OPT_PADVIEW = "My Map Is Rich 컨트롤러 보기 켜기",
    OPT_JUMP = "십자키로 아이콘 사이 이동", OPT_MAGNET = "아이콘 자석", OPT_MAGNET_RADIUS = "자석 범위",
    OPT_MAGNET_SMALL = "짧게", OPT_MAGNET_MEDIUM = "보통", OPT_MAGNET_LARGE = "길게", OPT_HINTS = "지도에 도움말 막대",
    OPT_KEYBOARD = "키보드 배열", OPT_GLYPHS = "버튼 아이콘", OPT_THEME = "색상", OPT_AUTO = "자동",
    OPT_RESET = "기본 설정",
    THEME_BROWN = "갈색", THEME_GREY = "회색", THEME_BLUE = "파랑", THEME_GREEN = "초록", THEME_PURPLE = "보라", THEME_PINK = "분홍",
    HINT_RECENTER = "내 위치로", HINT_FOLLOW = "나를 따라가기", HINT_FOLLOW_STOP = "따라가기 중지", OPT_CENTER_OPEN = "지도를 열 때 내 위치로", HINT_ICON_CYCLE = "다음 아이콘 (LT: 이전)",
    HINT_ACTIONS = "My Map Is Rich 동작", HINT_EDGE_PAN = "가장자리 커서: 이동",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "My Map Is Rich 메뉴", ACT_PIN = "핀 꽂기", ACT_PINS = "핀",
    ACT_QUILL = "깃펜", ACT_PLACES = "장소", ACT_RECENTER = "내 위치로",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("koKR", {
    TAB_DONATE = "둘러보기",
    DONATE_TITLE = "My Map Is Rich 후원하기",
    DONATE_INTRO = "My Map Is Rich는 무료이며 앞으로도 무료입니다. 도움이 되었고 감사를 전하고 싶다면 PayPal로 원하는 금액을 후원할 수 있습니다.",
    DONATE_SCAN = "휴대폰으로 QR 코드를 스캔하세요",
    DONATE_LINK = "또는 링크를 복사(Ctrl+C)해 브라우저에 붙여 넣으세요:",
    DONATE_THANKS = "후원은 전적으로 선택 사항이며 아무것도 잠금 해제하지 않습니다. 모든 기능은 누구나 사용할 수 있습니다. 후원해 주셔서 감사합니다!",
    TAB_HELP = "도움말",
    OPEN_CONFIG = "설정 열기",
    MINIMAP_DRAG = "끌기: 미니맵 주위로 이 버튼 이동",
    MINIMAP_HIDDEN = "미니맵 버튼을 숨겼습니다. 다시 표시하려면 /mmir minimap을 입력하세요.",
    MINIMAP_SHOWN = "미니맵 버튼을 표시했습니다.",
    OPT_MINIMAP = "미니맵 주위 버튼",
    TAB_SETTINGS = "설정",
    SET_MAP = "지도에서 컨트롤러",
    SET_LOOK = "모양",
    OPT_MINIMAP_TIP = "클릭: 이 창. 우클릭: 지도에서 컨트롤러 켜기/끄기.",
    MINIMAP_LEFT = "클릭: 창 열기",
    MINIMAP_RIGHT_OFF = "우클릭: 지도에서 컨트롤러 끄기",
    MINIMAP_RIGHT_ON = "우클릭: 지도에서 컨트롤러 켜기",
    STATUS_BAR_NO_OPENMAP = "My Map Is Rich이 없거나 호환되지 않습니다",
    STATUS_BAR_NO_PADUI = "게임패드 UI 꺼짐: 애드온이 기다립니다",
    STATUS_BAR_READY = "준비됨: 컨트롤러로 지도를 여세요",
    STATUS_BAR_WAIT = "지도를 열면 My Map Is Rich 컨트롤러 보기가 시작됩니다 (아니면 /reload)",
    HELP_INTRO = "지도별로 각 버튼이 하는 일입니다. 지도 아래 도움말 막대에도 표시됩니다.",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("koKR", {
    PROJECTS_TITLE = "내 프로젝트",
    PROJECTS_INTRO = "WoW Forever용 무료 애드온입니다. 링크를 복사해 CurseForge 페이지를 여세요.",
    PROJECTS_THIS = "이 애드온",
    PROJECTS_INSTALLED = "설치됨",
    PROJECTS_ALL = "CurseForge의 모든 프로젝트:",
    PROJECT_MGIR = "컨트롤러의 추가 버튼과 층, HUD, 똑똑한 소모품.",
    PROJECT_MGUIR = "길드의 중심: 서로 돕기, 공격대, 달력, 모험이 자동으로 동기화됩니다.",
    PROJECT_OMGP = "컨트롤러로 완전히 쓰는 OpenMap: 아이콘, 장소, 키보드, 던전.",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("koKR", {
    HINT_TRAVEL = "여기까지 경로", HINT_TRAVEL_CANCEL = "경로 취소",
    OPT_TRAVEL = "R3로 경로 찾기", OPT_TRAVEL_SPEED = "이동 속도",
    OPT_SPEED_WALK = "도보", OPT_SPEED_SLOW = "탈것 (60%)", OPT_SPEED_FAST = "빠른 탈것 (100%)",
    TRAVEL_PLANNED = "경로: %s, 약 %s.", TRAVEL_STEP = "단계 %d/%d: %s (%s).",
    TRAVEL_ONE_STEP = "1단계", TRAVEL_STEPS = "%d단계",
    TRAVEL_ARRIVED = "도착했습니다.", TRAVEL_CANCELLED = "경로가 취소되었습니다.",
    TRAVEL_DEST = "목적지", TRAVEL_DEST_IN = "목적지 (%s)", TRAVEL_FM = "비행 조련사 (%s)", TRAVEL_FM_NEW = "새 비행 조련사 (%s): 대화하세요", TRAVEL_DOCK = "부두 (%s)",
    TRAVEL_QUEST_DEST = "퀘스트 \"%s\"", TRAVEL_NO_QUEST = "게임이 퀘스트 \"%s\"의 위치를 알려주지 않습니다.", HINT_TRAVEL_QUEST = "이 퀘스트까지 경로",
    TRAVEL_LEG_WALK = "%s(으)로 이동", TRAVEL_LEG_FLIGHT = "%s(으)로 비행", TRAVEL_LEG_BOAT = "%s행 배 타기",
    TRAVEL_LEG_ZEPPELIN = "%s행 비행선 타기", TRAVEL_TOOLTIP_TITLE = "경로", TRAVEL_TOTAL = "합계",
    TRAVEL_PORTAL = "차원문 (%s)", TRAVEL_TRAM = "깊은굴 지하철 (%s)", TRAVEL_LEG_PORTAL = "%s행 차원문 타기", TRAVEL_LEG_TRAM = "%s행 깊은굴 지하철 타기",
    TRAVEL_REPORT_NAV = "격자: 층 칸 %d, 승강기 %d, 표면 %d -> %d, 대체: %s", TRAVEL_REPORT_NAV_NONE = "격자: 경로 없음 (%s)",
    SET_TRAVEL = "경로", OPT_TRAVEL_ROADS = "도로 따라가기",
    OPT_TRAVEL_MINIMAP = "미니맵에 경로 표시",
    OPT_TRAVEL_TERRAIN = "장애물 우회",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("koKR", {
    WHATSNEW_TITLE = "새 소식", WHATSNEW_NEW = "새로움", WHATSNEW_BUTTON = "새 소식…",
    WHATSNEW_NEVER = "업데이트 후 표시하지 않기", OPT_WHATSNEW = "업데이트 후 새 소식",
})

-- 0.6.0 (나머지는 영어)
ns.AddLocale("koKR", {
    TAB_TRAVEL = "경로", SET_GUIDE = "안내", SET_GROUP = "파티",
    HUD_TITLE = "경로", HUD_FLIGHT = "비행 중", HUD_CORPSE = "시체로 돌아가기", HUD_RALLY = "집결", HUD_TO = "%s(으)로",
    HUD_STEP = "단계 %d / %d · %s", HUD_LEFT = "남음", HUD_FLIGHT_LEFT = "비행", HUD_ARRIVAL = "도착 %s",
    HUD_LANDING = "%d초 후 착륙", HUD_THEN = "다음: %s", HUD_QUEUE_ONE = "대기열에 목적지 +1", HUD_QUEUE = "대기열에 목적지 +%d",
    HUD_RALLY_HERE = "도착",
    KIND_WALK = "도보", KIND_FLIGHT = "비행", KIND_BOAT = "배", KIND_ZEPPELIN = "비행선", KIND_PORTAL = "차원문", KIND_TRAM = "지하철",
    WHEEL_PICK = "오른쪽 스틱 또는 십자키", ACT_QUEUE = "대기열에 추가", ACT_SHARE = "파티에 보내기",
    HINT_CLOSE = "닫기", HINT_WHEEL_CHOOSE = "선택", HINT_WHEEL_STICK = "선택",
    PLACES_TAB_PLACES = "장소", PLACES_TAB_SEARCH = "검색", PLACES_TAB_RECENT = "최근", PLACES_TAB_QUEUE = "대기열", PLACES_TAB_QUEUE_N = "대기열 (%d)",
    PLACES_WORLD = "세계", SEARCH_NPC = "NPC", SEARCH_OBJECT = "오브젝트",
    PLACES_OPEN = "열기", PLACES_ROUTE = "경로", PLACES_QUEUE = "대기열에 추가", PLACES_SHOW = "지도에서 보기",
    QUEUE_GO = "지금 가기", QUEUE_REMOVE = "제거", QUEUE_SORT = "가장 빠른 순서",
    SHARE_TITLE = "제안된 목적지", SHARE_GO = "가기", SHARE_LATER = "대기열에 추가", SHARE_NO = "괜찮아요",
    OPT_TRAVEL_CORPSE = "내 시체까지 경로", OPT_TRAVEL_HUD = "경로 패널", OPT_TRAVEL_ARROW = "GPS 화살표", OPT_TRAVEL_RUMBLE = "진동", OPT_TRAVEL_SOUND = "소리",
    OPT_TRAVEL_SHARE = "파티의 목적지",
})

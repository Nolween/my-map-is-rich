-- Русский (ce qui manque vient de l'anglais : enUS.lua)
local _, root = ...
local ns = root.Plus

ns.AddLocale("ruRU", {
    YES = "да", NO = "нет", NONE = "нет",
    HINT_MOVE = "Перемещение", HINT_SELECT = "Выбрать", HINT_RIGHT_CLICK = "Правый клик", HINT_BACK = "Назад",
    HINT_TABS = "Вкладки", HINT_MENU = "Меню", HINT_MENU_CLOSE = "Закрыть меню", HINT_SCROLL = "Прокрутка",
    HINT_JUMP = "Следующий значок", HINT_PAN = "Сдвинуть карту", HINT_PLACES = "Места", HINT_FIND_ME = "Где я",
    HINT_PIN = "Поставить метку", HINT_PIN_CANCEL = "Отменить метку", HINT_PIN_DROP = "Поставить метку здесь", HINT_PINS = "Метки",
    HINT_PRESS = "Нажать / приблизить", HINT_ZOOM_OUT = "Отдалить", HINT_ZOOM = "Масштаб", HINT_WAYPOINT = "Путевая точка",
    HINT_CLOSE_MAP = "Закрыть карту", HINT_QUILL_DONE = "Убрать перо", HINT_QUILL_TOOLS = "Инструменты пера",
    HINT_QUILL_PEN = "Перо вниз / вверх", HINT_FLOORS = "Этажи", HINT_SIDE = "Панель", HINT_BACK_WORLD = "Назад к миру",
    HINT_CANCEL = "Отмена", HINT_CARET = "Курсор текста", HINT_TYPE = "Ввод",
    KB_TITLE = "Клавиатура", KB_SHIFT = "Заглав", KB_SHIFT_ON = "ЗАГЛАВ", KB_SPACE = "Пробел", KB_BACKSPACE = "Стереть", KB_OK = "Готово",
    PLACES_TITLE = "Места", PLACES_CONTINENTS = "Континенты", PLACES_ZONES = "Зоны", PLACES_HERE = "В этой зоне",
    PLACES_RECENT = "Недавние", PLACES_FIND_ME = "Моё положение", PLACES_FIND_ME_TIP = "Карта переместится к вам.",
    PLACE_WHOLE_ZONE = "Вся зона", PLACE_DUNGEON = "Подземелье", PLACE_RAID = "Рейд", PLACE_FLIGHT = "Распорядитель полетов",
    SETTINGS_DESC = "Делает My Map Is Rich полностью управляемым с геймпада в интерфейсе геймпада WoW Forever: вид для геймпада My Map Is Rich, крестовина в его окнах, прыжки между значками, экранная клавиатура и обзор мест.",
    OPT_ENABLED = "Геймпад в My Map Is Rich", OPT_PADVIEW = "Включить вид для геймпада My Map Is Rich",
    OPT_JUMP = "Крестовина прыгает между значками", OPT_MAGNET = "Магнит значков", OPT_MAGNET_RADIUS = "Радиус магнита",
    OPT_MAGNET_SMALL = "Малый", OPT_MAGNET_MEDIUM = "Средний", OPT_MAGNET_LARGE = "Большой", OPT_HINTS = "Панель подсказок на карте",
    OPT_KEYBOARD = "Раскладка клавиатуры", OPT_GLYPHS = "Значки кнопок", OPT_THEME = "Цвета", OPT_AUTO = "Авто",
    OPT_RESET = "Настройки по умолчанию",
    THEME_BROWN = "Коричневый", THEME_GREY = "Серый", THEME_BLUE = "Синий", THEME_GREEN = "Зелёный", THEME_PURPLE = "Фиолетовый", THEME_PINK = "Розовый",
    HINT_RECENTER = "Центрировать на мне", HINT_FOLLOW = "Следовать за мной", HINT_FOLLOW_STOP = "Не следовать", OPT_CENTER_OPEN = "Центрировать на мне при открытии", HINT_ICON_CYCLE = "Следующий значок (LT: предыдущий)",
    HINT_ACTIONS = "Действия My Map Is Rich", HINT_EDGE_PAN = "Курсор у края: сдвиг",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "Меню My Map Is Rich", ACT_PIN = "Поставить метку", ACT_PINS = "Метки",
    ACT_QUILL = "Перо", ACT_PLACES = "Места", ACT_RECENTER = "Центрировать на мне",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("ruRU", {
    TAB_DONATE = "Узнать больше",
    DONATE_TITLE = "Поддержать My Map Is Rich",
    DONATE_INTRO = "My Map Is Rich бесплатен и останется бесплатным. Если он вам полезен и вы хотите сказать спасибо, можно сделать пожертвование через PayPal на любую сумму.",
    DONATE_SCAN = "Отсканируйте QR-код телефоном",
    DONATE_LINK = "Или скопируйте ссылку (Ctrl+C) и вставьте её в браузер:",
    DONATE_THANKS = "Пожертвования полностью добровольны и ничего не открывают: все функции доступны всем. Спасибо за поддержку!",
    TAB_HELP = "Справка",
    OPEN_CONFIG = "Открыть настройки",
    MINIMAP_DRAG = "Перетаскивание: переместить кнопку вокруг миникарты",
    MINIMAP_HIDDEN = "Кнопка у миникарты скрыта. Введите /mmir minimap, чтобы показать её снова.",
    MINIMAP_SHOWN = "Кнопка у миникарты показана.",
    OPT_MINIMAP = "Кнопка у миникарты",
    TAB_SETTINGS = "Настройки",
    SET_MAP = "Геймпад на карте",
    SET_LOOK = "Внешний вид",
    OPT_MINIMAP_TIP = "Клик: это окно. Правый клик: включить или выключить геймпад на карте.",
    MINIMAP_LEFT = "Клик: открыть окно",
    MINIMAP_RIGHT_OFF = "Правый клик: выключить геймпад на карте",
    MINIMAP_RIGHT_ON = "Правый клик: включить геймпад на карте",
    STATUS_BAR_NO_OPENMAP = "My Map Is Rich не найден или несовместим",
    STATUS_BAR_NO_PADUI = "Интерфейс геймпада выключен: аддон ждёт",
    STATUS_BAR_READY = "Готово: откройте карту с геймпада",
    STATUS_BAR_WAIT = "Вид для геймпада My Map Is Rich запустится при открытии карты (иначе /reload)",
    HELP_INTRO = "Что делает каждая кнопка, карта за картой. Панель подсказок внизу карты тоже это показывает.",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("ruRU", {
    PROJECTS_TITLE = "Мои проекты",
    PROJECTS_INTRO = "Мои бесплатные аддоны для WoW Forever: скопируйте ссылку, чтобы открыть страницу на CurseForge.",
    PROJECTS_THIS = "этот аддон",
    PROJECTS_INSTALLED = "установлен",
    PROJECTS_ALL = "Все мои проекты на CurseForge:",
    PROJECT_MGIR = "Дополнительные кнопки геймпада и их слои, HUD, умные расходники.",
    PROJECT_MGUIR = "Центр гильдии: взаимопомощь, рейды, календарь и приключения, всё синхронизируется само.",
    PROJECT_OMGP = "OpenMap полностью с геймпада: значки, места, клавиатура, подземелья.",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("ruRU", {
    HINT_TRAVEL = "Маршрут сюда", HINT_TRAVEL_CANCEL = "Отменить маршрут",
    OPT_TRAVEL = "Маршруты по R3", OPT_TRAVEL_SPEED = "Скорость передвижения",
    OPT_SPEED_WALK = "Пешком", OPT_SPEED_SLOW = "Верховое животное (60%)", OPT_SPEED_FAST = "Быстрое верховое животное (100%)",
    TRAVEL_PLANNED = "Маршрут: %s, около %s.", TRAVEL_STEP = "Этап %d/%d: %s (%s).",
    TRAVEL_ONE_STEP = "1 этап", TRAVEL_STEPS = "этапов: %d",
    TRAVEL_ARRIVED = "Вы прибыли.", TRAVEL_CANCELLED = "Маршрут отменён.",
    TRAVEL_DEST = "пункт назначения", TRAVEL_DEST_IN = "пункт назначения (%s)", TRAVEL_FM = "распорядитель полётов (%s)", TRAVEL_FM_NEW = "новый распорядитель полётов (%s): поговорите с ним", TRAVEL_DOCK = "причал (%s)",
    TRAVEL_QUEST_DEST = "задание «%s»", TRAVEL_NO_QUEST = "Игра не указывает место для задания «%s».", HINT_TRAVEL_QUEST = "Маршрут к этому заданию",
    TRAVEL_LEG_WALK = "Идите к: %s", TRAVEL_LEG_FLIGHT = "Летите в %s", TRAVEL_LEG_BOAT = "Корабль до: %s",
    TRAVEL_LEG_ZEPPELIN = "Дирижабль до: %s", TRAVEL_TOOLTIP_TITLE = "Маршрут", TRAVEL_TOTAL = "Всего",
    TRAVEL_PORTAL = "портал (%s)", TRAVEL_TRAM = "Подземный поезд (%s)", TRAVEL_LEG_PORTAL = "Портал в: %s", TRAVEL_LEG_TRAM = "Подземный поезд до: %s",
    TRAVEL_REPORT_NAV = "сетка: этажей %d, лифтов %d, поверхности %d -> %d, запасной: %s", TRAVEL_REPORT_NAV_NONE = "сетка: пути нет (%s)",
    SET_TRAVEL = "Маршруты", OPT_TRAVEL_ROADS = "Держаться дорог",
    OPT_TRAVEL_MINIMAP = "Маршрут на миникарте",
    OPT_TRAVEL_TERRAIN = "Обходить препятствия",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("ruRU", {
    WHATSNEW_TITLE = "Что нового", WHATSNEW_NEW = "Новое", WHATSNEW_BUTTON = "Что нового…",
    WHATSNEW_NEVER = "Не показывать после обновления", OPT_WHATSNEW = "Что нового после обновления",
})

-- 0.6.0 (остальное — из английского)
ns.AddLocale("ruRU", {
    TAB_TRAVEL = "Маршруты", SET_GUIDE = "Навигация", SET_GROUP = "Группа",
    HUD_TITLE = "Маршрут", HUD_FLIGHT = "В полёте", HUD_CORPSE = "К телу", HUD_RALLY = "Сбор", HUD_TO = "к: %s",
    HUD_STEP = "Этап %d / %d · %s", HUD_LEFT = "осталось", HUD_FLIGHT_LEFT = "полёта", HUD_ARRIVAL = "Прибытие %s",
    HUD_LANDING = "Посадка через %d с", HUD_THEN = "Затем: %s", HUD_QUEUE_ONE = "+1 цель в очереди", HUD_QUEUE = "+%d целей в очереди",
    HUD_RALLY_HERE = "на месте",
    KIND_WALK = "пешком", KIND_FLIGHT = "полёт", KIND_BOAT = "корабль", KIND_ZEPPELIN = "дирижабль", KIND_PORTAL = "портал", KIND_TRAM = "трамвай",
    WHEEL_PICK = "Правый стик или крестовина", ACT_QUEUE = "В очередь", ACT_SHARE = "Отправить группе",
    HINT_CLOSE = "Закрыть", HINT_WHEEL_CHOOSE = "Выбрать", HINT_WHEEL_STICK = "Выбрать",
    PLACES_TAB_PLACES = "Места", PLACES_TAB_SEARCH = "Поиск", PLACES_TAB_RECENT = "Недавние", PLACES_TAB_QUEUE = "Очередь", PLACES_TAB_QUEUE_N = "Очередь (%d)",
    PLACES_WORLD = "Мир", SEARCH_NPC = "НИП", SEARCH_OBJECT = "Объект",
    PLACES_OPEN = "Открыть", PLACES_ROUTE = "Маршрут", PLACES_QUEUE = "В очередь", PLACES_SHOW = "На карте",
    QUEUE_GO = "Идти сейчас", QUEUE_REMOVE = "Убрать", QUEUE_SORT = "Быстрейший порядок",
    SHARE_TITLE = "Предложенная цель", SHARE_GO = "Идти", SHARE_LATER = "В очередь", SHARE_NO = "Нет, спасибо",
    OPT_TRAVEL_CORPSE = "Маршрут к телу", OPT_TRAVEL_HUD = "Панель маршрута", OPT_TRAVEL_ARROW = "GPS-стрелка", OPT_TRAVEL_RUMBLE = "Вибрация", OPT_TRAVEL_SOUND = "Звуки",
    OPT_TRAVEL_SHARE = "Цели от группы",
})

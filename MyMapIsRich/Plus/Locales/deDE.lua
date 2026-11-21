-- Deutsch (ce qui manque vient de l'anglais : enUS.lua)
local _, root = ...
local ns = root.Plus

ns.AddLocale("deDE", {
    YES = "ja", NO = "nein", NONE = "keine",
    HINT_MOVE = "Bewegen", HINT_SELECT = "Wählen", HINT_RIGHT_CLICK = "Rechtsklick", HINT_BACK = "Zurück",
    HINT_TABS = "Reiter", HINT_MENU = "Menü", HINT_MENU_CLOSE = "Menü schließen", HINT_SCROLL = "Blättern",
    HINT_JUMP = "Nächstes Symbol", HINT_PAN = "Karte bewegen", HINT_PLACES = "Orte", HINT_FIND_ME = "Mich finden",
    HINT_PIN = "Nadel setzen", HINT_PIN_CANCEL = "Nadel abbrechen", HINT_PIN_DROP = "Nadel hier setzen", HINT_PINS = "Nadeln",
    HINT_PRESS = "Drücken / zoomen", HINT_ZOOM_OUT = "Herauszoomen", HINT_ZOOM = "Zoom", HINT_WAYPOINT = "Wegpunkt",
    HINT_CLOSE_MAP = "Karte schließen", HINT_QUILL_DONE = "Feder weglegen", HINT_QUILL_TOOLS = "Federwerkzeuge",
    HINT_QUILL_PEN = "Feder ab / auf", HINT_FLOORS = "Ebenen", HINT_SIDE = "Seitenleiste", HINT_BACK_WORLD = "Zurück zur Welt",
    HINT_CANCEL = "Abbrechen", HINT_CARET = "Textcursor", HINT_TYPE = "Tippen",
    KB_TITLE = "Tastatur", KB_SHIFT = "Groß", KB_SHIFT_ON = "GROSS", KB_SPACE = "Leer", KB_BACKSPACE = "Löschen", KB_OK = "Fertig",
    PLACES_TITLE = "Orte", PLACES_CONTINENTS = "Kontinente", PLACES_ZONES = "Gebiete", PLACES_HERE = "In diesem Gebiet",
    PLACES_RECENT = "Zuletzt", PLACES_FIND_ME = "Meine Position", PLACES_FIND_ME_TIP = "Die Karte gleitet zu dir.",
    PLACE_WHOLE_ZONE = "Ganzes Gebiet", PLACE_DUNGEON = "Dungeon", PLACE_RAID = "Schlachtzug", PLACE_FLIGHT = "Flugmeister",
    SETTINGS_DESC = "Macht My Map Is Rich mit der Gamepad-Oberfläche von WoW Forever vollständig mit dem Controller bedienbar: die Controller-Ansicht von My Map Is Rich, das Steuerkreuz in seinen Fenstern, Symbolsprung, Bildschirmtastatur und Ortsbrowser.",
    OPT_ENABLED = "Controller in My Map Is Rich nutzen", OPT_PADVIEW = "Controller-Ansicht von My Map Is Rich einschalten",
    OPT_JUMP = "Steuerkreuz springt von Symbol zu Symbol", OPT_MAGNET = "Symbolmagnet", OPT_MAGNET_RADIUS = "Magnetreichweite",
    OPT_MAGNET_SMALL = "Kurz", OPT_MAGNET_MEDIUM = "Mittel", OPT_MAGNET_LARGE = "Weit", OPT_HINTS = "Hilfeleiste auf der Karte",
    OPT_KEYBOARD = "Tastaturbelegung", OPT_GLYPHS = "Tastensymbole", OPT_THEME = "Farben", OPT_AUTO = "Automatisch",
    OPT_RESET = "Standardeinstellungen",
    THEME_BROWN = "Braun", THEME_GREY = "Grau", THEME_BLUE = "Blau", THEME_GREEN = "Grün", THEME_PURPLE = "Lila", THEME_PINK = "Rosa",
    HINT_RECENTER = "Auf mich zentrieren", HINT_FOLLOW = "Mir folgen", HINT_FOLLOW_STOP = "Nicht mehr folgen", OPT_CENTER_OPEN = "Beim Öffnen auf mich zentrieren", HINT_ICON_CYCLE = "Nächstes Symbol (LT: vorheriges)",
    HINT_ACTIONS = "My Map Is Rich-Aktionen", HINT_EDGE_PAN = "Cursor am Rand: bewegen",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "My Map Is Rich-Menü", ACT_PIN = "Nadel setzen", ACT_PINS = "Nadeln",
    ACT_QUILL = "Feder", ACT_PLACES = "Orte", ACT_RECENTER = "Auf mich zentrieren",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("deDE", {
    TAB_DONATE = "Entdecken",
    DONATE_TITLE = "My Map Is Rich unterstützen",
    DONATE_INTRO = "My Map Is Rich ist kostenlos und bleibt es auch. Wenn es dir hilft und du dich bedanken möchtest, kannst du mir über PayPal einen Betrag deiner Wahl spenden.",
    DONATE_SCAN = "Scanne den QR-Code mit deinem Handy",
    DONATE_LINK = "Oder kopiere den Link (Strg+C) und füge ihn in deinen Browser ein:",
    DONATE_THANKS = "Spenden sind völlig freiwillig und schalten nichts frei: Alle Funktionen bleiben für alle verfügbar. Danke für deine Unterstützung!",
    TAB_HELP = "Hilfe",
    OPEN_CONFIG = "Konfiguration öffnen",
    MINIMAP_DRAG = "Ziehen: diese Taste um die Minikarte verschieben",
    MINIMAP_HIDDEN = "Minikarten-Taste ausgeblendet. Gib /mmir minimap ein, um sie wieder anzuzeigen.",
    MINIMAP_SHOWN = "Minikarten-Taste angezeigt.",
    OPT_MINIMAP = "Taste an der Minikarte",
    TAB_SETTINGS = "Einstellungen",
    SET_MAP = "Der Controller auf der Karte",
    SET_LOOK = "Aussehen",
    OPT_MINIMAP_TIP = "Klick: dieses Fenster. Rechtsklick: den Controller auf der Karte ein- oder ausschalten.",
    MINIMAP_LEFT = "Klick: Fenster öffnen",
    MINIMAP_RIGHT_OFF = "Rechtsklick: Controller auf der Karte ausschalten",
    MINIMAP_RIGHT_ON = "Rechtsklick: Controller auf der Karte einschalten",
    STATUS_BAR_NO_OPENMAP = "My Map Is Rich fehlt oder ist nicht kompatibel",
    STATUS_BAR_NO_PADUI = "Gamepad-Oberfläche aus: das Addon wartet",
    STATUS_BAR_READY = "Bereit: öffne die Karte mit dem Controller",
    STATUS_BAR_WAIT = "My Map Is Richs Controller-Ansicht startet beim Öffnen der Karte (sonst /reload)",
    HELP_INTRO = "Was jede Taste tut, Karte für Karte. Die Hilfeleiste unten auf der Karte zeigt sie auch.",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("deDE", {
    PROJECTS_TITLE = "Meine Projekte",
    PROJECTS_INTRO = "Meine kostenlosen Addons für WoW Forever: kopiere einen Link, um seine CurseForge-Seite zu öffnen.",
    PROJECTS_THIS = "dieses Addon",
    PROJECTS_INSTALLED = "installiert",
    PROJECTS_ALL = "Alle meine Projekte auf CurseForge:",
    PROJECT_MGIR = "Zusatztasten deines Controllers und ihre Ebenen, ein HUD, schlaue Verbrauchsgüter.",
    PROJECT_MGUIR = "Das Gildenzentrum: gegenseitige Hilfe, Schlachtzüge, Kalender und Abenteuer, automatisch synchronisiert.",
    PROJECT_OMGP = "OpenMap vollständig mit dem Controller: Symbole, Orte, Tastatur, Dungeons.",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("deDE", {
    HINT_TRAVEL = "Route hierher", HINT_TRAVEL_CANCEL = "Route abbrechen",
    OPT_TRAVEL = "Routen mit R3", OPT_TRAVEL_SPEED = "Reisetempo",
    OPT_SPEED_WALK = "Zu Fuß", OPT_SPEED_SLOW = "Reittier (60 %)", OPT_SPEED_FAST = "Schnelles Reittier (100 %)",
    TRAVEL_PLANNED = "Route: %s, etwa %s.", TRAVEL_STEP = "Schritt %d/%d: %s (%s).",
    TRAVEL_ONE_STEP = "1 Schritt", TRAVEL_STEPS = "%d Schritte",
    TRAVEL_ARRIVED = "Du bist angekommen.", TRAVEL_CANCELLED = "Route abgebrochen.",
    TRAVEL_DEST = "das Ziel", TRAVEL_DEST_IN = "das Ziel (%s)", TRAVEL_FM = "den Flugmeister (%s)", TRAVEL_FM_NEW = "den neuen Flugmeister (%s): sprich ihn an", TRAVEL_DOCK = "den Anleger (%s)",
    TRAVEL_QUEST_DEST = "die Quest „%s“", TRAVEL_NO_QUEST = "Das Spiel nennt keinen Ort für die Quest „%s“.", HINT_TRAVEL_QUEST = "Route zu dieser Quest",
    TRAVEL_LEG_WALK = "Geh zu %s", TRAVEL_LEG_FLIGHT = "Flieg nach %s", TRAVEL_LEG_BOAT = "Nimm das Schiff nach %s",
    TRAVEL_LEG_ZEPPELIN = "Nimm den Zeppelin nach %s", TRAVEL_TOOLTIP_TITLE = "Route", TRAVEL_TOTAL = "Gesamt",
    TRAVEL_PORTAL = "das Portal (%s)", TRAVEL_TRAM = "die Tiefenbahn (%s)", TRAVEL_LEG_PORTAL = "Nimm das Portal nach %s", TRAVEL_LEG_TRAM = "Nimm die Tiefenbahn nach %s",
    TRAVEL_REPORT_NAV = "Raster: %d Etagenfelder, %d Aufzug/Aufzüge, Flächen %d -> %d, Ersatz: %s", TRAVEL_REPORT_NAV_NONE = "Raster: kein Weg (%s)",
    SET_TRAVEL = "Routen", OPT_TRAVEL_ROADS = "Straßen folgen",
    OPT_TRAVEL_MINIMAP = "Route auf der Minikarte",
    OPT_TRAVEL_TERRAIN = "Hindernisse umgehen",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("deDE", {
    WHATSNEW_TITLE = "Neuigkeiten", WHATSNEW_NEW = "Neu", WHATSNEW_BUTTON = "Neuigkeiten…",
    WHATSNEW_NEVER = "Nach einem Update nicht mehr anzeigen", OPT_WHATSNEW = "Neuigkeiten nach einem Update",
})

-- 0.6.0 (der Rest kommt aus dem Englischen)
ns.AddLocale("deDE", {
    TAB_TRAVEL = "Routen", SET_GUIDE = "Führung", SET_GROUP = "Gruppe",
    HUD_TITLE = "Route", HUD_FLIGHT = "Im Flug", HUD_CORPSE = "Zurück zur Leiche", HUD_RALLY = "Sammeln", HUD_TO = "nach %s",
    HUD_STEP = "Schritt %d / %d · %s", HUD_LEFT = "übrig", HUD_FLIGHT_LEFT = "Flug", HUD_ARRIVAL = "Ankunft %s",
    HUD_LANDING = "Landung in %d s", HUD_THEN = "Danach: %s", HUD_QUEUE_ONE = "+1 Ziel in der Liste", HUD_QUEUE = "+%d Ziele in der Liste",
    HUD_RALLY_HERE = "angekommen",
    KIND_WALK = "zu Fuß", KIND_FLIGHT = "Flug", KIND_BOAT = "Schiff", KIND_ZEPPELIN = "Zeppelin", KIND_PORTAL = "Portal", KIND_TRAM = "Tiefenbahn",
    WHEEL_PICK = "Rechter Stick oder Steuerkreuz", ACT_QUEUE = "Zur Liste hinzufügen", ACT_SHARE = "An die Gruppe senden",
    HINT_CLOSE = "Schließen", HINT_WHEEL_CHOOSE = "Wählen", HINT_WHEEL_STICK = "Wählen",
    PLACES_TAB_PLACES = "Orte", PLACES_TAB_SEARCH = "Suchen", PLACES_TAB_RECENT = "Zuletzt", PLACES_TAB_QUEUE = "Liste", PLACES_TAB_QUEUE_N = "Liste (%d)",
    PLACES_WORLD = "Welt", SEARCH_NPC = "NPC", SEARCH_OBJECT = "Objekt",
    PLACES_OPEN = "Öffnen", PLACES_ROUTE = "Route", PLACES_QUEUE = "Zur Liste hinzufügen", PLACES_SHOW = "Auf der Karte zeigen",
    QUEUE_GO = "Jetzt hin", QUEUE_REMOVE = "Entfernen", QUEUE_SORT = "Schnellste Reihenfolge",
    SHARE_TITLE = "Vorgeschlagenes Ziel", SHARE_GO = "Hin", SHARE_LATER = "Zur Liste hinzufügen", SHARE_NO = "Nein danke",
    OPT_TRAVEL_CORPSE = "Route zu meiner Leiche", OPT_TRAVEL_HUD = "Routenanzeige", OPT_TRAVEL_ARROW = "GPS-Pfeil", OPT_TRAVEL_RUMBLE = "Vibration", OPT_TRAVEL_SOUND = "Töne",
    OPT_TRAVEL_SHARE = "Ziele der Gruppe",
})

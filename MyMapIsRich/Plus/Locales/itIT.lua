-- Italiano (ce qui manque vient de l'anglais : enUS.lua)
local _, root = ...
local ns = root.Plus

ns.AddLocale("itIT", {
    YES = "sì", NO = "no", NONE = "nessuno",
    HINT_MOVE = "Muovi", HINT_SELECT = "Scegli", HINT_RIGHT_CLICK = "Clic destro", HINT_BACK = "Indietro",
    HINT_TABS = "Schede", HINT_MENU = "Menu", HINT_MENU_CLOSE = "Chiudi menu", HINT_SCROLL = "Scorri",
    HINT_JUMP = "Icona successiva", HINT_PAN = "Sposta la mappa", HINT_PLACES = "Luoghi", HINT_FIND_ME = "Trovami",
    HINT_PIN = "Metti uno spillo", HINT_PIN_CANCEL = "Annulla spillo", HINT_PIN_DROP = "Metti lo spillo qui", HINT_PINS = "Spilli",
    HINT_PRESS = "Premi / ingrandisci", HINT_ZOOM_OUT = "Rimpicciolisci", HINT_ZOOM = "Zoom", HINT_WAYPOINT = "Punto di passaggio",
    HINT_CLOSE_MAP = "Chiudi mappa", HINT_QUILL_DONE = "Riponi la penna", HINT_QUILL_TOOLS = "Strumenti della penna",
    HINT_QUILL_PEN = "Penna giù / su", HINT_FLOORS = "Piani", HINT_SIDE = "Pannello", HINT_BACK_WORLD = "Torna al mondo",
    HINT_CANCEL = "Annulla", HINT_CARET = "Cursore del testo", HINT_TYPE = "Scrivi",
    KB_TITLE = "Tastiera", KB_SHIFT = "Maiusc", KB_SHIFT_ON = "MAIUSC", KB_SPACE = "Spazio", KB_BACKSPACE = "Cancella", KB_OK = "Fatto",
    PLACES_TITLE = "Luoghi", PLACES_CONTINENTS = "Continenti", PLACES_ZONES = "Zone", PLACES_HERE = "In questa zona",
    PLACES_RECENT = "Recenti", PLACES_FIND_ME = "La mia posizione", PLACES_FIND_ME_TIP = "La mappa scorre fino a te.",
    PLACE_WHOLE_ZONE = "Tutta la zona", PLACE_DUNGEON = "Spedizione", PLACE_RAID = "Incursione", PLACE_FLIGHT = "Maestro di volo",
    SETTINGS_DESC = "Rende My Map Is Rich completamente utilizzabile con il controller, con l'interfaccia controller di WoW Forever: la vista controller di My Map Is Rich, la croce nelle sue finestre, salto tra icone, tastiera a schermo ed esploratore di luoghi.",
    OPT_ENABLED = "Usa il controller su My Map Is Rich", OPT_PADVIEW = "Attiva la vista controller di My Map Is Rich",
    OPT_JUMP = "La croce salta da icona a icona", OPT_MAGNET = "Calamita delle icone", OPT_MAGNET_RADIUS = "Portata della calamita",
    OPT_MAGNET_SMALL = "Corta", OPT_MAGNET_MEDIUM = "Media", OPT_MAGNET_LARGE = "Lunga", OPT_HINTS = "Barra di aiuto sulla mappa",
    OPT_KEYBOARD = "Layout della tastiera", OPT_GLYPHS = "Icone dei pulsanti", OPT_THEME = "Colori", OPT_AUTO = "Automatico",
    OPT_RESET = "Impostazioni predefinite",
    THEME_BROWN = "Marrone", THEME_GREY = "Grigio", THEME_BLUE = "Blu", THEME_GREEN = "Verde", THEME_PURPLE = "Viola", THEME_PINK = "Rosa",
    HINT_RECENTER = "Centra su di me", HINT_FOLLOW = "Seguimi", HINT_FOLLOW_STOP = "Smetti di seguirmi", OPT_CENTER_OPEN = "Centra su di me all'apertura", HINT_ICON_CYCLE = "Icona successiva (LT: precedente)",
    HINT_ACTIONS = "Azioni di My Map Is Rich", HINT_EDGE_PAN = "Cursore al bordo: sposta",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "Menu di My Map Is Rich", ACT_PIN = "Metti uno spillo", ACT_PINS = "Spilli",
    ACT_QUILL = "Penna", ACT_PLACES = "Luoghi", ACT_RECENTER = "Centra su di me",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("itIT", {
    TAB_DONATE = "Scopri",
    DONATE_TITLE = "Sostieni My Map Is Rich",
    DONATE_INTRO = "My Map Is Rich è gratuito e lo resterà. Se ti è utile e vuoi ringraziarmi, puoi farmi una donazione su PayPal, dell'importo che preferisci.",
    DONATE_SCAN = "Scansiona il codice QR con il telefono",
    DONATE_LINK = "Oppure copia il link (Ctrl+C) e incollalo nel browser:",
    DONATE_THANKS = "Le donazioni sono del tutto facoltative e non sbloccano nulla: tutte le funzioni restano disponibili per tutti. Grazie per il tuo sostegno!",
    TAB_HELP = "Aiuto",
    OPEN_CONFIG = "Apri la configurazione",
    MINIMAP_DRAG = "Trascina: sposta questo pulsante intorno alla minimappa",
    MINIMAP_HIDDEN = "Pulsante della minimappa nascosto. Scrivi /mmir minimap per mostrarlo di nuovo.",
    MINIMAP_SHOWN = "Pulsante della minimappa visibile.",
    OPT_MINIMAP = "Pulsante intorno alla minimappa",
    TAB_SETTINGS = "Impostazioni",
    SET_MAP = "Il controller sulla mappa",
    SET_LOOK = "Aspetto",
    OPT_MINIMAP_TIP = "Clic: questa finestra. Clic destro: attiva o disattiva il controller sulla mappa.",
    MINIMAP_LEFT = "Clic: apri la finestra",
    MINIMAP_RIGHT_OFF = "Clic destro: disattiva il controller sulla mappa",
    MINIMAP_RIGHT_ON = "Clic destro: attiva il controller sulla mappa",
    STATUS_BAR_NO_OPENMAP = "My Map Is Rich manca o non è compatibile",
    STATUS_BAR_NO_PADUI = "Interfaccia controller disattivata: l'addon aspetta",
    STATUS_BAR_READY = "Pronto: apri la mappa con il controller",
    STATUS_BAR_WAIT = "La vista controller di My Map Is Rich parte all'apertura della mappa (altrimenti /reload)",
    HELP_INTRO = "Cosa fa ogni pulsante, mappa per mappa. Anche la barra di aiuto in fondo alla mappa lo mostra.",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("itIT", {
    PROJECTS_TITLE = "I miei progetti",
    PROJECTS_INTRO = "I miei addon gratuiti per WoW Forever: copia un link per aprire la sua pagina CurseForge.",
    PROJECTS_THIS = "questo addon",
    PROJECTS_INSTALLED = "installato",
    PROJECTS_ALL = "Tutti i miei progetti su CurseForge:",
    PROJECT_MGIR = "I pulsanti extra del tuo controller e i loro strati, un HUD, consumabili intelligenti.",
    PROJECT_MGUIR = "Il cuore della gilda: aiuto reciproco, incursioni, calendario e avventure, sincronizzati da soli.",
    PROJECT_OMGP = "OpenMap completamente con il controller: icone, luoghi, tastiera, spedizioni.",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("itIT", {
    HINT_TRAVEL = "Percorso fin qui", HINT_TRAVEL_CANCEL = "Annulla il percorso",
    OPT_TRAVEL = "Percorsi con R3", OPT_TRAVEL_SPEED = "Velocità di viaggio",
    OPT_SPEED_WALK = "A piedi", OPT_SPEED_SLOW = "Cavalcatura (60%)", OPT_SPEED_FAST = "Cavalcatura veloce (100%)",
    TRAVEL_PLANNED = "Percorso: %s, circa %s.", TRAVEL_STEP = "Tappa %d/%d: %s (%s).",
    TRAVEL_ONE_STEP = "1 tappa", TRAVEL_STEPS = "%d tappe",
    TRAVEL_ARRIVED = "Sei arrivato.", TRAVEL_CANCELLED = "Percorso annullato.",
    TRAVEL_DEST = "la destinazione", TRAVEL_DEST_IN = "la destinazione (%s)", TRAVEL_FM = "il maestro di volo (%s)", TRAVEL_FM_NEW = "il nuovo maestro di volo (%s): parlagli", TRAVEL_DOCK = "il molo (%s)",
    TRAVEL_QUEST_DEST = "la missione «%s»", TRAVEL_NO_QUEST = "Il gioco non dà alcuna posizione per la missione «%s».", HINT_TRAVEL_QUEST = "Percorso verso questa missione",
    TRAVEL_LEG_WALK = "Vai a %s", TRAVEL_LEG_FLIGHT = "Vola a %s", TRAVEL_LEG_BOAT = "Prendi la nave per %s",
    TRAVEL_LEG_ZEPPELIN = "Prendi lo zeppelin per %s", TRAVEL_TOOLTIP_TITLE = "Percorso", TRAVEL_TOTAL = "Totale",
    TRAVEL_PORTAL = "il portale (%s)", TRAVEL_TRAM = "la Tranvia Sotterranea (%s)", TRAVEL_LEG_PORTAL = "Prendi il portale per %s", TRAVEL_LEG_TRAM = "Prendi la Tranvia Sotterranea per %s",
    TRAVEL_REPORT_NAV = "griglia: %d celle di piano, %d ascensore/i, superfici %d -> %d, ripiego: %s", TRAVEL_REPORT_NAV_NONE = "griglia: nessun percorso (%s)",
    SET_TRAVEL = "Percorsi", OPT_TRAVEL_ROADS = "Seguire le strade",
    OPT_TRAVEL_MINIMAP = "Percorso sulla minimappa",
    OPT_TRAVEL_TERRAIN = "Aggirare gli ostacoli",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("itIT", {
    WHATSNEW_TITLE = "Novità", WHATSNEW_NEW = "Nuovo", WHATSNEW_BUTTON = "Novità…",
    WHATSNEW_NEVER = "Non mostrare dopo un aggiornamento", OPT_WHATSNEW = "Novità dopo un aggiornamento",
})

-- 0.6.0 (il resto viene dall'inglese)
ns.AddLocale("itIT", {
    TAB_TRAVEL = "Percorsi", SET_GUIDE = "Guida", SET_GROUP = "Gruppo",
    HUD_TITLE = "Percorso", HUD_FLIGHT = "In volo", HUD_CORPSE = "Ritorno al corpo", HUD_RALLY = "Raduno", HUD_TO = "verso %s",
    HUD_STEP = "Tappa %d / %d · %s", HUD_LEFT = "rimanenti", HUD_FLIGHT_LEFT = "di volo", HUD_ARRIVAL = "Arrivo %s",
    HUD_LANDING = "Atterraggio tra %d s", HUD_THEN = "Poi: %s", HUD_QUEUE_ONE = "+1 destinazione in coda", HUD_QUEUE = "+%d destinazioni in coda",
    HUD_RALLY_HERE = "arrivato",
    KIND_WALK = "a piedi", KIND_FLIGHT = "volo", KIND_BOAT = "nave", KIND_ZEPPELIN = "zeppelin", KIND_PORTAL = "portale", KIND_TRAM = "tram",
    WHEEL_PICK = "Levetta destra o croce", ACT_QUEUE = "Aggiungi alla coda", ACT_SHARE = "Invia al gruppo",
    HINT_CLOSE = "Chiudi", HINT_WHEEL_CHOOSE = "Scegli", HINT_WHEEL_STICK = "Scegli",
    PLACES_TAB_PLACES = "Luoghi", PLACES_TAB_SEARCH = "Cerca", PLACES_TAB_RECENT = "Recenti", PLACES_TAB_QUEUE = "Coda", PLACES_TAB_QUEUE_N = "Coda (%d)",
    PLACES_WORLD = "Mondo", SEARCH_NPC = "PNG", SEARCH_OBJECT = "Oggetto",
    PLACES_OPEN = "Apri", PLACES_ROUTE = "Percorso", PLACES_QUEUE = "Aggiungi alla coda", PLACES_SHOW = "Vedi sulla mappa",
    QUEUE_GO = "Vai ora", QUEUE_REMOVE = "Rimuovi", QUEUE_SORT = "Ordine più rapido",
    SHARE_TITLE = "Destinazione proposta", SHARE_GO = "Vai", SHARE_LATER = "Aggiungi alla coda", SHARE_NO = "No, grazie",
    OPT_TRAVEL_CORPSE = "Percorso verso il mio corpo", OPT_TRAVEL_HUD = "Pannello del percorso", OPT_TRAVEL_ARROW = "Freccia GPS", OPT_TRAVEL_RUMBLE = "Vibrazioni", OPT_TRAVEL_SOUND = "Suoni",
    OPT_TRAVEL_SHARE = "Destinazioni del gruppo",
})

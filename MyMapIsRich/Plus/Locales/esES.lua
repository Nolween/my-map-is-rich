-- Español (ce qui manque vient de l'anglais : enUS.lua ; aussi pour esMX)
local _, root = ...
local ns = root.Plus

ns.AddLocale("esES", {
    YES = "sí", NO = "no", NONE = "ninguno",
    HINT_MOVE = "Mover", HINT_SELECT = "Elegir", HINT_RIGHT_CLICK = "Clic derecho", HINT_BACK = "Volver",
    HINT_TABS = "Pestañas", HINT_MENU = "Menú", HINT_MENU_CLOSE = "Cerrar menú", HINT_SCROLL = "Desplazar",
    HINT_JUMP = "Icono siguiente", HINT_PAN = "Mover el mapa", HINT_PLACES = "Lugares", HINT_FIND_ME = "Encontrarme",
    HINT_PIN = "Poner chincheta", HINT_PIN_CANCEL = "Cancelar chincheta", HINT_PIN_DROP = "Poner la chincheta aquí", HINT_PINS = "Chinchetas",
    HINT_PRESS = "Pulsar / acercar", HINT_ZOOM_OUT = "Alejar", HINT_ZOOM = "Zoom", HINT_WAYPOINT = "Punto de ruta",
    HINT_CLOSE_MAP = "Cerrar mapa", HINT_QUILL_DONE = "Guardar la pluma", HINT_QUILL_TOOLS = "Herramientas de la pluma",
    HINT_QUILL_PEN = "Bajar / subir la pluma", HINT_FLOORS = "Plantas", HINT_SIDE = "Panel", HINT_BACK_WORLD = "Volver al mundo",
    HINT_CANCEL = "Cancelar", HINT_CARET = "Cursor de texto", HINT_TYPE = "Escribir",
    KB_TITLE = "Teclado", KB_SHIFT = "Mayús", KB_SHIFT_ON = "MAYÚS", KB_SPACE = "Espacio", KB_BACKSPACE = "Borrar", KB_OK = "Aceptar",
    PLACES_TITLE = "Lugares", PLACES_CONTINENTS = "Continentes", PLACES_ZONES = "Zonas", PLACES_HERE = "En esta zona",
    PLACES_RECENT = "Recientes", PLACES_FIND_ME = "Mi posición", PLACES_FIND_ME_TIP = "El mapa se desliza hasta ti.",
    PLACE_WHOLE_ZONE = "Toda la zona", PLACE_DUNGEON = "Mazmorra", PLACE_RAID = "Banda", PLACE_FLIGHT = "Maestro de vuelo",
    SETTINGS_DESC = "Hace My Map Is Rich totalmente usable con mando, con la interfaz de mando de WoW Forever: la vista de mando de My Map Is Rich, la cruceta en sus ventanas, salto entre iconos, teclado en pantalla y explorador de lugares.",
    OPT_ENABLED = "Usar el mando en My Map Is Rich", OPT_PADVIEW = "Activar la vista de mando de My Map Is Rich",
    OPT_JUMP = "La cruceta salta de icono en icono", OPT_MAGNET = "Imán de iconos", OPT_MAGNET_RADIUS = "Alcance del imán",
    OPT_MAGNET_SMALL = "Corto", OPT_MAGNET_MEDIUM = "Medio", OPT_MAGNET_LARGE = "Largo", OPT_HINTS = "Barra de ayuda en el mapa",
    OPT_KEYBOARD = "Distribución del teclado", OPT_GLYPHS = "Iconos de botones", OPT_THEME = "Colores", OPT_AUTO = "Automático",
    OPT_RESET = "Ajustes por defecto",
    THEME_BROWN = "Marrón", THEME_GREY = "Gris", THEME_BLUE = "Azul", THEME_GREEN = "Verde", THEME_PURPLE = "Morado", THEME_PINK = "Rosa",
    HINT_RECENTER = "Centrar en mí", HINT_FOLLOW = "Seguirme", HINT_FOLLOW_STOP = "Dejar de seguirme", OPT_CENTER_OPEN = "Centrar en mí al abrir el mapa", HINT_ICON_CYCLE = "Icono siguiente (LT: anterior)",
    HINT_ACTIONS = "Acciones de My Map Is Rich", HINT_EDGE_PAN = "Cursor en el borde: mover",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "Menú de My Map Is Rich", ACT_PIN = "Poner chincheta", ACT_PINS = "Chinchetas",
    ACT_QUILL = "Pluma", ACT_PLACES = "Lugares", ACT_RECENTER = "Centrar en mí",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("esES", {
    TAB_DONATE = "Descubrir",
    DONATE_TITLE = "Apoya My Map Is Rich",
    DONATE_INTRO = "My Map Is Rich es gratuito y lo seguirá siendo. Si te resulta útil y quieres darme las gracias, puedes hacerme una donación en PayPal, de la cantidad que quieras.",
    DONATE_SCAN = "Escanea el código QR con tu móvil",
    DONATE_LINK = "O copia el enlace (Ctrl+C) y pégalo en tu navegador:",
    DONATE_THANKS = "Las donaciones son totalmente opcionales y no desbloquean nada: todas las funciones siguen disponibles para todos. ¡Gracias por tu apoyo!",
    TAB_HELP = "Ayuda",
    OPEN_CONFIG = "Abrir la configuración",
    MINIMAP_DRAG = "Arrastrar: mover este botón alrededor del minimapa",
    MINIMAP_HIDDEN = "Botón del minimapa oculto. Escribe /mmir minimap para mostrarlo de nuevo.",
    MINIMAP_SHOWN = "Botón del minimapa visible.",
    OPT_MINIMAP = "Botón junto al minimapa",
    TAB_SETTINGS = "Ajustes",
    SET_MAP = "El mando en el mapa",
    SET_LOOK = "Aspecto",
    OPT_MINIMAP_TIP = "Clic: esta ventana. Clic derecho: activar o desactivar el mando en el mapa.",
    MINIMAP_LEFT = "Clic: abrir la ventana",
    MINIMAP_RIGHT_OFF = "Clic derecho: desactivar el mando en el mapa",
    MINIMAP_RIGHT_ON = "Clic derecho: activar el mando en el mapa",
    STATUS_BAR_NO_OPENMAP = "My Map Is Rich falta o no es compatible",
    STATUS_BAR_NO_PADUI = "Interfaz de mando desactivada: el addon espera",
    STATUS_BAR_READY = "Listo: abre el mapa con el mando",
    STATUS_BAR_WAIT = "La vista de mando de My Map Is Rich arranca al abrir el mapa (si no, /reload)",
    HELP_INTRO = "Lo que hace cada botón, mapa por mapa. La barra de ayuda abajo del mapa también lo muestra.",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("esES", {
    PROJECTS_TITLE = "Mis proyectos",
    PROJECTS_INTRO = "Mis addons gratuitos para WoW Forever: copia un enlace para abrir su página de CurseForge.",
    PROJECTS_THIS = "este addon",
    PROJECTS_INSTALLED = "instalado",
    PROJECTS_ALL = "Todos mis proyectos en CurseForge:",
    PROJECT_MGIR = "Los botones extra de tu mando y sus capas, un HUD, consumibles inteligentes.",
    PROJECT_MGUIR = "El centro de la hermandad: ayuda mutua, bandas, calendario y aventuras, sincronizados solos.",
    PROJECT_OMGP = "OpenMap totalmente con mando: iconos, lugares, teclado, mazmorras.",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("esES", {
    HINT_TRAVEL = "Ruta hasta aquí", HINT_TRAVEL_CANCEL = "Cancelar la ruta",
    OPT_TRAVEL = "Rutas con R3", OPT_TRAVEL_SPEED = "Velocidad de viaje",
    OPT_SPEED_WALK = "A pie", OPT_SPEED_SLOW = "Montura (60 %)", OPT_SPEED_FAST = "Montura rápida (100 %)",
    TRAVEL_PLANNED = "Ruta: %s, unos %s.", TRAVEL_STEP = "Paso %d/%d: %s (%s).",
    TRAVEL_ONE_STEP = "1 paso", TRAVEL_STEPS = "%d pasos",
    TRAVEL_ARRIVED = "Has llegado.", TRAVEL_CANCELLED = "Ruta cancelada.",
    TRAVEL_DEST = "el destino", TRAVEL_DEST_IN = "el destino (%s)", TRAVEL_FM = "el maestro de vuelo (%s)", TRAVEL_FM_NEW = "el nuevo maestro de vuelo (%s): háblale", TRAVEL_DOCK = "el muelle (%s)",
    TRAVEL_QUEST_DEST = "la misión «%s»", TRAVEL_NO_QUEST = "El juego no da ninguna ubicación para la misión «%s».", HINT_TRAVEL_QUEST = "Ruta a esta misión",
    TRAVEL_LEG_WALK = "Ve a %s", TRAVEL_LEG_FLIGHT = "Vuela a %s", TRAVEL_LEG_BOAT = "Toma el barco a %s",
    TRAVEL_LEG_ZEPPELIN = "Toma el zepelín a %s", TRAVEL_TOOLTIP_TITLE = "Ruta", TRAVEL_TOTAL = "Total",
    TRAVEL_PORTAL = "el portal (%s)", TRAVEL_TRAM = "el Tranvía Subterráneo (%s)", TRAVEL_LEG_PORTAL = "Toma el portal a %s", TRAVEL_LEG_TRAM = "Toma el Tranvía Subterráneo a %s",
    TRAVEL_REPORT_NAV = "rejilla: %d casillas de piso, %d ascensor(es), superficies %d -> %d, alternativa: %s", TRAVEL_REPORT_NAV_NONE = "rejilla: sin camino (%s)",
    SET_TRAVEL = "Rutas", OPT_TRAVEL_ROADS = "Seguir los caminos",
    OPT_TRAVEL_MINIMAP = "Ruta en el minimapa",
    OPT_TRAVEL_TERRAIN = "Rodear los obstáculos",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("esES", {
    WHATSNEW_TITLE = "Novedades", WHATSNEW_NEW = "Nuevo", WHATSNEW_BUTTON = "Novedades…",
    WHATSNEW_NEVER = "No mostrar tras una actualización", OPT_WHATSNEW = "Novedades tras una actualización",
})

-- 0.6.0 (lo demás viene del inglés)
ns.AddLocale("esES", {
    TAB_TRAVEL = "Rutas", SET_GUIDE = "Guiado", SET_GROUP = "Grupo",
    HUD_TITLE = "Ruta", HUD_FLIGHT = "En vuelo", HUD_CORPSE = "Volver al cadáver", HUD_RALLY = "Reunión", HUD_TO = "a %s",
    HUD_STEP = "Etapa %d / %d · %s", HUD_LEFT = "restantes", HUD_FLIGHT_LEFT = "de vuelo", HUD_ARRIVAL = "Llegada %s",
    HUD_LANDING = "Aterrizaje en %d s", HUD_THEN = "Después: %s", HUD_QUEUE_ONE = "+1 destino en la cola", HUD_QUEUE = "+%d destinos en la cola",
    HUD_RALLY_HERE = "llegó",
    KIND_WALK = "a pie", KIND_FLIGHT = "vuelo", KIND_BOAT = "barco", KIND_ZEPPELIN = "zepelín", KIND_PORTAL = "portal", KIND_TRAM = "tranvía",
    WHEEL_PICK = "Stick derecho o cruceta", ACT_QUEUE = "Añadir a la cola", ACT_SHARE = "Enviar al grupo",
    HINT_CLOSE = "Cerrar", HINT_WHEEL_CHOOSE = "Elegir", HINT_WHEEL_STICK = "Elegir",
    PLACES_TAB_PLACES = "Lugares", PLACES_TAB_SEARCH = "Buscar", PLACES_TAB_RECENT = "Recientes", PLACES_TAB_QUEUE = "Cola", PLACES_TAB_QUEUE_N = "Cola (%d)",
    PLACES_WORLD = "Mundo", SEARCH_NPC = "PNJ", SEARCH_OBJECT = "Objeto",
    PLACES_OPEN = "Abrir", PLACES_ROUTE = "Ruta", PLACES_QUEUE = "Añadir a la cola", PLACES_SHOW = "Ver en el mapa",
    QUEUE_GO = "Ir ahora", QUEUE_REMOVE = "Quitar", QUEUE_SORT = "Orden más rápido",
    SHARE_TITLE = "Destino propuesto", SHARE_GO = "Ir", SHARE_LATER = "Añadir a la cola", SHARE_NO = "No, gracias",
    OPT_TRAVEL_CORPSE = "Ruta a mi cadáver", OPT_TRAVEL_HUD = "Panel de ruta", OPT_TRAVEL_ARROW = "Flecha GPS", OPT_TRAVEL_RUMBLE = "Vibraciones", OPT_TRAVEL_SOUND = "Sonidos",
    OPT_TRAVEL_SHARE = "Destinos del grupo",
})

-- Português (ce qui manque vient de l'anglais : enUS.lua)
local _, root = ...
local ns = root.Plus

ns.AddLocale("ptBR", {
    YES = "sim", NO = "não", NONE = "nenhum",
    HINT_MOVE = "Mover", HINT_SELECT = "Escolher", HINT_RIGHT_CLICK = "Clique direito", HINT_BACK = "Voltar",
    HINT_TABS = "Abas", HINT_MENU = "Menu", HINT_MENU_CLOSE = "Fechar menu", HINT_SCROLL = "Rolar",
    HINT_JUMP = "Próximo ícone", HINT_PAN = "Mover o mapa", HINT_PLACES = "Lugares", HINT_FIND_ME = "Encontrar-me",
    HINT_PIN = "Pôr alfinete", HINT_PIN_CANCEL = "Cancelar alfinete", HINT_PIN_DROP = "Pôr o alfinete aqui", HINT_PINS = "Alfinetes",
    HINT_PRESS = "Apertar / aproximar", HINT_ZOOM_OUT = "Afastar", HINT_ZOOM = "Zoom", HINT_WAYPOINT = "Ponto de passagem",
    HINT_CLOSE_MAP = "Fechar mapa", HINT_QUILL_DONE = "Guardar a pena", HINT_QUILL_TOOLS = "Ferramentas da pena",
    HINT_QUILL_PEN = "Baixar / levantar a pena", HINT_FLOORS = "Andares", HINT_SIDE = "Painel", HINT_BACK_WORLD = "Voltar ao mundo",
    HINT_CANCEL = "Cancelar", HINT_CARET = "Cursor do texto", HINT_TYPE = "Digitar",
    KB_TITLE = "Teclado", KB_SHIFT = "Maiús", KB_SHIFT_ON = "MAIÚS", KB_SPACE = "Espaço", KB_BACKSPACE = "Apagar", KB_OK = "Pronto",
    PLACES_TITLE = "Lugares", PLACES_CONTINENTS = "Continentes", PLACES_ZONES = "Zonas", PLACES_HERE = "Nesta zona",
    PLACES_RECENT = "Recentes", PLACES_FIND_ME = "Minha posição", PLACES_FIND_ME_TIP = "O mapa desliza até você.",
    PLACE_WHOLE_ZONE = "Zona inteira", PLACE_DUNGEON = "Masmorra", PLACE_RAID = "Raide", PLACE_FLIGHT = "Mestre de voo",
    SETTINGS_DESC = "Torna o My Map Is Rich totalmente utilizável com controle, com a interface de controle do WoW Forever: a visão de controle do My Map Is Rich, o direcional nas janelas, salto entre ícones, teclado na tela e navegador de lugares.",
    OPT_ENABLED = "Usar o controle no My Map Is Rich", OPT_PADVIEW = "Ativar a visão de controle do My Map Is Rich",
    OPT_JUMP = "O direcional salta de ícone em ícone", OPT_MAGNET = "Ímã de ícones", OPT_MAGNET_RADIUS = "Alcance do ímã",
    OPT_MAGNET_SMALL = "Curto", OPT_MAGNET_MEDIUM = "Médio", OPT_MAGNET_LARGE = "Longo", OPT_HINTS = "Barra de ajuda no mapa",
    OPT_KEYBOARD = "Layout do teclado", OPT_GLYPHS = "Ícones dos botões", OPT_THEME = "Cores", OPT_AUTO = "Automático",
    OPT_RESET = "Configurações padrão",
    THEME_BROWN = "Marrom", THEME_GREY = "Cinza", THEME_BLUE = "Azul", THEME_GREEN = "Verde", THEME_PURPLE = "Roxo", THEME_PINK = "Rosa",
    HINT_RECENTER = "Centralizar em mim", HINT_FOLLOW = "Seguir-me", HINT_FOLLOW_STOP = "Parar de me seguir", OPT_CENTER_OPEN = "Centralizar em mim ao abrir o mapa", HINT_ICON_CYCLE = "Próximo ícone (LT: anterior)",
    HINT_ACTIONS = "Ações do My Map Is Rich", HINT_EDGE_PAN = "Cursor na borda: mover",
    ACTIONS_TITLE = "My Map Is Rich", ACT_MENU = "Menu do My Map Is Rich", ACT_PIN = "Pôr alfinete", ACT_PINS = "Alfinetes",
    ACT_QUILL = "Pena", ACT_PLACES = "Lugares", ACT_RECENTER = "Centralizar em mim",
})

-- La fenêtre de l'addon, le bouton de la minimap, l'onglet Soutenir
ns.AddLocale("ptBR", {
    TAB_DONATE = "Descobrir",
    DONATE_TITLE = "Apoie o My Map Is Rich",
    DONATE_INTRO = "O My Map Is Rich é gratuito e continuará sendo. Se ele te ajuda e você quiser me agradecer, pode fazer uma doação pelo PayPal, do valor que quiser.",
    DONATE_SCAN = "Escaneie o QR code com seu celular",
    DONATE_LINK = "Ou copie o link (Ctrl+C) e cole no seu navegador:",
    DONATE_THANKS = "As doações são totalmente opcionais e não desbloqueiam nada: todos os recursos continuam disponíveis para todos. Obrigado pelo apoio!",
    TAB_HELP = "Ajuda",
    OPEN_CONFIG = "Abrir a configuração",
    MINIMAP_DRAG = "Arrastar: mover este botão ao redor do minimapa",
    MINIMAP_HIDDEN = "Botão do minimapa oculto. Digite /mmir minimap para mostrá-lo de novo.",
    MINIMAP_SHOWN = "Botão do minimapa visível.",
    OPT_MINIMAP = "Botão ao redor do minimapa",
    TAB_SETTINGS = "Configurações",
    SET_MAP = "O controle no mapa",
    SET_LOOK = "Aparência",
    OPT_MINIMAP_TIP = "Clique: esta janela. Clique direito: ativar ou desativar o controle no mapa.",
    MINIMAP_LEFT = "Clique: abrir a janela",
    MINIMAP_RIGHT_OFF = "Clique direito: desativar o controle no mapa",
    MINIMAP_RIGHT_ON = "Clique direito: ativar o controle no mapa",
    STATUS_BAR_NO_OPENMAP = "My Map Is Rich ausente ou incompatível",
    STATUS_BAR_NO_PADUI = "Interface de controle desligada: o addon aguarda",
    STATUS_BAR_READY = "Pronto: abra o mapa com o controle",
    STATUS_BAR_WAIT = "A visão de controle do My Map Is Rich inicia ao abrir o mapa (senão, /reload)",
    HELP_INTRO = "O que cada botão faz, mapa por mapa. A barra de ajuda embaixo do mapa também mostra.",
})

-- Mes projets (UI/Projects.lua, onglet Découvrir) : les mêmes textes dans chaque addon
ns.AddLocale("ptBR", {
    PROJECTS_TITLE = "Meus projetos",
    PROJECTS_INTRO = "Meus addons gratuitos para WoW Forever: copie um link para abrir a página do CurseForge.",
    PROJECTS_THIS = "este addon",
    PROJECTS_INSTALLED = "instalado",
    PROJECTS_ALL = "Todos os meus projetos no CurseForge:",
    PROJECT_MGIR = "Os botões extras do seu controle e suas camadas, um HUD, consumíveis inteligentes.",
    PROJECT_MGUIR = "O centro da guilda: ajuda mútua, raides, calendário e aventuras, sincronizados sozinhos.",
    PROJECT_OMGP = "OpenMap totalmente pelo controle: ícones, lugares, teclado, masmorras.",
})

-- Les itinéraires (Travel/) : R3 sur la carte
ns.AddLocale("ptBR", {
    HINT_TRAVEL = "Rota até aqui", HINT_TRAVEL_CANCEL = "Cancelar a rota",
    OPT_TRAVEL = "Rotas com R3", OPT_TRAVEL_SPEED = "Velocidade de viagem",
    OPT_SPEED_WALK = "A pé", OPT_SPEED_SLOW = "Montaria (60%)", OPT_SPEED_FAST = "Montaria rápida (100%)",
    TRAVEL_PLANNED = "Rota: %s, cerca de %s.", TRAVEL_STEP = "Etapa %d/%d: %s (%s).",
    TRAVEL_ONE_STEP = "1 etapa", TRAVEL_STEPS = "%d etapas",
    TRAVEL_ARRIVED = "Você chegou.", TRAVEL_CANCELLED = "Rota cancelada.",
    TRAVEL_DEST = "o destino", TRAVEL_DEST_IN = "o destino (%s)", TRAVEL_FM = "o mestre de voo (%s)", TRAVEL_FM_NEW = "o novo mestre de voo (%s): fale com ele", TRAVEL_DOCK = "o cais (%s)",
    TRAVEL_QUEST_DEST = "a missão \"%s\"", TRAVEL_NO_QUEST = "O jogo não dá nenhum local para a missão \"%s\".", HINT_TRAVEL_QUEST = "Rota até esta missão",
    TRAVEL_LEG_WALK = "Vá até %s", TRAVEL_LEG_FLIGHT = "Voe para %s", TRAVEL_LEG_BOAT = "Pegue o navio para %s",
    TRAVEL_LEG_ZEPPELIN = "Pegue o zepelim para %s", TRAVEL_TOOLTIP_TITLE = "Rota", TRAVEL_TOTAL = "Total",
    TRAVEL_PORTAL = "o portal (%s)", TRAVEL_TRAM = "o Metrô Correfundo (%s)", TRAVEL_LEG_PORTAL = "Pegue o portal para %s", TRAVEL_LEG_TRAM = "Pegue o Metrô Correfundo para %s",
    TRAVEL_REPORT_NAV = "grade: %d células de andar, %d elevador(es), superfícies %d -> %d, alternativa: %s", TRAVEL_REPORT_NAV_NONE = "grade: sem caminho (%s)",
    SET_TRAVEL = "Rotas", OPT_TRAVEL_ROADS = "Seguir as estradas",
    OPT_TRAVEL_MINIMAP = "Rota no minimapa",
    OPT_TRAVEL_TERRAIN = "Contornar obstáculos",
})

-- Les nouveautés (UI/WhatsNew.lua)
ns.AddLocale("ptBR", {
    WHATSNEW_TITLE = "Novidades", WHATSNEW_NEW = "Novo", WHATSNEW_BUTTON = "Novidades…",
    WHATSNEW_NEVER = "Não mostrar após uma atualização", OPT_WHATSNEW = "Novidades após uma atualização",
})

-- 0.6.0 (o resto vem do inglês)
ns.AddLocale("ptBR", {
    TAB_TRAVEL = "Rotas", SET_GUIDE = "Orientação", SET_GROUP = "Grupo",
    HUD_TITLE = "Rota", HUD_FLIGHT = "Em voo", HUD_CORPSE = "Voltar ao corpo", HUD_RALLY = "Reunião", HUD_TO = "para %s",
    HUD_STEP = "Etapa %d / %d · %s", HUD_LEFT = "restantes", HUD_FLIGHT_LEFT = "de voo", HUD_ARRIVAL = "Chegada %s",
    HUD_LANDING = "Pouso em %d s", HUD_THEN = "Depois: %s", HUD_QUEUE_ONE = "+1 destino na fila", HUD_QUEUE = "+%d destinos na fila",
    HUD_RALLY_HERE = "chegou",
    KIND_WALK = "a pé", KIND_FLIGHT = "voo", KIND_BOAT = "navio", KIND_ZEPPELIN = "zepelim", KIND_PORTAL = "portal", KIND_TRAM = "metrô",
    WHEEL_PICK = "Analógico direito ou direcional", ACT_QUEUE = "Adicionar à fila", ACT_SHARE = "Enviar ao grupo",
    HINT_CLOSE = "Fechar", HINT_WHEEL_CHOOSE = "Escolher", HINT_WHEEL_STICK = "Escolher",
    PLACES_TAB_PLACES = "Lugares", PLACES_TAB_SEARCH = "Buscar", PLACES_TAB_RECENT = "Recentes", PLACES_TAB_QUEUE = "Fila", PLACES_TAB_QUEUE_N = "Fila (%d)",
    PLACES_WORLD = "Mundo", SEARCH_NPC = "PNJ", SEARCH_OBJECT = "Objeto",
    PLACES_OPEN = "Abrir", PLACES_ROUTE = "Rota", PLACES_QUEUE = "Adicionar à fila", PLACES_SHOW = "Ver no mapa",
    QUEUE_GO = "Ir agora", QUEUE_REMOVE = "Remover", QUEUE_SORT = "Ordem mais rápida",
    SHARE_TITLE = "Destino sugerido", SHARE_GO = "Ir", SHARE_LATER = "Adicionar à fila", SHARE_NO = "Não, obrigado",
    OPT_TRAVEL_CORPSE = "Rota até meu corpo", OPT_TRAVEL_HUD = "Painel da rota", OPT_TRAVEL_ARROW = "Seta GPS", OPT_TRAVEL_RUMBLE = "Vibrações", OPT_TRAVEL_SOUND = "Sons",
    OPT_TRAVEL_SHARE = "Destinos do grupo",
})

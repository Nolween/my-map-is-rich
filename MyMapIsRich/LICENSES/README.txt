My Map Is Rich: GPL-3.0-or-later (the LICENSE file next to the toc).

Parts that come from OpenMap 0.8.11 and keep its MIT licence (OpenMap.txt):
  Plus/Map/Art.lua, Plus/Map/Close.lua   the map's drawing and its close-up zoom, ported
  Data/Map/                              the map's data tables (made by OpenMap's tools)
  Media/Map/                             textures cut from Blizzard's map art: see ../Media/Map/NOTICE.md

Data that come from the Forever database of QuestieDB (GPLv3; its notice: QuestieDB.txt):
  Plus/Data/Quests.lua                   quests, their givers and objectives, where to find them
                                         (made by tools/quests/build_quests.py)

No library is bundled since 0.6.0 (OpenMap shipped the Ace3 libraries until then).

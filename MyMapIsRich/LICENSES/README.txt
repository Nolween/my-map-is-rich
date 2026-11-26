My Map Is Rich: GPL-3.0-or-later (the LICENSE file next to the toc).

Parts that come from OpenMap 0.8.11 and keep its MIT licence (OpenMap.txt):
  Plus/Map/Art.lua, Plus/Map/Close.lua   the map's drawing and its close-up zoom, ported
  Data/Map/                              the map's data tables (made by OpenMap's tools)
  Media/Map/                             textures cut from Blizzard's map art: see ../Media/Map/NOTICE.md

Data that come from the Forever database of QuestieDB (GPLv3; its notice: QuestieDB.txt):
  Plus/Data/Quests.lua                   quests, their givers and objectives, where to find them
                                         (made by tools/quests/build_quests.py)

Figures and rules taken up from Polestar (GPL-3.0, https://github.com/fitzforge/polestar), no code copied:
  Plus/Travel/Nav.lua                    the walking styles (Fastest, Balanced, Roads): the price of a
                                         yard on each kind of ground (Polestar_Nav/Routing/Costs.lua);
                                         the zones too high for you (Polestar/Nav/Danger.lua, an idea
                                         Polestar credits to Ding! by Yendi)
  Plus/Travel/Planner.lua, Guide.lua,    the travel rules: flight times, class teleports, keeping the
  Graph.lua                              route on a replan, the missing flight path (Polestar/Nav/Travel.lua)

Rules rewritten from Shortest Path Forever (GPL-3.0-or-later, by cjber), with its data:
  Plus/Travel/Transit.lua                the boat and zeppelin timetables learned on board, and the
                                         alerts (its Transport/Model.lua, Observer.lua, UI/Alert.lua)
  Plus/Data/Transit.lua, Teleports.lua   its Data/Routes.lua and Data/Teleports.lua
                                         (made by tools/transit and tools/teleports)

No library is bundled since 0.6.0 (OpenMap shipped the Ace3 libraries until then).

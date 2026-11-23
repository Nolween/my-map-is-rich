-- Vérification automatique du code (luacheck, lancé par GitHub à chaque
-- envoi : .github/workflows/luacheck.yml).
-- Pour commencer, seules les erreurs de syntaxe comptent (une fin de bloc
-- oubliée, une parenthèse en trop...) : elles empêchent un fichier entier
-- de se charger en jeu. Les avertissements (variables globales du jeu,
-- variables inutilisées...) sont ignorés en attendant la liste des
-- globales de WoW utilisées par l'addon.
std = "lua51"
max_line_length = false
ignore = { "1", "2", "3", "4", "5", "6" }
-- (les données générées : Data/Map, par les outils d'OpenMap ; Plus/Data, par tools/)
exclude_files = { "MyMapIsRich/Data/**", "MyMapIsRich/Plus/Data/**" }

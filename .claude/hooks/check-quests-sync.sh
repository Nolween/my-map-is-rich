#!/usr/bin/env bash
# Crochet de fin de tâche (Stop) de Claude Code, pour My Map Is Rich : si la base des
# quêtes n'a pas été synchronisée avec QuestieDB aujourd'hui (la date que
# tools/quests/build_quests.py --fetch écrit dans tools/quests/source/last_sync.txt),
# Claude ne finit pas encore : il lance /sync-quetes. Une seule fois par réponse
# (stop_hook_active : la relance passe, même si la synchronisation a échoué).
input=$(cat)
if printf '%s' "$input" | grep -q '"stop_hook_active": *true'; then exit 0; fi
f="$CLAUDE_PROJECT_DIR/tools/quests/source/last_sync.txt"
if [ "$(cat "$f" 2>/dev/null)" != "$(date +%F)" ]; then
    printf '%s\n' '{"decision":"block","reason":"La base des quêtes n'"'"'a pas été synchronisée aujourd'"'"'hui (tools/quests/source/last_sync.txt). Avant de finir, lance la compétence sync-quetes (/sync-quetes) et ajoute son résumé à ta réponse."}'
fi
exit 0

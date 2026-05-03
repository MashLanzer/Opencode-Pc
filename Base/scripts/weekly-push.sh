#!/usr/bin/env bash
# Weekly Git Push - Sube cambios a GitHub
# Usage: weekly-push.sh

cd /home/mash/Opencode/
git add -A
git commit -m "Weekly automated backup $(date '+%Y-%m-%d')"
git push origin master

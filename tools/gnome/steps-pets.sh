# Steps for tools/gnome/shell.sh: the pets (hero and the accounts' pets), a
# few reactions, and the dark style.
#   tools/gnome/shell.sh OUT tools/gnome/steps-pets.sh
# (a pet's key is logic.js petKeyOf's: profileDir/chatId)
pet='const g = ext.groups.find(g => g.name.startsWith("work")); const key = n => { const s = g.sessions.find(x => x.name === n); return `${s.profileDir || ""}/${s.chatId || s.sessionId || s.key}`; };'
ev 'ext.menu.open()'
sleep 3
popup pets
ev "$pet ext._pets.event({kind: 'done', text: 'fix parser is done!', key: key('fix parser')})"
sleep 0.6
popup pets-done
ev "ext._pets.event({kind: 'reset', text: '5h limit reset!', key: ''})"
sleep 0.6
popup pets-reset
ev 'ext._pets.hero.list.get("").petIt()'
sleep 0.5
popup pets-petted
ev 'ext.menu.close()'
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
sleep 1
ev 'ext.menu.open()'
sleep 3
popup pets-dark

# Spots right after opening: every pet stands where it belongs
ev 'ext.menu.close()'
sleep 1
ev 'ext.menu.open()'
sleep 0.3
echo "spots: $(ev 'JSON.stringify([...ext._pets._stages.values()].map(s => ({width: Math.round(s.width), pets: [...s.list.values()].map(p => [p.label, Math.round(p.px), Math.round(s.slotX(p.key))])})))')"

# A reaction that fails can't freeze the popup (on Plasma one froze it at a
# limit reset): break the pets, change a session, the status still updates
ev 'ext._pets.event = () => { throw new Error("broken on purpose"); }'
before=$(ev 'ext._status.generatedAt')
for f in "$HOME"/.claude-work/sessions/*.json; do
  python3 - "$f" <<'PY'
import json, sys, time
s = json.load(open(sys.argv[1]))
if s.get("name") == "fix parser":
    s.update(status="idle", statusUpdatedAt=int(time.time() * 1000))
    json.dump(s, open(sys.argv[1], "w"))
PY
done
sleep 5
echo "status with broken pets: $before -> $(ev 'ext._status.generatedAt'), fix parser now: $(ev 'ext.groups.flatMap(g => g.sessions).find(s => s.name === "fix parser").state')"
echo "guard logged: $(grep -c 'broken on purpose' /out/shell.log)"

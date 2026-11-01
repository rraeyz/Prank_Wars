#!/usr/bin/env bash
# Two real processes on one machine: host + client over ENet (localhost). ~45 s.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
D=$(mktemp -d)
"$GODOT" --headless --path . -- --host --autostart=2 --quick --rounds=1 --name=Host $HOST_EXTRA --quit-after=50 --nettest=host > "$D/host.log" 2>&1 &
HP=$!
sleep 2
"$GODOT" --headless --path . -- --join=127.0.0.1 --name=Client --quit-after=46 --nettest=client > "$D/client.log" 2>&1 &
CP=$!
wait $CP; wait $HP
grep -h "NETRESULT" "$D"/*.log
fail=0
grep -qE "NETRESULT client phases=.*(run|chaos)" "$D/client.log" || { echo "client did not see the play phase"; fail=1; }
moved=$(grep -o "NETRESULT client.*moved=[0-9.]*" "$D/client.log" | sed 's/.*moved=//')
awk "BEGIN{exit !($moved > 3.0)}" || { echo "client bean did not move via host (moved=$moved)"; fail=1; }
grep -q "frames=[1-9]" "$D/client.log" || { echo "client got no snapshots"; fail=1; }
if grep -E "SCRIPT ERROR" "$D"/*.log; then fail=1; fi
[ $fail = 0 ] && echo "NET TEST PASSED" || { echo "NET TEST FAILED"; tail -15 "$D/client.log"; tail -15 "$D/host.log"; }
rm -rf "$D"
exit $fail

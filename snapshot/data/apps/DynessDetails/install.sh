#!/bin/sh
set -eu
SRC=/data/apps/DynessDetails
DST=/data/apps/available/DynessDetails
FILE="$SRC/DynessDetails.json"
[ -s "$FILE" ] || { echo 'Erreur: DynessDetails.json manquant' >&2; exit 1; }
python3 - "$FILE" <<'PYTEST'
import json,base64,sys,struct,re
p=json.load(open(sys.argv[1]));r=base64.b64decode(p['resource'],validate=True)
assert p['name']=='DynessDetails' and p['version']=='5.0.0' and r[:4]==b'qres'
assert p['integrations'][0]['type']==2 and p['integrations'][0]['productId']=='0xba77'
off=struct.unpack_from('>I',r,12)[0]
n=struct.unpack_from('>I',r,off)[0]
qml=r[off+4:off+4+n].decode('utf-8')
assert 'GradientListView {' in qml and 'ListQuantityGroup {' in qml
assert not re.search(r'\bListItem\s*\{',qml)
assert 'property var device: null' in qml
print('DynessDetails v5 : ressources et controles QML verifies')
PYTEST
if [ -e /data/apps/enabled/DynessDetails ] && [ ! -L /data/apps/enabled/DynessDetails ]; then
  echo 'Erreur: apps/enabled/DynessDetails nest pas un lien' >&2;exit 1
fi
mkdir -p "$DST/gui-v2" /data/apps/enabled
if [ -f "$DST/gui-v2/DynessDetails.json" ]; then
  cp "$DST/gui-v2/DynessDetails.json" "$DST/gui-v2/DynessDetails.json.before_v5"
fi
cp "$FILE" "$DST/gui-v2/DynessDetails.json.new"
mv -f "$DST/gui-v2/DynessDetails.json.new" "$DST/gui-v2/DynessDetails.json"
ln -sfn "$DST" /data/apps/enabled/DynessDetails
if [ -d /service/flashmq ]; then svc -t /service/flashmq; fi
echo 'DynessDetails v5 actif. Recharger le navigateur (Ctrl+Shift+R).'

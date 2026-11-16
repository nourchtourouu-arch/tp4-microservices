#!/bin/bash
cd ~/calculatrice-spring-cloud
mkdir -p preuves
H=http://localhost:8082
J='Content-Type: application/json'
t() { echo "\$ $*"; "$@"; echo; echo; }
{
  echo "=== D.4 (historique-service, direct) ==="
  echo "# 1"; t curl -s -i -X POST -H "$J" -d '{"operateur":"somme","a":8,"b":2}' $H/operations
  echo "# 2"; t curl -s -i -X POST -H "$J" -d '{"operateur":"produit","a":6,"b":7}' $H/operations
  echo "# 3"; t curl -s -i -X POST -H "$J" -d '{"operateur":"division","a":7,"b":2}' $H/operations
  echo "# 4"; t curl -s -i -X POST -H "$J" -d '{"operateur":"division","a":7,"b":0}' $H/operations
  echo "# 5"; t curl -s -i -X POST -H "$J" -d '{"operateur":"racine","a":9,"b":0}' $H/operations
  echo "# 6"; t curl -s -i $H/operations
  echo "# 7"; t curl -s -i $H/operations/2
  echo "=== Traces des instances calcul-service (requetes 1 a 4) ==="
  echo "--- instance 8081 ---"; grep "\[calcul-service:8081\]" ~/logs-tp4/calcul-8081.log
  echo "--- instance 8083 ---"; grep "\[calcul-service:8083\]" ~/logs-tp4/calcul-8083.log
  echo "=== D.1 : six fois la requete 1 (somme 1+1) ==="
  for i in 1 2 3 4 5 6; do curl -s -o /dev/null -X POST -H "$J" -d '{"operateur":"somme","a":1,"b":1}' $H/operations; done
  echo "instance 8081 : $(grep -c 'somme 1+1' ~/logs-tp4/calcul-8081.log) trace(s)"
  echo "instance 8083 : $(grep -c 'somme 1+1' ~/logs-tp4/calcul-8083.log) trace(s)"
} 2>&1 | tee preuves/D4.txt

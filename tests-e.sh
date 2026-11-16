#!/bin/bash
cd ~/calculatrice-spring-cloud
mkdir -p preuves
G=http://localhost:8888
J='Content-Type: application/json'
t() { echo "\$ $*"; "$@"; echo; echo; }
cnt() { grep -c "$2" ~/logs-tp4/calcul-$1.log; }

start_gw() {
  java -jar gateway-service/target/gateway-service-0.0.1-SNAPSHOT.jar --spring.profiles.active=$1 > ~/logs-tp4/gateway-$1.log 2>&1 &
  GW_PID=$!
  for i in $(seq 1 90); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' $G/actuator/gateway/routes)" = "200" ] && break
    sleep 1
  done
  sleep 10
}
stop_gw() { kill $GW_PID; wait $GW_PID 2>/dev/null; sleep 3; }

tests_static() {
  {
    echo "=== E ($1) : requetes via la passerelle ==="
    echo "# 1 GET /calcul/somme?a=2&b=3";        t curl -s -i "$G/calcul/somme?a=2&b=3"
    echo "# 2 GET /calcul/division?a=7&b=0";      t curl -s -i "$G/calcul/division?a=7&b=0"
    echo "# 3 GET /operations";                   t curl -s -i "$G/operations"
    echo "# 4 POST /operations soustraction";     t curl -s -i -X POST -H "$J" -d '{"operateur":"soustraction","a":10,"b":4}' "$G/operations"
    echo "# 5 GET /calcul/somme/detail?a=2&b=3";  t curl -s -i "$G/calcul/somme/detail?a=2&b=3"
    echo "# 6 GET /bonjour";                      t curl -s -i "$G/bonjour"
    echo "# Swagger : zone Servers de /docs/calcul"
    curl -s "$G/docs/calcul" | grep -o '"servers":\[[^]]*\]'; echo
    a1=$(cnt 8081 'somme 5+5'); a3=$(cnt 8083 'somme 5+5')
    for i in 1 2 3 4 5 6; do curl -s -o /dev/null "$G/calcul/somme?a=5&b=5"; done
    echo "# Six requetes GET /calcul/somme?a=5&b=5 : instance 8081 = $(( $(cnt 8081 'somme 5+5') - a1 )) trace(s), instance 8083 = $(( $(cnt 8083 'somme 5+5') - a3 )) trace(s)"
  } 2>&1 | tee preuves/$2
}

for p in "http E2-http.txt" "lb E3-lb.txt" "java E4-java.txt"; do
  set -- $p
  start_gw $1; tests_static $1 $2; stop_gw
done

start_gw dynamic
{
  echo "=== E.5 (routes dynamiques) ==="
  echo "# 1 GET /calcul-service/calcul/somme?a=2&b=3";      t curl -s -i "$G/calcul-service/calcul/somme?a=2&b=3"
  echo "# 2 GET /calcul-service/calcul/produit/6/7";        t curl -s -i "$G/calcul-service/calcul/produit/6/7"
  echo "# 3 GET /historique-service/operations";            t curl -s -i "$G/historique-service/operations"
  echo "# 4 POST /historique-service/operations somme 1+1"; t curl -s -i -X POST -H "$J" -d '{"operateur":"somme","a":1,"b":1}' "$G/historique-service/operations"
  echo "# 5 GET /calcul/somme?a=2&b=3 (plus de route)";     t curl -s -i "$G/calcul/somme?a=2&b=3"
  echo "# 6 GET /gateway-service/actuator/gateway/routes";  t curl -s -o /dev/null -w "statut %{http_code}" "$G/gateway-service/actuator/gateway/routes"; echo
  echo "# Swagger : zone Servers de /calcul-service/v3/api-docs"
  curl -s "$G/calcul-service/v3/api-docs" | grep -o '"servers":\[[^]]*\]'; echo
} 2>&1 | tee preuves/E5-dynamic.txt
curl -s "$G/actuator/gateway/routes" > preuves/E5-routes.json
stop_gw
echo "=== TERMINE ==="

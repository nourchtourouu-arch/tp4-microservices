#!/bin/bash
cd ~/calculatrice-spring-cloud
mkdir -p ~/logs-tp4
pkill -f "target/.*-0.0.1-SNAPSHOT.jar" 2>/dev/null; sleep 2
rm -f ~/logs-tp4/*.log
wait_port() { for i in $(seq 1 120); do [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$1/)" != "000" ] && return; sleep 1; done; }
nohup java -jar eureka-service/target/eureka-service-0.0.1-SNAPSHOT.jar > ~/logs-tp4/eureka.log 2>&1 &
wait_port 8761
nohup java -jar calcul-service/target/calcul-service-0.0.1-SNAPSHOT.jar > ~/logs-tp4/calcul-8081.log 2>&1 &
nohup java -jar calcul-service/target/calcul-service-0.0.1-SNAPSHOT.jar --server.port=8083 > ~/logs-tp4/calcul-8083.log 2>&1 &
nohup java -jar historique-service/target/historique-service-0.0.1-SNAPSHOT.jar > ~/logs-tp4/historique.log 2>&1 &
wait_port 8081; wait_port 8083; wait_port 8082
sleep 15
echo "=== TOUT EST LANCE ==="

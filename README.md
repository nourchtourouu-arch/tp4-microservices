# TP4 Spring Cloud : Microservices « Calculatrice » avec Eureka, Gateway et OpenFeign

Matière : Architecture MicroServices | Filière : MPSRCC1 | Faculté des Sciences de Sfax

## 1. Contenu du dépôt

| Module | Rôle | Port |
|---|---|---|
| `eureka-service/` | Annuaire des services (Eureka Server) | 8761 |
| `calcul-service/` | Les 4 calculs (`/calcul`), Swagger UI, Lombok | 8081 et 8083 (2 instances) |
| `historique-service/` | Opérations (`/operations`), appelle `CALCUL-SERVICE` par OpenFeign | 8082 |
| `gateway-service/` | Passerelle Spring Cloud Gateway (routes YAML, Java, `lb://`, dynamiques) | 8888 |
| `preuves/` | Sorties des tests (D.4, E.2, E.3, E.4, E.5) |  |
| `start-all.sh`, `tests-d4.sh`, `tests-e.sh` | Lancement et tests automatiques |  |

Un pom parent (`pom.xml`) regroupe les quatre modules ; chaque module reste une application indépendante (JVM, port et `.jar` propres).

Versions : Spring Boot 4.0.9, Spring Cloud 2025.1.4, springdoc-openapi 3.0.3, JDK 17.

## 2. Construire et lancer (WSL, sans IntelliJ)

```bash
./mvnw clean package -DskipTests          # construit les 4 modules
./start-all.sh                             # lance eureka, calcul 8081, calcul 8083, historique
java -jar gateway-service/target/gateway-service-0.0.1-SNAPSHOT.jar --spring.profiles.active=dynamic
./tests-d4.sh                              # tests D.4
./tests-e.sh                               # tests E.2 a E.5 (lance la passerelle dans chaque profil)
```

Profils de la passerelle : `http` (E.2), `lb` (E.3), `java` (E.4), `dynamic` (E.5).
Swagger UI : `http://localhost:<port>/swagger-ui.html`. Tableau de bord Eureka : `http://localhost:8761`.

---

## 3. Partie A : questions de conception

**1. Qui fait la correspondance nom → adresses ?** L'annuaire **Eureka Server**. Elle est mise à jour à chaque inscription au démarrage, à chaque désinscription à l'arrêt, et à l'expiration d'une instance qui n'envoie plus de battement de cœur. Chaque client en garde une copie locale, rafraîchie périodiquement (toutes les 5 s dans ce TP).

**2. Point d'entrée unique.** Avantage : le client ne connaît qu'une adresse, et la passerelle centralise le routage, la sécurité et les journaux. Inconvénient : c'est un point de défaillance unique et un goulot d'étranglement potentiel, avec un saut réseau de plus.

**3. Six requêtes sur deux instances.** Trois requêtes par instance (tour de rôle). Le client ne s'en aperçoit pas : l'URI et la réponse sont identiques. Seules les traces des consoles le montrent.

## 4. Partie B

**Question B.1.** Chaque programme est une JVM distincte avec son propre Tomcat sur son propre port : 8761 pour l'annuaire, 8081, 8083 et 8082 pour les microservices. Il n'y a donc aucun conflit de port.

## 5. Partie C

**Question C.1.** Le **nom** (`CALCUL-SERVICE`) est le même pour toutes les instances : c'est lui que `historique-service` et la passerelle utilisent pour désigner le service. L'**identifiant** (`calcul-service:8081`, `calcul-service:8083`) distingue chaque instance dans l'annuaire (battement de cœur, désinscription, adresse précise). LoadBalancer choisit une instance parmi celles qui portent le nom demandé.

**Question C.2.** Sans `--server.port=8083`, la seconde instance essaierait aussi le port 8081 et échouerait (`Port 8081 was already in use`). Elles auraient en plus le même identifiant dans Eureka.

## 6. Partie D : OpenFeign (tests directs sur `historique-service`, voir `preuves/D4.txt`)

| N° | Requête | Corps envoyé | Statut obtenu | Instance qui a tracé |
|---|---|---|---|---|
| 1 | POST /operations | `{"operateur":"somme","a":8,"b":2}` | 201 (+ `Location`) | 8081 (`somme 8+2`) |
| 2 | POST /operations | `{"operateur":"produit","a":6,"b":7}` | 201 | 8083 (`produit 6*7`) |
| 3 | POST /operations | `{"operateur":"division","a":7,"b":2}` | 201 | 8081 (`division 7/2`) |
| 4 | POST /operations | `{"operateur":"division","a":7,"b":0}` | 400 `{"erreur":"Erreur : division par 0 impossible"}` | 8083 (`division 7/0`) |
| 5 | POST /operations | `{"operateur":"racine","a":9,"b":0}` | 400 `{"erreur":"Operateur inconnu : racine"}` | aucune (refusé avant l'appel) |
| 6 | GET /operations | aucun | 200, tableau des trois opérations | aucune |
| 7 | GET /operations/2 | aucun | 200, opération 2 (produit, 42.0) | aucune |

**Question D.1.** Six fois la requête 1 : **trois traces sur 8081 et trois sur 8083**, en alternance. La règle est le tour de rôle, c'est-à-dire le **round robin**.

**Question D.2.** Avec `name = "CALCUL-SERVIC"`, LoadBalancer ne trouve aucune instance de ce nom et Feign lève une `FeignException` (503). C'est le second bloc `catch (FeignException e)` qui produit la réponse : statut **503** et `{"erreur":"calcul-service injoignable"}`. (Réponse établie d'après le code ; ce cas n'a pas été rejoué.)

## 7. Partie E : la passerelle

Résultats via la passerelle (détails dans `preuves/E2-http.txt`, `E3-lb.txt`, `E4-java.txt`, `E5-dynamic.txt`).

| N° | Requête (préfixe `http://localhost:8888`) | Statut |
|---|---|---|
| 1 | GET /calcul/somme?a=2&b=3 | 200 |
| 2 | GET /calcul/division?a=7&b=0 | 400 |
| 3 | GET /operations | 200 |
| 4 | POST /operations (soustraction 10-4) | 201 |
| 5 | GET /calcul/somme/detail?a=2&b=3 | 200 |
| 6 | GET /bonjour | 404 (aucune route, réponse de la passerelle) |

Ces six résultats sont identiques en E.2 (YAML, adresses fixes), E.3 (`lb://`) et E.4 (routes Java).

**Répartition de charge (six requêtes GET /calcul/somme?a=5&b=5)** :

| Configuration | Instance 8081 | Instance 8083 |
|---|---|---|
| E.2 : adresses fixes `http://localhost:8081` | 6 | 0 |
| E.3 : `lb://CALCUL-SERVICE` | 3 | 3 |
| E.4 : routes Java (`lb://`) | 3 | 3 |

En E.2, l'instance 8083 est ignorée (adresse fixe) ; en E.3 et E.4, la passerelle sollicite les deux instances à tour de rôle.

**E.5 : routes dynamiques** (préfixe `http://localhost:8888`) :

| N° | Requête | Statut |
|---|---|---|
| 1 | GET /calcul-service/calcul/somme?a=2&b=3 | 200 |
| 2 | GET /calcul-service/calcul/produit/6/7 | 200 |
| 3 | GET /historique-service/operations | 200 |
| 4 | POST /historique-service/operations (somme 1+1) | 201 |
| 5 | GET /calcul/somme?a=2&b=3 | 404 (plus de route `/calcul/**`) |
| 6 | GET /gateway-service/actuator/gateway/routes | 404 dans notre essai (200 attendu, voir remarques) |

**Remarques sur deux écarts observés.**
- La zone *Servers* de la description OpenAPI (`/docs/calcul`, `/calcul-service/v3/api-docs`) affiche l'adresse de l'instance (`localhost:8081` ou une adresse IP du poste avec le port 8083) et non `localhost:8888`. Nous avons vérifié que le microservice utilise bien les en-têtes `X-Forwarded-*` quand ils sont présents : avec `curl -H "X-Forwarded-Host: localhost:8888" -H "X-Forwarded-Proto: http" -H "X-Forwarded-Port: 8888" http://localhost:8083/v3/api-docs`, la réponse contient `"url":"http://localhost:8888"`. Dans notre environnement, la passerelle ne les a pas transmis.
- Le test 6 d'E.5 a donné 404 dans notre essai : la route que la passerelle crée vers elle-même n'était pas disponible au moment du test.

**Question E.1.** La passerelle ajoute à la requête transmise les en-têtes `X-Forwarded-Host`, `X-Forwarded-Port`, `X-Forwarded-Proto` (et `X-Forwarded-Prefix` en E.5), qui décrivent l'adresse vue par le client. Avec `server.forward-headers-strategy=framework`, Spring reconstruit l'URL de la requête à partir de ces en-têtes : `ServletUriComponentsBuilder.fromCurrentRequest()` produit donc un `Location` avec le port 8888 et non 8082.

**Question E.2.** E.3 : `/calcul/somme` ; E.5 : `/calcul-service/calcul/somme`. La forme E.3 donne des URI propres, identiques à celles du TP3, mais oblige à **modifier la passerelle** (ajouter une route) à chaque nouveau microservice. La forme E.5 crée les routes automatiquement à partir de l'annuaire, sans rien modifier, mais le nom du service apparaît dans l'URI.

**Question E.3.** La passerelle est elle-même enregistrée dans l'annuaire, donc le mécanisme dynamique crée aussi une route vers elle-même. Ce n'est pas gênant en développement, mais en production il faut éviter d'exposer ainsi ses points d'accès d'administration (Actuator).

---

## 8. Questions de synthèse

**1. Étape où l'on observe chaque différence du tableau A.3**

| Aspect | Étape |
|---|---|
| Nombre de programmes | B (annuaire), C.5 (2e instance), E.1 (passerelle) |
| Dépendances Maven | B.2, C.1, C.7, E.1 |
| Adresse d'un microservice | C.2, C.7, D.2 |
| Appel entre microservices | D.2 |
| Erreurs d'appel | D.3 |
| Point d'entrée du client | E.2 |
| Plusieurs instances | C.5, D.4, E.3 |
| Serveur embarqué | E.1 (Netty) et consoles de démarrage |
| Arrêt d'un microservice | C.6 |
| Organisation du code | B.0, C.0 |
| Outil de test | C.4 (Swagger UI) |
| Classes de données | C.1 bis, C.7 (Lombok) |

**2. Trajet de `POST :8888/historique-service/operations` (`{"operateur":"somme","a":1,"b":2}`)**
1. Le client envoie la requête HTTP à la **passerelle** (8888).
2. La passerelle consulte sa copie locale de l'annuaire (consultation n° 1) : route dynamique `/historique-service/**` → `HISTORIQUE-SERVICE`. Elle retire le préfixe et transmet `POST /operations` à une instance (requête HTTP n° 2).
3. `OperationController.creer` appelle `calculClient.calculer("somme", 1, 2)`. **OpenFeign** construit `GET /calcul/somme?a=1&b=2`, et **LoadBalancer** consulte la copie locale de l'annuaire (consultation n° 2) pour choisir une instance de `CALCUL-SERVICE` (8081 ou 8083) ; requête HTTP n° 3.
4. `calcul-service` répond `3`. `historique-service` le convertit en `3.0`, enregistre l'opération et répond `201` avec l'en-tête `Location`.
5. La réponse remonte : historique-service → passerelle → client.

**3. LoadBalancer.** Il est présent dans trois programmes : la **passerelle** (résout `CALCUL-SERVICE` et `HISTORIQUE-SERVICE`), **historique-service** (résout `CALCUL-SERVICE`), et **calcul-service**, qui l'embarque avec le client Eureka mais n'appelle aucun autre service : il n'a aucun nom à résoudre.

**4. Dépendances nécessaires**
- **Client Eureka** : dans les trois programmes. `calcul-service` s'y inscrit ; `historique-service` s'y inscrit et y découvre `CALCUL-SERVICE` ; la passerelle y découvre les services (routes `lb://` et dynamiques) et s'y inscrit.
- **OpenFeign** : seulement dans `historique-service`, le seul service qui appelle un autre service par son nom.
- **Spring Cloud Gateway** : seulement dans `gateway-service`, le point d'entrée. Les microservices n'en ont pas besoin.

**5. Adresse écrite en dur et répartition de charge.** Avec `calcul.service.url=http://localhost:8081`, `historique-service` n'appelle qu'une seule instance : trois exemplaires de `calcul-service` ne répartiraient rien, et un changement de port ou de machine obligerait à modifier la configuration et à relancer. Ce TP corrige le problème : **Eureka** tient la liste des instances, le **client Eureka** inscrit chaque instance et envoie le battement de cœur, **OpenFeign + LoadBalancer** appellent le service par son nom, à tour de rôle, et la **passerelle** (`lb://`) fait de même pour les clients externes.

**6. Deux instances d'`historique-service`.** Chaque instance a sa propre mémoire : `GET /historique-service/operations` ne renvoie que les opérations de l'instance sollicitée (à tour de rôle), donc une liste incomplète et variable. Le principe mis en défaut est celui d'un service **sans état local** : l'état doit être partagé. On le corrigerait avec une **base de données partagée** (JPA, PostgreSQL par exemple) ou un cache distribué (Redis).

**7. Sans IntelliJ**, depuis la racine du projet :
```bash
./mvnw clean package -DskipTests
java -jar eureka-service/target/eureka-service-0.0.1-SNAPSHOT.jar                        # 1. annuaire
java -jar calcul-service/target/calcul-service-0.0.1-SNAPSHOT.jar                         # 2. calcul 8081
java -jar calcul-service/target/calcul-service-0.0.1-SNAPSHOT.jar --server.port=8083      # 3. calcul 8083
java -jar historique-service/target/historique-service-0.0.1-SNAPSHOT.jar                 # 4. historique
java -jar gateway-service/target/gateway-service-0.0.1-SNAPSHOT.jar                       # 5. passerelle
```
Chaque commande `java -jar` tourne dans son propre terminal (ou en arrière-plan avec `&`). `start-all.sh` automatise les quatre premières.

**8. `@GetMapping("/calcul/{operateur}")`.** Dans `CalculController`, elle décrit la requête **reçue** : le contrôleur répond à cette URI. Dans l'interface `CalculClient`, elle décrit la requête à **envoyer** : OpenFeign génère un client qui appelle cette URI sur `CALCUL-SERVICE`.

**9. Modules d'un même projet et indépendance.** Le regroupement ne remet pas en cause l'indépendance : chaque microservice a **sa propre JVM**, **son propre port**, **son propre `.jar`** et **son propre cycle de vie** (lancement, arrêt, redéploiement séparés). Seuls le code source et la construction (pom parent) sont réunis.

**10. Adresse de la zone *Servers*.** Elle vient des en-têtes `X-Forwarded-*` ajoutés par la passerelle (`Host`, `Port`, `Proto`, et `Prefix` en E.5, d'où `/calcul-service`), lus par le microservice grâce à `server.forward-headers-strategy=framework`. Sans cette propriété, le microservice ignore ces en-têtes et indique sa propre adresse (8081 ou 8082) : Swagger UI enverrait alors l'*Execute* directement au microservice en contournant la passerelle (voir les remarques de la partie E pour notre observation).

**11. Lombok.** Les constructeurs, getters et setters se trouvent dans le fichier compilé `Operation.class` (`historique-service/target/classes`) : Lombok les ajoute au bytecode à la compilation, via le processeur d'annotations. On le vérifie avec `javap -cp historique-service/target/classes com.exemple.historique.model.Operation`. Lombok peut être exclu du `.jar` parce qu'il ne sert qu'à la compilation : le bytecode contient déjà les méthodes, donc il n'est pas nécessaire à l'exécution.

**Note technique.** La classe `Operation` n'utilise que `@NoArgsConstructor` (et non `@AllArgsConstructor`) : avec deux constructeurs, Jackson 3 (Spring Boot 4) n'arrivait plus à lire le JSON du `POST` (erreur 400).

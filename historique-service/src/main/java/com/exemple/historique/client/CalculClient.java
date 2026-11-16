package com.exemple.historique.client;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;

// name = nom du service dans l'annuaire (spring.application.name de calcul-service)
@FeignClient(name = "CALCUL-SERVICE")
public interface CalculClient {

    // Chaque appel envoie GET http://<instance>/calcul/{operateur}?a=..&b=..
    // et retourne le corps de la reponse (texte brut : "5" ou "3.5")
    @GetMapping("/calcul/{operateur}")
    String calculer(@PathVariable("operateur") String operateur,
                    @RequestParam("a") int a,
                    @RequestParam("b") int b);
}

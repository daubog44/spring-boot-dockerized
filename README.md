# Spring Boot Dockerized

Per la consegna e la demo dell'esame usa questa documentazione:

- [README-ESAME-TTFCLOUD.md](./README-ESAME-TTFCLOUD.md)
- [Guida Setup & Cheat Sheet](./guida_setup_e_cheatsheet.md)
- [Guida Prova Finale Spring Boot](./guida_prova_finale_spring_boot.md)

Nel README dell'esame trovi anche:

- prerequisiti da installare sull'host
- setup minimo per eseguire `task docker-up`
- coordinate demo consigliate per Bolzano
- contratti OpenAPI / Swagger UI

Il progetto è organizzato come multi-module Maven dentro [demo](./demo):

- `common-dto`
- `naming-server`
- `tourist-service`
- `random-service`
- `store-service`
- `event-ui`

Task principali:

- `task build`
- `task docker-up`
- `task docker-down`
- `task docker-logs`

URL principali:

- UI applicativa: `http://localhost:8080`
- Eureka dashboard: `http://localhost:8761`
- Swagger UI Tourist Service: `http://localhost:8081/swagger-ui.html`
- Swagger UI Random Service: `http://localhost:8082/swagger-ui.html`
- Swagger UI Store Service: `http://localhost:8083/swagger-ui.html`
- Swagger UI Event UI: `http://localhost:8080/swagger-ui.html`


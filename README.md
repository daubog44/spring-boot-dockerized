# Spring Boot Dockerized

Per la consegna e la demo dell'esame usa questa documentazione:

- [README-ESAME-TTFCLOUD.md](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/README-ESAME-TTFCLOUD.md)

Nel README dell'esame trovi anche:

- prerequisiti da installare sull'host
- setup minimo per eseguire `task docker-up`
- coordinate demo consigliate per Bolzano

Il progetto ora e` organizzato come multi-module Maven dentro [demo](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo):

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

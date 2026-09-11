# Come si parlano i servizi

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 25 minuti | obiettivo: Sai che cosa succede fra il clic nel browser e la riga nel database: chi si registra su Eureka, come Feign trova l'altro servizio e perché nel codice non c'è nessun indirizzo. -->

In un'applicazione normale un metodo chiama un altro metodo. Qui l'altro
metodo sta in un altro processo, magari in un altro container: la chiamata
diventa una richiesta HTTP. Tre pezzi la rendono semplice: Eureka, Feign e i
DTO di `common-dto`.

## Eureka: il registro

`naming-server` è un Eureka Server: l'elenco di chi è acceso, e dove. Ogni
servizio, appena parte, gli dice «sono `CATALOGO-SERVICE`, mi trovi a
172.18.0.5:8081», e poi ogni cinque secondi conferma di essere vivo.

Il nome è quello scritto nell'`application.yml` del servizio:

```yaml demo/catalogo-service/src/main/resources/application.yml
spring:
  application:
    name: CATALOGO-SERVICE

eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
```

Con lo stack acceso, apri `http://localhost:8761`: la dashboard elenca le
istanze registrate. È una delle tre cose da far vedere alla demo.

## Feign: chiamare per nome

In `prestiti-service`, per sapere se un libro esiste, si scrive
un'interfaccia:

```java demo/prestiti-service/src/main/java/esame/prestitiservice/client/CatalogoClient.java
@FeignClient(name = "CATALOGO-SERVICE")
public interface CatalogoClient {

    @GetMapping("/api/libri/{id}")
    LibroDto libro(@PathVariable("id") Long id);

    @PutMapping("/api/libri/{id}/disponibilita")
    LibroDto cambiaDisponibilita(@PathVariable("id") Long id, @RequestParam("disponibile") boolean disponibile);
}
```

Nessuna implementazione: la scrive Spring all'avvio, perché `Main` ha
`@EnableFeignClients` (lo mette `task new-service`). Quando il codice chiama
`catalogo.libro(3)`:

1. Feign chiede al load balancer un'istanza di `CATALOGO-SERVICE`;
2. il load balancer la prende dall'elenco che il client Eureka tiene aggiornato;
3. parte `GET http://172.18.0.5:8081/api/libri/3`;
4. il JSON della risposta diventa un `LibroDto`, lo stesso record che il
   catalogo ha trasformato in JSON.

Il nome in `@FeignClient` e lo `spring.application.name` dell'altro servizio
devono essere **identici**. È il primo posto dove guardare quando una chiamata
fallisce.

## Il giro completo di un prestito

Il bibliotecario, dalla pagina, presta *Il nome della rosa* a
`anna@esempio.it`:

```text
browser        POST /prestiti                         -> biblioteca-ui :8090
biblioteca-ui  POST /api/prestiti             (Feign)  -> prestiti-service :8082
prestiti       GET  /api/libri/3              (Feign)  -> catalogo-service :8081 -> SELECT su "biblioteca"
prestiti       INSERT INTO prestiti ...                -> PostgreSQL "prestiti"
prestiti       PUT  /api/libri/3/disponibilita (Feign) -> catalogo-service       -> UPDATE libri
biblioteca-ui  redirect a /: la pagina si ridisegna con i dati nuovi
```

In nessuno di questi passaggi c'è un indirizzo scritto a mano. Nel codice ci
sono solo nomi.

## In locale e in Docker

| | In locale (`task dev`) | In Docker (`task docker-up`) |
| :--- | :--- | :--- |
| Eureka | `localhost:8761` | `eureka-server:8761` |
| il database | `localhost:5432` | `postgres:5432` |
| chi decide | i valori dopo i due punti nell'`application.yml` | le variabili d'ambiente del `docker-compose.yml` |
| gli indirizzi dei servizi | li dà Eureka | li dà Eureka |

In Docker ogni container si raggiunge con il nome del suo servizio nel
compose, ed è quel nome che gli altri usano: `localhost`, dentro un container,
è il container stesso.

## Le porte non stanno nel codice

Una porta è scritta nell'`application.yml`, nel compose e nella lista di
avvio. Il codice Java non ne contiene nessuna, perché si chiama per nome:
spostare un servizio con `task set-port SERVICE=catalogo-service PORT=9081`
non rompe nessuna chiamata.

## Perché dopo l'avvio ci vuole qualche secondo

Il template accorcia i tempi di Eureka, che di serie sono di 30 secondi:

| Impostazione | Dove | Valore |
| :--- | :--- | :--- |
| ogni quanto un servizio rilegge il registro | `eureka.client.registry-fetch-interval-seconds` | 5 s |
| ogni quanto conferma di essere vivo | `eureka.instance.lease-renewal-interval-in-seconds` | 5 s |
| dopo quanto, se tace, viene tolto | `eureka.instance.lease-expiration-duration-in-seconds` | 15 s |
| quanto il load balancer tiene l'elenco in cache | `spring.cloud.loadbalancer.cache.ttl` | 5 s |

Quindi un servizio appena acceso diventa chiamabile in 5-10 secondi, non in un
minuto. Se subito dopo `task dev` una chiamata fallisce con *Load balancer does
not contain an instance*, aspetta e riprova; se continua, `task status` ti dice
chi è registrato davvero.

> **Prova tu**
>
> Con lo stack acceso, `task status`, e guarda la parte sul registro Eureka.
> Poi apri `http://localhost:8761/eureka/apps`: è lo stesso elenco, in XML,
> che leggono i client.

> **Fatto quando**
>
> - [ ] sai dire che cosa c'è scritto in Eureka e chi ce lo scrive
> - [ ] sai perché il nome in `@FeignClient` deve essere uguale a `spring.application.name`
> - [ ] sai perché in Docker il database si chiama `postgres` e non `localhost`

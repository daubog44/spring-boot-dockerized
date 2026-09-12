# L'esame in una pagina

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 10 minuti | obiettivo: Sai che cosa ti chiedono, dove stanno i 40 punti e che cosa consegni alla fine delle sei ore. -->

La prova finale dura **sei ore**. Ti danno una traccia — un magazzino, un
catasto, un ospedale, una biblioteca — e alla fine consegni un archivio,
`COGNOME_NOME.zip`, con dentro un sistema a microservizi che parte con Docker e
un documento che lo spiega.

Questo corso ti porta dalla traccia alla consegna con il template che hai
davanti. Il filo è una traccia svolta per intero, la **Biblioteca di
quartiere**: il codice che vedi nelle lezioni è quello del branch
`example/biblioteca`, compilato e collaudato, non un esempio scritto per
l'occasione.

## Dove stanno i punti

| Parte | Punti | Che cosa vogliono vedere |
| :--- | ---: | :--- |
| Allegato tecnico | 8 | analisi, schema del database, moduli e porte, l'algoritmo, come si collauda |
| Eureka | 3 | un naming server a cui i servizi si registrano |
| Servizio principale | 8 | REST, database, Swagger, dati di prova |
| Interfaccia e servizio che chiama gli altri | 10 | le pagine, le chiamate agli altri servizi per nome, l'algoritmo |
| Servizio ausiliario | 3 | un secondo servizio registrato su Eureka |
| Domanda teorica A | 4 | Docker e macchine virtuali, Compose, sicurezza |
| Domanda teorica B | 4 | database relazionali e NoSQL, Java EE e Spring Boot |

Quasi metà dei punti — Eureka, Swagger, Docker, i dati di prova, metà
dell'allegato — non dipende dalla traccia: è impalcatura, e il template la dà
già fatta e collaudata. Le tue sei ore vanno nel resto: le entity, le regole,
le chiamate fra servizi, l'interfaccia, l'allegato e le due risposte.

## Com'è fatta una traccia

Le tracce si somigliano. Quasi sempre ci sono:

1. **dati da tenere**: un'anagrafica (prodotti, libri, pazienti) con il suo
   database;
2. **un secondo servizio** con i suoi dati, che chiede gli altri al primo;
3. **una regola o un algoritmo**: la distanza più corta, la classe
   energetica, la penale per chi restituisce in ritardo;
4. **un'interfaccia web** che mostra i dati e fa fare le operazioni;
5. **Eureka e Docker** a tenere tutto insieme.

Nella Biblioteca: il catalogo dei libri, i prestiti, la penale, una pagina per
il bibliotecario. Tre moduli più Eureka:

```text
                 naming-server  (Eureka, :8761)
         tutti si registrano qui, e si trovano per nome

browser --> biblioteca-ui :8090
               |-- Feign --> catalogo-service :8081 --> PostgreSQL "biblioteca"
               '-- Feign --> prestiti-service :8082 --> PostgreSQL "prestiti"
                                  '-- Feign --> catalogo-service
```

## Che cosa consegni

Alla fine, un comando: `task consegna NOME=COGNOME_NOME`. Prepara la cartella
`consegna/` e l'archivio: i sorgenti di ogni modulo (senza `target/`),
`docker-compose.yml` e `Dockerfile`, l'allegato tecnico già scritto per metà,
lo schema del database letto dal database vero e le istruzioni per farlo
partire. Chi corregge scompatta e lancia `docker compose up --build`. Ci
arriviamo nella [lezione sulla consegna](16-consegna-e-allegato.md).

## Che cosa fa il template, e che cosa fai tu

| Già fatto, e collaudato con i task | Tocca a te |
| :--- | :--- |
| Eureka configurato sulla porta 8761 | leggere la traccia e decidere i moduli |
| `task wizard` / `task new-service` per creare e collegare i moduli a pom, Dockerfile, compose e avvio | personalizzare i campi e i nomi |
| `task new-entity` che genera in blocco Entity JPA, Repository, Service e Controller REST | le regole di business specifiche e le relazioni JPA |
| `task new-client` per generare le chiamate Feign e i DTO condivisi | invocare i client nei service |
| `task new-view` per generare le schermate Thymeleaf con form e tabelle | personalizzare layout e flussi della UI |
| `task new-auth` e `task new-handler` per sicurezza e gestione eccezioni | definire credenziali e ruoli |
| `task seed-data` e `task db-schema` per dati di prova e schema database | verificare i flussi |
| `task consegna` per impacchettare l'archivio d'esame e l'allegato tecnico pronto | le risposte alle due domande teoriche |

La lezione dopo apre il template cartella per cartella. Se vuoi prima vedere
tutta la giornata con l'orologio in mano, c'è [la procedura del giorno
d'esame](../../GIORNO-ESAME.md).

> **Fatto quando**
>
> - [ ] sai quanto vale ogni parte, e che metà dei punti è impalcatura già pronta
> - [ ] in una traccia riconosci i dati, il secondo servizio, la regola e l'interfaccia
> - [ ] sai che alla fine si consegna un archivio che parte con `docker compose up --build`

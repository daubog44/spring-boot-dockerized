# Docker e la demo

<!-- parte: C · Chiudere | quando: 13:10 | durata: 15 minuti | obiettivo: Lo stack gira tutto in container, sai che cosa mostrare e in che ordine, e sai spegnere un servizio davanti alla commissione senza paura. -->

Durante la giornata hai lavorato con `task dev`, i servizi come processi sul
tuo PC. Alla demo si mostra quello che si consegna: tutto in container, con
Docker Compose.

## Accendere

```bash
task docker-up
```

Fa quattro cose, in quest'ordine:

1. `task check`: meglio fermarsi subito che dopo dieci minuti di build;
2. `task dev-down`: lo stack locale userebbe le stesse porte;
3. `docker compose build`: un'immagine per servizio, dallo stesso Dockerfile;
4. `docker compose up -d`: i container, in background.

Il compose li accende nell'ordine giusto grazie alle healthcheck: prima
PostgreSQL, poi Eureka, e solo quando Eureka risponde i servizi
(`depends_on` con `condition: service_healthy`). Aspetta che `task status`
mostri tutti i servizi registrati, poi comincia.

## Che cosa mostrare, e in che ordine

1. **L'applicazione**: `http://localhost:8090`. Registra un prestito, fai
   vedere il messaggio, restituisci un libro in ritardo e fai vedere la
   penale. È la parte che vale di più.
2. **Eureka**: `http://localhost:8761`. I servizi registrati, col loro nome:
   è il discovery di cui parli nell'allegato.
3. **Swagger**: `http://localhost:8082/swagger-ui.html`. I contratti delle API,
   e una richiesta vera con *Try it out*: prova a prestare un libro già fuori e
   fai vedere il 409.

## La resilienza, dal vivo

Se ti chiedono che cosa succede quando un servizio cade, fallo cadere. Dalla
cartella `demo`:

```bash
docker compose stop catalogo-service
```

Ricarica la pagina: resta in piedi e dice che il catalogo non risponde;
`http://localhost:8082/api/prestiti` mostra i prestiti con «(libro N)» al posto
del titolo. Dopo quindici secondi Eureka lo toglie dal registro. Poi:

```bash
docker compose start catalogo-service
```

e in una decina di secondi è tutto come prima. I container non hanno un nome
fisso (Compose li chiama `<cartella>-<servizio>-1`): per questo i comandi usano
il nome del **servizio** e si lanciano dalla cartella del compose.

## I log

```bash
task docker-logs
```

Oppure di un servizio solo, dalla cartella `demo`:
`docker compose logs -f prestiti-service`.

## Spegnere

| Comando | I dati del database |
| :--- | :--- |
| `task docker-down` | restano |
| `task docker-reset` | **cancellati** |

Durante la demo usa sempre `docker-down`. `docker-reset` serve quando vuoi un
database da zero, per esempio dopo aver cambiato utente o password con
`task db-config`.

## Se Docker Hub non passa

`docker compose build` ha bisogno delle immagini di base (`eclipse-temurin`,
`postgres`) e, se la cache non ce l'ha, di scaricare `curl` da Ubuntu.
`task rete` ti dice se quei domini passano; `task offline` se le immagini sono
già sul disco. Se proprio non si può costruire, la demo si fa lo stesso con
`task dev` e il solo PostgreSQL in container (`task run-db`): Maven lavora
dalla `~/.m2` e Docker deve solo far partire un'immagine che hai già.

> **Fatto quando**
>
> - [ ] `task docker-up` porta su tutto e `task status` mostra i servizi registrati
> - [ ] hai provato la demo nell'ordine: pagina, Eureka, Swagger
> - [ ] hai spento e riacceso un servizio e la pagina è rimasta in piedi
> - [ ] sai perché alla fine si usa `docker-down` e non `docker-reset`

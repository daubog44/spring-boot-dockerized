# Com'è fatto il template

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 25 minuti | obiettivo: Sai che cosa c'è in ogni cartella, che cosa decide il pom padre, perché c'è un Dockerfile solo e perché un modulo nuovo tocca sei file. -->

Il template è una cartella. Dentro ci sono un progetto Maven con più moduli, i
comandi per lavorarci e le guide. Niente installatori e niente generatori:
copi la cartella e sei operativo.

```text
spring-boot-dockerized/
├── Taskfile.yml            i comandi: task help li elenca tutti
├── scripts/                che cosa fa ogni comando, in PowerShell e in bash
├── demo/                   il progetto Maven: è questo che si consegna
│   ├── pom.xml             il pom padre: versioni ed elenco dei moduli
│   ├── Dockerfile          uno solo, per tutti i moduli
│   ├── docker-compose.yml  PostgreSQL, Eureka e un blocco per ogni servizio
│   ├── naming-server/      Eureka, porta 8761
│   └── common-dto/         le classi che i servizi si scambiano
├── corso/                  questo corso e la lavagna
├── .vscode/  .zed/         debug e comandi per gli editor
└── *.md                    le guide, che trovi anche dentro il corso
```

La cartella `demo` si chiama così perché nasce da Spring Initializr. Se
vuoi, `task rename-project NAME=biblioteca` le dà il nome del progetto e
aggiorna tutto quello che la nomina.

## I comandi: `task`

Tutto quello che tocca più file passa da un comando `task`, scritto nel
`Taskfile.yml`. Si usano sempre con variabili `NOME=valore`, mai con i
trattini:

```bash
task wizard                                                              # configura l'intera architettura
task new-service NAME=catalogo-service                                   # crea un singolo modulo
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=...           # genera Entity, Repo, Service, Controller
task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto   # genera Feign client (+ DTO)
task new-view SERVICE=biblioteca-ui NAME=Libri FIELDS=...                # genera pagina Thymeleaf e controller UI
task add-dep SERVICE=catalogo-service DEPS=security                      # aggiunge dipendenze
```

`task help` li elenca con una riga di spiegazione; `task --summary new-service`
dà il dettaglio di uno, con le variabili e gli esempi. Ogni comando esiste due
volte in `scripts/`, per PowerShell e per bash: su Windows `task` sceglie da
solo il primo, su Linux e macOS il secondo.

## Il pom padre

`demo/pom.xml` non produce niente: tiene insieme i moduli e decide le
versioni per tutti.

```xml demo/pom.xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>4.0.5</version>
</parent>

<modules>
    <module>common-dto</module>
    <module>naming-server</module>
    <!-- task new-service aggiunge qui una riga per modulo -->
</modules>

<properties>
    <java.version>25</java.version>
    <spring-cloud.version>2025.1.1</spring-cloud.version>
</properties>
```

Tre cose da sapere:

- **nei moduli le versioni non si scrivono.** Spring Boot (dal parent) e
  Spring Cloud (dal BOM importato in `dependencyManagement`) le decidono per
  tutti: in un modulo scrivi `spring-boot-starter-data-jpa` e basta. Per questo
  `task add-dep` vuole solo il nome;
- **devtools lo ereditano tutti**: è lui che fa ripartire un servizio in pochi
  secondi dopo `task compile`. Non finisce nei jar, quindi le immagini Docker
  non ne risentono;
- **Lombok è configurato una volta sola**, come annotation processor del
  compilatore. Nei moduli c'è la dipendenza e nient'altro.

`java.version` segue il JDK della macchina: se all'esame trovi Java 21,
`task set-java` (o il wizard, da solo) allinea pom, Dockerfile ed editor.

## Un modulo

Un modulo è una cartella con il suo `pom.xml` e i suoi sorgenti. Quando
`task new-service` lo crea, il pom ha già quello che serve a un servizio della
prova (qui abbreviato: nel file vero ogni dipendenza ha il suo `groupId`):

```xml demo/catalogo-service/pom.xml
<dependencies>
    <dependency>common-dto</dependency>                    <!-- i DTO condivisi -->
    <dependency>spring-boot-starter-actuator</dependency>  <!-- /actuator/health -->
    <dependency>spring-boot-starter-data-jpa</dependency>
    <dependency>spring-boot-starter-validation</dependency>
    <dependency>spring-boot-starter-web</dependency>
    <dependency>spring-cloud-starter-netflix-eureka-client</dependency>
    <dependency>spring-cloud-starter-openfeign</dependency>
    <dependency>h2</dependency>
    <dependency>postgresql</dependency>
    <dependency>springdoc-openapi-starter-webmvc-ui</dependency>  <!-- Swagger -->
    <dependency>lombok</dependency>
</dependencies>
```

Con `UI=1`, al posto di JPA e dei driver c'è Thymeleaf; con `NODB=1` niente
database.

I sorgenti stanno in `src/main/java/esame/<modulo senza trattini>/`:
`catalogo-service` ha il pacchetto `esame.catalogoservice`. La base `esame` si
cambia per tutti i moduli con `task set-package PACKAGE=it.rossi`, se la
traccia o il docente vogliono un pacchetto preciso.

## L'`application.yml`, in locale e in Docker

Ogni valore che cambia fra il tuo PC e Docker è scritto così:

```yaml demo/catalogo-service/src/main/resources/application.yml
server:
  port: ${SERVER_PORT:8081}

spring:
  application:
    name: CATALOGO-SERVICE
  datasource:
    url: ${CATALOGO_DB_URL:jdbc:postgresql://localhost:5432/biblioteca}
```

`${SERVER_PORT:8081}` vuol dire: la variabile d'ambiente `SERVER_PORT` se c'è,
altrimenti `8081`. In locale le variabili non ci sono e valgono i valori dopo i
due punti; in Docker le passa il `docker-compose.yml`, e il database diventa
`postgres:5432` invece di `localhost:5432`. Lo stesso file funziona nei due
posti, senza profili.

## Un Dockerfile per tutti

Invece di un Dockerfile per modulo ce n'è uno solo, con un argomento:

```dockerfile demo/Dockerfile
FROM eclipse-temurin:25-jdk AS builder
COPY pom.xml .
COPY common-dto/pom.xml common-dto/pom.xml
COPY catalogo-service/pom.xml catalogo-service/pom.xml
ARG MODULE="naming-server"
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -pl ${MODULE} -am dependency:go-offline
COPY . .
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -pl ${MODULE} -am clean package -Dmaven.test.skip=true

FROM eclipse-temurin:25-jre
COPY --from=builder /workspace/${MODULE}/target/${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

(Anche questo abbreviato.) Il compose lo usa per ogni servizio, passando
`MODULE: catalogo-service`. Prima si copiano i soli pom: così il livello con
le dipendenze scaricate resta in cache finché non cambia un pom, e la cache di
Maven (`--mount=type=cache`) sopravvive fra una build e l'altra. Il secondo
`FROM` tiene solo il JRE e il jar: l'immagine finale non contiene né Maven né i
sorgenti.

## Perché un modulo tocca sei file

| Dove | Che cosa | Se manca |
| :--- | :--- | :--- |
| `demo/<modulo>/` | pom, `Main`, `application.yml` | non c'è niente da compilare |
| `demo/pom.xml` | la riga `<module>` | Maven non lo compila |
| `demo/Dockerfile` | `COPY <modulo>/pom.xml` | la build Docker fallisce |
| `demo/docker-compose.yml` | il blocco del servizio | in Docker non parte |
| `scripts/dev.ps1` e `dev.sh` | la riga nella lista di avvio | `task dev` non lo avvia |
| `.vscode/` e `.zed/` | la configurazione di debug | l'editor non lo vede |

Dimenticarne uno dà errori che sembrano scollegati: compila ma non parte,
parte in locale e non in Docker. Per questo i moduli si creano, si spostano e
si tolgono con i comandi (`new-service`, `set-port`, `remove-service`), e
`task check` controlla che i sei posti dicano la stessa cosa.

> **Prova tu**
>
> Dalla cartella del progetto lancia `task check`. Poi apri
> `demo/docker-compose.yml` e trova il blocco di `eureka-server`: la porta, la
> healthcheck, l'argomento `MODULE`. Infine guarda la pagina *Il tuo progetto,
> adesso* di questo corso: è la stessa cosa, disegnata.

> **Fatto quando**
>
> - [ ] sai dove sta il progetto Maven, ed è quello che si consegna
> - [ ] sai perché nei moduli le dipendenze non hanno la versione
> - [ ] sai leggere `${SERVER_PORT:8081}`
> - [ ] sai perché un modulo si crea con `task new-service` e non a mano

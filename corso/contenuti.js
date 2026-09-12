// Generato da task learn: non modificarlo, rilancia il comando.
window.CORSO = {
  generato: '2026-09-12 13:55',
  progetto: {
    cartella: 'demo',
    pacchetto: 'esame',
    java: '25',
    moduli: [
    { nome: 'common-dto', tipo: 'libreria', porta: '', applicazione: '', database: '', entity: [], feign: [], classi: ['LibroDto', 'NuovoPrestitoRequest', 'PrestitoDto'] },
    { nome: 'naming-server', tipo: 'eureka', porta: '8761', applicazione: 'eureka-server', database: '', entity: [], feign: [], classi: [] },
    { nome: 'catalogo-service', tipo: 'rest', porta: '8081', applicazione: 'CATALOGO-SERVICE', database: 'PostgreSQL biblioteca', entity: ['AutoreEntity', 'LibroEntity'], feign: [], classi: [] },
    { nome: 'prestiti-service', tipo: 'rest', porta: '8082', applicazione: 'PRESTITI-SERVICE', database: 'PostgreSQL prestiti', entity: ['PrestitoEntity'], feign: ['CATALOGO-SERVICE'], classi: [] },
    { nome: 'biblioteca-ui', tipo: 'ui', porta: '8090', applicazione: 'BIBLIOTECA-UI', database: '', entity: [], feign: ['CATALOGO-SERVICE', 'PRESTITI-SERVICE'], classi: [] }
    ]
  },
  lezioni: [
    { file: 'corso/lezioni/01-esame.md', testo: `# L'esame in una pagina

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 10 minuti | obiettivo: Sai che cosa ti chiedono, dove stanno i 40 punti e che cosa consegni alla fine delle sei ore. -->

La prova finale dura **sei ore**. Ti danno una traccia — un magazzino, un
catasto, un ospedale, una biblioteca — e alla fine consegni un archivio,
\`COGNOME_NOME.zip\`, con dentro un sistema a microservizi che parte con Docker e
un documento che lo spiega.

Questo corso ti porta dalla traccia alla consegna con il template che hai
davanti. Il filo è una traccia svolta per intero, la **Biblioteca di
quartiere**: il codice che vedi nelle lezioni è quello del branch
\`example/biblioteca\`, compilato e collaudato, non un esempio scritto per
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

\`\`\`text
                 naming-server  (Eureka, :8761)
         tutti si registrano qui, e si trovano per nome

browser --> biblioteca-ui :8090
               |-- Feign --> catalogo-service :8081 --> PostgreSQL "biblioteca"
               '-- Feign --> prestiti-service :8082 --> PostgreSQL "prestiti"
                                  '-- Feign --> catalogo-service
\`\`\`

## Che cosa consegni

Alla fine, un comando: \`task consegna NOME=COGNOME_NOME\`. Prepara la cartella
\`consegna/\` e l'archivio: i sorgenti di ogni modulo (senza \`target/\`),
\`docker-compose.yml\` e \`Dockerfile\`, l'allegato tecnico già scritto per metà,
lo schema del database letto dal database vero e le istruzioni per farlo
partire. Chi corregge scompatta e lancia \`docker compose up --build\`. Ci
arriviamo nella [lezione sulla consegna](16-consegna-e-allegato.md).

## Che cosa fa il template, e che cosa fai tu

| Già fatto, e collaudato con i task | Tocca a te |
| :--- | :--- |
| Eureka configurato sulla porta 8761 | leggere la traccia e decidere i moduli |
| \`task wizard\` / \`task new-service\` per creare e collegare i moduli a pom, Dockerfile, compose e avvio | personalizzare i campi e i nomi |
| \`task new-entity\` che genera in blocco Entity JPA, Repository, Service e Controller REST | le regole di business specifiche e le relazioni JPA |
| \`task new-client\` per generare le chiamate Feign e i DTO condivisi | invocare i client nei service |
| \`task new-view\` per generare le schermate Thymeleaf con form e tabelle | personalizzare layout e flussi della UI |
| \`task new-auth\` e \`task new-handler\` per sicurezza e gestione eccezioni | definire credenziali e ruoli |
| \`task seed-data\` e \`task db-schema\` per dati di prova e schema database | verificare i flussi |
| \`task consegna\` per impacchettare l'archivio d'esame e l'allegato tecnico pronto | le risposte alle due domande teoriche |

La lezione dopo apre il template cartella per cartella. Se vuoi prima vedere
tutta la giornata con l'orologio in mano, c'è [la procedura del giorno
d'esame](../../GIORNO-ESAME.md).

> **Fatto quando**
>
> - [ ] sai quanto vale ogni parte, e che metà dei punti è impalcatura già pronta
> - [ ] in una traccia riconosci i dati, il secondo servizio, la regola e l'interfaccia
> - [ ] sai che alla fine si consegna un archivio che parte con \`docker compose up --build\`
` },
    { file: 'corso/lezioni/02-template.md', testo: `# Com'è fatto il template

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 25 minuti | obiettivo: Sai che cosa c'è in ogni cartella, che cosa decide il pom padre, perché c'è un Dockerfile solo e perché un modulo nuovo tocca sei file. -->

Il template è una cartella. Dentro ci sono un progetto Maven con più moduli, i
comandi per lavorarci e le guide. Niente installatori e niente generatori:
copi la cartella e sei operativo.

\`\`\`text
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
\`\`\`

La cartella \`demo\` si chiama così perché nasce da Spring Initializr. Se
vuoi, \`task rename-project NAME=biblioteca\` le dà il nome del progetto e
aggiorna tutto quello che la nomina.

## I comandi: \`task\`

Tutto quello che tocca più file passa da un comando \`task\`, scritto nel
\`Taskfile.yml\`. Si usano sempre con variabili \`NOME=valore\`, mai con i
trattini:

\`\`\`bash
task wizard                                                              # configura l'intera architettura
task new-service NAME=catalogo-service                                   # crea un singolo modulo
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=...           # genera Entity, Repo, Service, Controller
task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto   # genera Feign client (+ DTO)
task new-view SERVICE=biblioteca-ui NAME=Libri FIELDS=...                # genera pagina Thymeleaf e controller UI
task add-dep SERVICE=catalogo-service DEPS=security                      # aggiunge dipendenze
\`\`\`

\`task help\` li elenca con una riga di spiegazione; \`task --summary new-service\`
dà il dettaglio di uno, con le variabili e gli esempi. Ogni comando esiste due
volte in \`scripts/\`, per PowerShell e per bash: su Windows \`task\` sceglie da
solo il primo, su Linux e macOS il secondo.

## Il pom padre

\`demo/pom.xml\` non produce niente: tiene insieme i moduli e decide le
versioni per tutti.

\`\`\`xml demo/pom.xml
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
\`\`\`

Tre cose da sapere:

- **nei moduli le versioni non si scrivono.** Spring Boot (dal parent) e
  Spring Cloud (dal BOM importato in \`dependencyManagement\`) le decidono per
  tutti: in un modulo scrivi \`spring-boot-starter-data-jpa\` e basta. Per questo
  \`task add-dep\` vuole solo il nome;
- **devtools lo ereditano tutti**: è lui che fa ripartire un servizio in pochi
  secondi dopo \`task compile\`. Non finisce nei jar, quindi le immagini Docker
  non ne risentono;
- **Lombok è configurato una volta sola**, come annotation processor del
  compilatore. Nei moduli c'è la dipendenza e nient'altro.

\`java.version\` segue il JDK della macchina: se all'esame trovi Java 21,
\`task set-java\` (o il wizard, da solo) allinea pom, Dockerfile ed editor.

## Un modulo

Un modulo è una cartella con il suo \`pom.xml\` e i suoi sorgenti. Quando
\`task new-service\` lo crea, il pom ha già quello che serve a un servizio della
prova (qui abbreviato: nel file vero ogni dipendenza ha il suo \`groupId\`):

\`\`\`xml demo/catalogo-service/pom.xml
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
\`\`\`

Con \`UI=1\`, al posto di JPA e dei driver c'è Thymeleaf; con \`NODB=1\` niente
database.

I sorgenti stanno in \`src/main/java/esame/<modulo senza trattini>/\`:
\`catalogo-service\` ha il pacchetto \`esame.catalogoservice\`. La base \`esame\` si
cambia per tutti i moduli con \`task set-package PACKAGE=it.rossi\`, se la
traccia o il docente vogliono un pacchetto preciso.

## L'\`application.yml\`, in locale e in Docker

Ogni valore che cambia fra il tuo PC e Docker è scritto così:

\`\`\`yaml demo/catalogo-service/src/main/resources/application.yml
server:
  port: \${SERVER_PORT:8081}

spring:
  application:
    name: CATALOGO-SERVICE
  datasource:
    url: \${CATALOGO_DB_URL:jdbc:postgresql://localhost:5432/biblioteca}
\`\`\`

\`\${SERVER_PORT:8081}\` vuol dire: la variabile d'ambiente \`SERVER_PORT\` se c'è,
altrimenti \`8081\`. In locale le variabili non ci sono e valgono i valori dopo i
due punti; in Docker le passa il \`docker-compose.yml\`, e il database diventa
\`postgres:5432\` invece di \`localhost:5432\`. Lo stesso file funziona nei due
posti, senza profili.

## Un Dockerfile per tutti

Invece di un Dockerfile per modulo ce n'è uno solo, con un argomento:

\`\`\`dockerfile demo/Dockerfile
FROM eclipse-temurin:25-jdk AS builder
COPY pom.xml .
COPY common-dto/pom.xml common-dto/pom.xml
COPY catalogo-service/pom.xml catalogo-service/pom.xml
ARG MODULE="naming-server"
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -pl \${MODULE} -am dependency:go-offline
COPY . .
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -pl \${MODULE} -am clean package -Dmaven.test.skip=true

FROM eclipse-temurin:25-jre
COPY --from=builder /workspace/\${MODULE}/target/\${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
\`\`\`

(Anche questo abbreviato.) Il compose lo usa per ogni servizio, passando
\`MODULE: catalogo-service\`. Prima si copiano i soli pom: così il livello con
le dipendenze scaricate resta in cache finché non cambia un pom, e la cache di
Maven (\`--mount=type=cache\`) sopravvive fra una build e l'altra. Il secondo
\`FROM\` tiene solo il JRE e il jar: l'immagine finale non contiene né Maven né i
sorgenti.

## Perché un modulo tocca sei file

| Dove | Che cosa | Se manca |
| :--- | :--- | :--- |
| \`demo/<modulo>/\` | pom, \`Main\`, \`application.yml\` | non c'è niente da compilare |
| \`demo/pom.xml\` | la riga \`<module>\` | Maven non lo compila |
| \`demo/Dockerfile\` | \`COPY <modulo>/pom.xml\` | la build Docker fallisce |
| \`demo/docker-compose.yml\` | il blocco del servizio | in Docker non parte |
| \`scripts/dev.ps1\` e \`dev.sh\` | la riga nella lista di avvio | \`task dev\` non lo avvia |
| \`.vscode/\` e \`.zed/\` | la configurazione di debug | l'editor non lo vede |

Dimenticarne uno dà errori che sembrano scollegati: compila ma non parte,
parte in locale e non in Docker. Per questo i moduli si creano, si spostano e
si tolgono con i comandi (\`new-service\`, \`set-port\`, \`remove-service\`), e
\`task check\` controlla che i sei posti dicano la stessa cosa.

> **Prova tu**
>
> Dalla cartella del progetto lancia \`task check\`. Poi apri
> \`demo/docker-compose.yml\` e trova il blocco di \`eureka-server\`: la porta, la
> healthcheck, l'argomento \`MODULE\`. Infine guarda la pagina *Il tuo progetto,
> adesso* di questo corso: è la stessa cosa, disegnata.

> **Fatto quando**
>
> - [ ] sai dove sta il progetto Maven, ed è quello che si consegna
> - [ ] sai perché nei moduli le dipendenze non hanno la versione
> - [ ] sai leggere \`\${SERVER_PORT:8081}\`
> - [ ] sai perché un modulo si crea con \`task new-service\` e non a mano
` },
    { file: 'corso/lezioni/03-servizi-ed-eureka.md', testo: `# Come si parlano i servizi

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 25 minuti | obiettivo: Sai che cosa succede fra il clic nel browser e la riga nel database: chi si registra su Eureka, come Feign trova l'altro servizio e perché nel codice non c'è nessun indirizzo. -->

In un'applicazione normale un metodo chiama un altro metodo. Qui l'altro
metodo sta in un altro processo, magari in un altro container: la chiamata
diventa una richiesta HTTP. Tre pezzi la rendono semplice: Eureka, Feign e i
DTO di \`common-dto\`.

## Eureka: il registro

\`naming-server\` è un Eureka Server: l'elenco di chi è acceso, e dove. Ogni
servizio, appena parte, gli dice «sono \`CATALOGO-SERVICE\`, mi trovi a
172.18.0.5:8081», e poi ogni cinque secondi conferma di essere vivo.

Il nome è quello scritto nell'\`application.yml\` del servizio:

\`\`\`yaml demo/catalogo-service/src/main/resources/application.yml
spring:
  application:
    name: CATALOGO-SERVICE

eureka:
  client:
    service-url:
      defaultZone: \${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
\`\`\`

Con lo stack acceso, apri \`http://localhost:8761\`: la dashboard elenca le
istanze registrate. È una delle tre cose da far vedere alla demo.

## Feign: chiamare per nome

In \`prestiti-service\`, per sapere se un libro esiste, si scrive
un'interfaccia:

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/client/CatalogoClient.java
@FeignClient(name = "CATALOGO-SERVICE")
public interface CatalogoClient {

    @GetMapping("/api/libri/{id}")
    LibroDto libro(@PathVariable("id") Long id);

    @PutMapping("/api/libri/{id}/disponibilita")
    LibroDto cambiaDisponibilita(@PathVariable("id") Long id, @RequestParam("disponibile") boolean disponibile);
}
\`\`\`

Nessuna implementazione: la scrive Spring all'avvio, perché \`Main\` ha
\`@EnableFeignClients\` (lo mette \`task new-service\`). Quando il codice chiama
\`catalogo.libro(3)\`:

1. Feign chiede al load balancer un'istanza di \`CATALOGO-SERVICE\`;
2. il load balancer la prende dall'elenco che il client Eureka tiene aggiornato;
3. parte \`GET http://172.18.0.5:8081/api/libri/3\`;
4. il JSON della risposta diventa un \`LibroDto\`, lo stesso record che il
   catalogo ha trasformato in JSON.

Il nome in \`@FeignClient\` e lo \`spring.application.name\` dell'altro servizio
devono essere **identici**. È il primo posto dove guardare quando una chiamata
fallisce.

## Il giro completo di un prestito

Il bibliotecario, dalla pagina, presta *Il nome della rosa* a
\`anna@esempio.it\`:

\`\`\`text
browser        POST /prestiti                         -> biblioteca-ui :8090
biblioteca-ui  POST /api/prestiti             (Feign)  -> prestiti-service :8082
prestiti       GET  /api/libri/3              (Feign)  -> catalogo-service :8081 -> SELECT su "biblioteca"
prestiti       INSERT INTO prestiti ...                -> PostgreSQL "prestiti"
prestiti       PUT  /api/libri/3/disponibilita (Feign) -> catalogo-service       -> UPDATE libri
biblioteca-ui  redirect a /: la pagina si ridisegna con i dati nuovi
\`\`\`

In nessuno di questi passaggi c'è un indirizzo scritto a mano. Nel codice ci
sono solo nomi.

## In locale e in Docker

| | In locale (\`task dev\`) | In Docker (\`task docker-up\`) |
| :--- | :--- | :--- |
| Eureka | \`localhost:8761\` | \`eureka-server:8761\` |
| il database | \`localhost:5432\` | \`postgres:5432\` |
| chi decide | i valori dopo i due punti nell'\`application.yml\` | le variabili d'ambiente del \`docker-compose.yml\` |
| gli indirizzi dei servizi | li dà Eureka | li dà Eureka |

In Docker ogni container si raggiunge con il nome del suo servizio nel
compose, ed è quel nome che gli altri usano: \`localhost\`, dentro un container,
è il container stesso.

## Le porte non stanno nel codice

Una porta è scritta nell'\`application.yml\`, nel compose e nella lista di
avvio. Il codice Java non ne contiene nessuna, perché si chiama per nome:
spostare un servizio con \`task set-port SERVICE=catalogo-service PORT=9081\`
non rompe nessuna chiamata.

## Perché dopo l'avvio ci vuole qualche secondo

Il template accorcia i tempi di Eureka, che di serie sono di 30 secondi:

| Impostazione | Dove | Valore |
| :--- | :--- | :--- |
| ogni quanto un servizio rilegge il registro | \`eureka.client.registry-fetch-interval-seconds\` | 5 s |
| ogni quanto conferma di essere vivo | \`eureka.instance.lease-renewal-interval-in-seconds\` | 5 s |
| dopo quanto, se tace, viene tolto | \`eureka.instance.lease-expiration-duration-in-seconds\` | 15 s |
| quanto il load balancer tiene l'elenco in cache | \`spring.cloud.loadbalancer.cache.ttl\` | 5 s |

Quindi un servizio appena acceso diventa chiamabile in 5-10 secondi, non in un
minuto. Se subito dopo \`task dev\` una chiamata fallisce con *Load balancer does
not contain an instance*, aspetta e riprova; se continua, \`task status\` ti dice
chi è registrato davvero.

> **Prova tu**
>
> Con lo stack acceso, \`task status\`, e guarda la parte sul registro Eureka.
> Poi apri \`http://localhost:8761/eureka/apps\`: è lo stesso elenco, in XML,
> che leggono i client.

> **Fatto quando**
>
> - [ ] sai dire che cosa c'è scritto in Eureka e chi ce lo scrive
> - [ ] sai perché il nome in \`@FeignClient\` deve essere uguale a \`spring.application.name\`
> - [ ] sai perché in Docker il database si chiama \`postgres\` e non \`localhost\`
` },
    { file: 'corso/lezioni/04-common-dto.md', testo: `# common-dto, il contratto fra i servizi

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 20 minuti | obiettivo: Sai che cosa mettere in common-dto e che cosa no, e perché due servizi che si scambiano dati devono usare la stessa classe. -->

Quando \`prestiti-service\` chiede un libro al catalogo, il JSON viaggia fra due
programmi diversi. Perché funzioni, chi lo scrive e chi lo legge devono essere
d'accordo su come è fatto: gli stessi campi, con gli stessi nomi e gli stessi
tipi. \`common-dto\` è il posto dove quell'accordo è scritto una volta sola.

## Che cos'è

Un modulo Maven che non parte: niente \`Main\`, niente porta. Produce un jar che
gli altri moduli usano come dipendenza, e ogni modulo creato da
\`task new-service\` ce l'ha già nel pom:

\`\`\`xml demo/prestiti-service/pom.xml
<dependency>
    <groupId>com.example</groupId>
    <artifactId>common-dto</artifactId>
    <version>\${project.version}</version>
</dependency>
\`\`\`

Se un modulo non ce l'ha (uno scritto a mano), si aggiunge con
\`task add-dep SERVICE=<modulo> DEPS=common-dto\`.

## Che cosa ci va

I **record** che due servizi si passano. Nella Biblioteca sono tre:

\`\`\`java demo/common-dto/src/main/java/esame/common/dto/LibroDto.java
/** Un libro del catalogo, come lo vede chi lo chiede via Feign. */
public record LibroDto(
        Long id,
        String titolo,
        String isbn,
        Integer annoPubblicazione,
        String genere,
        boolean disponibile,
        String autore) {
}
\`\`\`

\`\`\`java demo/common-dto/src/main/java/esame/common/dto/NuovoPrestitoRequest.java
/**
 * Il corpo di POST /api/prestiti. Sta in common-dto perche' lo usano in due:
 * prestiti-service lo riceve, biblioteca-ui lo manda via Feign.
 */
public record NuovoPrestitoRequest(
        @NotNull Long libroId,
        @NotBlank @Email String utenteEmail,
        @Min(1) @Max(60) Integer giorni) {
}
\`\`\`

| Record | Chi lo scrive | Chi lo legge |
| :--- | :--- | :--- |
| \`LibroDto\` | \`catalogo-service\` | \`prestiti-service\`, \`biblioteca-ui\` |
| \`PrestitoDto\` | \`prestiti-service\` | \`biblioteca-ui\` |
| \`NuovoPrestitoRequest\` | \`biblioteca-ui\` | \`prestiti-service\` |

## Scrivere i DTO con un comando: \`task new-dto\`

Invece di creare a mano i record in \`common-dto\`, puoi generarli con un comando:

\`\`\`bash
task new-dto NAME=Libro FIELDS=id:long,titolo:string(150):required,isbn:string(13):required,disponibile:bool
task new-dto NAME=NuovoPrestitoRequest FIELDS=libroId:long:required,utenteEmail:email:required,giorni:int:min(1):max(60)
\`\`\`

Crea il file in \`demo/common-dto/src/main/java/esame/common/dto/\` come Java \`record\`
moderno con le annotazioni di validazione (\`@NotNull\`, \`@NotBlank\`, \`@Email\`, \`@Min\`, \`@Max\`).
Se preferisci una classe classica con getter e setter Lombok, aggiungi \`CLASS=1\`.

> 💡 **Modalità Interattiva**: puoi anche lanciare \`task new-dto\` senza parametri. Un comodo wizard ti chiederà nome del record, campi da inserire e se preferisci un record o una classe!


Il record è la forma giusta per un DTO: immutabile, con costruttore,
accessori, \`equals\` e \`toString\` già fatti, e Jackson lo trasforma in JSON e
ritorno senza configurazione. Le annotazioni di validazione sui componenti
funzionano: \`prestiti-service\` riceve \`@Valid @RequestBody NuovoPrestitoRequest\`
e risponde 400 se l'email non è un'email. \`common-dto\` ha già
\`jakarta.validation-api\` fra le dipendenze.

## Che cosa **non** ci va

- **Le entity.** \`LibroEntity\` sta in \`catalogo-service\` e ci resta: è il modo
  in cui il catalogo tiene i suoi dati, e nessun altro deve dipenderne. Se
  domani la tabella cambia, il DTO no. Il catalogo trasforma l'entity in DTO
  prima di rispondere: lo vedi nella [lezione sui
  controller](09-service-e-controller.md).
- **Le classi di un servizio solo.** \`PrestitoForm\`, i campi del form della
  pagina, lo usa solo \`biblioteca-ui\`, e sta lì. In \`common-dto\` va quello che
  attraversa la rete.
- **La logica.** Niente service, niente repository: solo la forma dei dati.

## Il vantaggio: gli errori arrivano quando compili

Se cambi \`LibroDto\` — aggiungi \`editore\`, togli \`isbn\` — chi lo usa non
compila più finché non lo sistemi. È molto meglio di un campo che arriva
\`null\` in silenzio durante la demo. Dopo aver cambiato un DTO:

\`\`\`bash
task compile
\`\`\`

ricompila tutti i moduli, \`common-dto\` compreso. Se un servizio acceso non vede
il campo nuovo, \`task dev\` lo riavvia da capo.

## In common-dto ci sono anche i dati di prova

In \`common-dto\` c'è un pacchetto che non devi toccare, \`devdata\`: è il codice
che all'avvio riempie le tabelle vuote e che legge lo schema per l'allegato
(\`task seed-data\` e \`task db-schema\`, nella [lezione sui dati di
prova](13-dati-e-schema.md)). Sta qui perché così arriva in ogni servizio senza
dipendenze in più, e si accende solo nei moduli che hanno un database.

> **Prova tu**
>
> Aggiungi a \`LibroDto\` un campo \`String editore\` e lancia \`task build\`. Leggi
> l'errore: ti dice esattamente dove il record viene costruito
> (\`CatalogoService.toDto\`). Poi togli il campo.

> **Fatto quando**
>
> - [ ] sai perché \`LibroDto\` sta in \`common-dto\` e \`LibroEntity\` no
> - [ ] sai dove mettere la classe del corpo di una POST che una pagina manda a un servizio
> - [ ] sai che cosa fare dopo aver cambiato un DTO
` },
    { file: 'corso/lezioni/05-macchina-e-rete.md', testo: `# La macchina e la rete

<!-- parte: A · Prima di cominciare | quando: la sera prima | durata: 30 minuti, quasi tutti di attesa | obiettivo: Il PC ha quello che serve, sai che cosa passa dalla rete dell'aula e hai già scaricato quello che potrebbe non passare. -->

Il giorno dell'esame non si installa niente e non si scopre niente: si
lavora. Tutto quello che può andare storto con la macchina deve andare storto
la sera prima, quando c'è tempo per rimediare.

## Gli attrezzi

| Che cosa | Perché | Come controlli |
| :--- | :--- | :--- |
| un JDK, dal 17 in su | Maven compila con quello; Spring Boot 4 vuole almeno il 17 | \`java -version\` |
| Docker Desktop | PostgreSQL e lo stack completo per la demo | \`docker info\` |
| go-task | i comandi \`task\` | \`task --version\` |
| un editor | VS Code con *Extension Pack for Java*, Zed con l'estensione *Java*, oppure IntelliJ | apri un file \`.java\` |

Maven non si installa: c'è il wrapper \`mvnw\` nel progetto, che si scarica da
solo la versione giusta. Il template nasce su Java 25; se sulla macchina
dell'esame c'è un altro JDK, il wizard allinea il progetto da solo
(\`task set-java\` a mano).

## La rete dell'esame: filtrata, non assente

All'esame la rete c'è, ma passa da una **whitelist** di domini. Maven Central
è fra quelli ammessi: le dipendenze Maven si scaricano come a casa, quindi
\`task add-dep\` e i moduli nuovi funzionano anche se ti serve una libreria che
non avevi previsto. Degli altri domini non si sa niente finché non ci provi.
Un comando ci prova per te, in pochi secondi, e non cambia niente:

\`\`\`bash
task rete
\`\`\`

\`\`\`text
LA RETE, DA QUESTA MACCHINA

  Maven Central        risponde       le dipendenze Maven: moduli nuovi, add-dep, il wrapper
  Docker Hub           NON risponde   le immagini di base: eclipse-temurin e postgres
  Ubuntu               NON risponde   curl dentro l'immagine, quando la cache di Docker non ce l'ha
  GitHub               risponde       git clone e le release del template
  VS Code Marketplace  NON risponde   le estensioni di VS Code

Quello che non passa, e cosa vuol dire:
  Docker Hub           le immagini devono essere gia' sul disco (task offline-prep, la sera prima)
  Ubuntu               docker compose build regge solo con la cache (task offline-prep)
  VS Code Marketplace  valgono solo le estensioni gia' installate
\`\`\`

(Un esempio: nell'aula vera le righe saranno le sue.) Qualunque risposta del
server, anche un «non autorizzato», vuol dire che il dominio passa; *NON
risponde* vuol dire che il filtro lo ferma, o che non c'è rete.

| Dominio | Che cosa ne dipende | Se non passa |
| :--- | :--- | :--- |
| Maven Central | le dipendenze nuove | si compila solo con quello che è già in \`~/.m2\` |
| Docker Hub | le immagini \`eclipse-temurin\` e \`postgres\` | servono quelle scaricate la sera prima |
| Ubuntu | \`curl\` dentro l'immagine, alla prima build | serve la cache di Docker della sera prima |
| GitHub | \`git clone\` | il template arriva dalla chiavetta |
| le estensioni degli editor | autocompletamento e debug | valgono quelle già installate |

## La sera prima: scaricare quello che potrebbe non passare

\`\`\`bash
task offline-prep
\`\`\`

Ci mette qualche minuto e fa tutto quello che il giorno dopo potrebbe servire
dalla rete:

1. scarica una copia del comando \`task\` stesso, dentro \`.tools/task\`: se sulla
   macchina dell'esame non c'è, o GitHub (il dominio che lo distribuisce) non
   passa dalla whitelist, l'hai già qui. Viaggia con la cartella del progetto,
   come tutto il resto: niente installer da portarsi dietro apposta;
2. scarica le dipendenze Maven del progetto e lo compila;
3. in una copia usa-e-getta crea con \`new-service\` un servizio con database e
   un'interfaccia, e li compila: così in \`~/.m2\` c'è anche quello che serve ai
   moduli che creerai all'esame (JPA, H2, PostgreSQL, Feign, Swagger,
   Thymeleaf);
4. scarica le immagini Docker di base;
5. fa una prima \`docker compose build\`, che riempie la cache dei livelli,
   compreso quello che installa \`curl\`.

Se il giorno dell'esame \`task\` non risponde (PATH diverso, macchina pulita),
\`task offline\` te lo segnala e \`scripts/usa-task-locale.ps1\` (o
\`usa-task-locale.sh\`) mette la copia locale sul PATH di quella sessione: va
lanciato col punto davanti (\`. .\\scripts\\usa-task-locale.ps1\`, o
\`source scripts/usa-task-locale.sh\`), altrimenti l'effetto sparisce subito.

Con \`ALL=1\` scarica anche tutto il catalogo di \`add-dep\` (security, kafka,
mongodb...): più lento, ma non resta niente di imprevisto. Poi controlla:

\`\`\`bash
task offline
\`\`\`

Deve finire con *Tutto pronto*. Dice anche se l'editor ha già quello che gli
serve: l'estensione Java di Zed scarica jdtls, Lombok e il debugger al primo
file \`.java\` che apri, quindi aprine uno **adesso**, con la rete.

## La chiavetta

Il template è la cartella: niente da installare. Portati:

| Che cosa | Perché |
| :--- | :--- |
| la cartella del progetto, \`.git\` compreso | è il template, e con \`.git\` torni indietro con \`git checkout .\` |
| la cartella \`~/.m2/repository\` | le dipendenze Maven, se Maven Central non dovesse passare |
| gli installatori del JDK e di Docker Desktop | solo se non sei sicuro della macchina (\`task\` non serve: c'è già in \`.tools/task\`) |

## Appena ti siedi

Quattro comandi, prima di leggere la traccia:

\`\`\`bash
task rete
\`\`\`

\`\`\`bash
task test
\`\`\`

\`\`\`bash
task dev
\`\`\`

\`\`\`bash
task dev-down
\`\`\`

\`task rete\` ti dice che cosa passa oggi. \`task test\` collauda gli strumenti su
una copia usa-e-getta del progetto (non tocca il tuo): se passa, sai che
\`new-service\`, \`add-dep\`, \`seed-data\` e gli altri funzionano su questa
macchina. \`task dev\` e \`task dev-down\` sono un giro a vuoto che scalda Maven e
libera le porte. Se falliscono, hai ancora tutto il tempo per capire perché.

> **Attenzione**
>
> Nei laboratori capita che la porta 5432 sia già di un PostgreSQL installato,
> o la 8080 di un'altra applicazione. Il wizard se ne accorge e propone
> un'altra porta; \`task status\` ti dice chi occupa che cosa.

> **Fatto quando**
>
> - [ ] \`java -version\`, \`docker info\` e \`task --version\` rispondono
> - [ ] hai letto che cosa dice \`task rete\` a casa tua
> - [ ] \`task offline-prep\` è finito e \`task offline\` dice *Tutto pronto*
> - [ ] hai aperto un file \`.java\` nell'editor, con la rete
> - [ ] \`task test\` passa
` },
    { file: 'corso/lezioni/06-leggere-la-traccia.md', testo: `# Leggere la traccia e disegnare i moduli

<!-- parte: B · Svolgere la traccia | quando: 08:30 | durata: 20 minuti | obiettivo: Dalla traccia della Biblioteca ricavi entità, servizi, porte, database, endpoint e algoritmo, e hai già scritto l'analisi che andrà nell'allegato. -->

I primi venti minuti non si scrive codice. Si legge la traccia con una matita
e si decide che cosa costruire: ogni minuto qui ne risparmia dieci dopo.

## La traccia

> **Biblioteca di quartiere**
>
> La biblioteca di quartiere vuole informatizzare il catalogo e i prestiti.
>
> 1. Il **catalogo** contiene i libri: titolo, codice ISBN di 13 cifre, anno
>    di pubblicazione, genere (romanzo, saggio, giallo, fantasy, storico),
>    autore (nome, cognome, nazionalità) e se il libro è disponibile.
> 2. Il servizio dei **prestiti** registra chi prende un libro (la sua email),
>    il giorno del prestito e la scadenza: di norma 30 giorni, al massimo 60.
>    Un libro già in prestito non si può prestare di nuovo.
> 3. Alla restituzione il libro torna disponibile. Per ogni giorno di ritardo
>    si paga una **penale** di 0,50 euro, fino a un massimo di 20 euro.
> 4. Un'**interfaccia web** mostra il catalogo e i prestiti, con il ritardo e
>    la penale, e permette di registrare un prestito e una restituzione.
> 5. I servizi si registrano su un **naming server Eureka** e si chiamano per
>    nome. Catalogo e prestiti hanno ognuno il proprio database PostgreSQL.
> 6. L'intero sistema parte con **Docker Compose**.
>
> Si consegnano i sorgenti, il \`docker-compose.yml\` e un allegato tecnico:
> analisi, schema del database, moduli e porte, l'algoritmo della penale,
> istruzioni per il collaudo. Seguono le domande teoriche A e B.

## Dal testo ai pezzi

Sottolinea i nomi (diventano dati), i verbi (diventano operazioni) e i
numeri (diventano regole):

| Nella traccia | Diventa |
| :--- | :--- |
| libri con titolo, ISBN, anno, genere, disponibilità | \`LibroEntity\` e l'enum \`Genere\`, in \`catalogo-service\` |
| l'autore con nome, cognome e nazionalità | \`AutoreEntity\`: molti libri, un autore |
| chi prende un libro, quando, la scadenza | \`PrestitoEntity\`, in \`prestiti-service\` |
| «30 giorni, al massimo 60» | un valore predefinito e \`@Min(1) @Max(60)\` sulla richiesta |
| «un libro già in prestito non si può prestare» | una regola nel service: si risponde **409 Conflict** |
| «alla restituzione torna disponibile» | \`prestiti-service\` avvisa il catalogo, via Feign |
| «0,50 euro al giorno, al massimo 20» | **l'algoritmo**: due funzioni e un test |
| un'interfaccia web | \`biblioteca-ui\`, con Thymeleaf |
| «ognuno il proprio database» | \`task use-postgres\`, con \`DBNAME=prestiti\` per il secondo |
| Eureka, Docker Compose | già nel template |

> 💡 **La catena dei comandi che trasforma questi pezzi in codice**:
> 1. \`task wizard\`: crea l'infrastruttura, \`catalogo-service\`, \`prestiti-service\` e \`biblioteca-ui\`;
> 2. \`task new-entity\`: genera \`LibroEntity\` e \`PrestitoEntity\` con repository, service e controller REST in un colpo solo;
> 3. \`task new-client\`: genera \`CatalogoClient\` per chiamare il catalogo da \`prestiti-service\` e \`biblioteca-ui\`;
> 4. \`task new-view\`: genera le pagine HTML Thymeleaf con form e tabelle;
> 5. \`task new-handler\` e \`task new-auth\`: mettono al sicuro errori di validazione e autenticazione;
> 6. \`task seed-data\` e \`task dev\`: popolano il database e avviano tutto lo stack a caldo!

## Chi possiede quali dati

La regola dei microservizi è semplice: **ogni servizio possiede le sue
tabelle**, e gli altri gliele chiedono. Il catalogo possiede libri e autori;
i prestiti possiedono i prestiti.

Ne segue una cosa che all'inizio sembra strana: \`PrestitoEntity\` non ha una
relazione con \`LibroEntity\`, ma solo un \`Long libroId\`. Le due tabelle stanno
in due database diversi, e una chiave esterna fra database diversi non esiste.
La coerenza la tiene il codice: prima di prestare, \`prestiti-service\` chiede
il libro al catalogo; dopo, gli dice di segnarlo come non disponibile.

## Moduli, porte, database

| Modulo | Porta | Nome su Eureka | Database | Chiama |
| :--- | ---: | :--- | :--- | :--- |
| \`naming-server\` | 8761 | \`eureka-server\` | — | — |
| \`catalogo-service\` | 8081 | \`CATALOGO-SERVICE\` | PostgreSQL \`biblioteca\` | — |
| \`prestiti-service\` | 8082 | \`PRESTITI-SERVICE\` | PostgreSQL \`prestiti\` | \`CATALOGO-SERVICE\` |
| \`biblioteca-ui\` | 8090 | \`BIBLIOTECA-UI\` | — | \`CATALOGO-SERVICE\`, \`PRESTITI-SERVICE\` |

L'interfaccia va sulla 8090 e non sulla 8080: la 8080 è la prima porta che
trovi occupata da qualcos'altro. Un solo container PostgreSQL basta per tutti e
due i database.

## Gli endpoint

| Metodo | Percorso | Servizio | Risponde |
| :--- | :--- | :--- | :--- |
| GET | \`/api/libri\` | catalogo | 200 e l'elenco |
| GET | \`/api/libri/disponibili\` | catalogo | 200 e l'elenco |
| GET | \`/api/libri/{id}\` | catalogo | 200, 404 |
| PUT | \`/api/libri/{id}/disponibilita?disponibile=false\` | catalogo | 200, 404 |
| GET | \`/api/prestiti\` | prestiti | 200, con ritardo e penale calcolati a oggi |
| POST | \`/api/prestiti\` | prestiti | 201; 400 dati non validi; 404 libro inesistente; 409 già in prestito |
| PUT | \`/api/prestiti/{id}/restituzione\` | prestiti | 200; 404; 409 se è già chiuso |

Scriverli prima di cominciare vuol dire che i codici di risposta li decidi una
volta, e non a metà di un metodo.

## Scrivi subito l'analisi

L'allegato vale 8 punti, e metà si scrive adesso che la traccia è fresca. Le
parti che scrivi tu stanno in un file del progetto, \`allegato.md\`, diviso in
sezioni col titolo \`##\`:

\`\`\`markdown allegato.md
## Analisi

La biblioteca di quartiere vuole informatizzare catalogo e prestiti: il
bibliotecario consulta i libri, registra chi ne prende uno e quando lo
riporta, e il sistema calcola la penale per i ritardi.

## Algoritmo

Per ogni prestito si calcola il ritardo come ...

## catalogo-service

Tiene i libri e gli autori, e dice agli altri se un libro e' disponibile.
\`\`\`

- **Analisi**: il problema in cinque righe, che cosa fa il sistema e per chi;
- **Algoritmo**: la formula della penale, a parole e in simboli (la
  [lezione sull'algoritmo](11-algoritmo.md) ti dà il testo);
- **una sezione per modulo**, col nome del modulo come titolo: una o due righe
  su che cosa fa.

Se il file non c'è, lo crea la prima \`task consegna\` con tutti i titoli
pronti; puoi anche scriverlo tu adesso. Alla fine \`task consegna\` prende ogni
sezione e la mette al suo posto in \`ALLEGATO-TECNICO.md\`, accanto a moduli,
porte, endpoint e schema che ricava dal progetto. \`task learn\` lo mostra anche
dentro questo corso, fra le guide.

> **Prova tu**
>
> Fai la stessa analisi con la traccia del magazzino WMS (nella [Guida
> 2](../../guida_prova_finale_spring_boot.md), paragrafo 7): entità, servizi,
> chi possiede che cosa, l'algoritmo. Poi confrontala con la soluzione, nel
> branch \`solution/wms\`.

> **Fatto quando**
>
> - [ ] hai la tabella dei moduli con porte, nomi Eureka e database
> - [ ] hai la tabella degli endpoint con i codici di risposta
> - [ ] sai perché \`PrestitoEntity\` tiene solo \`libroId\`
> - [ ] l'analisi e la formula della penale sono scritte in un file
` },
    { file: 'corso/lezioni/07-montare-il-progetto.md', testo: `# Montare il progetto

<!-- parte: B · Svolgere la traccia | quando: 08:50 | durata: 15 minuti | obiettivo: I tre moduli della Biblioteca esistono, sono collegati a pom, Dockerfile, compose, avvio ed editor, e rispondono. -->

Deciso che cosa costruire, lo scheletro si monta in un quarto d'ora: nessun
file si scrive a mano.

## Con il wizard

\`\`\`bash
task wizard
\`\`\`

Per prima cosa allinea Java al JDK della macchina, poi fa le domande. Per la
Biblioteca:

| Domanda | Risposta |
| :--- | :--- |
| come si chiama la cartella dei moduli | Invio: resta \`demo\` |
| il pacchetto Java di base | Invio: resta \`esame\` |
| il progetto usa PostgreSQL? | sì: database \`biblioteca\`, utente \`bib\`, password \`bib2026\`, porta 5432 |
| primo servizio | \`catalogo-service\`: REST con database, porta proposta (8081), PostgreSQL condiviso |
| secondo servizio | \`prestiti-service\`: REST con database, porta proposta (8082), un database suo (\`prestiti\`) |
| terzo servizio | \`biblioteca-ui\`: interfaccia Thymeleaf, porta 8090 |
| quarto servizio | Invio per finire |

Alla fine lancia \`task check\`. Il wizard non fa niente di magico: chiama gli
stessi comandi che puoi dare a mano, nell'ordine giusto.

## Oppure, un comando alla volta (anche interattivi!)

Puoi passare le variabili sulla riga di comando oppure lanciare qualsiasi comando **senza argomenti** (es. \`task new-service\`, \`task use-postgres\`): si aprirà un wizard interattivo con elenchi numerati tra cui scegliere e default intelligenti.

Sono i comandi con cui è stato montato il branch \`example/biblioteca\`:

\`\`\`bash
task db-config DBNAME=biblioteca USER=bib PASSWORD=bib2026
task new-service NAME=catalogo-service
task use-postgres SERVICE=catalogo-service
task new-service NAME=prestiti-service
task use-postgres SERVICE=prestiti-service DBNAME=prestiti
task new-service NAME=biblioteca-ui UI=1 PORT=8090
task check
\`\`\`

| Comando | Che cosa fa |
| :--- | :--- |
| \`db-config\` | nome, utente e password del PostgreSQL del compose, dappertutto |
| \`new-service\` | il modulo, e le righe in pom, Dockerfile, compose, lista di avvio ed editor |
| \`use-postgres\` | sposta un modulo da H2 in memoria al PostgreSQL del compose |
| \`use-postgres ... DBNAME=\` | come sopra, ma con un database tutto suo nello stesso container |
| \`new-service ... UI=1\` | un modulo Thymeleaf con un controller e una pagina |
| \`check\` | i sei posti dicono la stessa cosa? |

## Che cosa è cambiato

\`git status\` dopo quei comandi:

\`\`\`text
 M .vscode/launch.json
 M .zed/debug.json
 M demo/Dockerfile
 M demo/docker-compose.yml
 M demo/pom.xml
 M scripts/dev.ps1
 M scripts/dev.sh
?? demo/biblioteca-ui/
?? demo/catalogo-service/
?? demo/postgres-init/
?? demo/prestiti-service/
\`\`\`

Il blocco di \`prestiti-service\` nel compose, scritto da \`new-service\` e
completato da \`use-postgres\`:

\`\`\`yaml demo/docker-compose.yml
  prestiti-service:
    build:
      context: .
      args:
        MODULE: prestiti-service
    environment:
      PRESTITI_DB_URL: jdbc:postgresql://postgres:5432/prestiti
      PRESTITI_DB_USERNAME: bib
      PRESTITI_DB_PASSWORD: bib2026
      PRESTITI_DB_DRIVER: org.postgresql.Driver
      SERVER_PORT: 8082
      EUREKA_SERVER_URL: http://eureka-server:8761/eureka/
    ports:
      - "8082:8082"
    depends_on:
      postgres:
        condition: service_healthy
      eureka-server:
        condition: service_healthy
\`\`\`

E lo script che crea il secondo database, che PostgreSQL esegue la prima volta
che parte:

\`\`\`sql demo/postgres-init/create-prestiti.sql
-- Creato da task use-postgres: un database per il modulo prestiti-service.
CREATE DATABASE prestiti;
GRANT ALL PRIVILEGES ON DATABASE prestiti TO bib;
\`\`\`

> **Attenzione**
>
> PostgreSQL esegue gli script di \`postgres-init/\` e crea utente e database
> **solo quando il suo volume è vuoto**. Se il container era già partito prima
> di \`db-config\` o di \`use-postgres ... DBNAME=\`, serve una volta
> \`task docker-reset\`, che cancella i dati.

## Accendere tutto

\`\`\`bash
task dev
\`\`\`

Libera le porte, compila, avvia PostgreSQL in Docker, Eureka e poi i servizi,
in background. Alla fine stampa gli indirizzi. Per ora ogni servizio REST ha
solo l'endpoint di prova, che cancellerai quando scrivi il controller vero:

\`\`\`bash
curl http://localhost:8081/api/ping
\`\`\`

In un secondo terminale:

\`\`\`bash
task logs SERVICE=catalogo
\`\`\`

I nomi brevi (\`eureka\`, \`catalogo\`, \`prestiti\`, \`biblioteca-ui\`) sono quelli
che stampa \`task status\`. Da qui in poi il ciclo è: scrivi, \`task compile\`, il
servizio riparte da solo in qualche secondo.

## Cosa fare subito dopo aver montato il progetto

Una volta che i moduli esistono e \`task check\` dice *Tutto coerente*, non devi scrivere a mano il codice ripetitivo:

| Cosa vuoi creare | Comando dedicato | Cosa fa |
| :--- | :--- | :--- |
| Tabella, Entity, Repository, Service e Controller REST | \`task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=...\` | Genera le 4 classi canoniche con CRUD completo e Swagger |
| DTO condiviso e Feign Client | \`task new-client FROM=biblioteca-ui TO=catalogo-service DTO=LibroDto FIELDS=...\` | Crea \`LibroDto\` in \`common-dto\` e l'interfaccia \`@FeignClient\` in un solo comando |
| Pagine e form Thymeleaf | \`task new-view SERVICE=biblioteca-ui NAME=Libri FIELDS=...\` | Genera \`LibriController\` e il template \`libri.html\` con tabella e form |
| Gestione errori globale REST | \`task new-handler SERVICE=catalogo-service\` | Genera \`@RestControllerAdvice\` per formattare gli errori \`@Valid\` in JSON |
| Autenticazione e Sicurezza | \`task new-auth SERVICE=catalogo-service TYPE=db\` | Configura Spring Security (utenti su DB con BCrypt, oppure Form per UI) |

## Se la traccia cambia a metà

| Serve | Comando |
| :--- | :--- |
| un servizio in più | \`task wizard SERVICE=notifiche-service\` |
| una libreria | \`task add-dep SERVICE=prestiti-service DEPS=mail\` |
| un'altra porta | \`task set-port SERVICE=biblioteca-ui PORT=9090\` |
| togliere un servizio | \`task remove-service SERVICE=notifiche-service\` |

Dopo un modulo o una dipendenza nuova ci vuole \`task dev\`, non
\`task compile\`: il classpath di un servizio si fissa quando parte.

> **Fatto quando**
>
> - [ ] \`task check\` dice *Tutto coerente*
> - [ ] \`task dev\` avvia tutto e \`task status\` mostra i tre servizi su Eureka
> - [ ] \`http://localhost:8081/api/ping\` risponde
> - [ ] sai quando serve \`task docker-reset\` e perché cancella i dati
` },
    { file: 'corso/lezioni/08-entity-e-repository.md', testo: `# Le entity e i repository

<!-- parte: B · Svolgere la traccia | quando: 09:05 | durata: 55 minuti | obiettivo: Scrivi le classi @Entity della traccia e i loro repository, e sai che cosa diventa ogni annotazione e ogni parola chiave del nome del metodo nel database. -->

Un'entity è una classe Java che Hibernate trasforma in una tabella: un campo,
una colonna; un oggetto, una riga. Il repository è l'interfaccia con cui la
leggi e la scrivi, senza scrivere SQL.

## Dove vanno

\`\`\`text
demo/catalogo-service/src/main/java/esame/catalogoservice/
├── Main.java
├── entity/        AutoreEntity, LibroEntity, Genere
├── repository/    LibroRepository
├── service/       CatalogoService
└── controller/    LibroController
\`\`\`

Spring trova da solo tutto quello che sta sotto il pacchetto di \`Main\`: i
sottopacchetti sono un ordine per te, non una configurazione.

## Generare tutto in 5 secondi: \`task new-entity\`

Invece di creare a mano classi, costruttori, annotazioni e interfacce, hai a disposizione il task di scaffolding completo:

\`\`\`bash
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,isbn:string(13):required:unique,annoPubblicazione:int,disponibile:bool
\`\`\`

> 💡 **Modalità Interattiva**: se non ricordi i parametri a memoria, puoi anche lanciare semplicemente \`task new-entity\` senza argomenti. Un wizard ti chiederà a quale modulo applicarlo, il nome dell'entità, i campi e se desideri generare anche il DTO!

In un solo colpo questo comando genera quattro file sincronizzati:
1. **\`entity/LibroEntity.java\`**: classe \`@Entity\` con \`@Table(name = "libri")\`, chiave \`@Id @GeneratedValue\`, campi con annotazioni di validazione (\`@NotBlank\`, \`@NotNull\`, ecc.) e getter/setter Lombok.
2. **\`repository/LibroRepository.java\`**: interfaccia \`JpaRepository<LibroEntity, Long>\` pronta con tutti i metodi CRUD.
3. **\`service/LibroService.java\`**: classe \`@Service\` con metodi operativi completi (\`tutti()\`, \`perId()\`, \`crea()\`, \`aggiorna()\`, \`elimina()\`).
4. **\`controller/LibroController.java\`**: \`@RestController\` mappato su \`/api/libri\` con documentazione OpenAPI Swagger (\`@Tag\`, \`@Operation\`), \`@GetMapping\`, \`@PostMapping\`, \`@PutMapping\`, \`@DeleteMapping\` e validazione \`@Valid\`.

### I tipi e i modificatori ammessi in \`FIELDS=\`

| Sintassi | Tipo Java | Colonna DB / Validazione |
| :--- | :--- | :--- |
| \`nome:string\` | \`String\` | \`VARCHAR(255)\` |
| \`nome:string(150)\` | \`String\` | \`VARCHAR(150)\` + \`@Size(max=150)\` |
| \`nome:int\` o \`nome:integer\` | \`Integer\` | \`INTEGER\` |
| \`nome:long\` | \`Long\` | \`BIGINT\` |
| \`nome:decimal\` | \`BigDecimal\` | \`NUMERIC(12,2)\` |
| \`nome:bool\` o \`nome:boolean\` | \`Boolean\` | \`BOOLEAN\` |
| \`nome:date\` | \`LocalDate\` | \`DATE\` |
| \`nome:datetime\` | \`LocalDateTime\` | \`TIMESTAMP\` |
| \`nome:email\` | \`String\` | \`@Email\` + \`VARCHAR(255)\` |
| \`nome:text\` | \`String\` | \`@Lob\` (\`TEXT\`) |
| \`:required\` | vincolo | \`@NotNull\` / \`@NotBlank\` + \`nullable = false\` |
| \`:unique\` | vincolo | \`unique = true\` sul database |

### Generazione automatica con DTO (\`DTO=1\`)

Se aggiungi \`DTO=1\`:
\`\`\`bash
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,prezzo:decimal,disponibile:bool DTO=1
\`\`\`
Il comando:
1. Crea automaticamente il record immutabile \`LibroDto\` in \`common-dto\` con tutte le validazioni.
2. Genera in \`LibroService\` i metodi mapper statici \`toDto(entity)\` e \`toEntity(dto)\`.
3. Modifica \`LibroController\` in modo che riceva e restituisca \`LibroDto\` invece dell'Entity. In questo modo rispetti alla lettera la best practice "fuori dal service esce solo il DTO" ed eviti per sempre i loop di serializzazione Jackson con le relazioni bidirezionali!

Dopo aver lanciato il comando, puoi aprire i file per aggiungere relazioni (\`@ManyToOne\`, \`@OneToMany\`), campi speciali (enum) o metodi di ricerca nel repository come vediamo qui sotto.

## Un'entity

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/entity/LibroEntity.java
@Entity
@Table(name = "libri")
@Getter
@Setter
@NoArgsConstructor
public class LibroEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String titolo;

    // ISBN-13: tredici cifre che cominciano con 978 o 979.
    @Pattern(regexp = "97[89][0-9]{10}")
    @Column(nullable = false, unique = true, length = 13)
    private String isbn;

    @Min(1450)
    @Max(2100)
    private Integer annoPubblicazione;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private Genere genere;

    @Column(nullable = false)
    private Boolean disponibile;

    // Molti libri, un autore: la colonna autore_id sta nella tabella libri.
    @ManyToOne(optional = false)
    @JoinColumn(name = "autore_id", nullable = false)
    private AutoreEntity autore;
}
\`\`\`

E che cosa ne fa Hibernate. Questa tabella è l'uscita vera di
\`task db-schema\` sul branch della Biblioteca:

| Colonna | Tipo | Chiave | Null | Note |
| :--- | :--- | :---: | :---: | :--- |
| \`id\` | BIGINT | PK | no | generato dal database (identity) |
| \`titolo\` | VARCHAR(150) |  | no |  |
| \`isbn\` | VARCHAR(13) |  | no | univoco |
| \`anno_pubblicazione\` | INTEGER |  | sì | da 1450 a 2100 |
| \`genere\` | VARCHAR(20) |  | sì | valori ammessi: ROMANZO, SAGGIO, GIALLO, FANTASY, STORICO |
| \`disponibile\` | BOOLEAN |  | no |  |
| \`autore_id\` | BIGINT | FK | no | riferimento a \`autori\`(\`id\`) |

| Annotazione | Che cosa fa |
| :--- | :--- |
| \`@Entity\`, \`@Table(name = "libri")\` | la classe è una tabella, e si chiama \`libri\` |
| \`@Id\`, \`@GeneratedValue(strategy = IDENTITY)\` | chiave primaria, numerata dal database |
| \`@Column(nullable = false, length = 150)\` | \`NOT NULL\`, \`VARCHAR(150)\` |
| \`unique = true\` | un vincolo di unicità |
| \`@Min\`, \`@Max\`, \`@Pattern\` | validazione: Hibernate la controlla prima di salvare, e per \`@Min\`/\`@Max\` mette anche un CHECK |
| \`@Enumerated(EnumType.STRING)\` | l'enum si salva col nome (\`GIALLO\`), non col numero |
| \`@ManyToOne\` + \`@JoinColumn\` | la chiave esterna \`autore_id\` verso \`autori\` |

I nomi dei campi diventano colonne in minuscolo con i trattini bassi:
\`annoPubblicazione\` diventa \`anno_pubblicazione\`.

## L'enum, e perché come stringa

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/entity/Genere.java
public enum Genere {
    ROMANZO,
    SAGGIO,
    GIALLO,
    FANTASY,
    STORICO
}
\`\`\`

Senza \`@Enumerated(EnumType.STRING)\` Hibernate salverebbe la posizione:
\`GIALLO\` = 2. Basta aggiungere un genere in mezzo e tutti i dati già salvati
cambiano significato. Con \`STRING\` si salva il nome, e l'ordine non conta.

## Le relazioni tra tabelle (nello stesso modulo)

All'interno dello **stesso modulo**, le tabelle risiedono nello stesso database.
JPA supporta tutte le cardinalità: ecco come si scrivono e le regole per non
sbagliare.

### 1. Many-to-One e One-to-Many (la più frequente all'esame)

Tanti libri hanno un solo autore (\`@ManyToOne\`); un autore ha una collezione di
libri (\`@OneToMany\`). La colonna della chiave esterna (\`autore_id\`) sta
**sempre** nella tabella del lato *Molti* (\`libri\`).

**Lato proprietario (\`LibroEntity\`, dove sta la chiave esterna):**

\`\`\`java
@ManyToOne(fetch = FetchType.LAZY, optional = false)
@JoinColumn(name = "autore_id", nullable = false)
private AutoreEntity autore;
\`\`\`

**Lato inverso (\`AutoreEntity\`, opzionale: aggiungilo solo se ti serve):**

\`\`\`java
@OneToMany(mappedBy = "autore", cascade = CascadeType.ALL, orphanRemoval = true)
private List<LibroEntity> libri = new ArrayList<>();
\`\`\`

- \`mappedBy = "autore"\` indica il nome del campo Java nella classe \`LibroEntity\`.
- \`cascade = CascadeType.ALL\`: salvando o cancellando l'autore, si sincronizzano anche i suoi libri.
- \`orphanRemoval = true\`: se togli un libro dalla lista \`libri\`, Hibernate lo elimina dalla tabella.

### 2. Many-to-Many (Molti a Molti)

Tanti studenti seguono molti corsi; ogni corso ha molti studenti. Hibernate crea
automaticamente la tabella di giunzione ponte (\`studenti_corsi\`).

**Lato proprietario (\`StudenteEntity\`):**

\`\`\`java
@ManyToMany(fetch = FetchType.LAZY)
@JoinTable(
    name = "studenti_corsi",
    joinColumns = @JoinColumn(name = "studente_id"),
    inverseJoinColumns = @JoinColumn(name = "corso_id")
)
private Set<CorsoEntity> corsi = new HashSet<>();
\`\`\`

**Lato inverso (\`CorsoEntity\`):**

\`\`\`java
@ManyToMany(mappedBy = "corsi", fetch = FetchType.LAZY)
private Set<StudenteEntity> studenti = new HashSet<>();
\`\`\`

> 💡 **Regola d'oro d'esame per Many-to-Many**: Se la relazione ha **dati propri**
> (es. \`dataIscrizione\`, \`votoEsame\`), **non** usare \`@ManyToMany\` semplice!
> Crea un'entità intermedia \`IscrizioneEntity\` che ha due \`@ManyToOne\`:
> uno verso \`StudenteEntity\` e uno verso \`CorsoEntity\`.

### 3. One-to-One (Uno a Uno)

Un utente ha un solo profilo/tessera. La chiave esterna (\`tessera_id\`) sta
in una delle due tabelle (es. \`utenti\`), con vincolo di unicità \`unique = true\`:

\`\`\`java
// In UtenteEntity (lato che detiene la foreign key tessera_id)
@OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
@JoinColumn(name = "tessera_id", unique = true)
private TesseraEntity tessera;
\`\`\`

\`\`\`java
// In TesseraEntity (lato inverso, opzionale)
@OneToOne(mappedBy = "tessera", fetch = FetchType.LAZY)
private UtenteEntity utente;
\`\`\`

### Le 4 trappole da evitare all'esame

1. **Usa sempre \`fetch = FetchType.LAZY\`**: di default \`@ManyToOne\` e \`@OneToOne\`
   usano \`EAGER\`, caricando a cascata decine di record non richiesti.
2. **Inizializza sempre le collezioni**: \`= new ArrayList<>()\` o \`= new HashSet<>()\`,
   altrimenti rischi \`NullPointerException\`.
3. **MAI \`@Data\` di Lombok sulle entity con relazioni**: genera in automatico
   \`toString()\`, \`equals()\` e \`hashCode()\` ricorsivi. Con relazioni bidirezionali,
   \`toString()\` entra in un loop infinito che fa esplodere la JVM con \`StackOverflowError\`.
   Usa solo \`@Getter\`, \`@Setter\`, \`@NoArgsConstructor\`.
4. **Evita il loop JSON Jackson**: se serializzi un'entity con relazione bidirezionale,
   Jackson va in loop infinito. La soluzione pulita è **restituire sempre DTO** dai
   controller (usa \`DTO=1\` in \`task new-entity\`!).

### Configurare le relazioni in 5 secondi: \`task add-relation\`

Invece di scrivere annotazioni, chiavi esterne e collezioni inverse a mano col rischio di dimenticare \`fetch = FetchType.LAZY\`, \`mappedBy\`, o gli import:

\`\`\`bash
task add-relation SERVICE=catalogo-service FROM=Libro TO=Autore TYPE=many-to-one
\`\`\`

Oppure lancialo **senza argomenti**:
\`\`\`bash
task add-relation
\`\`\`
Si aprirà una comoda procedura guidata nel terminale: ti chiederà in quale microservizio vuoi operare, elencherà tutte le entità rilevate e ti farà scegliere il tipo di relazione desiderata (\`many-to-one\`, \`one-to-many\`, \`one-to-one\`, \`many-to-many\`).

Cosa fa per te:
- Inserisce l'annotazione corretta con \`fetch = FetchType.LAZY\`.
- Configura \`@JoinColumn(name = "autore_id")\` sul lato proprietario.
- Configura il lato inverso con \`mappedBy\` e lista già inizializzata (\`= new ArrayList<>()\`).
- Aggiunge automaticamente tutti gli \`import\` necessari (\`jakarta.persistence.*\`, \`java.util.List\`, ecc.).
- Con \`UNIDIRECTIONAL=1\` evita di aggiungere il campo inverso se ti serve unidirezionale.

---

## Fra due servizi, niente relazioni nel database

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/entity/PrestitoEntity.java
// Il libro vive in un altro servizio, con il suo database: qui se ne tiene
// solo l'id. Niente chiave esterna, perche' la tabella libri non e' qui.
@Entity
@Table(name = "prestiti")
@Getter
@Setter
@NoArgsConstructor
public class PrestitoEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long libroId;

    @Email
    @Column(nullable = false, length = 120)
    private String utenteEmail;

    @Column(nullable = false)
    private LocalDate dataPrestito;

    @Column(nullable = false)
    private LocalDate dataScadenza;

    private LocalDate dataRestituzione;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StatoPrestito stato;
}
\`\`\`

\`LocalDate\` diventa \`DATE\`: per le date senza ora è il tipo giusto, e con
\`ChronoUnit.DAYS.between\` si contano i giorni senza pensieri.

## I repository

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {

    // Spring Data scrive la query dal nome: ... WHERE disponibile = true
    List<LibroEntity> findByDisponibileTrue();
}
\`\`\`

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/repository/PrestitoRepository.java
public interface PrestitoRepository extends JpaRepository<PrestitoEntity, Long> {

    // ... WHERE libro_id = ? AND stato = ?, e dice solo se c'e' almeno una riga.
    boolean existsByLibroIdAndStato(Long libroId, StatoPrestito stato);
}
\`\`\`

\`JpaRepository<LibroEntity, Long>\` ti dà già, senza scrivere niente:
\`findAll()\`, \`findById(Long)\` (torna un \`Optional\`), \`save(entity)\` (inserisce
o aggiorna, decide lui guardando l'\`id\`), \`deleteById(Long)\`, \`count()\`,
\`existsById(Long)\`. Il resto — quello specifico della tua traccia — si scrive
da solo nel nome del metodo: Spring Data lo legge e costruisce la query.

## Il nome del metodo è la query: tutte le parole chiave

Lo schema è \`<verbo><NomeCampo><Condizione>And/Or<AltroCampo>...\`. Il verbo
decide che cosa torna, il resto la clausola \`WHERE\`. Il campo si scrive come
in Java (\`autore.cognome\` diventa \`AutoreCognome\`, e Spring fa la \`JOIN\` da
solo).

| Verbo | Torna | Esempio |
| :--- | :--- | :--- |
| \`findBy...\` / \`getBy...\` / \`queryBy...\` | \`List<T>\` (o un solo \`T\`/\`Optional<T>\` se il campo è unico) | \`findByIsbn(String isbn)\` → \`Optional<LibroEntity>\` |
| \`existsBy...\` | \`boolean\` | \`existsByIsbn(String isbn)\` |
| \`countBy...\` | \`long\` | \`countByGenere(Genere g)\` |
| \`deleteBy...\` / \`removeBy...\` | \`void\` o \`long\` (righe cancellate) | \`deleteByDisponibileFalse()\` |

| Condizione nel nome | \`WHERE\` generato | Esempio |
| :--- | :--- | :--- |
| \`findByGenere(Genere g)\` | \`genere = ?\` | uguaglianza semplice |
| \`findByGenereAndDisponibileTrue(Genere g)\` | \`genere = ? AND disponibile = true\` | \`And\`/\`Or\` fra più campi |
| \`findByAnnoPubblicazioneGreaterThan(int a)\` | \`anno_pubblicazione > ?\` | anche \`GreaterThanEqual\`, \`LessThan\`, \`LessThanEqual\` |
| \`findByAnnoPubblicazioneBetween(int da, int a)\` | \`anno_pubblicazione BETWEEN ? AND ?\` | due parametri, in ordine |
| \`findByTitoloContainingIgnoreCase(String t)\` | \`lower(titolo) LIKE lower('%'+?+'%')\` | anche \`StartingWith\`, \`EndingWith\` |
| \`findByTitoloIsNull()\` / \`IsNotNull()\` | \`titolo IS NULL\` / \`IS NOT NULL\` | senza parametri |
| \`findByGenereIn(List<Genere> generi)\` | \`genere IN (...)\` | anche \`NotIn\` |
| \`findByDisponibileTrue()\` / \`False()\` | \`disponibile = true\` / \`= false\` | scorciatoia per i booleani, meglio di \`Is(true)\` |
| \`findByGenereNot(Genere g)\` | \`genere <> ?\` | negazione |
| \`findByAutoreCognome(String c)\` | \`JOIN autori ON ... WHERE cognome = ?\` | attraversa la relazione \`@ManyToOne\` |
| \`findByOrderByAnnoPubblicazioneDesc()\` | \`ORDER BY anno_pubblicazione DESC\` | anche senza condizione, solo ordinamento |
| \`findTop5ByOrderByAnnoPubblicazioneDesc()\` | \`ORDER BY ... DESC LIMIT 5\` | \`Top3\`, \`First10\`... |
| \`findDistinctByGenere(Genere g)\` | \`SELECT DISTINCT ...\` | toglie i duplicati |

Si combinano: \`findTop10ByGenereAndDisponibileTrueOrderByAnnoPubblicazioneDesc(Genere g)\`
è lungo da leggere ma resta un metodo solo, senza una riga di SQL.

## Un solo risultato che potrebbe non esserci: \`Optional\`

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {
    Optional<LibroEntity> findByIsbn(String isbn);
}
\`\`\`

Nel service, non si controlla mai un \`null\` a mano: si sceglie che cosa fare
quando manca, nello stesso punto in cui si legge.

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/service/CatalogoService.java
public LibroDto trovaPerIsbn(String isbn) {
    LibroEntity libro = libroRepository.findByIsbn(isbn)
            .orElseThrow(() -> new LibroNonTrovatoException(isbn));   // -> 404, vedi lezione 9
    return toDto(libro);
}
\`\`\`

\`findById\` di \`JpaRepository\` torna \`Optional<LibroEntity>\` per lo stesso
motivo: un id che non esiste più non è un errore di Java, è un caso normale
da gestire.

## Ordinare e paginare senza scriverlo nel nome

Per un ordinamento deciso a runtime (non fisso come \`OrderByTitoloAsc\`) si
passa un \`Sort\`; per una lista lunga, invece di tornare tutto, si passa un
\`Pageable\` e si torna una \`Page<T>\`, che porta con sé anche il totale delle
righe:

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {
    List<LibroEntity> findByGenere(Genere genere, Sort sort);
    Page<LibroEntity> findByDisponibileTrue(Pageable pageable);
}
\`\`\`

\`\`\`java
libroRepository.findByGenere(Genere.GIALLO, Sort.by("titolo").ascending());
Page<LibroEntity> pagina = libroRepository.findByDisponibileTrue(PageRequest.of(0, 20));
pagina.getContent();        // i 20 elementi
pagina.getTotalElements();  // quanti sono in tutto, non solo in questa pagina
\`\`\`

Per una traccia d'esame, quasi sempre basta \`List\` senza paginazione: usala
solo se il numero di righe è dichiaratamente grande.

## Quando il nome non basta: \`@Query\`

Un \`JOIN\` con più condizioni, un \`GROUP BY\`, o solo un nome che diventerebbe
illeggibile: si scrive la query a mano, in **JPQL** (si ragiona su classi e
campi Java, non su tabelle e colonne — niente \`libri\`, \`LibroEntity\`; niente
\`anno_pubblicazione\`, \`annoPubblicazione\`):

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {

    @Query("select l from LibroEntity l where l.autore.cognome = :cognome and l.disponibile = true")
    List<LibroEntity> disponibiliDiUnAutore(@Param("cognome") String cognome);

    // native = true: SQL vero, per quando serve una funzione del database
    // che JPQL non ha (qui, il conteggio per genere).
    @Query(value = "select genere, count(*) from libri group by genere", nativeQuery = true)
    List<Object[]> conteggioPerGenere();
}
\`\`\`

\`@Param("cognome")\` collega il segnaposto \`:cognome\` nella query al parametro
del metodo — il nome deve combaciare. Una query nativa torna righe grezze
(\`Object[]\`, o una proiezione con un'interfaccia), non entity: usala solo
quando JPQL davvero non basta.

Una query che **scrive** (\`UPDATE\`/\`DELETE\` in JPQL) vuole in più
\`@Modifying\` e va chiamata dentro una transazione:

\`\`\`java
@Modifying
@Transactional
@Query("update LibroEntity l set l.disponibile = false where l.id = :id")
void segnaNonDisponibile(@Param("id") Long id);
\`\`\`

Per una traccia d'esame è raro servirne una: quasi sempre basta caricare
l'entity col repository, cambiarne un campo col setter, e richiamare \`save\`
(Hibernate si accorge da solo che è un update, non un insert, perché l'\`id\`
c'è già).

## Paura dell'autocompletamento nell'editor? Le 3 strategie a prova di bomba

Negli editor (come Zed, VS Code o IntelliJ), il Language Server Java suggerisce immediatamente tutti i metodi standard di \`JpaRepository\`:
- \`findAll()\`, \`findById(id)\`, \`save(entity)\` (fa sia \`INSERT\` che \`UPDATE\`), \`deleteById(id)\`, \`existsById(id)\`, \`count()\`. Nel 90% delle tracce d'esame questi metodi predefiniti bastano per coprire l'intero CRUD!

Tuttavia, quando vuoi scrivere un metodo di ricerca personalizzato (es. \`findByTitoloContainingIgnoreCase\`), l'editor spesso **non può suggerirlo in anticipo** con l'autocompletamento, perché in Spring Data i *derived query methods* vengono sintetizzati a runtime da Spring via proxy dinamico.

Se all'esame ti viene il dubbio sulla sintassi esatta, hai tre strategie infallibili:

### Strategia 1: La formula mnemonica del nome
La regola è sempre lineare:
\`\`\`text
findBy + <NomeCampoJava> + [Condizione] + [And/Or + AltroCampo]
\`\`\`
- Uguaglianza: \`findByGenere(Genere g)\`
- Testo parziale: \`findByTitoloContainingIgnoreCase(String testo)\`
- Confronto numerico: \`findByPrezzoLessThan(BigDecimal max)\`
- Combinazione: \`findByPrezzoLessThanAndDisponibileTrue(BigDecimal max)\`
- Esistenza rapida: \`existsByCodice(String codice)\`

### Strategia 2: La query a mano con \`@Query\` (Il salvagente definitivo)
Non perdere tempo a indovinare il nome del metodo! Dai al metodo il nome che preferisci tu e scrivi la query sopra l'interfaccia:
- **In JPQL (oggetti Java)**: usi il nome della classe Entity e dei suoi campi Java:
  \`\`\`java
  @Query("SELECT l FROM LibroEntity l WHERE l.prezzo <= :max AND l.disponibile = true")
  List<LibroEntity> trovaEconomici(@Param("max") BigDecimal max);
  \`\`\`
- **In SQL Nativo (\`nativeQuery = true\`)**: usi il normalissimo SQL del database (nomi di tabelle e colonne SQL reali):
  \`\`\`java
  @Query(value = "SELECT * FROM libri WHERE prezzo <= :max AND disponibile = true", nativeQuery = true)
  List<LibroEntity> trovaEconomiciSql(@Param("max") BigDecimal max);
  \`\`\`
  Con \`nativeQuery = true\` scrivi la query SQL esattamente come la testeresti in DBeaver o nella console di PostgreSQL.

### Strategia 3: Il cheat sheet offline con \`task learn\`
Il giorno dell'esame lancia \`task learn\` in un terminale: si aprirà questa guida nel browser **completamente offline e senza connessione**. Puoi consultare la tabella delle parole chiave in qualsiasi momento e fare copia-incolla delle firme.

## Chi crea le tabelle

Nessuno le scrive: le crea Hibernate all'avvio, leggendo le entity, perché
l'\`application.yml\` generato dice

\`\`\`yaml demo/catalogo-service/src/main/resources/application.yml
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true
\`\`\`

\`update\` crea quello che manca e non cancella niente; \`show-sql\` stampa ogni
query nei log (\`task logs SERVICE=catalogo\`), che è il modo più veloce per
capire che cosa fa davvero un repository. Lo stesso codice gira su H2 in
memoria e su PostgreSQL.

## Lombok, e una trappola

\`@Getter\`, \`@Setter\` e \`@NoArgsConstructor\` bastano per un'entity: Hibernate
vuole un costruttore vuoto e i metodi per leggere e scrivere i campi. **Non**
usare \`@Data\` sulle entity: genera \`equals\`, \`hashCode\` e \`toString\` su tutti
i campi, relazioni comprese, e con due entity che si nominano a vicenda
\`toString\` non finisce più.

## Le stesse quattro classi, ogni volta: \`task new-entity\`

Ogni tabella della traccia rifà lo stesso giro: un'entity, un repository, un
service col CRUD, un controller con Swagger. Adesso che sai cosa c'è dentro
ognuno, un comando li scrive per te:

\`\`\`bash
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,isbn:string(13):unique,annoPubblicazione:int:min(1450):max(2100),disponibile:bool:required,genere:enum(ROMANZO|SAGGIO|GIALLO)
\`\`\`

\`FIELDS\` è una lista \`nome:tipo[:modificatore]*\`: i tipi sono \`string\`,
\`string(N)\`, \`text\`, \`int\`, \`long\`, \`decimal\`, \`bool\`, \`date\`, \`datetime\`,
\`email\`, \`enum(A|B|C)\` (genera anche l'enum, in un file a parte); i
modificatori sono \`required\`, \`unique\`, \`min(N)\`, \`max(N)\`. Il catalogo
completo è in \`task --summary new-entity\`.

Quello che **non** genera, apposta: le relazioni con altre entity
(\`@ManyToOne\`, \`@OneToMany\`...) e le regole della tua traccia nel service. Le
aggiungi tu, a mano, dopo — sono la parte che si valuta, non boilerplate. Il
controller generato torna \`LibroEntity\` direttamente: se questi dati li
consuma anche un altro servizio via Feign, o vuoi nascondere dei campi,
sostituiscilo con un DTO come hai visto nella lezione 9 (te lo ricorda anche
un commento nel file generato).

> **Prova tu**
>
> Aggiungi a \`LibroEntity\` un campo \`editore\` (una stringa di 80 caratteri, che
> può mancare) e a \`LibroRepository\` il metodo \`findByGenere(Genere genere)\`.
> Poi lancia \`task db-schema\` e cerca la colonna nuova nella tabella \`libri\`.
> Poi prova anche il comando: \`task new-entity SERVICE=catalogo-service
> NAME=Autore FIELDS=nome:string(80):required,cognome:string(80):required\` e
> guarda i quattro file che genera.

> **Fatto quando**
>
> - [ ] le entity della traccia compilano e \`task db-schema\` le mostra
> - [ ] sai perché gli enum si salvano come stringa
> - [ ] sai dove sta la colonna di una relazione \`@ManyToOne\`
> - [ ] sai scrivere una query col nome del metodo, comprese \`And\`, \`Between\`, \`ContainingIgnoreCase\`, \`OrderBy\`
> - [ ] sai quando un repository torna \`Optional\` e come si gestisce con \`orElseThrow\`
> - [ ] sai quando serve \`@Query\` invece del nome del metodo
> - [ ] sai cosa genera \`task new-entity\` e cosa resta da aggiungere a mano
` },
    { file: 'corso/lezioni/09-service-e-controller.md', testo: `# Service e controller REST

<!-- parte: B · Svolgere la traccia | quando: 09:45 | durata: 45 minuti | obiettivo: Il catalogo risponde in JSON con i codici HTTP giusti, le regole stanno nel service, e Swagger mostra ogni endpoint con la sua descrizione. -->

Le entity tengono i dati; adesso qualcuno deve darli fuori. Si fa in due
classi: il **service**, dove stanno le regole, e il **controller**, che parla
HTTP.

## Tre strati, tre mestieri

| Strato | Sa di | Non sa di |
| :--- | :--- | :--- |
| controller | percorsi, parametri, codici HTTP, JSON | database, regole |
| service | regole della traccia, transazioni, trasformare entity in DTO | HTTP |
| repository | tabelle e query | tutto il resto |

Un controller sottile e un service che non sa niente di HTTP: così le regole
stanno in un posto solo, e si provano senza avviare un server.

> 💡 **Scorciatoia d'esame**: Ricorda che eseguendo \`task new-entity SERVICE=<modulo> NAME=<Nome> FIELDS=...\` hai già ottenuto sia il \`Service\` che il \`Controller\` REST con le operazioni CRUD complete, la validazione e la documentazione Swagger! Qui vediamo come sono composti per personalizzarli.

## Il service

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/service/CatalogoService.java
@Service
@RequiredArgsConstructor
public class CatalogoService {

    private final LibroRepository libri;

    public List<LibroDto> tutti() {
        return libri.findAll().stream().map(CatalogoService::toDto).toList();
    }

    public List<LibroDto> disponibili() {
        return libri.findByDisponibileTrue().stream().map(CatalogoService::toDto).toList();
    }

    public LibroDto perId(Long id) {
        return toDto(trova(id));
    }

    // Dentro una transazione l'entity e' "gestita": basta cambiarla, e
    // Hibernate scrive l'UPDATE da solo alla fine del metodo.
    @Transactional
    public LibroDto cambiaDisponibilita(Long id, boolean disponibile) {
        LibroEntity libro = trova(id);
        libro.setDisponibile(disponibile);
        return toDto(libro);
    }

    private LibroEntity trova(Long id) {
        return libri.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Libro " + id + " non trovato"));
    }

    // Fuori dal servizio esce il DTO, mai l'entity: l'autore diventa una
    // stringa, e chi chiama non dipende da come e' fatto il database.
    static LibroDto toDto(LibroEntity libro) {
        AutoreEntity autore = libro.getAutore();
        return new LibroDto(
                libro.getId(),
                libro.getTitolo(),
                libro.getIsbn(),
                libro.getAnnoPubblicazione(),
                libro.getGenere() == null ? null : libro.getGenere().name(),
                Boolean.TRUE.equals(libro.getDisponibile()),
                autore == null ? null : autore.getNome() + " " + autore.getCognome());
    }
}
\`\`\`

Tre cose da portarsi via:

- **\`@RequiredArgsConstructor\`** di Lombok scrive il costruttore con i campi
  \`final\`, e Spring ci passa il repository. È l'iniezione delle dipendenze,
  senza \`@Autowired\`;
- **\`ResponseStatusException\`** è il modo più corto per rispondere con un
  errore: lanciata ovunque, diventa la risposta HTTP con quel codice;
- **\`@Transactional\`** su un metodo che modifica: l'entity letta dentro la
  transazione è seguita da Hibernate, e ogni modifica diventa un \`UPDATE\` alla
  fine del metodo, senza chiamare \`save\`.

## Il controller

\`\`\`java demo/catalogo-service/src/main/java/esame/catalogoservice/controller/LibroController.java
@Tag(name = "Catalogo", description = "I libri della biblioteca e la loro disponibilita'")
@RestController
@RequestMapping("/api/libri")
@RequiredArgsConstructor
public class LibroController {

    private final CatalogoService catalogo;

    @Operation(summary = "Tutti i libri del catalogo")
    @GetMapping
    public List<LibroDto> tutti() {
        return catalogo.tutti();
    }

    @Operation(summary = "Solo i libri che si possono prendere in prestito")
    @GetMapping("/disponibili")
    public List<LibroDto> disponibili() {
        return catalogo.disponibili();
    }

    @Operation(summary = "Un libro, per id (404 se non c'e')")
    @GetMapping("/{id}")
    public LibroDto perId(@PathVariable Long id) {
        return catalogo.perId(id);
    }

    // La chiama prestiti-service, via Feign, quando un libro esce o rientra.
    @Operation(summary = "Segna un libro come disponibile o in prestito")
    @PutMapping("/{id}/disponibilita")
    public LibroDto cambiaDisponibilita(@PathVariable Long id, @RequestParam boolean disponibile) {
        return catalogo.cambiaDisponibilita(id, disponibile);
    }
}
\`\`\`

| Annotazione | Che cosa fa |
| :--- | :--- |
| \`@RestController\` | quello che il metodo restituisce diventa il corpo della risposta, in JSON |
| \`@RequestMapping("/api/libri")\` | il pezzo di percorso comune a tutti i metodi |
| \`@GetMapping("/{id}")\` + \`@PathVariable\` | \`GET /api/libri/3\`: il 3 arriva in \`id\` |
| \`@RequestParam\` | \`?disponibile=false\`: il valore arriva nel parametro |
| \`@Tag\`, \`@Operation\` | il gruppo e la descrizione che mostra Swagger |

## I codici di risposta

| Codice | Quando | Come lo ottieni |
| :--- | :--- | :--- |
| 200 | è andato bene | restituisci il valore |
| 201 | hai creato qualcosa | \`@ResponseStatus(HttpStatus.CREATED)\` sul metodo |
| 400 | la richiesta è sbagliata | da solo, con \`@Valid\` su un corpo che non rispetta i vincoli |
| 404 | la cosa non c'è | \`ResponseStatusException(HttpStatus.NOT_FOUND, ...)\` |
| 409 | c'è, ma la regola non lo permette | \`ResponseStatusException(HttpStatus.CONFLICT, ...)\` |
| 500 | un'eccezione non prevista | è un bug: guarda \`task logs\` |

Il corpo dell'errore lo scrive Spring Boot: \`status\`, \`error\`, \`path\`. Il
messaggio che hai scritto nell'eccezione, di serie, non c'è; se lo vuoi nella
risposta, aggiungi \`server.error.include-message: always\` all'\`application.yml\`.

## Una POST con validazione

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/controller/PrestitoController.java
@Tag(name = "Prestiti", description = "Prestiti, restituzioni e penali per ritardo")
@RestController
@RequestMapping("/api/prestiti")
@RequiredArgsConstructor
public class PrestitoController {

    private final PrestitoService servizio;

    @Operation(summary = "Tutti i prestiti, con ritardo e penale calcolati a oggi")
    @GetMapping
    public List<PrestitoDto> tutti() {
        return servizio.tutti();
    }

    // @Valid: se l'email non e' un'email o i giorni sono fuori da 1-60,
    // Spring risponde 400 prima ancora di entrare nel metodo.
    @Operation(summary = "Presta un libro: 201, 404 se non esiste, 409 se e' gia' fuori")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PrestitoDto presta(@Valid @RequestBody NuovoPrestitoRequest richiesta) {
        return servizio.presta(richiesta);
    }

    @Operation(summary = "Chiude un prestito: il libro torna disponibile")
    @PutMapping("/{id}/restituzione")
    public PrestitoDto restituisci(@PathVariable Long id) {
        return servizio.restituisci(id);
    }
}
\`\`\`

\`@RequestBody\` trasforma il JSON in un \`NuovoPrestitoRequest\`; \`@Valid\` fa
controllare i vincoli scritti sul record (\`@NotNull\`, \`@Email\`, \`@Min\`,
\`@Max\`) prima di chiamare il metodo.

## Gestione globale degli errori con \`task new-handler\`

Quando un client invia dati errati (es. email non valida o campi obbligatori mancanti), Spring lancia un'eccezione di validazione (\`MethodArgumentNotValidException\`). Senza un gestore globale, rischieresti di restituire status non chiari o stack trace grezzi.

Per generare automaticamente un gestore \`@RestControllerAdvice\` centralizzato per il servizio:

\`\`\`bash
task new-handler SERVICE=catalogo-service
\`\`\`

Questo comando genera \`exception/GlobalExceptionHandler.java\` pronto all'uso, che:
- Intercetta gli errori di validazione dei campi (\`@Valid\`) e risponde con **400 Bad Request** e una lista dettagliata di ogni campo errato con il relativo messaggio;
- Intercetta \`ResponseStatusException\` mantenendo lo status HTTP specificato (es. 404, 409);
- Intercetta \`EntityNotFoundException\` / \`NoSuchElementException\` rispondendo con **404 Not Found**;
- Intercetta qualsiasi altro errore imprevisto rispondendo con un JSON pulito in formato standard.

## Provarlo: Swagger

Ogni modulo creato da \`task new-service\` ha Swagger acceso. Con lo stack
avviato:

- \`http://localhost:8081/swagger-ui.html\` — il catalogo
- \`http://localhost:8082/swagger-ui.html\` — i prestiti

Ci sono tutti gli endpoint, raggruppati per \`@Tag\`, con la descrizione di
\`@Operation\`, lo schema dei JSON e il bottone *Try it out* per mandare una
richiesta vera. È il modo più comodo per provare una POST, ed è una delle tre
cose da far vedere alla demo.

Per una GET basta il browser, oppure:

\`\`\`bash
curl http://localhost:8081/api/libri/1
\`\`\`

Su Windows PowerShell scrivi \`curl.exe\`: \`curl\` da solo lì è un'altra cosa
(\`Invoke-WebRequest\`). Una POST da bash (Git Bash, Linux, macOS):

\`\`\`bash
curl -i -X POST http://localhost:8082/api/prestiti -H "Content-Type: application/json" -d '{"libroId":1,"utenteEmail":"anna@esempio.it","giorni":14}'
\`\`\`

La seconda volta, con lo stesso libro, la risposta è \`409\`.

> **Prova tu**
>
> Aggiungi al catalogo \`GET /api/libri/cerca?titolo=rosa\`: un metodo
> \`findByTitoloContainingIgnoreCase\` nel repository, uno nel service, uno nel
> controller con \`@RequestParam String titolo\`. Poi provalo da Swagger.

> **Fatto quando**
>
> - [ ] le regole stanno nel service e il controller non fa altro che chiamarlo
> - [ ] un id che non esiste dà 404, non 500
> - [ ] una POST con l'email sbagliata dà 400
> - [ ] Swagger mostra ogni endpoint con la sua descrizione
` },
    { file: 'corso/lezioni/10-feign.md', testo: `# Chiamare un altro servizio: OpenFeign

<!-- parte: B · Svolgere la traccia | quando: 10:30 | durata: 40 minuti | obiettivo: prestiti-service chiede i libri al catalogo e gli dice quando escono e rientrano; sai che cosa succede quando l'altro servizio risponde con un errore, o non risponde affatto. -->

È la parte che vale di più nella griglia: un servizio che ne chiama un altro
per nome, attraverso Eureka. Con Feign è un'interfaccia e una chiamata di
metodo.

## Il client

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/client/CatalogoClient.java
// Il nome e' quello con cui catalogo-service si registra su Eureka
// (spring.application.name): niente URL, lo risolve il load balancer.
@FeignClient(name = "CATALOGO-SERVICE")
public interface CatalogoClient {

    @GetMapping("/api/libri/{id}")
    LibroDto libro(@PathVariable("id") Long id);

    @PutMapping("/api/libri/{id}/disponibilita")
    LibroDto cambiaDisponibilita(@PathVariable("id") Long id, @RequestParam("disponibile") boolean disponibile);
}
\`\`\`

Le regole sono tre:

1. \`name\` è lo \`spring.application.name\` dell'altro servizio, lettera per
   lettera;
2. ogni metodo copia il metodo del controller che chiama: stesso verbo, stesso
   percorso completo (\`/api/libri/{id}\`, non \`/{id}\`), stessi parametri;
3. il tipo restituito è il DTO di \`common-dto\`, lo stesso che l'altro servizio
   restituisce.

Il \`Main\` generato da \`task new-service\` ha già \`@EnableFeignClients\`: ogni
interfaccia \`@FeignClient\` sotto il suo pacchetto diventa un bean che puoi
iniettare come qualsiasi altro.

## Generare il client con un comando: \`task new-client\`

Puoi generare l'interfaccia \`@FeignClient\` collegata al servizio target direttamente:

\`\`\`bash
task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto
\`\`\`

> 💡 **Modalità Interattiva**: puoi anche lanciare semplicemente \`task new-client\` senza argomenti. Ti mostrerà l'elenco dei microservizi presenti da cui scegliere il modulo chiamante e il target, e ti chiederà il nome del DTO!

Oppure, se il DTO non esiste ancora in \`common-dto\`, puoi specificare anche i campi:

\`\`\`bash
task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto FIELDS=id:long,titolo:string:required,disponibile:bool
\`\`\`

Questo comando:
1. Crea \`CatalogoClient.java\` sotto \`prestiti-service/.../client/\`, annotato con \`@FeignClient(name = "CATALOGO-SERVICE")\` e con i metodi HTTP (\`GET\`, \`POST\`, \`PUT\`, \`DELETE\`) predisposti per scambiare \`LibroDto\`.
2. Se specifichi \`FIELDS=...\` e il DTO non esiste, genera in contemporanea il record \`LibroDto.java\` dentro \`common-dto/src/main/java/esame/common/dto/\` con campi e validazioni Jakarta!

## Usarlo

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/service/PrestitoService.java
@Transactional
public PrestitoDto presta(NuovoPrestitoRequest richiesta) {
    LibroDto libro;
    try {
        libro = catalogo.libro(richiesta.libroId());
    } catch (FeignException.NotFound e) {
        // Il 404 del catalogo diventa il nostro 404, con un messaggio chiaro.
        throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                "Libro " + richiesta.libroId() + " non presente nel catalogo");
    }
    if (!libro.disponibile() || prestiti.existsByLibroIdAndStato(libro.id(), StatoPrestito.IN_CORSO)) {
        throw new ResponseStatusException(HttpStatus.CONFLICT, "\\"" + libro.titolo() + "\\" e' gia' in prestito");
    }

    LocalDate oggi = LocalDate.now();
    int giorni = richiesta.giorni() == null ? GIORNI_DEFAULT : richiesta.giorni();
    PrestitoEntity prestito = new PrestitoEntity();
    prestito.setLibroId(libro.id());
    prestito.setUtenteEmail(richiesta.utenteEmail());
    prestito.setDataPrestito(oggi);
    prestito.setDataScadenza(oggi.plusDays(giorni));
    prestito.setStato(StatoPrestito.IN_CORSO);
    prestiti.save(prestito);

    catalogo.cambiaDisponibilita(libro.id(), false);
    return toDto(prestito, libro.titolo(), oggi);
}
\`\`\`

Quando l'altro servizio risponde con un errore, Feign lancia una
\`FeignException\`, con una sottoclasse per i codici più comuni:
\`FeignException.NotFound\` per il 404, \`Conflict\` per il 409, \`BadRequest\` per
il 400. Senza il \`try\`, il 404 del catalogo diventerebbe un 500 dei prestiti:
un errore di chi chiama, non di chi ha sbagliato. Qui invece diventa un 404
con un messaggio che si capisce.

## Quando l'altro servizio non risponde

Se il catalogo è spento, la chiamata non arriva nemmeno: Feign lancia comunque
una \`FeignException\` (con \`status()\` uguale a -1, o 503 se Eureka non conosce
nessuna istanza). Dove il dato è un di più, si va avanti senza:

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/service/PrestitoService.java
private String titolo(Long libroId) {
    try {
        return catalogo.libro(libroId).titolo();
    } catch (FeignException e) {
        // Il catalogo non risponde, o il libro non c'e' piu': il prestito
        // si mostra lo stesso.
        return "(libro " + libroId + ")";
    }
}
\`\`\`

L'elenco dei prestiti resta in piedi anche col catalogo spento, con
«(libro 3)» al posto del titolo. È esattamente quello che vuoi far vedere se
alla demo ti chiedono della resilienza.

## Nell'interfaccia: una POST via Feign

\`biblioteca-ui\` ha i suoi client, con le stesse regole. Per mandare un prestito
serve il corpo della POST: è \`NuovoPrestitoRequest\`, e per questo sta in
\`common-dto\`.

\`\`\`java demo/biblioteca-ui/src/main/java/esame/bibliotecaui/client/PrestitiClient.java
// Le stesse firme del PrestitoController di prestiti-service, con gli stessi
// DTO di common-dto: Feign scrive la richiesta HTTP, Jackson il JSON.
@FeignClient(name = "PRESTITI-SERVICE")
public interface PrestitiClient {

    @GetMapping("/api/prestiti")
    List<PrestitoDto> prestiti();

    @PostMapping("/api/prestiti")
    PrestitoDto presta(@RequestBody NuovoPrestitoRequest richiesta);

    @PutMapping("/api/prestiti/{id}/restituzione")
    PrestitoDto restituisci(@PathVariable("id") Long id);
}
\`\`\`

## Le trappole, e come si riconoscono

| Che cosa vedi nei log | Che cosa è successo | Che cosa fai |
| :--- | :--- | :--- |
| \`Load balancer does not contain an instance for the service CATALOGO-SERVICE\` | il nome non è registrato: sbagliato, o il servizio non è ancora su | confronta con la dashboard di Eureka; subito dopo l'avvio aspetta 10 secondi |
| \`FeignException$NotFound\` su un percorso che esiste | il percorso nel client non è quello del controller | copia il percorso completo, \`@RequestMapping\` compreso |
| \`No qualifying bean of type 'CatalogoClient'\` | manca \`@EnableFeignClients\`, o il client è fuori dal pacchetto di \`Main\` | guarda \`Main\` e i pacchetti |
| un campo sempre \`null\` | i due servizi usano classi diverse per lo stesso JSON | un DTO solo, in \`common-dto\` |
| \`Connection refused\` | il servizio è registrato ma spento | \`task status\`, poi \`task logs SERVICE=<nome>\` |

Una cosa da sapere: **le transazioni non attraversano la rete.** Se \`presta\`
fallisce dopo \`cambiaDisponibilita\`, l'inserimento del prestito si annulla ma
il catalogo resta com'è. Per questo nel codice la chiamata che modifica l'altro
servizio viene per ultima, dopo tutti i controlli.

> **Prova tu**
>
> Con lo stack acceso, spegni il catalogo (\`task dev-down\` e poi riaccendi
> solo gli altri, oppure in Docker \`docker compose stop catalogo-service\` dalla
> cartella \`demo\`). Apri \`http://localhost:8082/api/prestiti\`: i prestiti ci
> sono, con «(libro N)» al posto del titolo. Poi riaccendi tutto.

> **Fatto quando**
>
> - [ ] il client ha lo stesso nome, gli stessi percorsi e gli stessi DTO dell'altro servizio
> - [ ] un libro che non esiste dà 404 anche passando da Feign
> - [ ] l'elenco dei prestiti non va in errore se il catalogo è spento
> - [ ] sai leggere *Load balancer does not contain an instance*
` },
    { file: 'corso/lezioni/11-algoritmo.md', testo: `# L'algoritmo della traccia

<!-- parte: B · Svolgere la traccia | quando: 11:10 | durata: 30 minuti | obiettivo: La penale è calcolata da due funzioni pure, provata da un test che si lancia in un secondo e descritta nell'allegato come la vuole la commissione. -->

Ogni traccia ha la sua regola da calcolare: la distanza più corta nel
magazzino, la classe energetica di un edificio, la penale per chi restituisce
tardi. Vale punti due volte: nel codice e nell'allegato. Conviene scriverla in
modo che si possa provare da sola.

## Dalla frase alla formula

La traccia dice: *per ogni giorno di ritardo si paga una penale di 0,50 euro,
fino a un massimo di 20 euro*. Prima di scrivere codice, la si scrive così:

- **ritardo** = giorni fra la scadenza e il giorno di riferimento, e mai meno
  di zero;
- **giorno di riferimento** = il giorno della restituzione se il prestito è
  chiuso, oggi se è ancora aperto;
- **penale** = il minore fra 0,50 × ritardo e 20,00.

Restituito in anticipo: ritardo 0, penale 0. Quaranta giorni di ritardo: la
formula darebbe 20,00 esatti, oltre si resta a 20,00.

## Il codice

\`\`\`java demo/prestiti-service/src/main/java/esame/prestitiservice/service/PrestitoService.java
static final BigDecimal PENALE_GIORNALIERA = new BigDecimal("0.50");
static final BigDecimal PENALE_MASSIMA = new BigDecimal("20.00");

// 0,50 euro per ogni giorno oltre la scadenza, fino a un massimo di 20
// euro. Per un prestito ancora aperto il ritardo si conta fino a oggi, per
// uno chiuso fino al giorno della restituzione. Due funzioni pure, senza
// database ne' Feign: si provano con un test in un attimo.

static long giorniRitardo(LocalDate scadenza, LocalDate riferimento) {
    return Math.max(0, ChronoUnit.DAYS.between(scadenza, riferimento));
}

static BigDecimal penale(long giorniRitardo) {
    return PENALE_GIORNALIERA.multiply(BigDecimal.valueOf(giorniRitardo)).min(PENALE_MASSIMA);
}

private PrestitoDto toDto(PrestitoEntity p, String titolo, LocalDate oggi) {
    LocalDate riferimento = p.getDataRestituzione() != null ? p.getDataRestituzione() : oggi;
    long ritardo = giorniRitardo(p.getDataScadenza(), riferimento);
    return new PrestitoDto(p.getId(), p.getLibroId(), titolo, p.getUtenteEmail(), p.getDataPrestito(),
            p.getDataScadenza(), p.getStato().name(), ritardo, penale(ritardo));
}
\`\`\`

- **Due funzioni pure**: ricevono tutto quello che serve come parametro e non
  toccano né database né rete. Si provano in un millisecondo, e si leggono in
  un colpo d'occhio all'orale.
- **\`BigDecimal\` per i soldi**, sempre: con \`double\`, 0,1 + 0,2 fa
  0,30000000000000004. I valori si creano da stringa (\`new BigDecimal("0.50")\`)
  per lo stesso motivo.
- **\`static\` e senza \`private\`**: le vede il test, che sta nello stesso
  pacchetto, e nessun altro fuori.
- \`ChronoUnit.DAYS.between\` conta i giorni di calendario fra due \`LocalDate\`,
  senza fusi orari e ore legali di mezzo.

## Il test

\`\`\`java demo/prestiti-service/src/test/java/esame/prestitiservice/service/PenaleTest.java
class PenaleTest {

    private static final LocalDate SCADENZA = LocalDate.of(2026, 3, 10);

    @Test
    void restituitoInTempoNonHaRitardo() {
        assertEquals(0, PrestitoService.giorniRitardo(SCADENZA, SCADENZA));
        assertEquals(0, PrestitoService.giorniRitardo(SCADENZA, SCADENZA.minusDays(4)));
    }

    @Test
    void ogniGiornoDopoLaScadenzaConta() {
        assertEquals(7, PrestitoService.giorniRitardo(SCADENZA, SCADENZA.plusDays(7)));
    }

    @Test
    void cinquantaCentesimiAlGiorno() {
        assertEquals(new BigDecimal("3.50"), PrestitoService.penale(7));
    }

    @Test
    void laPenaleSiFermaAVentiEuro() {
        assertEquals(new BigDecimal("20.00"), PrestitoService.penale(40));
        assertEquals(new BigDecimal("20.00"), PrestitoService.penale(400));
    }
}
\`\`\`

Serve JUnit, che i moduli generati non hanno: si aggiunge con un comando.

\`\`\`bash
task add-dep SERVICE=prestiti-service DEPS=test
\`\`\`

Poi, dalla cartella \`demo\` (su Windows \`.\\mvnw.cmd\` al posto di \`./mvnw\`):

\`\`\`bash
./mvnw -pl prestiti-service -am test
\`\`\`

\`\`\`text
[INFO] Tests run: 4, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
\`\`\`

\`task dev\`, \`task build\` e le immagini Docker saltano i test
(\`-Dmaven.test.skip=true\`), così un test rotto non ti blocca lo stack a metà
giornata: si lanciano quando li chiedi tu.

## Nell'allegato

La commissione vuole l'algoritmo spiegato, non incollato. Un paragrafo così
basta:

> **Algoritmo della penale.** Per ogni prestito si calcola il ritardo come il
> numero di giorni fra la data di scadenza e la data di riferimento — la data
> di restituzione se il prestito è chiuso, la data odierna se è aperto — con
> un minimo di zero. La penale è pari a 0,50 € per giorno di ritardo, con un
> tetto di 20,00 €: penale = min(0,50 × ritardo; 20,00). Il calcolo avviene in
> \`PrestitoService\` (metodi \`giorniRitardo\` e \`penale\`) ogni volta che un
> prestito viene restituito all'esterno, quindi il valore mostrato è sempre
> aggiornato al giorno corrente e non viene salvato nel database. Costa un
> tempo costante per prestito, lineare nel numero di prestiti per l'elenco.
> È verificato dai test di \`PenaleTest\`: restituzione in anticipo, sette
> giorni di ritardo (3,50 €), tetto raggiunto (20,00 €).

## Gli algoritmi delle altre tracce

Stesso schema, sempre: formula a parole, funzione pura, test, paragrafo. Nel
magazzino WMS (branch \`solution/wms\`) la regola è trovare l'ubicazione libera
più vicina, con la distanza di Manhattan fra armadi disposti a griglia:
|riga₁ − riga₂| + |colonna₁ − colonna₂|, calcolata su tutte le ubicazioni
compatibili e presa la minima.

> **Prova tu**
>
> La biblioteca cambia idea: la prima settimana di ritardo costa 0,20 € al
> giorno, dall'ottavo giorno 0,50 €, sempre con il tetto di 20 €. Scrivi prima
> i test (sette giorni: 1,40 €; dieci giorni: 2,90 €), poi cambia \`penale\`
> finché passano.

> **Fatto quando**
>
> - [ ] la formula è scritta a parole prima che in Java
> - [ ] il calcolo sta in funzioni che non toccano database e rete
> - [ ] \`./mvnw -pl prestiti-service -am test\` passa
> - [ ] il paragrafo per l'allegato è scritto
` },
    { file: 'corso/lezioni/12-thymeleaf.md', testo: `# L'interfaccia con Thymeleaf

<!-- parte: B · Svolgere la traccia | quando: 11:40 | durata: 60 minuti | obiettivo: La pagina mostra catalogo e prestiti, registra un prestito con un form validato e una restituzione con un bottone, e non va in errore se un servizio è spento. -->

L'interfaccia è un servizio come gli altri, con una differenza: invece di
restituire JSON, restituisce pagine HTML. Le scrive Thymeleaf, riempiendo un
modello di pagina con i dati che il controller gli passa. Niente JavaScript,
niente framework: un form HTML fa già tutto quello che serve.

## Come gira

1. il browser chiede \`GET /\`;
2. il metodo del \`@Controller\` prende i dati (qui con Feign) e li mette nel
   \`Model\`;
3. restituisce il nome di un modello di pagina, \`"index"\`: Spring apre
   \`src/main/resources/templates/index.html\`;
4. Thymeleaf sostituisce gli attributi \`th:\` con i valori, e al browser
   arriva HTML normale.

Il modulo creato con \`task new-service NAME=biblioteca-ui UI=1\` ha già la
dipendenza di Thymeleaf, un \`HomeController\` e una pagina da sostituire.

## Generare una vista completa con tabella e form: \`task new-view\`

Per non dover scrivere a mano controller, tabella, form e gestione errori:

\`\`\`bash
task new-view SERVICE=biblioteca-ui NAME=Libri FIELDS=titolo:string:required,autore:string,anno:int
\`\`\`

> 💡 **Modalità Interattiva**: puoi anche lanciare \`task new-view\` senza argomenti. Ti mostrerà i moduli UI tra cui scegliere e ti chiederà nome della vista e campi del form!

Genera:
1. \`controller/LibriUiController.java\`: controller Spring MVC con \`@GetMapping\` (elenco + form vuoto) e \`@PostMapping\` (salvataggio con \`@Valid\` e binding errori).
2. \`src/main/resources/templates/libri.html\`: pagina HTML completa, con stile pulito, tabella dinamica \`th:each\` e form collegato \`th:object\` con visualizzazione errori \`th:errors\`.

## Il controller

\`\`\`java demo/biblioteca-ui/src/main/java/esame/bibliotecaui/HomeController.java
@Controller
@RequiredArgsConstructor
public class HomeController {

    private final CatalogoClient catalogo;
    private final PrestitiClient prestiti;

    @GetMapping("/")
    public String home(Model model) {
        // Dopo un redirect il form puo' esserci gia' (flash): non sovrascriverlo.
        if (!model.containsAttribute("form")) {
            model.addAttribute("form", new PrestitoForm());
        }
        return pagina(model);
    }

    // POST, poi redirect, poi GET: se l'utente ricarica la pagina non rimanda
    // il form una seconda volta, e il messaggio arriva come "flash attribute".
    @PostMapping("/prestiti")
    public String presta(@Valid @ModelAttribute("form") PrestitoForm form, BindingResult errori,
            Model model, RedirectAttributes redirect) {
        if (errori.hasErrors()) {
            // Niente redirect: la pagina torna con i campi sbagliati segnati.
            return pagina(model);
        }
        try {
            PrestitoDto p = prestiti.presta(
                    new NuovoPrestitoRequest(form.getLibroId(), form.getUtenteEmail(), form.getGiorni()));
            redirect.addFlashAttribute("messaggio",
                    "Prestito registrato: \\"" + p.titoloLibro() + "\\", da restituire entro il " + p.dataScadenza() + ".");
        } catch (FeignException e) {
            redirect.addFlashAttribute("errore", spiega(e));
        }
        return "redirect:/";
    }

    private String pagina(Model model) {
        model.addAttribute("titolo", "Biblioteca di quartiere");
        try {
            List<LibroDto> libri = catalogo.libri();
            model.addAttribute("libri", libri);
            model.addAttribute("disponibili", libri.stream().filter(LibroDto::disponibile).toList());
            model.addAttribute("prestiti", prestiti.prestiti());
        } catch (RuntimeException e) {
            // Subito dopo l'avvio i servizi possono non essere ancora su
            // Eureka: meglio una pagina che lo dice di una pagina d'errore.
            model.addAttribute("errore", "I servizi non rispondono ancora: riprova fra qualche secondo.");
            model.addAttribute("libri", List.of());
            model.addAttribute("disponibili", List.of());
            model.addAttribute("prestiti", List.of());
        }
        return "index";
    }

    // Il codice HTTP che ha risposto l'altro servizio, detto in italiano.
    static String spiega(FeignException e) {
        return switch (e.status()) {
            case 400 -> "Dati non validi: controlla l'email e i giorni.";
            case 404 -> "Quel libro, o quel prestito, non esiste.";
            case 409 -> "Non si puo': il libro e' gia' in prestito, o il prestito e' gia' chiuso.";
            default -> "Il servizio dei prestiti non risponde: riprova fra qualche secondo.";
        };
    }
}
\`\`\`

(Nel file c'è anche il metodo della restituzione: stesso schema, con
\`@PostMapping("/prestiti/{id}/restituzione")\`.)

- **\`@Controller\`**, non \`@RestController\`: il valore restituito è il nome di
  una pagina, non il corpo della risposta.
- **POST, redirect, GET**: dopo aver registrato il prestito non si mostra la
  pagina, si rimanda a \`/\`. Se l'utente ricarica, il browser rifà la GET e non
  un secondo prestito. Il messaggio sopravvive al redirect perché è un *flash
  attribute*: vive per una richiesta sola.
- **Il flash attribute sta nella sessione**, e al primo invio il browser non ne
  ha ancora una: Tomcat allora la scrive nell'indirizzo del redirect
  (\`/;jsessionid=...\`) e Spring non lo riconosce più come \`/\`. Il primo prestito
  finisce in un 500 senza form, i successivi vanno. Per questo l'\`application.yml\`
  della UI dice \`server.servlet.session.tracking-modes: cookie\` (con
  \`task new-service UI=1\` c'è già). Il collaudo l'ha trovato così: con \`curl\`, che
  segue il redirect com'è, il primo POST dava 500.
- **Se il form è sbagliato non si fa redirect**: si ridisegna la pagina con
  \`BindingResult\`, che porta con sé i messaggi di ogni campo.
- **Se un servizio non risponde**, la pagina lo dice e resta in piedi.

## Il form: una classe, non un record

\`\`\`java demo/biblioteca-ui/src/main/java/esame/bibliotecaui/PrestitoForm.java
@Getter
@Setter
public class PrestitoForm {

    @NotNull(message = "Scegli un libro")
    private Long libroId;

    @NotBlank(message = "Serve l'email di chi prende il libro")
    @Email(message = "Questa non e' un'email")
    private String utenteEmail;

    @NotNull(message = "Quanti giorni?")
    @Min(value = 1, message = "Almeno un giorno")
    @Max(value = 60, message = "Al massimo 60 giorni")
    private Integer giorni = 30;
}
\`\`\`

Thymeleaf (\`th:field\`) e il binding della POST lavorano con getter e setter,
e un record non li ha: per il form serve una classe normale. È anche il posto
giusto per i messaggi in italiano che vede l'utente. Poi il controller la
trasforma nel \`NuovoPrestitoRequest\` di \`common-dto\`.

## La pagina

Il form, con i messaggi di errore campo per campo:

\`\`\`html demo/biblioteca-ui/src/main/resources/templates/index.html
<form class="nuovo" th:action="@{/prestiti}" th:object="\${form}" method="post">
    <label>Libro
        <select th:field="*{libroId}">
            <option value="">scegli un libro disponibile</option>
            <option th:each="l : \${disponibili}" th:value="\${l.id}" th:text="\${l.titolo} + ' - ' + \${l.autore}"></option>
        </select>
        <span class="errore-campo" th:if="\${#fields.hasErrors('libroId')}" th:errors="*{libroId}"></span>
    </label>
    <label>Email di chi lo prende
        <input type="text" th:field="*{utenteEmail}" placeholder="nome@esempio.it">
        <span class="errore-campo" th:if="\${#fields.hasErrors('utenteEmail')}" th:errors="*{utenteEmail}"></span>
    </label>
    <label>Giorni
        <input type="number" th:field="*{giorni}" min="1" max="60">
    </label>
    <button type="submit">Presta</button>
</form>
\`\`\`

La tabella dei prestiti, con il bottone per restituire solo dove serve:

\`\`\`html demo/biblioteca-ui/src/main/resources/templates/index.html
<tr th:each="p : \${prestiti}">
    <td th:text="\${p.titoloLibro}"></td>
    <td th:text="\${p.utenteEmail}"></td>
    <td th:text="\${#temporals.format(p.dataScadenza, 'dd/MM/yyyy')}"></td>
    <td th:classappend="\${p.giorniRitardo > 0} ? 'ritardo'" th:text="\${p.giorniRitardo} + ' gg'"></td>
    <td th:text="\${#numbers.formatDecimal(p.penale, 1, 2, 'COMMA')} + ' EUR'"></td>
    <td>
        <form th:if="\${p.stato == 'IN_CORSO'}" th:action="@{/prestiti/{id}/restituzione(id=\${p.id})}" method="post">
            <button class="piccolo" type="submit">Restituisci</button>
        </form>
    </td>
</tr>
\`\`\`

| Scrivi | Che cosa fa |
| :--- | :--- |
| \`th:text="\${titolo}"\` | il testo dell'elemento, con l'HTML protetto |
| \`th:each="p : \${prestiti}"\` | ripete l'elemento per ogni prestito |
| \`th:if="\${messaggio}"\` | l'elemento c'è solo se il valore c'è |
| \`th:object="\${form}"\` e \`th:field="*{utenteEmail}"\` | lega il campo alla proprietà: scrive \`name\`, \`id\` e \`value\` |
| \`th:errors="*{utenteEmail}"\` | il messaggio di validazione di quel campo |
| \`@{/prestiti/{id}/restituzione(id=\${p.id})}\` | un indirizzo con un pezzo variabile |
| \`th:classappend="\${...} ? 'ritardo'"\` | una classe CSS in più, se la condizione è vera |
| \`\${#temporals.format(data, 'dd/MM/yyyy')}\` | una data scritta all'italiana |
| \`\${#numbers.formatDecimal(n, 1, 2, 'COMMA')}\` | 3,50 invece di 3.5 |

Il resto — frammenti, \`th:switch\`, messaggi da file — sta nel [cheat sheet di
Thymeleaf](../../guida_prova_finale_spring_boot.md#67-thymeleaf-il-cheat-sheet-delle-pagine)
della Guida 2.

## Com'è fatta la pagina

Il CSS sta in un blocco \`<style>\` in cima alla pagina: per l'esame basta, e
non ci sono file da servire. Poche regole fanno la differenza fra un elenco e
un'applicazione: le tabelle con le righe separate, i messaggi colorati (verde
se è andata, rosso se no), il ritardo in rosso, il form su una riga. Non
serve di più: la commissione guarda che le operazioni funzionino.

> **Prova tu**
>
> Aggiungi sopra il catalogo un campo di ricerca: un form con \`method="get"\` e
> un \`<input name="q">\`; nel controller \`@RequestParam(required = false) String q\`
> e un filtro sui titoli prima di metterli nel modello.

> **Fatto quando**
>
> - [ ] la pagina mostra catalogo e prestiti con ritardo e penale
> - [ ] un prestito con l'email sbagliata torna con il messaggio sotto il campo
> - [ ] dopo un prestito, ricaricare la pagina non ne registra un altro
> - [ ] col catalogo spento la pagina dice che cosa succede invece di dare errore
` },
    { file: 'corso/lezioni/13-dati-e-schema.md', testo: `# Dati di prova e schema del database

<!-- parte: B · Svolgere la traccia | quando: 12:40 | durata: 10 minuti | obiettivo: Le tabelle si riempiono da sole di righe credibili a ogni avvio, e hai lo schema concettuale e logico per l'allegato, letto dal database vero. -->

Una demo su tabelle vuote non si vede, e lo schema del database vale punti
nell'allegato. Scritte le entity, sono due comandi, e tutti e due lavorano sul
database vero: avviano l'applicazione, lasciano che Hibernate crei le tabelle
e lavorano su quelle.

## I dati di prova

\`\`\`bash
task seed-data
\`\`\`

L'uscita vera, sul branch della Biblioteca:

\`\`\`text
  catalogo-service/src/main/resources/application.yml  dev-data.rows: 5
  prestiti-service/src/main/resources/application.yml  dev-data.rows: 5

==> Prova su un database H2 usa-e-getta
  compilo con Maven...

  catalogo-service
    AutoreEntity: 5 righe nuove
    LibroEntity: 5 righe nuove
    dati di prova: 2 entity riempite
    righe per tabella: autori 5, libri 5

  prestiti-service
    PrestitoEntity: 5 righe nuove
    dati di prova: 1 entity riempite
    righe per tabella: prestiti 5

Dati di prova pronti.
\`\`\`

Il comando scrive due righe nell'\`application.yml\` di ogni modulo con delle
\`@Entity\`:

\`\`\`yaml demo/catalogo-service/src/main/resources/application.yml
dev-data:
  rows: 5
\`\`\`

e da lì in poi, a ogni avvio, il pacchetto \`devdata\` di \`common-dto\` riempie
le tabelle **ancora vuote**. Costruisce oggetti delle tue entity con valori
inventati e li salva passando da Hibernate, come farebbe il tuo codice. Per
questo rispetta quello che rispetta la tua applicazione:

- gli id li genera chi deve; le relazioni puntano a righe che esistono, perché
  le tabelle si riempiono nell'ordine giusto (prima \`autori\`, poi \`libri\`);
- gli enum sono i tuoi; lunghezze, \`@NotNull\`, \`@Min\`/\`@Max\`, \`@Email\` e
  perfino \`@Pattern\`: gli ISBN escono di tredici cifre che cominciano con 978 o
  979;
- i valori seguono il nome del campo e dell'entity: il \`titolo\` di un libro è
  il titolo di un libro, un'\`email\` è un'email, un \`cognome\` è un cognome.

Un riavvio non duplica niente, perché si riempiono solo le tabelle vuote; vale
su H2, su PostgreSQL e in Docker. Prima di finire, il comando prova tutto su un
H2 usa-e-getta e ti dice tabella per tabella com'è andata: se una entity non
entra, lo scopri adesso e non davanti alla commissione.

| Variante | Che cosa fa |
| :--- | :--- |
| \`task seed-data SERVICE=catalogo-service ROWS=10\` | un modulo solo, dieci righe |
| \`task seed-data ROWS=0\` | spenti |
| \`task seed-data CHECK=0\` | scrive la configurazione senza la prova |

### Che cosa non può sapere

\`PrestitoEntity.libroId\` non è una relazione: è un numero che punta a un libro
di un altro servizio. I dati di prova gli danno valori da 1 in su, gli id che il
catalogo ha davvero, così i titoli si risolvono. Ma una regola che attraversa
due servizi non la conoscono: può capitare un libro segnato come disponibile
con un prestito in corso. Per la demo va bene; se la traccia vuole dati
precisi (quei libri, quegli utenti) scrivili in un \`data.sql\` tuo. Le tabelle
che riempie lui non vengono toccate. Perché venga eseguito dopo Hibernate,
anche su PostgreSQL:

\`\`\`yaml demo/catalogo-service/src/main/resources/application.yml
spring:
  jpa:
    defer-datasource-initialization: true
  sql:
    init:
      mode: always
\`\`\`

## Lo schema del database

\`\`\`bash
task db-schema
\`\`\`

Avvia ogni modulo con delle entity su un H2 usa-e-getta e interroga le tabelle
che Hibernate ha creato. Il database del progetto non lo tocca, e funziona a
stack spento. Ne esce un documento Markdown con, per ogni modulo:

- il **modello concettuale**: le entità, i loro attributi e le relazioni con la
  cardinalità;
- il **modello logico**: tabelle, colonne, tipi SQL, chiavi primarie ed
  esterne, vincoli e valori ammessi degli enum;
- un **diagramma ER** in mermaid, che GitHub e VS Code disegnano da soli.

Un pezzo dell'uscita vera, per il catalogo:

\`\`\`text
- **Autore** (id (identificatore), nome, cognome, nazionalita) -- classe \`AutoreEntity\`, tabella \`autori\`
- **Libro** (id (identificatore), titolo, isbn, annoPubblicazione, genere (ROMANZO | SAGGIO | GIALLO | FANTASY | STORICO), disponibile) -- classe \`LibroEntity\`, tabella \`libri\`

**Relazioni**

- **Libro** -> **Autore**: molti a uno, obbligatoria (campo \`autore\`)
\`\`\`

\`\`\`mermaid
erDiagram
    AUTORI {
        bigint id PK
        varchar nome
        varchar cognome
        varchar nazionalita
    }
    LIBRI {
        bigint id PK
        varchar titolo
        varchar isbn UK
        integer anno_pubblicazione
        varchar genere
        boolean disponibile
        bigint autore_id FK
    }
    AUTORI ||--o{ LIBRI : "autore_id"
\`\`\`

È lo *schema concettuale e logico della base dati* che chiede l'allegato, e
\`task consegna\` lo mette da solo in \`SCHEMA-DATABASE.md\` e dentro
\`ALLEGATO-TECNICO.md\`. Per averlo in un file adesso:
\`task db-schema OUT=schema.md\`.

> **Prova tu**
>
> Lancia \`task dev\`, apri \`http://localhost:8081/api/libri\` e guarda i libri
> inventati. Poi riavvia (\`task dev\` di nuovo) e controlla che siano ancora
> cinque, non dieci.

> **Fatto quando**
>
> - [ ] \`task seed-data\` dice che ogni entity si è riempita
> - [ ] dopo un riavvio le righe non sono raddoppiate
> - [ ] hai lo schema, e sai che lo mette da solo anche la consegna
` },
    { file: 'corso/lezioni/14-collaudo.md', testo: `# Il collaudo

<!-- parte: C · Chiudere | quando: 12:50 | durata: 20 minuti | obiettivo: Prima di chiamare la commissione hai provato ogni flusso della traccia, dai casi buoni agli errori, e sai dove guardare se uno non torna. -->

«Funziona» vuol dire che hai provato ogni cosa che la traccia chiede, compresi
i casi che devono dire di no. Venti minuti adesso valgono più di un'ora di
codice in più.

## Uno: il progetto è coerente

\`\`\`bash
task check
\`\`\`

Non avvia niente: legge i file e controlla che moduli, porte, Dockerfile,
compose e lista di avvio dicano la stessa cosa. Se hai toccato qualcosa a mano,
è qui che lo scopri.

## Due: i servizi si vedono fra loro

\`\`\`bash
task status
\`\`\`

Porta per porta chi è in ascolto, i container accesi e, soprattutto, chi è
registrato su Eureka. Un servizio acceso ma non registrato non lo chiama
nessuno.

## Tre: ogni flusso, anche quelli che dicono di no

Da Swagger (\`http://localhost:8081/swagger-ui.html\` e \`:8082\`) o dal browser:

| Prova | Come | Che cosa deve succedere |
| :--- | :--- | :--- |
| il catalogo ha dei libri | \`GET :8081/api/libri\` | 200 e i libri dei dati di prova |
| prestare un libro disponibile | \`POST :8082/api/prestiti\` con \`libroId\`, \`utenteEmail\`, \`giorni\` | 201; \`GET :8081/api/libri/{id}\` dice \`disponibile: false\` |
| prestarlo di nuovo | la stessa POST | 409 |
| un libro che non c'è | \`libroId: 999\` | 404 |
| un'email sbagliata | \`utenteEmail: "non-una-email"\` | 400 |
| restituirlo | \`PUT :8082/api/prestiti/{id}/restituzione\` | 200; il libro torna disponibile |
| restituirlo due volte | la stessa PUT | 409 |
| ritardo e penale | \`GET :8082/api/prestiti\` | i prestiti scaduti hanno \`giorniRitardo\` e \`penale\` |
| la pagina | \`http://localhost:8090\` | catalogo, prestiti, form; un prestito e una restituzione dalla pagina |
| un servizio giù | spegni il catalogo | i prestiti si vedono con «(libro N)», la pagina avvisa |

Nel branch \`example/biblioteca\` queste prove le fa uno script, dopo
\`task dev\` (o dopo \`task docker-up\`):

\`\`\`bash
powershell -ExecutionPolicy Bypass -File test_e2e_biblioteca.ps1
\`\`\`

Ogni riga dice che cosa ha provato e com'è andata; alla fine il conto. Per la
tua traccia, scriverne uno così è mezz'ora spesa bene: ti fa rifare tutte le
prove dopo ogni modifica, in dieci secondi.

## Quattro: l'algoritmo

\`\`\`bash
./mvnw -pl prestiti-service -am test
\`\`\`

(Dalla cartella \`demo\`; su Windows \`.\\mvnw.cmd\`.) I test della penale,
raccontati nella [lezione sull'algoritmo](11-algoritmo.md).

## Se una prova non torna

Non fare ipotesi: guarda.

\`\`\`bash
task logs SERVICE=prestiti
\`\`\`

Con \`show-sql: true\` vedi anche le query. Un 500 ha sempre uno stack trace nel
log del servizio che l'ha dato: la prima riga \`Caused by:\` di solito dice
tutto. Un 404 su un endpoint che esiste è quasi sempre un percorso sbagliato,
nel controller o nel client Feign.

> **Fatto quando**
>
> - [ ] \`task check\` è pulito e \`task status\` mostra tutti i servizi su Eureka
> - [ ] hai provato ogni riga della tabella, errori compresi
> - [ ] i test dell'algoritmo passano
> - [ ] hai fatto dalla pagina un prestito e una restituzione, come li farai alla demo
` },
    { file: 'corso/lezioni/15-docker-e-demo.md', testo: `# Docker e la demo

<!-- parte: C · Chiudere | quando: 13:10 | durata: 15 minuti | obiettivo: Lo stack gira tutto in container, sai che cosa mostrare e in che ordine, e sai spegnere un servizio davanti alla commissione senza paura. -->

Durante la giornata hai lavorato con \`task dev\`, i servizi come processi sul
tuo PC. Alla demo si mostra quello che si consegna: tutto in container, con
Docker Compose.

## Accendere

\`\`\`bash
task docker-up
\`\`\`

Fa quattro cose, in quest'ordine:

1. \`task check\`: meglio fermarsi subito che dopo dieci minuti di build;
2. \`task dev-down\`: lo stack locale userebbe le stesse porte;
3. \`docker compose build\`: un'immagine per servizio, dallo stesso Dockerfile;
4. \`docker compose up -d\`: i container, in background.

Il compose li accende nell'ordine giusto grazie alle healthcheck: prima
PostgreSQL, poi Eureka, e solo quando Eureka risponde i servizi
(\`depends_on\` con \`condition: service_healthy\`). Aspetta che \`task status\`
mostri tutti i servizi registrati, poi comincia.

## Che cosa mostrare, e in che ordine

1. **L'applicazione**: \`http://localhost:8090\`. Registra un prestito, fai
   vedere il messaggio, restituisci un libro in ritardo e fai vedere la
   penale. È la parte che vale di più.
2. **Eureka**: \`http://localhost:8761\`. I servizi registrati, col loro nome:
   è il discovery di cui parli nell'allegato.
3. **Swagger**: \`http://localhost:8082/swagger-ui.html\`. I contratti delle API,
   e una richiesta vera con *Try it out*: prova a prestare un libro già fuori e
   fai vedere il 409.

## La resilienza, dal vivo

Se ti chiedono che cosa succede quando un servizio cade, fallo cadere. Dalla
cartella \`demo\`:

\`\`\`bash
docker compose stop catalogo-service
\`\`\`

Ricarica la pagina: resta in piedi e dice che il catalogo non risponde;
\`http://localhost:8082/api/prestiti\` mostra i prestiti con «(libro N)» al posto
del titolo. Dopo quindici secondi Eureka lo toglie dal registro. Poi:

\`\`\`bash
docker compose start catalogo-service
\`\`\`

e in una decina di secondi è tutto come prima. I container non hanno un nome
fisso (Compose li chiama \`<cartella>-<servizio>-1\`): per questo i comandi usano
il nome del **servizio** e si lanciano dalla cartella del compose.

## I log

\`\`\`bash
task docker-logs
\`\`\`

Oppure di un servizio solo, dalla cartella \`demo\`:
\`docker compose logs -f prestiti-service\`.

## Spegnere

| Comando | I dati del database |
| :--- | :--- |
| \`task docker-down\` | restano |
| \`task docker-reset\` | **cancellati** |

Durante la demo usa sempre \`docker-down\`. \`docker-reset\` serve quando vuoi un
database da zero, per esempio dopo aver cambiato utente o password con
\`task db-config\`.

## Se Docker Hub non passa

\`docker compose build\` ha bisogno delle immagini di base (\`eclipse-temurin\`,
\`postgres\`) e, se la cache non ce l'ha, di scaricare \`curl\` da Ubuntu.
\`task rete\` ti dice se quei domini passano; \`task offline\` se le immagini sono
già sul disco. Se proprio non si può costruire, la demo si fa lo stesso con
\`task dev\` e il solo PostgreSQL in container (\`task run-db\`): Maven lavora
dalla \`~/.m2\` e Docker deve solo far partire un'immagine che hai già.

> **Fatto quando**
>
> - [ ] \`task docker-up\` porta su tutto e \`task status\` mostra i servizi registrati
> - [ ] hai provato la demo nell'ordine: pagina, Eureka, Swagger
> - [ ] hai spento e riacceso un servizio e la pagina è rimasta in piedi
> - [ ] sai perché alla fine si usa \`docker-down\` e non \`docker-reset\`
` },
    { file: 'corso/lezioni/16-consegna-e-allegato.md', testo: `# La consegna e l'allegato tecnico

<!-- parte: C · Chiudere | quando: 13:25 | durata: 60 minuti, con le domande teoriche | obiettivo: Hai l'archivio da consegnare, provato da scompattato, con l'allegato completo e le due risposte teoriche. -->

L'ultima ora non si scrive codice. Si prepara l'archivio, si completa
l'allegato e si risponde alle domande teoriche: sono 16 punti su 40, e si
prendono con la testa fredda.

## Un comando

\`\`\`bash
task consegna NOME=ROSSI_MARIO
\`\`\`

> 💡 **Modalità Interattiva**: puoi anche lanciare semplicemente \`task consegna\` senza parametri: ti chiederà interattivamente il tuo \`COGNOME_NOME\` prima di impacchettare il tutto!

Prima controlla che il progetto sia coerente (\`task check\`) e si ferma se non
lo è. Poi prepara la cartella \`consegna/\`:

| File | Cos'è |
| :--- | :--- |
| \`<modulo>/\` | i sorgenti di ogni modulo, **senza** \`target/\` |
| \`docker-compose.yml\`, \`Dockerfile\`, \`pom.xml\`, \`mvnw\`, \`.mvn/\` | accanto ai moduli, come nel progetto: lo stack riparte dai sorgenti |
| \`ALLEGATO-TECNICO.md\` | l'allegato, con dentro quello che si ricava dal progetto e quello che hai scritto tu |
| \`SCHEMA-DATABASE.md\` | lo schema concettuale e logico, letto dal database |
| \`ISTRUZIONI-ESECUZIONE.md\` | come farlo partire, con Docker e senza |
| \`ROSSI_MARIO.zip\` | tutto quanto sopra in un archivio solo: **è quello da consegnare** |

Dentro l'archivio non ci sono altri archivi: chi corregge lo scompatta, entra
nella cartella con \`docker-compose.yml\` e lancia \`docker compose up -d --build\`.

## L'allegato: metà lo scrive il comando, metà tu

| Sezione | Chi la scrive |
| :--- | :--- |
| 1. Analisi del problema | tu, in \`allegato.md\` sotto \`## Analisi\` |
| 2. Architettura: moduli, porte, nomi su Eureka | il comando, dal progetto |
| 3. Schema concettuale e logico | il comando, dal database (come \`task db-schema\`) |
| 4. I moduli: endpoint esposti | il comando, dai controller |
| 4. I moduli: che cosa fa ognuno | tu, sotto \`## <nome del modulo>\` |
| 5. L'algoritmo | tu, sotto \`## Algoritmo\` |
| 6. Istruzioni per il collaudo | il comando |
| 7. Risposte alle domande teoriche | tu, se le vogliono qui: \`## Domanda A\`, \`## Domanda B\` |

Il tuo testo sta in \`allegato.md\`, nella cartella del progetto, e non dentro
\`consegna/\`, che a ogni giro si rifà da zero. La prima consegna crea il file
con tutti i titoli pronti (se non l'hai già scritto alla [lettura della
traccia](06-leggere-la-traccia.md)); le successive ne prendono ogni sezione e
la mettono al suo posto **prima** di fare l'archivio. Quindi l'archivio ha
sempre dentro l'ultima versione del testo, e puoi rilanciare la consegna
quante volte vuoi. Un modulo nato dopo l'ultima consegna trova la sua sezione
aggiunta in fondo al file.

Alla fine il comando ti dice che cosa manca:

\`\`\`text
  ROSSI_MARIO.zip   41 KB   <- questo e' l'archivio da consegnare

  Nell'allegato mancano ancora: Algoritmo, biblioteca-ui.
  Scrivile in allegato.md, nella cartella del progetto, e rilancia
  task consegna: l'archivio si rifa' con dentro il testo.
\`\`\`

Una sezione lasciata fra parentesi quadre conta come da scrivere. Per la
Biblioteca, \`allegato.md\` finito è così (l'algoritmo è quello della
[lezione 11](11-algoritmo.md)):

\`\`\`markdown allegato.md
## Analisi

La biblioteca di quartiere informatizza catalogo e prestiti. Il bibliotecario
consulta i libri con autore, genere e disponibilita', registra un prestito
indicando l'email di chi prende il libro e la durata (30 giorni di norma, al
massimo 60), e registra la restituzione. Il sistema impedisce di prestare un
libro gia' fuori e calcola la penale per i ritardi.

## Algoritmo

Per ogni prestito si calcola il ritardo come il numero di giorni fra la data
di scadenza e la data di riferimento ...

## naming-server

Il registro Eureka: i servizi vi si registrano col loro nome e lo usano per
trovarsi, senza indirizzi scritti nel codice.

## catalogo-service

Tiene libri e autori su PostgreSQL (database biblioteca) e dice agli altri
servizi se un libro e' disponibile.

## prestiti-service

Registra prestiti e restituzioni su un database suo (prestiti), chiede i libri
al catalogo via Feign e calcola ritardo e penale.

## biblioteca-ui

L'interfaccia Thymeleaf: mostra catalogo e prestiti, registra un prestito con
un form validato e una restituzione con un bottone.
\`\`\`

## Provala come la proverà chi corregge

Prima di consegnare, fai tu la stessa prova: scompatta \`ROSSI_MARIO.zip\` in una
cartella nuova, fuori dal progetto, e da lì

\`\`\`bash
docker compose up -d --build
\`\`\`

(Se lo stack del progetto è acceso, prima \`task docker-down\`: userebbe le
stesse porte.) Apri la pagina, fai un prestito, poi spegni con
\`docker compose down -v\`. Se parte da lì, parte anche sul PC della commissione.

## Le domande teoriche

Valgono 4 punti ciascuna, e si scrivono meglio se le leghi al tuo progetto: ne
hai appena costruito uno che risponde a metà delle domande.

**Domanda A — Docker, Compose, sicurezza.** Container e macchina virtuale: il
container condivide il kernel dell'host, parte in secondi, pesa megabyte, isola
meno; la VM ha un sistema operativo intero. Compose: il tuo
\`docker-compose.yml\` è l'esempio — servizi, rete comune in cui si chiamano per
nome, volume per i dati di PostgreSQL, healthcheck e \`depends_on\` per l'ordine
di avvio. Sicurezza e federazione: Spring Security nei servizi, un identity
provider come Keycloak che rilascia token OAuth2/OpenID Connect (JWT), un API
Gateway come unico ingresso che li verifica e li inoltra.

**Domanda B — Relazionale o NoSQL, Java EE o Spring Boot.** Un database
relazionale ha uno schema, le transazioni ACID e le join (i libri e i loro
autori); un NoSQL rinuncia a qualcosa di questo per scalare in orizzontale o
per dati senza schema fisso. Nella Biblioteca, lo storico delle letture o le
recensioni starebbero bene in MongoDB, la disponibilità in una cache Redis.
Java EE (Jakarta EE) gira in un application server e si configura a
descrittori; Spring Boot ha il server dentro il jar, gli starter e la
configurazione automatica, e con Spring Cloud dà Eureka e Feign.

Il testo completo, da adattare, sta nella Guida 2: [svolgimento delle domande
teoriche](../../guida_prova_finale_spring_boot.md#9-svolgimento-completo-delle-domande-teoriche-a-e-b).

> **Fatto quando**
>
> - [ ] \`task consegna\` finisce dicendo che l'allegato è completo
> - [ ] hai scompattato l'archivio altrove e \`docker compose up -d --build\` parte
> - [ ] nell'archivio non ci sono cartelle \`target/\` né altri archivi
> - [ ] le due domande teoriche hanno una risposta legata al tuo progetto
` },
    { file: 'corso/lezioni/17-se-va-storto.md', testo: `# Quando qualcosa va storto

<!-- parte: C · Chiudere | quando: sempre | durata: da tenere aperta | obiettivo: Per ogni sintomo sai qual è il primo comando da lanciare, invece di fare ipotesi. -->

La regola è una: **prima guarda, poi pensa.** Quasi ogni problema si capisce
in trenta secondi con due comandi.

\`\`\`bash
task status
\`\`\`

\`\`\`bash
task logs SERVICE=<nome>
\`\`\`

Il primo dice chi è acceso, su che porta, chi occupa le porte che ti servono e
chi è registrato su Eureka. Il secondo ti mostra che cosa ha detto il servizio
che non va, col nome breve che vedi nel primo (\`catalogo\`, \`prestiti\`,
\`biblioteca-ui\`).

## Sintomo, e che cosa fare

| Sintomo | Che cosa fare |
| :--- | :--- |
| un servizio non risponde | \`task status\`, poi \`task logs SERVICE=<nome>\` |
| *Port 8081 was already in use* | \`task dev\`: chiude lui chi tiene la porta |
| su \`localhost:8080\` risponde un'altra applicazione | \`task dev\` la chiude; se ti serve viva, \`task dev KEEPFOREIGN=1 UI_PORT=9080\` |
| hai cambiato il codice e non cambia niente | \`task compile\`, e leggi se ci sono errori di compilazione |
| hai aggiunto una dipendenza o un modulo e non si vede | \`task dev\`: il classpath si fissa all'avvio |
| hai cambiato l'\`application.yml\` e non cambia niente | \`task dev\`: la configurazione si legge all'avvio |
| *Load balancer does not contain an instance for the service X* | aspetta 10 secondi; poi confronta il nome in \`@FeignClient\` con la dashboard di Eureka |
| \`FeignException$NotFound\` su un endpoint che esiste | il percorso nel client Feign non è quello del controller |
| un 500 dalla pagina | \`task logs SERVICE=biblioteca-ui\`: di solito è un servizio chiamato che ha dato errore, e lo dice |
| errori REST restituiscono 500 o stack trace invece di 400/404 | \`task new-handler SERVICE=<nome>\`: crea un \`@RestControllerAdvice\` che mappa le eccezioni in risposte JSON pulite |
| *password authentication failed* o *database "prestiti" does not exist* | il volume di PostgreSQL è vecchio: \`task docker-reset\` (cancella i dati), poi \`task dev\` |
| *release version 25 not supported* | il JDK è più vecchio del progetto: \`task set-java\` |
| una porta **RISERVATA** in \`task status\` | l'ha presa Windows (Docker Desktop, Hyper-V): \`task set-port\` per spostare il servizio |
| \`task docker-up\` si ferma su *unhealthy* | \`docker compose ps\` e \`docker compose logs <servizio>\` dalla cartella \`demo\` |
| la build Docker non scarica le immagini | \`task rete\`: se Docker Hub non passa, servono quelle della sera prima (\`task offline\`) |
| Maven non scarica una dipendenza nuova | \`task rete\`: se Maven Central non passa, vale solo la \`~/.m2\` |
| \`task\` non è un comando riconosciuto | \`. .\\scripts\\usa-task-locale.ps1\` (o \`source scripts/usa-task-locale.sh\`): c'è già una copia in \`.tools/task\`, se hai lanciato \`task offline-prep\` la sera prima |
| è tutto ingarbugliato | \`task dev-down\`, poi \`task dev\` |

## Due comandi da non usare

> **Attenzione**
>
> **\`task kill-java\`** chiude *tutti* i processi Java della macchina: anche
> l'editor, e con lui il lavoro non salvato. Serve solo se il resto ha fallito.
>
> **\`task docker-reset\`** durante la demo cancella il database, dati di prova
> compresi. Per spegnere si usa \`task docker-down\`.

## Per saperne di più

Le guide del progetto hanno una sezione per le emergenze: [Se qualcosa va
storto](../../GIORNO-ESAME.md#se-qualcosa-va-storto) nella procedura del giorno
d'esame, e il [cheat sheet delle
emergenze](../../guida_setup_e_cheatsheet.md#5-cheat-sheet-risoluzione-emergenze-esame)
della Guida 1.

> **Fatto quando**
>
> - [ ] sai che il primo comando è sempre \`task status\`
> - [ ] sai la differenza fra \`task compile\` e \`task dev\`
> - [ ] sai perché \`kill-java\` e \`docker-reset\` non si usano alla leggera
` },
    { file: 'corso/lezioni/18-sicurezza-e-autenticazione.md', testo: `# Lezione 18: Sicurezza e Autenticazione con Spring Security

Questa lezione ti spiega come padroneggiare **Spring Security** per l'esame: come funziona dietro le quinte, come configurare utenti e ruoli (in memoria o su database), come gestire il login (API REST o interfaccia web Thymeleaf) e come rispondere alle domande teoriche su OAuth2, Keycloak e JWT.

---

## 1. Come Funziona Spring Security: La Catena dei Filtri

Spring Security non è magia: è un insieme di filtri servlet (**Filter Chain**) posizionati davanti ai tuoi controller Spring MVC:

\`\`\`
Richiesta HTTP (Browser / Postman / Feign)
      │
      ▼
┌────────────────────────────────────────────────────────┐
│               SecurityFilterChain                      │
│                                                        │
│ 1. CsrfFilter: Controlla il token CSRF su POST/PUT/DEL │
│ 2. LogoutFilter: Intercetta /logout                   │
│ 3. UsernamePasswordAuthenticationFilter: /login       │
│ 4. BasicAuthenticationFilter: Header Authorization    │
│ 5. AuthorizationFilter: Verifica ruoli e permessi     │
└────────────────────────────────────────────────────────┘
      │
      ▼ (Se autorizzato)
DispatcherServlet ──> Tuo @RestController o @Controller
\`\`\`

Quando aggiungi \`spring-boot-starter-security\` al pom, Spring Boot attiva una configurazione predefinita molto severa:
1. **Blocca tutto con 401 Unauthorized**: qualsiasi endpoint richiede login.
2. **Genera una password alfanumerica a caso** nei log ad ogni riavvio.
3. **Attiva il controllo CSRF**: qualsiasi chiamata REST \`POST\`/\`PUT\`/\`DELETE\` viene bloccata con **403 Forbidden** se non possiede il token CSRF.

---

## 2. Le Due Modalità di Autenticazione all'Esame

La traccia d'esame richiede tipicamente una di queste due modalità:

### A. API REST (Microservizi Backend)
- Si usa l'autenticazione **HTTP Basic**: le credenziali viaggiano nell'header HTTP \`Authorization: Basic base64(user:pass)\`.
- Si **disabilita il CSRF** (\`csrf.disable()\`) perché le chiamate tra microservizi o da Swagger non mantengono sessioni cookie del browser.
- Si lasciano aperte in \`permitAll()\` le rotte tecniche (\`/swagger-ui/**\`, \`/v3/api-docs/**\`, \`/actuator/**\`, \`/h2-console/**\`).

### B. Web UI (Applicazione Frontend Thymeleaf)
- Si usa il **Form Login**: un form HTML (\`/login\`) in cui l'utente inserisce username e password.
- In caso di successo, Spring Security crea una **sessione HTTP** e salva l'utente loggato nel \`SecurityContext\`.
- Si predispone il logout (\`/logout\`) che invalida la sessione.
- Nei template HTML si mostrano/nascondono pulsanti in base al ruolo dell'utente loggato.

---

## 3. Il Comando Rapido: \`task new-auth\`

Per evitare di scrivere decine di righe di configurazione, usa \`task new-auth\`:

\`\`\`bash
# Modalità 1: In-Memory REST (per un microservizio di backend)
task new-auth SERVICE=ordini-service TYPE=inmemory

# Modalità 2: Database (Entity Utente + Repo + UserDetailsService + BCrypt)
task new-auth SERVICE=ordini-service TYPE=db

# Modalità 3: Form Login Web (per un modulo UI con login.html e sessioni)
task new-auth SERVICE=store-ui TYPE=form
\`\`\`

> 💡 **Modalità Interattiva**: puoi anche lanciare \`task new-auth\` senza argomenti. Ti mostrerà l'elenco dei moduli del progetto e ti farà scegliere quale tipo di sicurezza configurare (\`inmemory\`, \`db\`, \`form\`)!

---

## 4. Approfondimento Tecnico: Le Tre Architetture

### Architettura 1: Autenticazione In-Memory (Semplice & Veloce)

Ideale quando la traccia dice: *"Proteggi le API con credenziali admin e user"*.

\`\`\`java
// config/SecurityConfig.java
package esame.ordiniservice.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable()) // Obbligatorio per REST/Swagger
            .headers(headers -> headers.frameOptions(f -> f.disable())) // Per console H2
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/actuator/**", "/h2-console/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .httpBasic(httpBasic -> {}); // Abilita Basic Auth

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService userDetailsService(PasswordEncoder encoder) {
        UserDetails admin = User.builder()
            .username("admin")
            .password(encoder.encode("admin123"))
            .roles("ADMIN", "USER")
            .build();

        UserDetails user = User.builder()
            .username("user")
            .password(encoder.encode("user123"))
            .roles("USER")
            .build();

        return new InMemoryUserDetailsManager(admin, user);
    }
}
\`\`\`

---

### Architettura 2: Autenticazione su Database (Entity + Service)

Quando la traccia richiede che gli utenti siano persistiti su tabella SQL:

1. **Entità JPA (\`UtenteEntity.java\`)**:
   \`\`\`java
   @Entity
   @Table(name = "utenti")
   @Getter @Setter @NoArgsConstructor @AllArgsConstructor
   public class UtenteEntity {
       @Id
       @GeneratedValue(strategy = GenerationType.IDENTITY)
       private Long id;

       @Column(nullable = false, unique = true, length = 50)
       private String username;

       @Column(nullable = false, length = 100)
       private String password; // Conserva SEMPRE l'hash BCrypt, mai in chiaro!

       @Column(nullable = false, length = 50)
       private String ruolo; // es: "ROLE_ADMIN", "ROLE_USER"
   }
   \`\`\`

2. **Repository (\`UtenteRepository.java\`)**:
   \`\`\`java
   public interface UtenteRepository extends JpaRepository<UtenteEntity, Long> {
       Optional<UtenteEntity> findByUsername(String username);
   }
   \`\`\`

3. **\`UserDetailsService\` Personalizzato**:
   \`\`\`java
   @Service
   @RequiredArgsConstructor
   public class CustomUserDetailsService implements UserDetailsService {

       private final UtenteRepository utenteRepository;

       @Override
       public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
           UtenteEntity u = utenteRepository.findByUsername(username)
               .orElseThrow(() -> new UsernameNotFoundException("Utente non trovato: " + username));

           return new User(
               u.getUsername(),
               u.getPassword(),
               Collections.singletonList(new SimpleGrantedAuthority(u.getRuolo()))
           );
       }
   }
   \`\`\`

4. **Inizializzazione Dati**:
   In \`SecurityConfig\`, un bean \`CommandLineRunner\` inserisce gli utenti predefiniti con password hashata se la tabella è vuota:
   \`\`\`java
   @Bean
   public CommandLineRunner seedUsers(UtenteRepository repo, PasswordEncoder encoder) {
       return args -> {
           if (repo.count() == 0) {
               repo.save(new UtenteEntity(null, "admin", encoder.encode("admin123"), "ROLE_ADMIN"));
               repo.save(new UtenteEntity(null, "user", encoder.encode("user123"), "ROLE_USER"));
           }
       };
   }
   \`\`\`

---

### Architettura 3: Form Login Web con Thymeleaf

Per le applicazioni Web con interfaccia utente:

1. **Configurazione Spring Security**:
   \`\`\`java
   http
       .authorizeHttpRequests(auth -> auth
           .requestMatchers("/login", "/css/**", "/js/**", "/images/**", "/error").permitAll()
           .requestMatchers("/admin/**").hasRole("ADMIN")
           .anyRequest().authenticated()
       )
       .formLogin(form -> form
           .loginPage("/login")             // La nostra rotta personalizzata
           .defaultSuccessUrl("/", true)    // Dove andare dopo il login
           .permitAll()
       )
       .logout(logout -> logout
           .logoutUrl("/logout")
           .logoutSuccessUrl("/login?logout")
           .permitAll()
       );
   \`\`\`

2. **Controller (\`LoginController.java\`)**:
   \`\`\`java
   @Controller
   public class LoginController {
       @GetMapping("/login")
       public String login() {
           return "login"; // punta a templates/login.html
       }
   }
   \`\`\`

3. **Pagina HTML (\`templates/login.html\`)**:
   Deve contenere un form con metodo \`post\` verso \`@{/login}\`:
   \`\`\`html
   <form th:action="@{/login}" method="post">
       <!-- Se il login fallisce, Spring aggiunge ?error -->
       <div th:if="\${param.error}" class="alert-error">
           Credenziali non corrette!
       </div>
       <!-- Dopo il logout, Spring aggiunge ?logout -->
       <div th:if="\${param.logout}" class="alert-info">
           Disconnesso con successo.
       </div>

       <label>Username</label>
       <input type="text" name="username" required>

       <label>Password</label>
       <input type="password" name="password" required>

       <button type="submit">Accedi</button>
   </form>
   \`\`\`

---

## 5. Taglib di Sicurezza in Thymeleaf

Nel template del modulo UI (con \`thymeleaf-extras-springsecurity6\`), puoi mostrare elementi HTML condizionatamente al ruolo dell'utente:

Dichiara il namespace in cima all'HTML:
\`\`\`html
<html xmlns:th="http://www.thymeleaf.org"
      xmlns:sec="http://www.thymeleaf.org/extras/spring-security">
\`\`\`

### Esempi di utilizzo:

1. **Mostrare il nome dell'utente loggato**:
   \`\`\`html
   <span>Benvenuto, <strong sec:authentication="name">Utente</strong>!</span>
   \`\`\`

2. **Mostrare un pulsante solo agli amministratori**:
   \`\`\`html
   <div sec:authorize="hasRole('ADMIN')">
       <a href="/nuovo-prodotto" class="btn btn-danger">Crea Prodotto</a>
   </div>
   \`\`\`

3. **Mostrare un blocco solo se l'utente è anonimo (non loggato)**:
   \`\`\`html
   <div sec:authorize="isAnonymous()">
       <a href="/login">Accedi</a>
   </div>
   \`\`\`

4. **Pulsante di Logout con form POST (anti-CSRF)**:
   \`\`\`html
   <form th:action="@{/logout}" method="post" sec:authorize="isAuthenticated()">
       <button type="submit" class="btn-logout">Esci</button>
   </form>
   \`\`\`

---

## 6. Domande Teoriche d'Esame: Sicurezza & Microservizi

La domanda teorica A dell'esame include spesso concetti di sicurezza in architetture distribuite:

### 1. Come si gestisce l'autenticazione tra microservizi?
- **Infrastruttura Monolitica tradizionale**: sessioni server-side salvate in memoria o su database con cookie \`JSESSIONID\`. Non scala sui microservizi perché richiederebbe sessioni replicate tra tutti i container.
- **Infrastruttura a Microservizi**:
  - Si usa un **API Gateway** (es. Spring Cloud Gateway) come punto unico di ingresso.
  - L'autenticazione avviene al Gateway tramite un Identity Provider (IdP) come **Keycloak** o protocolli standard come **OAuth2 / OIDC (OpenID Connect)**.
  - Il Gateway valida le credenziali ed emette o propaga un token stateless **JWT (JSON Web Token)** contenente i claim dell'utente (username, ruoli, scadenza) firmato crittograficamente.
  - I microservizi interni (chiamati via Feign) ricevono il token JWT nell'header \`Authorization: Bearer <token>\` e possono validare i permessi in locale senza interrogare il database centrale.

### 2. Perché la password va sempre cifrata con BCrypt?
- BCrypt è una funzione di hashing a senso unico adattiva (*salted and stretched*). Include automaticamente un valore *salt* casuale per impedire attacchi basati su Rainbow Tables e permette di aumentare il fattore di costo computazionale (*work factor*) per resistere agli attacchi brute-force.
` }
  ],
  documenti: [
    { file: 'README.md', testo: `# Spring Boot Dockerized — Traccia svolta: Biblioteca di quartiere

Questo branch contiene la traccia **Biblioteca di quartiere** svolta per
intero sul template del branch
[\`main\`](https://github.com/daubog44/spring-boot-dockerized/tree/main): un
catalogo di libri e autori, un servizio dei prestiti con la penale per i
ritardi, un'interfaccia web, due database PostgreSQL, Eureka e Docker Compose.
È il filo del corso (\`task learn\`): ogni pezzo di codice che il corso mostra
sta qui, compilato e collaudato. Traccia, architettura, endpoint e collaudo
sono in **[README-ESAME-TTFCLOUD.md](./README-ESAME-TTFCLOUD.md)**.

\`\`\`bash
task dev
\`\`\`

\`\`\`bash
powershell -ExecutionPolicy Bypass -File test_e2e_biblioteca.ps1
\`\`\`

Il resto di questa pagina è il README del template. Nel template i servizi
della traccia si generano con un comando:

\`\`\`bash
task new-service NAME=ordini-service
\`\`\`

che crea il modulo *e* lo collega dove serve — pom aggregatore, Dockerfile,
docker-compose, lista di avvio — senza che tu debba ricordarti nessuno dei sei
posti. Dentro un modulo, ogni tabella si scrive con lo stesso schema (entity,
repository, service, controller): anche quello lo genera un comando,

\`\`\`bash
task new-entity SERVICE=ordini-service NAME=Ordine FIELDS=numero:string:required,totale:decimal
\`\`\`

e per i DTO condivisi, i client Feign, le viste Thymeleaf, la sicurezza e la gestione errori:

\`\`\`bash
task new-dto NAME=Ordine FIELDS=id:long,numero:string:required,totale:decimal
task new-client FROM=report-service TO=ordini-service DTO=OrdineDto FIELDS=id:long,numero:string:required
task new-view SERVICE=store-ui NAME=Ordini FIELDS=numero:string:required,totale:decimal
task new-auth SERVICE=ordini-service TYPE=db
task new-handler SERVICE=ordini-service
\`\`\`

e ti lascia aggiungere solo quello che conta davvero: le relazioni fra entity
e le regole della tua traccia.

---

## La prima cosa da fare

\`\`\`bash
task learn
\`\`\`

Apre il corso: una pagina statica (niente server, niente rete) con diciotto
lezioni dalla A alla Z — com'è fatto il template, come si parlano i servizi,
\`common-dto\`, le entity e i repository JPA con tutti gli esempi, la rete
dell'esame, e la traccia Biblioteca svolta pezzo per pezzo. Su **questo**
branch il codice della Biblioteca c'è già, in \`demo/\`: la mappa dei moduli che
il corso legge da \`task learn\` è la stessa che vedi qui, non un esempio da
un'altra parte. Sul template vuoto (branch \`main\`) è diverso: lì la mappa è
solo Eureka e \`common-dto\`, e il codice della Biblioteca nelle lezioni resta
un esempio da leggere, come spiega la lezione 1.

## Documentazione

- **[Il corso: Dalla traccia alla consegna](./corso/index.html)** — si apre con \`task learn\`, vedi sopra.
- **[Il giorno dell'esame: procedura operativa](./GIORNO-ESAME.md)** — le quattro fasi, dal clone alla demo.
- [La giornata alla lavagna](./corso/giornata.html) — la stessa giornata in nove fasi, con l'orologio dell'esame e una lavagna che legge le fasi ad alta voce. Il video lo registra la macchina: \`powershell -File corso/genera-video.ps1\` (voce italiana di Windows, Edge e ffmpeg) scrive \`corso/quaderno-esame.mp4\`, che resta fuori dal repository.
- [Guida 1: Setup & Cheat Sheet Emergenze](./guida_setup_e_cheatsheet.md)
- [Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot](./guida_prova_finale_spring_boot.md) — c'è anche **come funziona il tutto insieme**: il giro di una richiesta da browser a database, chi accende cosa (Lombok, Swagger, Feign, JPA/Hibernate) e come si usa \`common-dto\`, più il **cheat sheet di Thymeleaf** (§ 6.7: espressioni, attributi, form con validazione, frammenti, errori tipici)
- [Guida 3: Multi-Modulo Maven e Funzionamento](./guida_multi_modulo_maven.md)

Dal terminale, la guida ai comandi è \`task help\` (o \`task\` da solo); il
dettaglio di un comando singolo, con le sue variabili, è
\`task --summary <comando>\`.

---

## Branch

- **\`main\`**: il template vuoto. È da qui che si parte a ogni traccia.
- **[\`solution/wms\`](https://github.com/daubog44/spring-boot-dockerized/tree/solution/wms)**: soluzione completa della traccia **WMS magazzino** (product, crm, wms, wms-ui, calcolo distanza Manhattan, DTO condivisi, collaudo end-to-end).
- **[\`example/tourist-events\`](https://github.com/daubog44/spring-boot-dockerized/tree/example/tourist-events)**: esempio svolto della traccia **eventi/turismo** (wrapper OpenFeign di OpenDataHub, estrazione casuale, storico su PostgreSQL).
- **\`example/biblioteca\`** (questo): la traccia **Biblioteca di quartiere** svolta per intero, ed è il filo del corso (catalogo e prestiti con due database, Feign nei due sensi, penale per ritardo con i suoi test, interfaccia con form e restituzioni, collaudo end-to-end).

I branch svolti servono da riferimento: non serve copiarli, serve guardarli
quando non ricordi come si fa una cosa.

---

## Scaricarlo senza git

Ogni versione è una [release](https://github.com/daubog44/spring-boot-dockerized/releases/latest)
con quattro zip, pronti da scaricare e da passare a chi ti pare:

| Archivio | Cosa c'è |
| :--- | :--- |
| \`spring-boot-dockerized.zip\` | il template vuoto: è da qui che si parte a ogni traccia |
| \`soluzione-wms.zip\` | la traccia WMS svolta (branch \`solution/wms\`) |
| \`esempio-tourist-events.zip\` | l'esempio eventi/turismo (branch \`example/tourist-events\`) |
| \`esempio-biblioteca.zip\` | la traccia Biblioteca svolta, quella del corso (branch \`example/biblioteca\`) |

Il link al template dell'ultima versione non cambia mai, si può condividere
così com'è:

\`\`\`text
https://github.com/daubog44/spring-boot-dockerized/releases/latest/download/spring-boot-dockerized.zip
\`\`\`

Scompatti, apri la cartella nel terminale, \`task help\`. Servono un JDK (dal 17
in su), Docker e go-task, come col clone. Il template nasce su Java 25: se il
tuo è un altro, \`task wizard\` (o \`task set-java\`) allinea il progetto al JDK
che trova in \`JAVA_HOME\` o, se manca, nel \`PATH\`.

**Pubblicare una versione nuova** (dopo il push di \`main\` e dei branch):

\`\`\`bash
git tag v1.2.5
git push origin v1.2.5
\`\`\`

Il resto lo fa la GitHub Action [\`release.yml\`](./.github/workflows/release.yml):
prepara i quattro zip dai branch e crea la release col tag.

---

## Cosa c'è nel template

Aggregatore Maven multi-modulo dentro \`demo/\`:

| Modulo | A cosa serve |
| :--- | :--- |
| \`naming-server\` | Eureka Server, porta \`8761\`. I servizi si registrano qui e si chiamano per nome. |
| \`common-dto\` | Le classi condivise fra i servizi (DTO). Un modulo solo, così non si duplicano. |

E, già pronto e configurato per i moduli che creerai:

- **Spring Boot 4.0.5** e **Spring Cloud 2025.1.1** con le versioni gestite dal pom padre: nei moduli le dipendenze si scrivono senza versione.
- **spring-boot-devtools** ereditato da tutti i moduli: hot reload dopo \`task compile\`.
- **springdoc-openapi**: ogni modulo creato da \`task new-service\` espone \`/swagger-ui.html\` dal primo avvio, senza configurazione (per gli altri c'è \`task enable-swagger\`).
- **PostgreSQL** in \`docker-compose.yml\` (database \`esame\`, utente e password \`exam\`): c'è un container, **non collegato a niente** finché non lo chiedi. I moduli generati partono con H2 in memoria; \`task use-postgres SERVICE=<modulo>\` sposta un modulo sul database vero, e con \`DBNAME=\` gliene dà uno tutto suo dentro lo stesso container.
- **Dockerfile unico** parametrico sul modulo: un'immagine per servizio, senza un Dockerfile per cartella.
- **Configurazione degli editor** gia' pronta e **mantenuta dai comandi**: \`.vscode/launch.json\` (un profilo di debug per servizio, piu' il compound *Stack completo*), \`.vscode/tasks.json\` e \`.zed/tasks.json\` (i comandi \`task\` dalla palette), piu' \`settings.json\`, \`extensions.json\` e \`.editorconfig\`. Li riscrivono \`new-service\`, \`remove-service\` e \`set-port\`; se restano indietro lo dice \`task check\`.
- **Pacchetto Java corto**: i sorgenti di un modulo stanno in \`src/main/java/esame/<modulo>/\`, non in \`com/example/...\`. La base si cambia per tutti i moduli con \`task set-package PACKAGE=it.cognome\` (lo chiede anche il wizard), e \`new-service\` la segue.
- **La versione di Java della macchina**: \`task set-java\` allinea pom, immagini Docker e VS Code al JDK installato (dal 17 in su); il wizard lo fa da solo all'inizio, e \`task check\` avvisa se il JDK è più vecchio del progetto.

---

## Come si lavora

Il giorno dell'esame, letta la traccia, il modo più rapido per montare il
progetto è il wizard: allinea Java al JDK della macchina, poi chiede come si
chiama la cartella dei moduli, il pacchetto Java di base, se serve PostgreSQL
e con quali credenziali, e i microservizi uno per uno.

\`\`\`bash
task wizard
\`\`\`

Per un microservizio solo: \`task wizard SERVICE=<nome>\`. Non fa niente di
magico: chiama \`set-java\`, \`rename-project\`, \`set-package\`, \`db-config\`,
\`new-service\` e \`use-postgres\` nell'ordine giusto, e finisce con \`task check\`.

Poi, una volta sola:

\`\`\`bash
task dev
\`\`\`

Libera le porte, compila e avvia in background quello che c'è, con hot reload.
Restituisce il prompt: niente finestre sparse da inseguire.

Poi il ciclo della giornata:

> scrivi il codice → \`task compile\` → il servizio si riavvia da solo

I log di tutti i servizi, in un terminale solo:

\`\`\`bash
task logs
\`\`\`

Quando qualcosa non risponde, prima di formulare ipotesi:

\`\`\`bash
task status
\`\`\`

Dice porta per porta chi è in ascolto — un tuo servizio, i container, o
un'applicazione estranea — e cosa si è registrato su Eureka.

### Quando cambia la struttura

Aggiungere un modulo o una dipendenza, o spostare una porta, tocca più file che
devono restare d'accordo. Un comando per ognuna di queste cose:

\`\`\`bash
task new-service NAME=ordini-service
\`\`\`

\`\`\`bash
task new-entity SERVICE=ordini-service NAME=Ordine FIELDS=numero:string:required,totale:decimal
\`\`\`

\`\`\`bash
task new-dto NAME=Ordine FIELDS=id:long,numero:string:required,totale:decimal
\`\`\`

\`\`\`bash
task new-client FROM=report-service TO=ordini-service DTO=OrdineDto
\`\`\`

\`\`\`bash
task new-view SERVICE=store-ui NAME=Ordini FIELDS=numero:string:required,totale:decimal
\`\`\`

\`\`\`bash
task new-auth SERVICE=ordini-service TYPE=db
\`\`\`

\`\`\`bash
task new-handler SERVICE=ordini-service
\`\`\`

\`\`\`bash
task add-dep SERVICE=ordini-service DEPS=security,mail
\`\`\`

\`\`\`bash
task set-port SERVICE=ordini-service PORT=8090
\`\`\`

\`\`\`bash
task remove-service SERVICE=ordini-service
\`\`\`

\`\`\`bash
task use-postgres SERVICE=ordini-service
\`\`\`

\`\`\`bash
task enable-swagger SERVICE=ordini-service
\`\`\`

\`\`\`bash
task db-config DBNAME=magazzino USER=wms PASSWORD=wms123
\`\`\`

\`\`\`bash
task rename-project NAME=wms
\`\`\`

Tutti si usano con variabili \`NOME=valore\`, mai con trattini. Dopo una
dipendenza o un modulo nuovo ci vuole \`task dev\`: \`task compile\` non basta,
perché il classpath di un servizio è fissato quando parte.

Due comandi di controllo:

\`\`\`bash
task check
\`\`\`

Verifica, senza avviare niente, che moduli, porte, Dockerfile, compose e liste
di avvio dicano la stessa cosa.

\`\`\`bash
task test
\`\`\`

Collauda gli strumenti stessi su una copia usa-e-getta del progetto. Lancialo
appena ti siedi: se passa, sai che funzionano quando ti serviranno.

### L'editor

Apri **la cartella del repository**, non quella di un singolo servizio: e' un
progetto Maven multi-modulo.

- **VS Code**: \`F5\` → **Stack completo** avvia tutti i servizi in debug, Eureka
  per primo. Serve l'*Extension Pack for Java*; le altre estensioni consigliate
  te le propone VS Code stesso (\`.vscode/extensions.json\`).
- **Zed**: \`F4\` → il servizio da avviare in debug (\`.zed/debug.json\`); palette
  → *task: Spawn* per i comandi \`task\`. Serve l'estensione *Java*, che al primo
  file \`.java\` scarica jdtls, Lombok e il debugger: la prima volta, con la rete.
- **IntelliJ IDEA**: niente da configurare, apri il pom aggregatore.

Se l'elenco dei servizi non torna (hai toccato i moduli a mano):

\`\`\`bash
task ide-sync
\`\`\`

### Il database e la consegna

Scritte le entity, due comandi le mettono al lavoro. Tutti e due passano dal
database vero, non dalla lettura dei sorgenti: avviano l'applicazione, lasciano
che Hibernate crei le tabelle e lavorano su quelle.

\`\`\`bash
task seed-data
\`\`\`

Accende i dati di prova: a ogni avvio le tabelle vuote si riempiono da sole
con righe plausibili, salvate passando da Hibernate, quindi con id, relazioni,
enum e vincoli di validazione rispettati. Prima prova su un H2 usa-e-getta e
ti dice tabella per tabella com'è andata. Una demo su tabelle vuote non si
vede.

\`\`\`bash
task db-schema
\`\`\`

Lo schema concettuale e logico della base dati — entità e relazioni, tabelle,
colonne, tipi SQL, chiavi, vincoli e un diagramma ER — letto dal database dopo
che Hibernate l'ha creato, non ricordato a memoria. È quello che chiede
l'allegato tecnico.

\`\`\`bash
task consegna NOME=COGNOME_NOME
\`\`\`

Prepara \`consegna/\`: il progetto pronto da eseguire (i moduli senza \`target/\`,
accanto a pom e compose), l'allegato tecnico già compilato con moduli, porte,
endpoint e schema, le istruzioni di esecuzione, e un archivio unico da
consegnare. Chi lo corregge lo scompatta e lancia \`docker compose up --build\`.
Le parti da scrivere a mano (analisi, algoritmo, che cosa fa ogni modulo)
stanno in \`allegato.md\`: la consegna le mette nell'allegato prima di fare
l'archivio, e si può rilanciare quante volte si vuole.

### La rete all'esame

All'esame la rete passa da una whitelist di domini: Maven Central sì, il
resto non si sa.

\`\`\`bash
task rete
\`\`\`

Dice, dominio per dominio (Maven Central, Docker Hub, Ubuntu, GitHub, le
estensioni di VS Code), se risponde e che cosa fare se no. La sera prima, con
la connessione di casa, \`task offline-prep\` scarica quello che potrebbe non
passare: le dipendenze Maven, anche quelle dei moduli che creerai, le immagini
Docker, una prima build dei container e una copia di scorta del comando
\`task\` stesso (in \`.tools/task\`, per quando GitHub non passa o la macchina
dell'esame non ce l'ha: si attiva con \`scripts/usa-task-locale.ps1\`/\`.sh\`).
\`task offline\` verifica. Portati la cartella del progetto e la \`~/.m2\` su una
chiavetta: il template *è* la cartella, non serve altro.

### Per la demo

\`\`\`bash
task docker-up
\`\`\`

Lo stack in container, che è quello che presenterai. Non devi fermare niente
prima: \`docker-up\` spegne da solo lo stack locale, e \`task dev\` spegne da solo i
container. Alla fine \`task docker-down\` (i dati del database restano;
\`docker-reset\` invece li cancella).

---

## Porte

| Indirizzo | Cosa |
| :--- | :--- |
| \`http://localhost:8761\` | Dashboard Eureka |
| \`localhost:5432\` | PostgreSQL (db \`esame\`, utente \`exam\`, password \`exam\`) |
| \`http://localhost:<porta>/swagger-ui.html\` | Swagger di un servizio |

Le porte dei servizi che crei le assegna \`task new-service\` (la prima libera
dopo l'ultima usata) e le stampa \`task dev\` alla fine dell'avvio. Per cambiarne
una: \`task set-port SERVICE=<modulo> PORT=<porta>\`.

> Se su una porta gira un'applicazione che ti serve viva, dillo:
> \`task dev KEEPFOREIGN=1 UI_PORT=9080\`. Senza \`KEEPFOREIGN=1\` viene chiusa.

---

## 🩺 Troubleshooting

### \`dependency failed to start: container <cartella>-eureka-server-1 is unhealthy\`

Sintomo: \`task docker-up\` fallisce, il container di \`eureka-server\` risulta \`unhealthy\` e nessun microservizio parte, anche se nei log Eureka scrive regolarmente \`Started Eureka Server\`.

Causa: l'healthcheck di \`eureka-server\` invoca \`curl\` su \`/actuator/health\`, ma l'immagine runtime \`eclipse-temurin:25-jre\` **non include \`curl\`**. Ogni probe fallisce con \`curl: not found\`, il container resta \`unhealthy\` e tutti i servizi con \`depends_on: condition: service_healthy\` non vengono mai avviati.

Il \`demo/Dockerfile\` di questo repo installa già \`curl\` nello stage runtime, quindi il problema non si presenta. Se aggiungi un healthcheck HTTP a un altro servizio, ricordati che vale la stessa regola.

Per capire *perché* un healthcheck non passa, leggi l'output delle probe (dalla cartella dei moduli, quella con \`docker-compose.yml\`):

\`\`\`bash
docker inspect $(docker compose ps -q eureka-server) --format "{{json .State.Health}}"
\`\`\`

### Su \`http://localhost:8080\` risponde qualcos'altro

Sintomo: il browser mostra una pagina che non è la tua (\`Method Not Allowed\`, un errore di un altro server, una app che non c'entra), anche se i servizi risultano avviati.

Causa: un'altra applicazione della macchina è in ascolto su \`127.0.0.1:8080\`. Su Windows il bind più specifico vince su quello generico, quindi \`http://localhost:8080\` finisce a quel processo anche quando Docker pubblica la porta su \`0.0.0.0\`. Se invece è lo stack locale a dover partire, Tomcat non riesce nemmeno a fare il bind e il servizio muore con \`Web server failed to start. Port 8080 was already in use\`.

\`\`\`bash
task status
\`\`\`

Elenca ogni processo in ascolto sulle porte dello stack e segnala esplicitamente questo caso. \`task dev\` chiude da solo quel processo al prossimo avvio; se invece ti serve tenerlo vivo, sposta la UI con \`task dev KEEPFOREIGN=1 UI_PORT=9080\`.

### Altri controlli utili

\`\`\`bash
docker compose ps
\`\`\`

\`\`\`bash
docker compose logs eureka-server --tail 50
\`\`\`

Per verificare quali servizi si sono effettivamente registrati su Eureka:

\`\`\`bash
docker compose exec eureka-server curl -s -H "Accept: application/json" http://localhost:8761/eureka/apps
\`\`\`

I container non hanno un nome fisso: Docker Compose li chiama \`<progetto>-<servizio>-1\`, e il progetto è la cartella del repository (lo impostano il Taskfile e gli script). Così la copia di prova e quella dell'esame hanno container e volume del database loro, anche con credenziali diverse. Per questo i comandi qui sopra usano il nome del **servizio** (\`eureka-server\`, \`postgres\`), e vanno lanciati dalla cartella dei moduli; fuori da \`task\`, \`docker compose\` usa il nome della cartella dei moduli, quindi aggiungi \`-p <cartella-del-repository>\`.
` },
    { file: 'GIORNO-ESAME.md', testo: `# Il giorno dell'esame — procedura operativa

Questa pagina è pensata per essere aperta e seguita, non ricordata. Se hai un
minuto solo, leggi le **quattro fasi** qui sotto e ignora il resto finché non
serve. Per imparare prima, con calma e col codice di una traccia svolta,
c'è il corso: \`task learn\`.

---

## La sera prima — la rete dell'esame

All'esame la rete c'è, ma filtrata: una whitelist di domini lascia passare
Maven Central, quindi Maven scarica le dipendenze come a casa. Degli altri
domini non si sa niente finché non ci provi: Docker Hub (le immagini di base),
i repository di Ubuntu (\`curl\` dentro l'immagine, alla prima build), GitHub, le
estensioni degli editor. Quello che potrebbe non passare va scaricato
**adesso**, con la connessione di casa.

Un comando solo, e ci mette qualche minuto:

\`\`\`bash
task offline-prep
\`\`\`

Scarica anche una copia del comando \`task\` stesso, dentro \`.tools/task\`: se
sulla macchina dell'esame non c'è o GitHub non passa dalla whitelist, l'hai
già nella cartella del progetto. Se \`task\` non risponde, attivala con
\`. .\\scripts\\usa-task-locale.ps1\` (o \`source scripts/usa-task-locale.sh\`) —
col punto davanti, altrimenti l'effetto sparisce subito.

Poi scarica le dipendenze Maven, compila una volta, scarica le immagini Docker
e fa una prima \`docker compose build\` (che riempie la cache dei livelli,
compreso quello che installa \`curl\` dentro l'immagine: senza rete non si
potrebbe più fare). Alla fine verifica:

\`\`\`bash
task offline
\`\`\`

Deve dire **Tutto pronto**. Se dice che manca qualcosa, hai ancora la rete per
rimediare. Guarda anche le righe dell'editor: l'estensione Java di Zed scarica
jdtls, Lombok e il debugger al primo file \`.java\` che apri, quindi aprine uno
**adesso**.

**Portati il progetto su una chiavetta.** Non serve un \`.exe\` né un
generatore: il template *è* la cartella, e i comandi stanno tutti dentro. Copia
sulla chiavetta:

| Cosa | Perché |
| :--- | :--- |
| la cartella del progetto, \`.git\` compreso | è il template, e con \`.git\` puoi tornare indietro con \`git checkout .\` |
| la cartella \`~/.m2/repository\` | le dipendenze Maven, se Maven Central non dovesse passare |
| l'installatore del JDK e di Docker Desktop | solo se non sei sicuro della macchina d'esame (\`task\` non serve: c'è già in \`.tools/task\`) |

Sul portatile d'esame: copi la cartella dove vuoi, copi \`.m2\` dentro la tua
home, e sei operativo. Il nome della cartella che contiene tutto non lo guarda
nessuno script: rinominala pure a mano.

> Se GitHub passa (\`task rete\` te lo dice), \`git clone\` resta la strada più
> veloce. Ma non contarci.

**Come presentare se Docker Hub non passa**, in ordine di sicurezza:

1. \`task dev\` per i servizi e \`task run-db\` per il solo PostgreSQL: Maven
   lavora offline dalla \`~/.m2\` e Docker deve solo far partire un'immagine che
   hai già. È il modo che regge meglio.
2. \`task docker-up\`: ricostruisce le immagini, quindi rifà anche i passaggi
   Maven **dentro** il container. Funziona se hai lanciato \`task offline-prep\`
   (la cache di Maven del Dockerfile sopravvive fra una build e l'altra), ma
   dipende da più cose.

---

## Fase 0 — Prima di scrivere una riga di codice (10 minuti)

Fallo appena ti siedi, non quando ti serve. Prima di tutto, che cosa passa
dalla rete dell'aula:

\`\`\`bash
task rete
\`\`\`

Dominio per dominio, dice se risponde e che cosa fare se no. Se GitHub passa:

\`\`\`bash
git clone https://github.com/daubog44/spring-boot-dockerized.git
\`\`\`

\`\`\`bash
cd spring-boot-dockerized
\`\`\`

Altrimenti copia dalla chiavetta la cartella del progetto e la cartella
\`.m2\` dentro la tua home (vedi *La sera prima*), poi entra nella cartella e
controlla di essere a posto:

\`\`\`bash
task offline
\`\`\`

Poi un giro a vuoto, che serve a scaldare tutto **prima** di averne bisogno:

\`\`\`bash
task dev
\`\`\`

\`\`\`bash
task dev-down
\`\`\`

Se questi due comandi funzionano, il resto della giornata è in discesa. Se
falliscono, hai ancora tutto il tempo per capire perché.

Poi, una volta sola, un giro di prova degli strumenti (dura una decina di
secondi e non tocca il progetto):

\`\`\`bash
task test
\`\`\`

Se passa, sai che \`new-service\`, \`add-dep\` e \`set-port\` funzionano su questa
macchina: quando ti serviranno, non dovrai scoprirlo.

> Le porte le libera \`task dev\` da solo, chiudendo quello che le tiene occupate:
> non devi controllare niente prima.

---

## Fase 0-bis — Il wizard, per montare il progetto della traccia

Letta la traccia, sai quanti microservizi ti servono e che cosa fa ognuno. Un
comando solo li mette tutti in piedi, facendoti le domande giuste:

\`\`\`bash
task wizard
\`\`\`

Prima di tutto, senza chiedere niente, **allinea Java al JDK di questo PC**:
se il progetto è su Java 25 e sulla macchina del laboratorio c'è Java 21,
passa a 21 il pom, le immagini Docker e VS Code (\`task set-java\`). Se il JDK
è più vecchio di 17, il minimo di Spring Boot 4, te lo dice e lascia stare.

Poi ti chiede, nell'ordine:

1. **come si chiama la cartella con i moduli Maven** — di default \`demo\`,
   perché così nasce da Spring Initializr; dagli il nome del progetto e la
   rinomina ovunque sia scritta (Taskfile, script, guide);
2. **il pacchetto Java di base** — di default \`esame\`, così i sorgenti stanno
   in \`src/main/java/esame/<modulo>/\`; se la traccia o il docente vogliono
   \`it.cognome\`, scrivilo qui e sposta tutto (\`task set-package\`);
3. **se il progetto usa PostgreSQL**, e con quale database, utente, password e
   porta — se sul PC la 5432 è già occupata (nei laboratori capita, con un
   PostgreSQL installato) te ne propone un'altra;
4. **i microservizi, uno per uno**: nome, che cos'è (servizio REST con
   database, servizio REST senza, interfaccia Thymeleaf), su quale porta, e se
   usa H2 in memoria o PostgreSQL — condiviso o tutto suo.

Alla fine lancia \`task check\` da solo. Non fa niente di magico: chiama
\`set-java\`, \`rename-project\`, \`set-package\`, \`db-config\`, \`new-service\` e
\`use-postgres\` nell'ordine giusto, gli stessi comandi che puoi dare a mano.

Per un microservizio solo, quando la traccia te ne fa venire in mente un altro
a metà giornata:

\`\`\`bash
task wizard SERVICE=spedizioni-service
\`\`\`

Quello che vale per **tutti** i servizi non te lo chiede, perché non c'è niente
da decidere: Eureka, OpenFeign, Swagger, Lombok, validation, actuator e
\`common-dto\` sono già nel modulo appena nasce.

---

## L'editor: VS Code, Zed, IntelliJ

Il progetto si apre **dalla cartella del repository**, non da quella di un
singolo servizio: è un progetto Maven multi-modulo, e l'editor deve vedere il
pom aggregatore per capirlo.

### VS Code

Nel repository ci sono già:

| File | Cosa fa |
| :--- | :--- |
| \`.vscode/launch.json\` | una configurazione di debug per servizio, più il compound **Stack completo** che li avvia tutti in ordine (Eureka per primo) |
| \`.vscode/tasks.json\` | i comandi \`task\` dalla palette: \`Ctrl+Shift+P\` → *Tasks: Run Task* |
| \`.vscode/settings.json\` | salvataggio automatico (senza, l'hot reload di \`task compile\` non si accorge di niente), \`target/\` nascosto dalla ricerca |
| \`.vscode/extensions.json\` | le estensioni consigliate: \`Ctrl+Shift+P\` → *Extensions: Show Recommended Extensions* |

L'unica indispensabile è **Extension Pack for Java**: senza, il tasto Debug non
esiste. Le altre (Spring Boot Extension Pack, Docker, YAML, Task) fanno comodo
ma non sono obbligatorie.

Premi \`F5\`, scegli **Stack completo** e hai tutti i servizi in debug, con i
breakpoint che funzionano. Se invece ti basta vederli girare, \`task dev\` resta
più leggero.

> \`launch.json\` e \`tasks.json\` (e i loro gemelli di Zed) sono **generati**: li riscrivono \`new-service\`,
> \`remove-service\` e \`set-port\`. Se li modifichi a mano, le modifiche si
> perdono al comando successivo. \`settings.json\` ed \`extensions.json\` no: quelli
> sono tuoi.

### Zed

| File | Cosa fa |
| :--- | :--- |
| \`.zed/debug.json\` | una configurazione di debug per servizio: \`F4\` e scegli quale avviare |
| \`.zed/tasks.json\` | i comandi \`task\` dalla palette: *task: Spawn* |
| \`.zed/settings.json\` | Java formattato al salvataggio, \`target/\` fuori dall'indice, jdtls che non va a cercare aggiornamenti |

Serve l'estensione **Java** (palette → *zed: extensions*). Al primo file
\`.java\` che apri scarica tre cose: \`jdtls\` (autocompletamento, errori,
navigazione fra i moduli), Lombok e il debugger. **Fallo la sera prima, con la
rete**: poi le impostazioni del progetto (\`"check_updates": "once"\`) dicono a
Zed di usare quello che ha già, e \`task offline\` ti conferma che c'è.

Il debug è quello vero, con i breakpoint, ma un servizio per volta: Zed non ha
il compound *Stack completo*. Se ti serve tutto lo stack in debug insieme, VS
Code (\`F5\` → *Stack completo*) resta la strada più corta.

### IntelliJ IDEA

Non c'è niente da configurare: *File → Open* sulla cartella del repository,
IntelliJ riconosce il pom aggregatore e importa i moduli da solo. Le
configurazioni di avvio se le crea lui quando apri una classe \`Main\`.

### Se l'elenco dei servizi non torna

\`\`\`bash
task ide-sync
\`\`\`

Riscrive \`launch.json\`, \`debug.json\` e i due \`tasks.json\` leggendo i moduli veri: trova la
classe \`Main\` nei sorgenti (quindi funziona anche per un modulo scritto a mano)
e la porta nell'\`application.yml\`. Serve solo se hai toccato i moduli senza
passare dai comandi; se il \`launch.json\` resta indietro, te lo dice \`task check\`.

---

## Fase 1 — Sviluppo: il ciclo che ripeterai tutto il giorno

Questo branch ha la traccia Biblioteca già svolta: \`catalogo-service\`,
\`prestiti-service\` e \`biblioteca-ui\`, oltre a Eureka e \`common-dto\`. Nel
template vuoto (\`main\`) i servizi della traccia li crei tu, un comando per
uno:

\`\`\`bash
task new-service NAME=ordini-service
\`\`\`

\`\`\`bash
task new-service NAME=ordini-ui UI=1
\`\`\`

Il primo ti dà un servizio REST (con JPA, H2 e Swagger già collegati), il
secondo una UI Thymeleaf. Entrambi si registrano su Eureka e possono chiamarsi
per nome con Feign. Poi:

\`\`\`bash
task dev
\`\`\`

Compila tutto, avvia i servizi **in background** e ti restituisce il prompt.
Nessuna finestra sparsa da inseguire.

In un **secondo** terminale, se vuoi vedere cosa succede:

\`\`\`bash
task logs
\`\`\`

Ogni riga è prefissata dal nome del servizio e colorata. \`Ctrl+C\` chiude solo
questa vista: i servizi restano accesi. Per seguirne uno solo:
\`task logs SERVICE=<nome>\`, con il nome breve che vedi in \`task status\`.

Poi il ciclo è **solo questo**:

> scrivi il codice → \`task compile\` → il servizio si riavvia da solo in ~5 secondi

\`\`\`bash
task compile
\`\`\`

**Non rilanciare \`task dev\` a ogni modifica.** Ti serve solo quando cambi
qualcosa che un riavvio a caldo non copre: un \`application.yml\`, una porta, una
dipendenza, un modulo nuovo. Per quei casi c'è un comando apposta: vedi
[Modifiche strutturali](#modifiche-strutturali-dipendenze-porte-moduli).
Puoi lanciarlo quando vuoi, fa pulizia da solo.

Quando qualcosa non risponde, **prima di formulare ipotesi**:

\`\`\`bash
task status
\`\`\`

Ti dice, porta per porta, chi è in ascolto: un tuo servizio, i container, o
un'applicazione estranea. E cosa si è registrato su Eureka.

---

## Modifiche strutturali: dipendenze, porte, moduli

Queste cose non le copre il ciclo \`task compile\`, perché toccano più file che
devono restare d'accordo fra loro. Per ognuna c'è un comando, e tutti si usano
allo stesso modo: **variabili \`NOME=valore\`, senza trattini**.

\`task help\` (o \`task\` da solo) stampa l'elenco; \`task --summary <comando>\` il
dettaglio di uno.

### Aggiungere una dipendenza a un microservizio

\`\`\`bash
task add-dep SERVICE=ordini-service DEPS=security,mail
\`\`\`

Le versioni **non si scrivono**: le decide il \`pom.xml\` padre, che eredita da
Spring Boot e importa il BOM di Spring Cloud. Per questo una dipendenza si
aggiunge con il solo nome.

I nomi brevi riconosciuti (\`web\`, \`data-jpa\`, \`security\`, \`feign\`, \`kafka\`,
\`postgresql\`, ...) li stampa:

\`\`\`bash
task add-dep LIST=1
\`\`\`

Se ti serve qualcosa che non è in elenco, passa le coordinate per esteso:
\`task add-dep SERVICE=ordini-service DEPS=org.apache.commons:commons-lang3:3.17.0\`.

> **Poi serve \`task dev\`, non \`task compile\`.** Il classpath di un servizio è
> fissato quando parte: un jar nuovo lo vede solo un riavvio vero. Vale per
> ogni dipendenza aggiunta e per ogni modulo nuovo.

\`devtools\` non serve aggiungerlo: è già nel pom padre, quindi ce l'hanno tutti
i moduli — è lui a dare l'hot reload dopo \`task compile\`.

### Cambiare una porta

\`\`\`bash
task set-port SERVICE=ordini-service PORT=8090
\`\`\`

Una porta è scritta in quattro punti: l'\`application.yml\` del modulo,
\`docker-compose.yml\` (variabile d'ambiente **e** pubblicazione) e la lista dei
servizi in \`dev.ps1\` e \`dev.sh\`. Cambiarne tre su quattro dà il caso peggiore:
in locale funziona e in Docker no, o viceversa. Il comando li cambia tutti, e
ti elenca i punti che restano (collaudo e documentazione) perché li guardi tu.

Il **codice Java non contiene porte**: i servizi si chiamano per nome via
Eureka e Feign, quindi spostare una porta non rompe nessuna chiamata. Anche
spostare Eureka funziona: il comando aggiorna il \`defaultZone\` di tutti.

Per una prova al volo, senza toccare i file, resta \`task dev UI_PORT=9080\`.

### Aggiungere un microservizio

\`\`\`bash
task new-service NAME=ordini-service
\`\`\`

Crea il modulo (pom, \`Main\`, \`application.yml\`, un endpoint \`/api/ping\`) e lo
collega dove serve: \`<modules>\` del pom aggregatore, \`COPY\` nel \`Dockerfile\`,
blocco in \`docker-compose.yml\`, lista dei servizi di \`task dev\`. La porta è la
prima libera, se non la passi tu con \`PORT=\`.

Varianti: \`UI=1\` per un modulo Thymeleaf invece di un servizio REST, \`NODB=1\`
per un servizio senza JPA.

Poi \`task dev\`, e il servizio nuovo si registra su Eureka con gli altri.

### Generare Entity, Repository, Service e Controller: task new-entity

Invece di scrivere a mano le classi ripetitive di ogni tabella:

\`\`\`bash
task new-entity SERVICE=ordini-service NAME=Ordine FIELDS=numero:string:required,totale:decimal:required,data:date
\`\`\`

Genera le quattro classi canoniche nello standard del progetto:
- \`OrdineEntity.java\` con annotazioni JPA e validazione Jakarta.
- \`OrdineRepository.java\` che estende \`JpaRepository\`.
- \`OrdineService.java\` con il CRUD pronto.
- \`OrdineController.java\` con gli endpoint REST documentati in OpenAPI/Swagger.

### Contratti DTO e Feign Client in un solo comando: task new-client e task new-dto

I microservizi non condividono le entity: si scambiano DTO definiti nel modulo \`common-dto\`.
Per collegare due microservizi:

\`\`\`bash
task new-client FROM=report-service TO=ordini-service DTO=OrdineDto FIELDS=id:long,numero:string:required,totale:decimal
\`\`\`

Se passi \`FIELDS=...\` o se il DTO non esiste ancora in \`common-dto\`, il comando genera automaticamente il record Java \`OrdineDto\` con validazione in \`common-dto\` e crea subito dopo il \`@FeignClient\` dentro \`FROM\`.
Per generare solo un DTO: \`task new-dto NAME=ProdottoDto FIELDS=...\`.

### Pagine Web Thymeleaf: task new-view

Se stai lavorando su un modulo UI (\`task new-service NAME=web-ui UI=1\`):

\`\`\`bash
task new-view SERVICE=web-ui NAME=Ordini FIELDS=numero:string:required,totale:decimal
\`\`\`

Genera:
- \`OrdiniController.java\` con \`@Controller\` per le rotte GET e POST.
- \`templates/ordini.html\` con tabella dinamica per visualizzare i record e form HTML per l'inserimento con validazione.

### Sicurezza e Login: task new-auth

Per proteggere le API o aggiungere una pagina di login senza configurare Spring Security a mano:

\`\`\`bash
task new-auth SERVICE=ordini-service TYPE=db        # Utenti su DB con BCrypt e ruoli (ROLE_USER, ROLE_ADMIN)
task new-auth SERVICE=web-ui TYPE=form             # Form login Thymeleaf con LoginController e login.html
task new-auth SERVICE=ordini-service TYPE=inmemory # Basic Auth leggera in memoria
\`\`\`

### Gestione Errori Globale REST: task new-handler

Per intercettare gli errori di validazione (\`@Valid\`) e rispondere con un JSON chiaro (\`400 Bad Request\`) invece di schermate d'errore grezze:

\`\`\`bash
task new-handler SERVICE=ordini-service
\`\`\`

Genera \`GlobalExceptionHandler.java\` con \`@RestControllerAdvice\`.

### Collegare un servizio a PostgreSQL

\`\`\`bash
task use-postgres SERVICE=ordini-service
\`\`\`

I servizi creati da \`task new-service\` partono con **H2 in memoria**: comodo
mentre sviluppi (nessun container da aspettare, database pulito a ogni
riavvio), ma i dati non sopravvivono. Quando la traccia chiede persistenza
vera, questo comando sposta il modulo sul PostgreSQL che è **già** nel
\`docker-compose.yml\`, in tutti i punti che servono: driver e JPA nel pom,
url/utente/password nell'\`application.yml\`, le stesse variabili nel compose
(dove il database non è \`localhost\` ma \`postgres\`), \`depends_on\` sul database,
e \`task dev\` che d'ora in poi lo avvia e ne aspetta la porta.

**Un database per servizio**, se lo vuoi:

\`\`\`bash
task use-postgres SERVICE=ordini-service DBNAME=ordini
\`\`\`

Crea anche \`demo/postgres-init/create-ordini.sql\`. PostgreSQL esegue gli script
di init **solo quando il volume è vuoto**: la prima volta serve un
\`task docker-reset\` (che cancella i dati già presenti).

> **Serve più di un database all'esame?** Quasi mai. Le tracce chiedono
> persistenza su uno o due servizi, e un solo database condiviso è accettato
> senza problemi — è quello che trovi già configurato (\`esame\`, utente e
> password \`exam\`). Se vuoi essere ortodosso ("un servizio, un database"), o se
> la traccia lo chiede esplicitamente, \`DBNAME=\` te lo dà: resta **un solo
> container** PostgreSQL, con più database dentro. Non serve un secondo
> container, e non conviene: sono altri 300 MB e un'altra porta da gestire.

### Cambiare nome, utente, password o porta del database

Senza variabili ti dice com'è configurato adesso e chi ci è collegato — è il
modo più veloce per ricordarsi la password mentre la commissione guarda:

\`\`\`bash
task db-config
\`\`\`

Con le variabili cambia i valori **dappertutto in una volta**: nel container
\`postgres\` del compose (compresa la sua healthcheck, che interroga il database
con quelle stesse credenziali, e la porta pubblicata sulla macchina), nelle
variabili d'ambiente di ogni modulo collegato, nell'\`application.yml\` di
ognuno, e negli script di init dei database dedicati.

\`\`\`bash
task db-config DBNAME=magazzino USER=wms PASSWORD=wms123
\`\`\`

\`\`\`bash
task db-config PORT=5433
\`\`\`

> PostgreSQL crea utente e database **solo al primo avvio, su volume vuoto**.
> Dopo aver cambiato nome, utente o password serve un \`task docker-reset\`,
> altrimenti il container continua a rispondere con i vecchi.
>
> \`PORT=\` cambia solo la porta pubblicata sulla macchina: dentro Docker i
> servizi parlano con \`postgres:5432\` e non cambia niente.

### Riempire il database di dati di prova

Scritte le entity:

\`\`\`bash
task seed-data
\`\`\`

Scrive due righe nell'\`application.yml\` di ogni modulo con delle \`@Entity\`:

\`\`\`yaml
dev-data:
  rows: 5
\`\`\`

e da lì in poi, a ogni avvio, le tabelle ancora vuote si riempiono da sole. Lo
fa il pacchetto \`devdata\` di \`common-dto\`, dentro l'applicazione, **dopo** che
Hibernate ha creato le tabelle: costruisce oggetti delle tue classi \`@Entity\`
con valori inventati e li salva con \`persist()\`, come farebbe il tuo codice.
Per questo rispetta tutto quello che rispetta la tua applicazione:

- gli id li genera chi deve (IDENTITY, sequenze, UUID); chiavi composte e
  \`@MapsId\` compresi;
- le relazioni puntano a righe che esistono (prima si riempiono le tabelle a
  cui le altre puntano), e le tabelle di collegamento dei molti a molti si
  riempiono anche loro;
- gli \`enum\` sono i tuoi, salvati come stringa o come numero;
- lunghezza delle colonne, \`@NotNull\`, \`@Size\`, \`@Min\`/\`@Max\`, \`@Email\`,
  \`@Past\`/\`@Future\` e perfino \`@Pattern\`: una targa \`[A-Z]{2}[0-9]{3}[A-Z]{2}\`
  diventa \`AB123CD\`;
- i valori seguono il nome del campo e dell'entity: il \`nome\` di un Articolo è
  un prodotto, quello di una Categoria una categoria, una \`citta\` una città.

Una riga rifiutata viene rifatta con valori diversi; se proprio non entra si
passa oltre e il log dice perché: l'avvio non fallisce mai per i dati di
prova. Vale su H2, su PostgreSQL e dentro Docker, e un riavvio non duplica
niente, perché si riempiono solo le tabelle vuote.

Il comando poi fa la prova: compila, avvia ogni modulo su un H2 usa-e-getta e
ti dice tabella per tabella quante righe sono entrate — o perché no, adesso e
non davanti al docente.

\`\`\`bash
task seed-data SERVICE=ordini-service ROWS=10
task seed-data ROWS=0      # spenti
\`\`\`

Servono dati precisi, quelli della traccia? Scrivili in un \`data.sql\` tuo:
le tabelle che riempie lui non vengono toccate. Perché venga eseguito dopo
Hibernate, anche su PostgreSQL, nell'\`application.yml\` servono:

\`\`\`yaml
spring:
  jpa:
    defer-datasource-initialization: true
  sql:
    init:
      mode: always
\`\`\`

I dati di prova valgono punti: una demo su tabelle vuote non si vede.


### Accendere Swagger dove manca

I moduli creati da \`task new-service\` hanno **già** Swagger: dipendenza nel pom
e blocco nell'\`application.yml\`, quindi \`http://localhost:<porta>/swagger-ui.html\`
risponde dal primo avvio — sia per un servizio REST sia per una UI. Non devi
fare niente.

Serve solo se lavori su un modulo scritto a mano, o da cui la dipendenza è
stata tolta:

\`\`\`bash
task enable-swagger SERVICE=ordini-service
\`\`\`

È idempotente: se c'è già tutto, te lo dice e non tocca niente.

### Togliere un microservizio

\`\`\`bash
task remove-service SERVICE=ordini-service
\`\`\`

L'inverso di \`new-service\`: cancella la cartella e toglie il modulo dagli
stessi sei posti. Ti avvisa se qualche altro modulo lo chiamava.

### Controllare che sia rimasto tutto a posto

\`\`\`bash
task check
\`\`\`

Non avvia niente: legge i file e verifica che moduli, porte, \`Dockerfile\`,
\`docker-compose.yml\` e liste dei servizi dicano la stessa cosa. Usalo dopo una
modifica fatta a mano, e prima della demo.

\`\`\`bash
task test
\`\`\`

Collauda gli strumenti stessi su una copia usa-e-getta del progetto (il
progetto vero non viene toccato): serve a sapere che funzionano **prima** di
averne bisogno. Con \`task test FULL=1\` compila anche il modulo generato.

### Rinominare la cartella dei moduli

Si chiama \`demo\` perché così nasce da Spring Initializr. Se all'esame preferisci
il nome del progetto:

\`\`\`bash
task rename-project NAME=wms
\`\`\`

Rinomina la cartella e aggiorna insieme a lei il Taskfile, gli script e le
guide che la nominano; alla fine lancia \`task check\`. I comandi non cambiano:
cambia solo il percorso dei sorgenti (\`wms/<modulo>/src/...\`).

La cartella che contiene *tutto* (quella del repository) rinominala pure a mano
da Esplora risorse: nessuno script dipende dal suo nome.

### Cambiare configurazione (\`application.yml\`)

Nessun comando: modifichi il file e rilanci \`task dev\`. Un \`application.yml\`
non è codice ricompilato, quindi l'hot reload non lo rilegge.

---

## Fase 2 — Collaudo, prima di chiamare la commissione

\`\`\`bash
task check
\`\`\`

Poi controlla che i servizi si vedano fra loro, non solo che siano accesi:
\`task status\` deve elencarli tutti nel registro Eureka.

Prova gli endpoint veri, uno per servizio: il modo più comodo è Swagger UI
(\`http://localhost:<porta>/swagger-ui.html\`), che mostra lo schema esatto
delle richieste. Infine percorri il flusso completo dalla UI, come lo mostrerai
alla commissione: è l'unico collaudo che conta davvero.

---

## Fase 3 — La demo

Non devi fermare niente prima: \`task docker-up\` spegne da solo lo stack locale.

\`\`\`bash
task docker-up
\`\`\`

Aspetta che \`task status\` mostri i tuoi servizi registrati su Eureka, poi
apri nell'ordine:

1. la tua UI — l'applicazione (l'indirizzo lo stampa \`task dev\`)
2. \`http://localhost:8761\` — la dashboard Eureka, per far vedere il discovery
3. lo Swagger di un servizio — i contratti OpenAPI

Se ti chiedono della **resilienza**, spegni un servizio davanti a loro e
ricarica la pagina: resta in piedi con i segnaposto invece di andare in
errore. Dalla cartella dei moduli (quella con \`docker-compose.yml\`), col nome
del servizio:

\`\`\`bash
docker compose stop <servizio>
\`\`\`

e poi \`docker compose start <servizio>\` per riaccenderlo.

Alla fine:

\`\`\`bash
task docker-down
\`\`\`

---

## Fase 4 — La consegna

\`\`\`bash
task consegna NOME=COGNOME_NOME
\`\`\`

Prepara la cartella \`consegna/\` con dentro tutto quello che va consegnato, e
niente di quello che non serve:

| File | Cos'è |
| :--- | :--- |
| \`<modulo>/\` | i sorgenti di ogni microservizio, **senza** \`target/\` |
| \`docker-compose.yml\` + \`Dockerfile\` + pom + wrapper | accanto ai moduli, come nel progetto: lo stack riparte dai sorgenti |
| \`ALLEGATO-TECNICO.md\` | già compilato con moduli, porte, endpoint e schema del database |
| \`SCHEMA-DATABASE.md\` | lo schema concettuale e logico da solo, comodo da copiare |
| \`ISTRUZIONI-ESECUZIONE.md\` | come far girare il progetto, con e senza Docker |
| \`COGNOME_NOME.zip\` | tutto quanto sopra in un archivio solo: **è quello da consegnare** |

Le cartelle \`target/\` restano fuori apposta: sono megabyte di roba
ricompilabile.

Dentro l'archivio non ci sono altri archivi: chi corregge lo scompatta, entra
nella cartella dove c'è \`docker-compose.yml\` e lancia
\`docker compose up -d --build\`. Prima di consegnare fai tu la stessa prova:
scompatta \`COGNOME_NOME.zip\` in una cartella nuova e avvialo da lì.

Le parti dell'allegato che scrivi tu — analisi, algoritmo, che cosa fa ogni
modulo, e se servono le risposte teoriche — stanno in \`allegato.md\`, nella
cartella del progetto, una sezione \`##\` per parte. La prima consegna lo crea
con i titoli pronti; le altre ne prendono il testo e lo mettono al suo posto
in \`ALLEGATO-TECNICO.md\` **prima** di fare l'archivio, così l'archivio ha
sempre dentro l'ultima versione e puoi rilanciare la consegna quante volte
vuoi. Alla fine ti dice che cosa manca ancora. Il resto (moduli con porte e
nome Eureka, endpoint di ogni controller, schema del database) è ricavato dal
progetto.

Lo schema del database lo puoi anche guardare da solo, in qualunque momento:

\`\`\`bash
task db-schema
\`\`\`

Avvia ogni modulo con delle \`@Entity\` su un database H2 usa-e-getta, lascia
che Hibernate crei le tabelle e le interroga: entità e relazioni (modello
concettuale), tabelle, colonne, tipi SQL, chiavi e vincoli (modello logico),
più un diagramma ER in mermaid che GitHub e VS Code disegnano da soli. Le
tabelle di collegamento, le colonne delle relazioni e i valori ammessi degli
enum sono quelli che Hibernate crea davvero, non quelli che ci si aspetta.
Funziona a stack spento e senza rete: serve solo Maven.

---

## Se qualcosa va storto

| Sintomo | Cosa fare |
| :--- | :--- |
| Un servizio non risponde | \`task status\`, poi \`task logs SERVICE=<servizio>\` |
| "Port N was already in use" | \`task dev\`: chiude lui chi tiene la porta |
| Su \`localhost:8080\` risponde un'altra app | \`task dev\` la chiude; se ti serve viva, \`task dev KEEPFOREIGN=1 UI_PORT=9080\` |
| Hai modificato il codice e non cambia niente | \`task compile\` (e controlla che non ci siano errori di compilazione) |
| Hai aggiunto una dipendenza e non la vede | \`task dev\`: il classpath si fissa all'avvio, \`task compile\` non basta |
| "Porta occupata da processo sconosciuto" | Non è un processo: Windows si è riservato quell'intervallo (succede quando parte Docker Desktop). \`task status\` la segna **RISERVATA**. Sposta il servizio con \`task set-port\`, o libera le riserve da terminale amministratore: \`net stop winnat\` e \`net start winnat\` |
| Il servizio è morto dopo una modifica | \`task logs SERVICE=<servizio>\`, poi \`task dev\` per ripartire pulito |
| I container non partono | \`task docker-down\`, poi \`task docker-up\` |
| Il database ha dati sporchi | \`task docker-reset\`, poi \`task docker-up\` — **cancella i dati** |
| È tutto ingarbugliato | \`task dev-down\`, poi \`task dev\`. **Non** \`task kill-java\`: chiude anche l'IDE |

**L'unica trappola vera**: \`task docker-reset\` cancella il database,
\`task docker-down\` no. Durante la demo usa sempre \`docker-down\`.

---

## Tutti i comandi

\`task\` da solo stampa questo elenco con le descrizioni.

| Comando | Cosa fa |
| :--- | :--- |
| \`task wizard\` | Fa le domande e monta il progetto (\`SERVICE=<modulo>\` per uno solo) |
| \`task dev\` | Libera le porte, compila e avvia tutto in background con hot reload |
| \`task logs\` | Segue i log di tutti i servizi in un terminale solo |
| \`task compile\` | Ricompila: i servizi toccati si riavviano da soli |
| \`task status\` | Chi occupa le porte, container attivi, registro Eureka |
| \`task dev-down\` | Ferma i servizi locali e libera le porte |
| \`task add-dep\` | Aggiunge dipendenze al pom di un modulo (\`LIST=1\` per l'elenco) |
| \`task set-port\` | Sposta un modulo su un'altra porta, ovunque sia scritta |
| \`task new-service\` | Crea un microservizio nuovo e lo collega a tutto |
| \`task remove-service\` | Toglie un modulo dal progetto e da tutti i file |
| \`task use-postgres\` | Collega un modulo a PostgreSQL (\`DBNAME=\` per un database suo) |
| \`task enable-swagger\` | Rimette Swagger su un modulo che non ce l'ha |
| \`task db-config\` | Stampa o cambia database, utente, password e porta di PostgreSQL |
| \`task ide-sync\` | Riallinea VS Code e Zed ai moduli veri (lo chiamano da soli new-service, remove-service, set-port) |
| \`task rename-project\` | Rinomina la cartella dei moduli Maven, ovunque sia nominata |
| \`task seed-data\` | Dati di prova: a ogni avvio le tabelle vuote si riempiono, passando da Hibernate |
| \`task db-schema\` | Schema concettuale e logico, letto dal database che crea Hibernate |
| \`task consegna\` | Prepara la cartella da consegnare (\`NOME=COGNOME_NOME\`) |
| \`task learn\` | Il corso nel browser, dalla traccia alla consegna |
| \`task rete\` | Quali domini passano dalla rete dell'aula, e cosa fare se no |
| \`task offline-prep\` | **La sera prima, a casa**: scarica tutto quello che servirà all'esame |
| \`task offline\` | Dice se il progetto partirebbe anche senza rete |
| \`task check\` | Moduli, porte, Docker e liste sono coerenti? |
| \`task test\` | Collauda gli strumenti su una copia usa-e-getta |
| \`task help\` | Questa guida, dal terminale |
| \`task docker-up\` | Costruisce le immagini e avvia lo stack in container |
| \`task docker-down\` | Ferma i container, **conservando** i dati del database |
| \`task docker-reset\` | Ferma i container **ed elimina** i volumi |
| \`task docker-logs\` | Segue i log dei container |
| \`task build\` | Compila e impacchetta tutti i moduli Maven |
| \`task run SERVICE=<modulo>\` | Avvia un solo modulo, in primo piano |
| \`task run-eureka\` | Avvia il solo Eureka, in primo piano |
| \`task kill-java\` | Ultima spiaggia: termina **tutti** i java della macchina |

### Opzioni utili

Si passano come variabili, senza trattini.

| Variabile | Quando |
| :--- | :--- |
| \`task dev UI_PORT=9080\` | Vuoi la UI su un'altra porta |
| \`task dev NOBUILD=1\` | Hai già compilato e vuoi solo riavviare |
| \`task dev KEEPFOREIGN=1\` | Su una porta gira qualcosa che ti serve viva: non chiuderla |
| \`task logs SERVICE=<nome>\` | Un servizio solo |

---

## Cosa fa \`task dev\` all'avvio, in dettaglio

Serve saperlo solo se qualcosa va storto:

1. **Libera le porte** dello stack: ferma i suoi servizi di un avvio
   precedente, spegne i container dell'esame se sono loro a tenerle
   (\`docker compose down\`, i dati restano) e chiude le applicazioni estranee
   rimaste in ascolto. Non tocca mai i processi di sistema né l'infrastruttura
   di Docker: quelli te li segnala soltanto.
2. Cancella i log del giro precedente, così \`task logs\` non ti mostra roba
   vecchia.
3. Compila tutti i moduli, una volta sola.
4. Avvia Eureka e **aspetta** che sia in ascolto, poi tutti gli altri.
5. Se qualcosa non parte, stampa le ultime righe del log del colpevole e
   **ritira quello che aveva avviato**, invece di lasciare mezzo stack acceso.
` },
    { file: 'allegato.md', testo: `# Allegato tecnico: le parti scritte da te

task consegna prende ogni sezione di questo file e la mette al suo posto in
ALLEGATO-TECNICO.md, accanto a quello che ricava dal progetto (moduli, porte,
endpoint, schema del database). Scrivi sotto ogni titolo e lascia i titoli
come sono: una sezione ancora fra parentesi quadre conta come da scrivere, e
la consegna te lo ricorda.

## Analisi

La biblioteca di quartiere informatizza il catalogo e i prestiti. Il
bibliotecario consulta i libri, con autore, genere, anno e disponibilità;
registra un prestito indicando l'email di chi prende il libro e la durata (30
giorni di norma, al massimo 60); registra la restituzione. Il sistema impedisce
di prestare un libro già fuori e calcola, per ogni prestito, i giorni di
ritardo e la penale.

La soluzione è divisa in tre microservizi, ognuno con i suoi dati: il catalogo
possiede libri e autori, i prestiti possiedono i prestiti e dei libri tengono
solo l'identificativo. La coerenza fra i due la mantiene il servizio dei
prestiti: prima di prestare chiede il libro al catalogo, dopo gli comunica che
non è più disponibile, e alla restituzione che lo è di nuovo. L'interfaccia web
chiama entrambi. Tutti si registrano su Eureka e si chiamano per nome con
OpenFeign.

## Algoritmo

Per ogni prestito si calcola il ritardo come il numero di giorni fra la data di
scadenza e la data di riferimento — la data di restituzione se il prestito è
chiuso, la data odierna se è aperto — con un minimo di zero. La penale è pari a
0,50 € per giorno di ritardo, con un tetto di 20,00 €:

penale = min(0,50 × ritardo; 20,00)

Il calcolo sta in \`PrestitoService\` (metodi \`giorniRitardo\` e \`penale\`), due
funzioni pure che non toccano né il database né la rete, e si esegue ogni volta
che un prestito viene restituito all'esterno: il valore mostrato è sempre
aggiornato al giorno corrente e non viene salvato. Il costo è costante per
prestito e lineare nel numero di prestiti per l'elenco. Gli importi usano
\`BigDecimal\`, per non avere errori di arrotondamento. I test di \`PenaleTest\`
verificano la restituzione in anticipo (nessuna penale), sette giorni di
ritardo (3,50 €) e il tetto (20,00 € da quaranta giorni in su).

## naming-server

Il registro Eureka: i servizi vi si registrano col loro nome
(\`spring.application.name\`) e lo usano per trovarsi, senza indirizzi scritti
nel codice.

## catalogo-service

Tiene libri e autori su PostgreSQL (database \`biblioteca\`) e li espone in REST.
Il servizio dei prestiti lo chiama per leggere un libro e per cambiarne la
disponibilità.

## prestiti-service

Registra prestiti e restituzioni su un database suo (\`prestiti\`). Chiede i
libri al catalogo via Feign: risponde 404 se il libro non esiste, 409 se è già
in prestito, 400 se i dati della richiesta non sono validi. Calcola ritardo e
penale di ogni prestito.

## biblioteca-ui

L'interfaccia web, con Thymeleaf: mostra catalogo e prestiti con ritardo e
penale, registra un prestito con un form validato e una restituzione con un
bottone. Se un servizio non risponde la pagina lo dice, invece di andare in
errore.

## Domanda A

[Facoltativa: la risposta alla domanda teorica, se la traccia la vuole nell'allegato.]

## Domanda B

[Facoltativa: la risposta alla domanda teorica, se la traccia la vuole nell'allegato.]
` },
    { file: 'guida_multi_modulo_maven.md', testo: `# Guida 3: Multi-Modulo Maven & Funzionamento Progetto

Guida teorica e pratica per comprendere la struttura **Multi-Module Maven**, il funzionamento del **Maven Reactor**, la gestione delle dipendenze e l'integrazione con **Docker**.

---

## 1. Cos'è un Progetto Multi-Modulo Maven e Perché si Usa

Un progetto **Multi-Module Maven** è una struttura aggregata composta da un **Parent POM** centrale e da molteplici **Sub-Moduli Maven** correlati.

### 🌟 Vantaggi per un'Architettura a Microservizi:
1. **Isolamento delle Dipendenze**: Ogni microservizio dichiara nel proprio \`pom.xml\` solo gli starter di cui ha realmente bisogno (un servizio con persistenza include Spring Data JPA e il driver del database; \`naming-server\` include solo Eureka Server).
2. **Centralizzazione delle Versioni (\`dependencyManagement\`)**: Le versioni di librerie, framework (Spring Boot, Spring Cloud, Lombok, Springdoc) e plugin sono definite un'unica volta nel Parent POM principale.
3. **Condivisione Pulita del Codice (\`common-dto\`)**: I DTO (Data Transfer Objects) comuni vengono inseriti in un modulo dedicato (\`common-dto\`) ed importati dagli altri servizi come dipendenza JAR interna, evitando la duplicazione del codice.
4. **Build Unificata o Singola**: È possibile compilare l'intero sistema con un unico comando (\`./mvnw clean package\`) oppure compilare ed avviare un singolo microservizio isolato.

---

## 2. Struttura del Parent POM e dei Sub-Moduli

In questo branch — il template vuoto — l'aggregatore contiene solo
l'infrastruttura; i moduli della traccia li aggiungi tu, e \`task new-service\`
li mette al posto giusto:

\`\`\`
demo/ (Directory Root Parent)
├── pom.xml                   <-- Parent POM (packaging: pom)
├── common-dto/
│   └── pom.xml               <-- Sub-modulo DTO condivisi
├── naming-server/
│   └── pom.xml               <-- Sub-modulo Eureka Server
│
│   ... e, dopo \`task new-service NAME=ordini-service\`:
│
├── ordini-service/
│   └── pom.xml               <-- Sub-modulo Microservizio REST
└── ordini-ui/
    └── pom.xml               <-- Sub-modulo Frontend Thymeleaf
\`\`\`

### 2.1 Il Parent POM (\`demo/pom.xml\`)

Il file Parent definisce il packaging \`pom\` e la lista dei moduli compresi nell'aggregatore:

\`\`\`xml
<project xmlns="http://maven.apache.org/POM/4.0.0" ...>
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>ttfcloud-esame-parent</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <packaging>pom</packaging> <!-- INDISPENSABILE: indica che è un parent aggregatore -->

    <!-- Elenco dei moduli da compilare: \`task new-service\` aggiunge qui la
         riga del modulo nuovo, \`task remove-service\` la toglie -->
    <modules>
        <module>common-dto</module>
        <module>naming-server</module>
        <module>ordini-service</module>
    </modules>

    <properties>
        <java.version>25</java.version>
        <spring-cloud.version>2025.1.1</spring-cloud.version>
        <lombok.version>1.18.44</lombok.version>
        <springdoc.version>2.8.5</springdoc.version>
    </properties>

    <!-- Gestione centralizzata delle versioni (senza includere le dipendenze nei figli) -->
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>\${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>org.springdoc</groupId>
                <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
                <version>\${springdoc.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>
</project>
\`\`\`

---

### 2.2 Un Sub-Modulo Figlio (es. \`ordini-service/pom.xml\`)

Ogni sub-modulo fa riferimento al Parent tramite il blocco \`<parent>\` ed eredita versioni e proprietà:

\`\`\`xml
<project xmlns="http://maven.apache.org/POM/4.0.0" ...>
    <modelVersion>4.0.0</modelVersion>

    <!-- Riferimento al Parent POM -->
    <parent>
        <groupId>com.example</groupId>
        <artifactId>ttfcloud-esame-parent</artifactId>
        <version>0.0.1-SNAPSHOT</version>
        <relativePath>../pom.xml</relativePath>
    </parent>

    <artifactId>ordini-service</artifactId>
    <name>ordini-service</name>

    <dependencies>
        <!-- Inclusione del modulo DTO interno -->
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>common-dto</artifactId>
            <version>\${project.version}</version>
        </dependency>

        <!-- Dipendenze Spring Boot (la versione è ereditata dal Parent) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
        </dependency>
    </dependencies>
</project>
\`\`\`

---

## 3. Il Meccanismo del Maven Reactor

Quando si lancia un comando Maven dalla root del Parent (es. \`./mvnw clean package\`), Maven attiva il **Maven Reactor**.

### Come funziona il Reactor:
1. Legge il \`pom.xml\` Parent e scansiona tutti i sub-moduli elencati in \`<modules>\`.
2. Costruisce un **Grafo Orientato Acliclico (DAG)** delle dipendenze tra i moduli.
3. Determina l'ordine esatto di compilazione (**Reactor Build Order**).

Esempio di output del Reactor in console:
\`\`\`text
[INFO] Reactor Build Order:
[INFO] 
[INFO] ttfcloud-esame-parent                                              [pom]
[INFO] common-dto                                                         [jar]
[INFO] naming-server                                                      [jar]
[INFO] ordini-service                                                     [jar]
[INFO] ordini-ui                                                          [jar]
\`\`\`
> 📌 *Nota*: \`common-dto\` viene sempre compilato per primo perché tutti gli altri microservizi dipendono dai suoi DTO!

---

## 4. Comandi Utili Maven per Progetti Multi-Modulo

### 1. Build Completa di Tutti i Moduli
\`\`\`bash
./mvnw clean package -Dmaven.test.skip=true
\`\`\`

### 2. Avviare un Singolo Modulo con le sue Dipendenze (\`-pl\` e \`-am\`)
- \`-pl\` / \`--projects\`: Specifica il modulo target (es. \`ordini-service\`).
- \`-am\` / \`--also-make\`: Ordina a Maven di compilare prima tutti i moduli da cui il target dipende (es. \`common-dto\`).

\`\`\`bash
# Esegue ordini-service ricompilando prima common-dto se necessario
./mvnw -pl ordini-service -am spring-boot:run
\`\`\`

### 3. Compilare Solo un Singolo Modulo
\`\`\`bash
./mvnw -pl ordini-service clean package -Dmaven.test.skip=true
\`\`\`

> Nel lavoro di tutti i giorni questi comandi non li scrivi: \`task compile\`
> ricompila tutto (il Reactor salta quello che non è cambiato) e
> \`task run SERVICE=<modulo>\` fa esattamente il \`-pl <modulo> -am
> spring-boot:run\` qui sopra.

---

## 5. Integrazione con Docker Multi-Stage Build

Per evitare di avere un \`Dockerfile\` diverso per ciascun microservizio, il progetto usa un **Dockerfile Parameterizzato** situato nella cartella \`demo\`:

\`\`\`dockerfile
# STAGE 1: Compilation Phase
FROM eclipse-temurin:25-jdk AS builder
WORKDIR /workspace

# Copia i file POM per sfruttare il caching delle dipendenze Docker
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY common-dto/pom.xml common-dto/pom.xml
COPY naming-server/pom.xml naming-server/pom.xml
# ... una riga per modulo: la aggiunge \`task new-service\`

# Argomento che definisce quale modulo compilare per l'immagine specifica
ARG MODULE="naming-server"

RUN chmod +x mvnw
RUN ./mvnw -B -pl \${MODULE} -am dependency:go-offline

# Copia i sorgenti Java ed esegue il packaging del solo modulo richiesto
COPY . .
RUN ./mvnw -B -pl \${MODULE} -am clean package -Dmaven.test.skip=true

# STAGE 2: Runtime Phase (Immagine finale ultra-leggera JRE)
FROM eclipse-temurin:25-jre
# curl serve all'healthcheck di Eureka in docker-compose.yml
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ARG MODULE="naming-server"
COPY --from=builder /workspace/\${MODULE}/target/\${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
\`\`\`

In \`docker-compose.yml\`, ogni servizio passa il nome del proprio modulo come argomento di build (\`MODULE\`):

\`\`\`yaml
  ordini-service:
    build:
      context: .
      args:
        MODULE: ordini-service
\`\`\`

> Le sole righe che cambiano da modulo a modulo sono quella \`COPY\` del pom e
> il blocco nel compose: sono due dei sei posti che \`task new-service\` tiene
> allineati, e che \`task check\` verifica.

---

## 6. Aggiungere, spostare o togliere un modulo

### 6.1 Con un comando

\`\`\`bash
task new-service NAME=ordini-service
\`\`\`

È il modo giusto il giorno dell'esame: un modulo nuovo tocca **sei** posti che
devono restare d'accordo, e questo comando li fa tutti e sei.

| # | Posto | Cosa ci finisce |
| :---: | :--- | :--- |
| 1 | \`demo/<nome>/\` | \`pom.xml\`, \`Main.java\`, \`application.yml\`, un endpoint di prova |
| 2 | \`demo/pom.xml\` | la riga \`<module><nome></module>\` |
| 3 | \`demo/Dockerfile\` | la \`COPY <nome>/pom.xml <nome>/pom.xml\` |
| 4 | \`demo/docker-compose.yml\` | il blocco del servizio, con porta ed Eureka |
| 5 | \`scripts/dev.ps1\` | la riga nella lista dei servizi di \`task dev\` |
| 6 | \`scripts/dev.sh\` | la stessa riga, per la versione POSIX |

Dimenticarne uno dà errori che sembrano scollegati dalla causa: il modulo non
compila (manca il 2), compila ma \`task dev\` non lo avvia (manca il 5), parte in
locale e non in Docker (manca il 3 o il 4).

Gli altri due comandi della stessa famiglia:

\`\`\`bash
task set-port SERVICE=ordini-service PORT=8090
\`\`\`

\`\`\`bash
task remove-service SERVICE=ordini-service
\`\`\`

E, quando vuoi essere sicuro che sia tutto a posto:

\`\`\`bash
task check
\`\`\`

### 6.2 A mano, se ti serve capire cosa succede

Il modulo di per sé sono tre file. Il \`pom.xml\` eredita dal parent, e per
questo non contiene **nessuna versione**:

\`\`\`xml
<project xmlns="http://maven.apache.org/POM/4.0.0" ...>
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>com.example</groupId>
        <artifactId>ttfcloud-esame-parent</artifactId>
        <version>0.0.1-SNAPSHOT</version>
        <relativePath>../pom.xml</relativePath>
    </parent>
    <artifactId>ordini-service</artifactId>
    <dependencies>
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>common-dto</artifactId>
            <version>\${project.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>
</project>
\`\`\`

La classe \`Main\`, che accende discovery e client Feign:

\`\`\`java
package esame.ordiniservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

@EnableDiscoveryClient
@EnableFeignClients
@SpringBootApplication
public class Main {
    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
\`\`\`

E l'\`application.yml\`, dove la porta si legge dall'ambiente (in Docker la passa
\`docker-compose.yml\`) e ricade sul valore locale:

\`\`\`yaml
server:
  port: \${SERVER_PORT:8081}

spring:
  application:
    name: ORDINI-SERVICE

eureka:
  client:
    service-url:
      defaultZone: \${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
  instance:
    prefer-ip-address: true
\`\`\`

Poi restano i cinque collegamenti della tabella qui sopra: la riga nei
\`<modules>\`, la \`COPY\` nel \`Dockerfile\`, il blocco nel compose

\`\`\`yaml
  ordini-service:
    build:
      context: .
      args:
        MODULE: ordini-service
    environment:
      SERVER_PORT: 8081
      EUREKA_SERVER_URL: http://eureka-server:8761/eureka/
    ports:
      - "8081:8081"
    depends_on:
      eureka-server:
        condition: service_healthy
\`\`\`

e le due righe nelle liste di avvio di \`dev.ps1\` e \`dev.sh\`.

> **Rinominare** un modulo non ha un comando suo: la strada più corta è
> \`task remove-service SERVICE=<vecchio>\` seguito da
> \`task new-service NAME=<nuovo>\`, e poi riportare il codice nella cartella
> nuova. Ricordati di cambiare anche il \`package\` delle classi e il
> \`spring.application.name\`, perché è quello il nome che gli altri moduli usano
> nei loro \`@FeignClient\`.

### 6.3 Dopo, in ogni caso: \`task dev\`

Un modulo nuovo non è in esecuzione, e il classpath dei servizi accesi è
fissato da quando sono partiti: \`task compile\` non basta, ci vuole un riavvio
vero.
` },
    { file: 'guida_prova_finale_spring_boot.md', testo: `# Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot

Manuale strategico e tecnico per la preparazione ed il superamento della **Prova Finale Backend ITS (Technologies Talent Factory)** basata su Spring Boot, Microservizi, Docker ed OpenAPI.

---

## 1. Struttura della Prova Finale & Griglia di Valutazione

La prova ha una durata tipica di **6 ore** e richiede la consegna di un archivio zip denominato \`COGNOME_NOME.zip\`.

### Griglia standard dei punteggi (Totale 40 Punti):

1. **Allegato Tecnico (fino a 8 Punti)**: Documento di analisi con schema DB distribuito, descrizione dei moduli, porte HTTP, descrizione algoritmi e istruzioni di collaudo.
2. **Server Naming Eureka (fino a 3 Punti)**: Progetto Spring Boot configurato come Eureka Server per il Service Discovery.
3. **Microservizio Anagrafica / Backend Core (fino a 8 Punti)**: Microservizio REST con persistenza DB, Swagger/OpenAPI e dati di test (dump SQL o inizializzatore Java).
4. **Applicazione UI / WMS / Servizio Principale (fino a 10 Punti)**: Frontend Web (Thymeleaf/JS), integrazione con DB e chiamate ai servizi esterni tramite Eureka.
5. **Servizio Ausiliario / Mock Esterno (fino a 3 Punti)**: Registrazione su Eureka del servizio mock/fornitore preesistente.
6. **Domanda Teorica A (fino a 4 Punti)**: Docker vs VM, Docker Compose, Sicurezza e Federazione dei Servizi (Spring Security, OAuth2, Keycloak).
7. **Domanda Teorica B (fino a 4 Punti)**: DB Relazionali vs NoSQL, integrazione NoSQL nella soluzione, Confronto Stack JEE vs Spring Boot.

---

## 1.1 Matrice delle Responsabilità: Tu vs Template / Comandi task

All'esame il tempo è prezioso: delega agli strumenti il lavoro meccanico e concentrati su quello che viene valutato dalla commissione:

| Ambito | Cosa deleghi al Template / ai comandi \`task\` | Cosa spetta a TE (Candidato) |
| :--- | :--- | :--- |
| **Architettura & Moduli** | \`task new-service\` collega il modulo in tutti i 6 punti (pom aggregatore, Dockerfile, docker-compose, dev, VS Code, porte). | Scegliere i nomi dei moduli dalla traccia (es. \`catalogo-service\`, \`ordini-service\`, \`ui-service\`). |
| **Persistenza & Entity** | \`task new-entity\` genera Entity, Repository, Service CRUD e Controller REST (anche con DTO via \`DTO=1\`). \`task add-relation\` collega le entity tra loro in JPA (\`@ManyToOne\`, \`@OneToMany\`...) con \`fetch = LAZY\`. | I metodi custom del repository (tramite nome derivato \`findBy...\` o query esplicita \`@Query\`/\`nativeQuery\`) e la logica specifica. |
| **Microservizi & Database** | Ogni modulo ha il suo database isolato (H2 in-memory o Postgres dedicato con \`task use-postgres\`). | **NON creare mai chiavi esterne tra moduli diversi!** Usare solo l'ID numerico (\`Long libroId\`) e OpenFeign. |
| **Contratti DTO & Record** | \`task new-dto\` genera i record Java in \`common-dto\` con validazione Bean Validation. | Decidere quali campi esporre e scambiare tra i microservizi. |
| **Chiamate tra Servizi** | \`task new-client\` crea l'interfaccia \`@FeignClient\` pronta con metodi CRUD risolti tramite Eureka. | Invocare il client nel \`@Service\` chiamante e gestire le eccezioni di business (es. 404 se un record non esiste). |
| **Interfaccia Web (UI)** | \`task new-view\` crea Controller Thymeleaf e template HTML con tabella dinamica e form validato. | Personalizzare i campi del form e visualizzare i dati ricevuti da Feign nel Model. |
| **Sicurezza (Spring Security)** | \`task new-auth\` genera la sicurezza completa: in-memory, su database (\`UtenteEntity\`, \`UtenteRepository\`, \`CustomUserDetailsService\`, BCrypt) o Web (\`login.html\` Thymeleaf). | Configurare le regole di autorizzazione per ruolo (es. \`.requestMatchers("/admin/**").hasRole("ADMIN")\`) se richieste dalla traccia. |
| **Gestione Errori REST** | \`task new-handler\` genera \`@RestControllerAdvice\` con formattazione automatica degli errori di validazione (@Valid), 404 e 500 in JSON. | Definire eventuali messaggi di errore custom di business. |
| **Logica di Business & Algoritmo** | *Nessuna automazione (apposta)*. | **È il cuore della valutazione:** implementare i calcoli, controlli di disponibilità, regole di sconto, algoritmi richiesti. |
| **Documentazione & Consegna** | \`task db-schema\` estrae lo schema ER; \`task consegna\` prepara lo zip pulito rimuovendo tutte le classi interne del template (\`devdata\`). | Scrivere analisi del problema, algoritmo e risposte teoriche in \`allegato.md\`. |

---

## 2. Workflow Operativo d'Esame in 6 Ore (Passo-Passo)

Per massimizzare il punteggio e completare l'esame senza stress, segui questa tabella di marcia temporale:

\`\`\`
[0:00 - 0:45] Fase 1: Analisi & Allegato Tecnico (8pt)
      │
[0:45 - 1:15] Fase 2: Naming Server Eureka (3pt)
      │
[1:15 - 2:45] Fase 3: Microservizio Core / Anagrafica REST + OpenAPI (8pt)
      │
[2:45 - 4:15] Fase 4: Applicazione UI / WMS + Feign Clients + Algoritmo (10pt)
      │
[4:15 - 5:15] Fase 5: Risposte alle Domande Teoriche A e B (8pt)
      │
[5:15 - 6:00] Fase 6: Containerizzazione Docker, Collaudo & Impacchettamento
\`\`\`

### 📋 Dettaglio Operativo delle Fasi:

- **Fase 1 (0:00 - 0:45) - Analisi & Allegato Tecnico**:
  1. Leggi l'intero testo d'esame ed evidenzia i requisiti funzionali (es. prodotti, ubicazioni, particelle, visite).
  2. Definisci le porte HTTP per ciascun servizio (es. Eureka \`8761\`, Anagrafica \`8081\`, Mock \`8082\`, UI \`8080\`, Postgres \`5432\`).
  3. Disegna lo schema ER/Logico distribuito delle tabelle.
  4. Scrivi subito la sezione dell'algoritmo nell'Allegato Tecnico (es. formula della distanza di Manhattan e complessità $O(N \\times M)$) per bloccare gli 8 punti dell'Allegato prima di scrivere codice.

- **Fase 2 (0:45 - 1:15) - Eureka Naming Server**:
  1. Crea o avvia il modulo \`naming-server\`.
  2. Inserisci \`@EnableEurekaServer\` sulla classe \`Main\`.
  3. Configura \`server.port: 8761\` e disabilita l'auto-registrazione in \`application.yml\`.
  4. Verifica la dashboard aprendo \`http://localhost:8761\`.

- **Fase 3 (1:15 - 2:45) - Microservizio Anagrafica / REST Core**:
  1. Definisci le classi \`@Entity\` JPA con i campi richiesti.
  2. Crea l'interfaccia \`JpaRepository\`.
  3. Realizza il \`@RestController\` con gli endpoint CRUD (\`@GetMapping\`, \`@PostMapping\`, \`@DeleteMapping\`).
  4. Aggiungi \`springdoc-openapi-starter-webmvc-ui\` e le annotazioni \`@Tag\`, \`@Operation\`, \`@Parameter\`.
  5. Inizializza i dati di prova tramite un bean \`@Bean CommandLineRunner\` o file \`data.sql\`.
  6. Collauda le API da \`http://localhost:8081/swagger-ui.html\`.

- **Fase 4 (2:45 - 4:15) - Applicazione WMS / UI & Client Feign**:
  1. Inserisci \`@EnableFeignClients\` e crea le interfacce \`@FeignClient\` per invocare l'anagrafica e il servizio mock tramite il nome logico registrato su Eureka.
  2. Implementa le regole di business (es. spostamento merci con verifica ingombro/cliente, oppure apertura/chiusura pratica catasto con ricalcolo classe energetica).
  3. Crea il controller Thymeleaf \`@Controller\` o le API REST per l'interfaccia web.
  4. Implementa il form HTML e, facoltativamente, la chiamata \`fetch()\` JavaScript per aggiornamenti asincroni senza reload.

- **Fase 5 (4:15 - 5:15) - Domande Teoriche A e B**:
  1. Compila le risposte teoriche (utilizzando il testo precompilato della Sezione 9 di questo manuale).
  2. Verifica di aver coperto: Docker vs VM, Docker Compose, OAuth2/Keycloak/Gateway per la Domanda A; SQL vs NoSQL (MongoDB/Redis) e JEE vs Spring Boot per la Domanda B.

- **Fase 6 (5:15 - 6:00) - Containerizzazione Docker, Collaudo & Consegna**:
  1. Configura \`docker-compose.yml\` mappando tutte le porte host.
  2. Esegui \`task docker-up\` e accertati che su Eureka tutti i microservizi risultino in stato **UP**.
  3. Compila l'archivio ZIP finale \`COGNOME_NOME.zip\` organizzato secondo le indicazioni della traccia d'esame.

---

## 3. OpenAPI & Swagger UI: Guida Passo-Passo

### 3.1 Perché è fondamentale
Nelle tracce d'esame è espressamente richiesto:
> *"Il servizio di anagrafica deve pubblicare i propri servizi REST tramite opportuno descrittore SWAGGER/(OPEN-API) e fornire l'interfaccia web SWAGGER-UI per i test."*

### 3.2 Abilitazione in Spring Boot (versione 3.x / 4.x)

1. **Aggiunta della Dipendenza Maven (\`pom.xml\`)**:
   \`\`\`xml
   <dependency>
       <groupId>org.springdoc</groupId>
       <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
       <version>2.8.5</version>
   </dependency>
   \`\`\`

   > In **questo** template la versione non si scrive: la governa il \`pom.xml\`
   > padre, che la fissa una volta per tutti i moduli. E i servizi creati con
   > \`task new-service\` hanno già springdoc dentro. Per aggiungerlo altrove:
   > \`task add-dep SERVICE=<modulo> DEPS=springdoc\`.

2. **Configurazione in \`application.yml\`**:
   \`\`\`yaml
   springdoc:
     api-docs:
       path: /v3/api-docs
     swagger-ui:
       path: /swagger-ui.html
       operations-sorter: method
   \`\`\`

3. **Annotazione dei Controller Java**:
   \`\`\`java
   @RestController
   @RequestMapping("/api/prodotti")
   @Tag(name = "Anagrafica Prodotti", description = "API per la gestione del catalogo prodotti")
   public class ProdottoController {

       @GetMapping("/{id}")
       @Operation(summary = "Recupera un prodotto", description = "Restituisce i dettagli del prodotto dato il suo ID univoco")
       public ResponseEntity<ProdottoDTO> getById(
           @Parameter(description = "ID del prodotto", example = "101") 
           @PathVariable Long id
       ) {
           return ResponseEntity.ok(prodottoService.findById(id));
       }
   }
   \`\`\`

4. **Visualizzazione dal Browser**:
   - Accedi a: \`http://localhost:<PORTA>/swagger-ui.html\`
   - Si aprirà l'interfaccia interattiva dove la commissione d'esame potrà testare i contratti REST ed inviare richieste HTTP con il tasto **"Try it out"**.

---

## 4. Proprietà e Configurazioni (\`application.yml\`)

Di seguito viene spiegato il significato ed il ruolo di ogni proprietà di configurazione utilizzata nei microservizi Spring Boot:

\`\`\`yaml
# ===================================================================
# CONFIGURAZIONE SERVER & NOME APPLICAZIONE
# ===================================================================
server:
  port: 8081 # Porta HTTP su cui risponde l'applicazione

spring:
  application:
    name: ORDINI-SERVICE # Nome logico registrato su Eureka (sempre MAIUSCOLO per convenzione)

# ===================================================================
# CONFIGURAZIONE EUREKA NAMING SERVER (CLIENT DISCOVERY)
# ===================================================================
eureka:
  client:
    register-with-eureka: true # True per i microservizi normali; False solo per il Server Eureka
    fetch-registry: true # Permette al servizio di scaricare l'elenco degli altri servizi da Eureka
    service-url:
      defaultZone: \${EUREKA_SERVER_URL:http://localhost:8761/eureka/} # URL del registro Eureka

  instance:
    prefer-ip-address: true # Eureka registra l'indirizzo IP invece dell'hostname (fondamentale in Docker)
    lease-renewal-interval-in-seconds: 10 # Frequenza invio heartbeat a Eureka
    lease-expiration-duration-in-seconds: 30 # Tempo massimo attesa prima di rimuovere il servizio disconnesso

# ===================================================================
# CONFIGURAZIONE DATABASE & DATABASE JPA / HIBERNATE
# ===================================================================
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/esame # URL JDBC di connessione
    username: exam
    password: exam
    driver-class-name: org.postgresql.Driver

  jpa:
    hibernate:
      ddl-auto: update # update: crea/aggiorna le tabelle in automatico; create-drop: cancella al termine
    show-sql: true # Stampa le query SQL eseguite nella console di log
    properties:
      hibernate:
        format_sql: true # Formatta le query SQL stampate nei log rendendole leggibili
        dialect: org.hibernate.dialect.PostgreSQLDialect

# ===================================================================
# CONFIGURAZIONE SPRINGDOC OPENAPI / SWAGGER UI
# ===================================================================
springdoc:
  api-docs:
    path: /v3/api-docs # Endpoint JSON che restituisce la specifica OpenAPI 3
  swagger-ui:
    path: /swagger-ui.html # URL Web per accedere all'interfaccia di collaudo Swagger
    operations-sorter: method # Ordina i metodi per tipo (GET, POST, PUT, DELETE)

# ===================================================================
# CONFIGURAZIONE OPENFEIGN (TIMEOUT E LOGGING)
# ===================================================================
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connectTimeout: 5000 # Timeout di connessione HTTP (in ms)
            readTimeout: 5000 # Timeout di lettura risposta HTTP (in ms)

# ===================================================================
# CONFIGURAZIONE LIVELLO LOGGING
# ===================================================================
logging:
  level:
    root: INFO
    esame: DEBUG # Abilita il log dettagliato per i package del progetto (la base: task set-package)
    org.hibernate.SQL: DEBUG # Stampa i parametri delle query SQL
\`\`\`

---

## 5. Come funziona il tutto insieme

Le librerie di questo progetto non sono pezzi indipendenti: ognuna accende un
anello della stessa catena. Vale la pena vederla una volta intera, perché
quando qualcosa non funziona il punto è quasi sempre uno di questi anelli.

### 5.1 Il giro completo di una richiesta

\`\`\`
browser
   │  GET /
   ▼
<nome>-ui            Spring Web + Thymeleaf: un @Controller restituisce il nome
   │                 di una pagina, Thymeleaf la riempie coi dati del Model
   │  ordiniClient.tutti()
   ▼
OpenFeign            l'interfaccia @FeignClient(name = "ORDINI-SERVICE"),
   │                 a runtime, diventa una vera chiamata HTTP
   │  "dove sta ORDINI-SERVICE?"
   ▼
Eureka  :8761        il registro risponde con indirizzo e porta dell'istanza
   │
   │  GET http://10.1.2.3:8081/api/ordini
   ▼
<nome>-service       un @RestController riceve la richiesta
   │  ordineRepository.findAll()
   ▼
Spring Data JPA      l'interfaccia JpaRepository diventa una query, senza che
   │                 tu scriva l'implementazione
   ▼
Hibernate            traduce in SQL e rimappa le righe sulle @Entity
   │
   ▼
H2 in memoria (o PostgreSQL)
\`\`\`

Nel frattempo, in parallelo e senza che tu scriva niente:

- **springdoc** legge gli stessi \`@RestController\` e pubblica \`/v3/api-docs\` e \`/swagger-ui.html\`;
- **Lombok** ha già generato getter, setter e costruttori delle classi che passano di lì;
- **devtools** tiene d'occhio le classi compilate: dopo \`task compile\` il servizio si riavvia da solo.

### 5.2 Chi accende cosa

Ogni pezzo si accende con una dipendenza nel \`pom.xml\` (che è quello che fa
\`task add-dep\`), e spesso con un'annotazione sulla classe \`Main\`.

| Cosa vuoi | Dipendenza (nome breve) | Annotazione / configurazione | Come te ne accorgi |
| :--- | :--- | :--- | :--- |
| Endpoint REST | \`web\` | \`@RestController\`, \`@RequestMapping\` | il servizio risponde su \`http://localhost:<porta>/api/...\` |
| Pagine HTML | \`thymeleaf\` | \`@Controller\` + file in \`resources/templates/\` | il browser mostra la pagina invece del JSON |
| Registrarsi su Eureka | \`eureka-client\` | \`@EnableDiscoveryClient\` + \`eureka.client.service-url.defaultZone\` | compare in \`task status\`, sezione REGISTRO EUREKA |
| Chiamare un altro servizio | \`feign\` | \`@EnableFeignClients\` + \`@FeignClient(name = "ALTRO-SERVICE")\` | la chiamata parte senza che tu scriva un URL |
| Persistenza | \`data-jpa\` + \`h2\` o \`postgresql\` | \`@Entity\`, \`JpaRepository\`, \`spring.datasource.*\` | Hibernate stampa le query nei log |
| Contratti OpenAPI | \`springdoc\` | nessuna: legge i controller | \`http://localhost:<porta>/swagger-ui.html\` |
| Meno codice ripetuto | \`lombok\` | \`@Data\`, \`@RequiredArgsConstructor\`, \`@Slf4j\` | le classi restano corte |
| Validazione degli input | \`validation\` | \`@Valid\` + \`@NotNull\`, \`@Size\`, ... | una richiesta sbagliata torna 400 invece di rompersi dopo |

I moduli creati con \`task new-service\` nascono già con quasi tutto questo
collegato: \`Main\` ha \`@EnableDiscoveryClient\` e \`@EnableFeignClients\`,
l'\`application.yml\` ha Eureka, il datasource e springdoc.

### 5.3 I nomi: dove nascono e chi li usa

È il punto che confonde di più, e vale un paragrafo suo.

\`\`\`yaml
# demo/ordini-service/src/main/resources/application.yml
spring:
  application:
    name: ORDINI-SERVICE      # <-- il nome con cui si registra su Eureka
\`\`\`

\`\`\`java
// dentro un ALTRO modulo, che vuole chiamarlo
@FeignClient(name = "ORDINI-SERVICE")   // <-- lo stesso nome, non un URL
public interface OrdiniClient {
    @GetMapping("/api/ordini")
    List<OrdineDTO> tutti();
}
\`\`\`

Le due stringhe devono coincidere: è l'unico collegamento fra chi chiama e chi
risponde. Da qui discendono tre conseguenze pratiche:

1. **Nel codice non compaiono mai host e porte.** Per questo \`task set-port\`
   può spostare un servizio senza rompere niente.
2. **Se sbagli il nome, l'errore arriva a runtime**, non in compilazione: una
   \`500\` con dentro un messaggio tipo *"Load balancer does not contain an
   instance for the service ORDINI-SERVICE"*. Controlla \`task status\`.
3. **Il registro non è immediato.** Ogni client tiene una copia del registro, e
   il load balancer una copia di quella: con i valori di Spring passano anche
   30-60 secondi prima che un servizio appena acceso sia chiamabile. I moduli
   di \`task new-service\` le rinfrescano ogni 5 secondi
   (\`registry-fetch-interval-seconds\`, \`spring.cloud.loadbalancer.cache.ttl\`),
   quindi basta poco; una \`500\` nei primissimi secondi non è un bug: riprova.

### 5.4 \`common-dto\`: il contratto condiviso

Quando due moduli si scambiano un oggetto, quell'oggetto deve avere **la stessa
forma da entrambe le parti**. Le strade sono due: duplicare la classe in ogni
modulo — e scoprire a metà esame che una delle due copie ha un campo in più —
oppure tenerla in un modulo solo, che gli altri usano come libreria. Quel
modulo è \`common-dto\`.

Non è un servizio: non ha \`Main\`, non ha una porta, non si registra su Eureka.
È un barattolo di classi.

**Aggiungere un DTO**: crei la classe dentro \`demo/common-dto/src/main/java/...\`

\`\`\`java
package esame.common.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data                 // getter, setter, equals, toString
@NoArgsConstructor    // Jackson ne ha bisogno per ricostruire l'oggetto dal JSON
@AllArgsConstructor
public class OrdineDTO {
    private Long id;
    private String cliente;
    private int quantita;
}
\`\`\`

\`@NoArgsConstructor\` non è decorativo: senza costruttore vuoto Jackson non sa
ricostruire l'oggetto, e la chiamata Feign fallisce con un errore che parla di
deserializzazione e non di DTO.

**Usarlo**: i moduli lo dichiarano già nel loro \`pom.xml\`, con la versione
presa dal progetto stesso —

\`\`\`xml
<dependency>
    <groupId>com.example</groupId>
    <artifactId>common-dto</artifactId>
    <version>\${project.version}</version>
</dependency>
\`\`\`

— quindi ti basta importarlo. Lo usa chi risponde:

\`\`\`java
@GetMapping("/api/ordini")
public List<OrdineDTO> tutti() { ... }
\`\`\`

e lo usa chi chiama, nella firma del \`@FeignClient\`. Stessa classe, stesso
JSON, nessuna sorpresa.

**La trappola**: \`common-dto\` è una dipendenza compilata, non un servizio. Se
lo modifichi, gli altri moduli continuano a usare la versione già installata
finché non li ricompili — e \`task compile\` fa esattamente questo, per tutti,
in un colpo solo. Se dopo una modifica a un DTO vedi un campo sparire dal
JSON, la causa è quasi sempre questa.

**Cosa ci va e cosa no**: DTO e piccoli \`enum\` condivisi. Non ci vanno le
\`@Entity\` (sono il modello del database di *un* servizio, non un contratto fra
servizi) né la logica di business.

### 5.5 Spring Security: Perché blocca tutto di default e come usarla all'esame

Quando aggiungi \`spring-boot-starter-security\` (con \`task add-dep SERVICE=... DEPS=security\`), Spring Boot attiva immediatamente l'autoconfigurazione di sicurezza:
1. **Blocca ogni rotta di default**: qualsiasi richiesta riceve \`401 Unauthorized\` (o redirect a \`/login\`).
2. **Genera una password casuale al boot**: visibile nei log con \`Using generated security password: ...\`.
3. **Abilita la protezione CSRF**: qualsiasi chiamata REST \`POST\`, \`PUT\`, \`DELETE\` inviata da Postman, curl o Feign viene bloccata con \`403 Forbidden\` perché priva del token CSRF.

#### Come si risolve per l'esame: \`task new-auth\`

Usa il comando \`task new-auth SERVICE=<modulo> [TYPE=inmemory|db|form]\` per generare l'architettura esatta richiesta dalla traccia:
- **\`TYPE=inmemory\` (default per REST)**: Genera \`SecurityConfig.java\` con Basic Auth, CSRF disabilitato, Swagger/Actuator/H2 aperti e utenti in-memory (\`admin\`/\`admin123\` e \`user\`/\`user123\`).
- **\`TYPE=db\` (Autenticazione su Database)**: Genera \`UtenteEntity\`, \`UtenteRepository\`, \`CustomUserDetailsService\` con crittografia BCrypt e seed automatico iniziale degli utenti a database vuoto.
- **\`TYPE=form\` (Web UI con Thymeleaf)**: Configura il Form Login con sessione, genera \`LoginController\` e crea il template \`templates/login.html\` stilizzato con gestione di errori e logout.

Per la spiegazione teorica dettagliata (come funzionano i filtri, taglib \`sec:authorize\` in Thymeleaf e domande d'esame su OAuth2/Keycloak), consulta la **[Lezione 18 del Corso: Sicurezza e Autenticazione](./corso/lezioni/18-sicurezza-e-autenticazione.md)**.

Se la traccia richiede autorizzazioni per ruolo, basta una sola riga nel bean \`SecurityFilterChain\`:
\`\`\`java
.requestMatchers(HttpMethod.POST, "/api/**").hasRole("ADMIN")
.requestMatchers(HttpMethod.GET, "/api/**").hasAnyRole("USER", "ADMIN")
\`\`\`

### 5.6 Relazioni JPA tra tabelle & Il confine sacro tra Microservizi

#### 1. All'interno dello stesso modulo (Stesso Database)
- **Many-to-One / One-to-Many**: La chiave esterna \`autore_id\` sta nella tabella del lato *Molti* (\`libri\`).
  \`\`\`java
  // In LibroEntity (lato Molti, detiene la FK)
  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "autore_id", nullable = false)
  private AutoreEntity autore;

  // In AutoreEntity (lato Uno, opzionale)
  @OneToMany(mappedBy = "autore", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<LibroEntity> libri = new ArrayList<>();
  \`\`\`
- **Many-to-Many**: Per relazioni N:N pure, Hibernate crea una tabella di giunzione automatica:
  \`\`\`java
  @ManyToMany(fetch = FetchType.LAZY)
  @JoinTable(name = "studenti_corsi",
      joinColumns = @JoinColumn(name = "studente_id"),
      inverseJoinColumns = @JoinColumn(name = "corso_id"))
  private Set<CorsoEntity> corsi = new HashSet<>();
  \`\`\`
  *Attenzione*: se la relazione ha attributi extra (es. \`dataIscrizione\`, \`voto\`), non usare \`@ManyToMany\`: crea un'entità intermedia con due \`@ManyToOne\`.
- **One-to-One**: Chiave esterna univoca (\`unique = true\`):
  \`\`\`java
  @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
  @JoinColumn(name = "tessera_id", unique = true)
  private TesseraEntity tessera;
  \`\`\`
- **Regole d'oro**:
  1. Usa sempre \`FetchType.LAZY\`.
  2. Mai \`@Data\` di Lombok sulle Entity con relazioni (causa \`StackOverflowError\` nel \`toString()\`).
  3. Inizializza sempre le liste (\`= new ArrayList<>()\`).
  4. Restituisci DTO dai controller per evitare loop infiniti di serializzazione JSON Jackson.

#### 2. Tra Moduli Diversi (Microservizi Diversi)
> **NON creare MAI relazioni JPA o chiavi esterne SQL che attraversano due moduli!**
> Ogni microservizio ha il proprio database. Salva esclusivamente l'ID numerico come colonna semplice (\`private Long libroId;\`) e recupera i dettagli invocando l'API REST dell'altro servizio via **OpenFeign** (\`task new-client\`) scambiando DTO (\`task new-dto\`).

---

## 6. Mini-Guida Completa alle Librerie ed Annotazioni Java

Per ogni libreria: la tabella delle annotazioni, e sotto un esempio completo
che dice **in quale modulo** va il codice.

### 6.1 Spring Web & MVC (\`@RestController\`, \`@Controller\`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| \`@RestController\` | Classe Controller | Marca la classe come controller REST. Ogni metodo restituisce direttamente JSON o dati strutturati (combina \`@Controller\` e \`@ResponseBody\`). |
| \`@Controller\` | Classe Controller | Marca la classe come controller Web tradizionali (Thymeleaf/HTML). I metodi restituiscono il nome del template HTML da renderizzare. |
| \`@RequestMapping("/api")\` | Classe / Metodo | Definisce il prefisso del percorso URL base gestito dal controller. |
| \`@GetMapping("/path")\` | Metodo | Mappa le richieste HTTP **GET** (lettura dati). |
| \`@PostMapping("/path")\` | Metodo | Mappa le richieste HTTP **POST** (creazione dati / form submit). |
| \`@PutMapping("/{id}")\` | Metodo | Mappa le richieste HTTP **PUT** (aggiornamento completo risorsa). |
| \`@DeleteMapping("/{id}")\` | Metodo | Mappa le richieste HTTP **DELETE** (cancellazione risorsa). |
| \`@PathVariable\` | Parametro metodo | Estrae un parametro variabile direttamente dal path dell'URL (es. \`/api/prodotti/{id}\`). |
| \`@RequestParam\` | Parametro metodo | Estrae un parametro dalla Query String (es. \`/api/prodotti?categoria=A1\`). |
| \`@RequestBody\` | Parametro metodo | Deserializza il corpo della richiesta HTTP JSON nel relativo DTO o Oggetto Java. |
| \`@ModelAttribute\` | Parametro metodo | Binda i dati inviati da un form HTML (Thymeleaf) ad un oggetto Java DTO. |
| \`@Validated\` / \`@Valid\` | Classe / Parametro | Attiva la validazione automatica delle annotazioni di vincolo (es. \`@NotNull\`, \`@Min\`) sui parametri di input. |

#### Esempio completo — un controller REST e uno Thymeleaf

Il primo va in un **servizio** (\`ordini-service\`), il secondo in una **UI**
(\`ordini-ui\`): stessa libreria, due usi diversi.

\`\`\`java
// demo/ordini-service/src/main/java/.../OrdineController.java
package esame.ordiniservice;

import esame.common.dto.OrdineDTO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController                       // ogni metodo restituisce JSON
@RequestMapping("/api/ordini")        // prefisso comune di tutti i path
@RequiredArgsConstructor              // Lombok: costruttore con i campi final
public class OrdineController {

    private final OrdineService service;   // iniettato dal costruttore

    // GET /api/ordini            -> elenco completo
    // GET /api/ordini?cliente=X  -> filtrato
    @GetMapping
    public List<OrdineDTO> elenco(@RequestParam(required = false) String cliente) {
        return (cliente == null) ? service.tutti() : service.perCliente(cliente);
    }

    // GET /api/ordini/7
    @GetMapping("/{id}")
    public ResponseEntity<OrdineDTO> uno(@PathVariable Long id) {
        return service.trova(id)
                .map(ResponseEntity::ok)                             // 200 col corpo
                .orElseGet(() -> ResponseEntity.notFound().build()); // 404
    }

    // POST /api/ordini, col JSON dell'ordine nel corpo
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)   // 201 invece del 200 di default
    public OrdineDTO crea(@Valid @RequestBody OrdineDTO nuovo) {
        return service.salva(nuovo);
    }

    @PutMapping("/{id}")
    public OrdineDTO aggiorna(@PathVariable Long id, @Valid @RequestBody OrdineDTO modifiche) {
        return service.aggiorna(id, modifiche);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)   // 204: fatto, niente da restituire
    public void elimina(@PathVariable Long id) {
        service.elimina(id);
    }
}
\`\`\`

> 💡 **Generazione automatica con \`task new-view\`**:
> \`\`\`bash
> task new-view SERVICE=ordini-ui NAME=Ordini FIELDS=cliente:string:required,quantita:int
> \`\`\`
> Genera contemporaneamente il controller Spring MVC (\`OrdiniUiController.java\`) e la vista HTML (\`templates/ordini.html\`) con tabella dinamica e form validato.

\`\`\`java
// demo/ordini-ui/src/main/java/.../OrdineWebController.java
package esame.ordiniui;

import esame.common.dto.OrdineDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

@Controller                    // NON @RestController: qui si restituiscono pagine
@RequiredArgsConstructor
public class OrdineWebController {

    private final OrdiniClient ordiniClient;   // il @FeignClient, vedi 6.3

    @GetMapping("/")
    public String elenco(Model model) {
        model.addAttribute("ordini", ordiniClient.tutti());
        model.addAttribute("nuovo", new OrdineDTO());   // oggetto vuoto per il form
        return "ordini";      // -> src/main/resources/templates/ordini.html
    }

    @PostMapping("/ordini")
    public String crea(@ModelAttribute OrdineDTO nuovo) {   // dati del form HTML
        ordiniClient.crea(nuovo);
        return "redirect:/";   // dopo una POST: niente doppio invio col refresh
    }
}
\`\`\`

\`\`\`html
<!-- demo/ordini-ui/src/main/resources/templates/ordini.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head><meta charset="UTF-8"><title>Ordini</title></head>
<body>
    <table>
        <tr th:each="o : \${ordini}">
            <td th:text="\${o.id}">1</td>
            <td th:text="\${o.cliente}">Rossi</td>
            <td th:text="\${o.quantita}">3</td>
        </tr>
    </table>

    <form th:action="@{/ordini}" th:object="\${nuovo}" method="post">
        <input type="text" th:field="*{cliente}">
        <input type="number" th:field="*{quantita}">
        <button type="submit">Aggiungi</button>
    </form>
</body>
</html>
\`\`\`

> Tre cose che all'esame fanno perdere tempo: \`@RestController\` su una classe
> che dovrebbe restituire pagine (il browser si ritrova il nome del template
> come testo), il \`redirect:\` dimenticato dopo una POST, e \`@RequestBody\` al
> posto di \`@ModelAttribute\` per i dati di un form — un form HTML non manda
> JSON.

---

### 6.2 OpenAPI / Springdoc (\`Swagger\`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| \`@Tag(name = "...", description = "...")\` | Classe Controller | Raggruppa gli endpoint sotto una categoria nell'interfaccia Swagger UI. |
| \`@Operation(summary = "...", description = "...")\` | Metodo REST | Descrive il titolo breve ed il dettaglio di cosa fa il singolo endpoint. |
| \`@Parameter(description = "...", example = "...")\` | Parametro metodo | Aggiunge descrizione ed un valore di esempio al parametro nella UI Swagger. |
| \`@ApiResponse(responseCode = "200", description = "...")\` | Metodo REST | Documenta l'esito HTTP di risposta restituito dall'API (200 OK, 400 Bad Request, 404 Not Found). |
| \`@Schema(description = "...", example = "...")\` | Campo DTO / Class | Documenta il significato ed i valori di esempio per le proprietà dei DTO nella sezione Schemas. |

#### Esempio completo — lo stesso controller, documentato

Va nel **servizio REST**; il \`@Schema\` dei campi va sul DTO, quindi in
**common-dto**. Senza nessuna di queste annotazioni Swagger funziona lo stesso
(elenca gli endpoint e li fa provare): servono a farlo leggere bene alla
commissione, ed è il punto della traccia che chiede il "descrittore".

\`\`\`java
// demo/ordini-service/src/main/java/.../OrdineController.java
package esame.ordiniservice;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/ordini")
@RequiredArgsConstructor
@Tag(name = "Ordini", description = "Creazione e consultazione degli ordini")
public class OrdineController {

    private final OrdineService service;

    @GetMapping("/{id}")
    @Operation(summary = "Un ordine per id",
               description = "Restituisce l'ordine, o 404 se quell'id non esiste")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Ordine trovato"),
        @ApiResponse(responseCode = "404", description = "Nessun ordine con quell'id",
                     content = @Content)   // 404 senza corpo: nessuno schema da mostrare
    })
    public ResponseEntity<OrdineDTO> uno(
            @Parameter(description = "Id dell'ordine", example = "7")
            @PathVariable Long id) {
        return service.trova(id).map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
\`\`\`

\`\`\`java
// demo/common-dto/src/main/java/.../OrdineDTO.java
import io.swagger.v3.oas.annotations.media.Schema;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Un ordine di magazzino")
public class OrdineDTO {

    @Schema(description = "Assegnato dal servizio", example = "7",
            accessMode = Schema.AccessMode.READ_ONLY)
    private Long id;

    @Schema(description = "Ragione sociale del cliente", example = "Rossi S.r.l.")
    private String cliente;

    @Schema(description = "Pezzi ordinati", example = "3")
    private int quantita;
}
\`\`\`

Titolo e versione dell'API, se non vuoi che la pagina si chiami "OpenAPI
definition" — una classe di configurazione, nello stesso servizio:

\`\`\`java
// demo/ordini-service/src/main/java/.../OpenApiConfig.java
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI openApi() {
        return new OpenAPI().info(new Info()
                .title("Ordini Service")
                .version("1.0")
                .description("API degli ordini — prova finale"));
    }
}
\`\`\`

> \`@Tag\` di Swagger è \`io.swagger.v3.oas.annotations.tags.Tag\`: se l'IDE
> importa \`org.junit.jupiter.api.Tag\`, il progetto non compila e l'errore parla
> di tutt'altro. Nel template la dipendenza c'è già in ogni modulo generato;
> altrimenti \`task enable-swagger SERVICE=<modulo>\`.

---

### 6.3 Spring Cloud (Eureka & OpenFeign)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| \`@EnableEurekaServer\` | Classe Main | Trasforma l'applicazione Spring Boot nel Server Eureka per il Service Discovery. |
| \`@EnableDiscoveryClient\` | Classe Main | Abilita l'applicazione client a registrarsi presso il registro Eureka Naming Server. |
| \`@EnableFeignClients\` | Classe Main / Config | Attiva la scansione e la generazione automatica delle interfacce OpenFeign. |
| \`@FeignClient(name = "ORDINI-SERVICE")\` | Interfaccia Java | Dichiara un client REST dichiarativo. Spring imposta automaticamente il bilanciamento del carico verso il servizio registrato su Eureka con quel nome logico. |

#### Esempio completo — il server, il client, e la chiamata

Tre moduli diversi. **Il server** (\`naming-server\`) è già nel template e non lo
tocchi quasi mai:

\`\`\`java
// demo/naming-server/src/main/java/.../Main.java
package esame.namingserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@EnableEurekaServer          // questa applicazione E' il registro
@SpringBootApplication
public class Main {
    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
\`\`\`

\`\`\`yaml
# demo/naming-server/src/main/resources/application.yml
server:
  port: \${SERVER_PORT:8761}
eureka:
  client:
    register-with-eureka: false   # il registro non si registra su se stesso
    fetch-registry: false
\`\`\`

**Chi chiama** (una UI, o un servizio che ne consuma un altro): l'annotazione
sulla \`Main\` e un'interfaccia. Nei moduli creati da \`task new-service\` la
\`Main\` è già così:

\`\`\`java
// demo/ordini-ui/src/main/java/.../Main.java
@EnableDiscoveryClient       // mi registro su Eureka
@EnableFeignClients          // cerca le interfacce @FeignClient e le implementa
@SpringBootApplication
public class Main {
    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
\`\`\`

> 💡 **Generazione automatica con \`task new-client\`**:
> Invece di scrivere l'interfaccia Feign e i DTO a mano:
> \`\`\`bash
> task new-client FROM=ordini-ui TO=ordini-service DTO=OrdineDTO FIELDS=id:long,cliente:string:required,quantita:int
> \`\`\`
> Genera \`OrdiniClient.java\` già annotato con \`@FeignClient(name = "ORDINI-SERVICE")\` e, se non esiste già, crea anche il record \`OrdineDTO\` dentro \`common-dto\` con i relativi campi!

\`\`\`java
// demo/ordini-ui/src/main/java/.../OrdiniClient.java
package esame.ordiniui;

import esame.common.dto.OrdineDTO;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// "ORDINI-SERVICE" e' lo spring.application.name dell'altro modulo,
// non un indirizzo: host e porta li chiede a Eureka.
@FeignClient(name = "ORDINI-SERVICE")
public interface OrdiniClient {

    @GetMapping("/api/ordini")
    List<OrdineDTO> tutti();

    @GetMapping("/api/ordini/{id}")
    OrdineDTO uno(@PathVariable("id") Long id);

    @GetMapping("/api/ordini")
    List<OrdineDTO> perCliente(@RequestParam("cliente") String cliente);

    @PostMapping("/api/ordini")
    OrdineDTO crea(@RequestBody OrdineDTO nuovo);
}
\`\`\`

Usarla è come chiamare un metodo normale — l'HTTP è nascosto:

\`\`\`java
// demo/ordini-ui/src/main/java/.../OrdineFacade.java
@Service
@RequiredArgsConstructor
@Slf4j
public class OrdineFacade {

    private final OrdiniClient ordiniClient;

    public List<OrdineDTO> elenco() {
        try {
            return ordiniClient.tutti();
        } catch (Exception e) {
            // Se il servizio e' spento, la UI resta in piedi con l'elenco vuoto:
            // e' la "resilienza" che la commissione chiede spesso di mostrare.
            log.warn("ORDINI-SERVICE non risponde: {}", e.getMessage());
            return List.of();
        }
    }
}
\`\`\`

> Nel \`@FeignClient\` i \`@PathVariable\` e i \`@RequestParam\` **devono avere il
> nome scritto** (\`@PathVariable("id")\`): in un'interfaccia i nomi dei
> parametri non sopravvivono alla compilazione, e senza quella stringa parte un
> errore poco leggibile all'avvio.
>
> E ricorda che il registro non è immediato: un client appena avviato non ha
> ancora la lista delle istanze, e la primissima chiamata può fallire anche se
> è tutto a posto (vedi 5.3: nei moduli generati bastano pochi secondi).

---

### 6.4 Spring Data JPA & Hibernate

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| \`@Entity\` | Classe Modello | Dichiara che la classe Java è una tabella del database gestita da JPA/Hibernate. |
| \`@Table(name = "nome_tabella")\` | Classe Entity | Mappa il nome esatto della tabella SQL sul DB relazionale. |
| \`@Id\` | Campo Entity | Mappa la Chiave Primaria (Primary Key) della tabella. |
| \`@GeneratedValue(strategy = GenerationType.IDENTITY)\` | Campo Id | Imposta l'incremento automatico del valore dell'ID a livello DB (\`AUTO_INCREMENT\` / \`SERIAL\`). |
| \`@Column(name = "...", nullable = false)\` | Campo Entity | Mappa il nome della colonna SQL e vincoli di nullabilità o lunghezza. |
| \`@Enumerated(EnumType.STRING)\` | Campo Enum | Memorizza un valore \`enum\` Java nel database come stringa di testo anziché come numero indice. |
| \`@Transient\` | Campo Entity | Indica a JPA di ignorare il campo (non verrà creata alcuna colonna sul DB). |
| \`@ManyToOne\` / \`@OneToMany\` | Campo Entity | Definisce le relazioni tra tabelle (Molti-a-Uno, Uno-a-Molti) con gestione delle Foreign Key. |
| \`JpaRepository<Entity, IdType>\` | Interfaccia Repo | Interfaccia Spring Data che fornisce gratuitamente tutti i metodi CRUD (\`save\`, \`findById\`, \`findAll\`, \`deleteById\`). |

#### Generazione automatica in 5 secondi: \`task new-entity\`

Invece di scrivere da zero l'Entity, il Repository, il Service e il Controller REST con decine di righe boilerplate:

\`\`\`bash
task new-entity SERVICE=ordini-service NAME=Ordine FIELDS=cliente:string(120):required,quantita:int:required,consegna:date
\`\`\`

Questo singolo comando genera un'architettura completa a 4 strati:
1. **Entity JPA** (\`OrdineEntity.java\`): \`@Entity\`, \`@Table(name = "ordini")\`, chiave \`@Id @GeneratedValue\`, vincoli di validazione Jakarta (\`@NotBlank\`, \`@NotNull\`, ecc.) e getter/setter Lombok.
2. **Spring Data Repository** (\`OrdineRepository.java\`): interfaccia estesa da \`JpaRepository<OrdineEntity, Long>\`.
3. **Service di Business** (\`OrdineService.java\`): con metodi CRUD pronti (\`tutti()\`, \`perId()\`, \`crea()\`, \`aggiorna()\`, \`elimina()\`).
4. **Controller REST** (\`OrdineController.java\`): con OpenAPI Swagger (\`@Tag\`, \`@Operation\`), rotte HTTP REST e validazione \`@Valid\`.

#### Esempio completo — entity, repository, service, dati di prova

Tutto dentro **il servizio che possiede quei dati**: le \`@Entity\` non si
condividono e non vanno in \`common-dto\`.

\`\`\`java
// demo/ordini-service/src/main/java/.../persistence/OrdineEntity.java
package esame.ordiniservice.persistence;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "ordini")
@Getter @Setter          // su una @Entity meglio questi che @Data (vedi 6.5)
@NoArgsConstructor       // richiesto da JPA
@AllArgsConstructor
public class OrdineEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "cliente", nullable = false, length = 120)
    private String cliente;

    @Column(nullable = false)
    private int quantita;

    @Enumerated(EnumType.STRING)     // salva "IN_CORSO", non 0
    @Column(nullable = false)
    private StatoOrdine stato;

    private LocalDate consegna;

    @Transient                       // calcolato, non salvato
    private boolean urgente;

    // Molti ordini appartengono a un magazzino: la FK sta qui.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "magazzino_id")
    private MagazzinoEntity magazzino;
}
\`\`\`

\`\`\`java
// demo/ordini-service/src/main/java/.../persistence/OrdineRepository.java
package esame.ordiniservice.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

// save, findById, findAll, deleteById, count... arrivano gratis.
public interface OrdineRepository extends JpaRepository<OrdineEntity, Long> {

    // Query derivate dal nome del metodo: Spring le traduce in SQL da sola.
    List<OrdineEntity> findByCliente(String cliente);
    List<OrdineEntity> findByQuantitaGreaterThanOrderByQuantitaDesc(int soglia);
    boolean existsByCliente(String cliente);

    // Quando il nome non basta, JPQL (sulle CLASSI, non sulle tabelle):
    @Query("SELECT o FROM OrdineEntity o WHERE o.stato = :stato AND o.quantita >= :min")
    List<OrdineEntity> daEvadere(@Param("stato") StatoOrdine stato, @Param("min") int min);
}
\`\`\`

\`\`\`java
// demo/ordini-service/src/main/java/.../OrdineService.java
package esame.ordiniservice;

import esame.common.dto.OrdineDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class OrdineService {

    private final OrdineRepository repository;

    public List<OrdineDTO> tutti() {
        return repository.findAll().stream().map(this::toDto).toList();
    }

    public Optional<OrdineDTO> trova(Long id) {
        return repository.findById(id).map(this::toDto);
    }

    @Transactional                       // scrittura: tutto o niente
    public OrdineDTO salva(OrdineDTO dto) {
        OrdineEntity entity = new OrdineEntity();
        entity.setCliente(dto.getCliente());
        entity.setQuantita(dto.getQuantita());
        entity.setStato(StatoOrdine.IN_CORSO);
        return toDto(repository.save(entity));   // save() torna l'entity con l'id
    }

    // L'@Entity resta dentro il servizio, fuori esce il DTO condiviso.
    private OrdineDTO toDto(OrdineEntity e) {
        return new OrdineDTO(e.getId(), e.getCliente(), e.getQuantita());
    }
}
\`\`\`

I **dati di prova** valgono punti nella griglia d'esame ("dati di test"). Il
modo più corto è un \`CommandLineRunner\`, che gira all'avvio:

\`\`\`java
// demo/ordini-service/src/main/java/.../DatiDiProva.java
@Configuration
@RequiredArgsConstructor
public class DatiDiProva {

    @Bean
    CommandLineRunner inizializza(OrdineRepository repository) {
        return args -> {
            if (repository.count() > 0) return;   // solo su database vuoto
            repository.save(new OrdineEntity(null, "Rossi S.r.l.", 3, StatoOrdine.IN_CORSO, null, false, null));
            repository.save(new OrdineEntity(null, "Bianchi SPA", 12, StatoOrdine.EVASO, null, false, null));
        };
    }
}
\`\`\`

In alternativa, un \`demo/ordini-service/src/main/resources/data.sql\` con degli
\`INSERT\`: Spring Boot lo esegue da solo dopo che Hibernate ha creato le tabelle.

> Con H2 in memoria le tabelle nascono e muoiono a ogni riavvio, quindi i dati
> di prova si ricreano sempre. Passando a PostgreSQL
> (\`task use-postgres SERVICE=ordini-service\`) restano: per questo il
> \`CommandLineRunner\` qui sopra controlla \`count() > 0\` prima di inserire.

---

### 6.5 Lombok (Riduzione del Codice Boilerplate)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| \`@Data\` | Classe DTO / Entity | Genera automaticamente Getters, Setters, \`equals()\`, \`hashCode()\` e \`toString()\`. |
| \`@Getter\` / \`@Setter\` | Campo / Classe | Genera i metodi di lettura e scrittura per le proprietà della classe. |
| \`@NoArgsConstructor\` | Classe | Genera il costruttore pubblico senza argomenti (richiesto obbligatoriamente da JPA/Jackson). |
| \`@AllArgsConstructor\` | Classe | Genera il costruttore completo con tutti i campi della classe. |
| \`@RequiredArgsConstructor\` | Classe | Genera un costruttore contenente solo i campi dichiarati \`private final\` (usato per l'Iniezione delle Dipendenze pulita). |
| \`@Builder\` | Classe | Pattern Builder per la creazione fluida degli oggetti (es. \`Prodotto.builder().nome("X").build()\`). |
| \`@Slf4j\` | Classe | Inietta un logger SLF4J denominato \`log\` per stampare log nel codice (\`log.info(...)\`, \`log.error(...)\`). |

#### Esempio completo — un DTO e un service, prima e dopo

Il DTO sta in **common-dto**, il service nel **modulo che lo usa**.

\`\`\`java
// demo/common-dto/src/main/java/.../OrdineDTO.java
package esame.common.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data                  // getter, setter, equals, hashCode, toString
@Builder               // OrdineDTO.builder().cliente("Rossi").build()
@NoArgsConstructor     // serve a Jackson per ricostruire l'oggetto dal JSON
@AllArgsConstructor    // serve al @Builder e ai costruttori a mano
public class OrdineDTO {
    private Long id;
    private String cliente;
    private int quantita;
}
\`\`\`

Le stesse tre righe, senza Lombok, sarebbero una sessantina: due costruttori,
sei fra getter e setter, \`equals\`, \`hashCode\` e \`toString\`.

\`\`\`java
// demo/ordini-service/src/main/java/.../OrdineService.java
package esame.ordiniservice;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor   // costruttore con i soli campi final: niente @Autowired
@Slf4j                     // mette a disposizione "log"
public class OrdineService {

    private final OrdineRepository repository;   // final = iniettato
    private final ProdottiClient prodottiClient;

    public OrdineDTO salva(OrdineDTO dto) {
        log.info("Nuovo ordine per {}, {} pezzi", dto.getCliente(), dto.getQuantita());
        ...
    }
}
\`\`\`

Uso del builder, comodo quando i campi sono tanti e non vuoi ricordarne
l'ordine:

\`\`\`java
OrdineDTO dto = OrdineDTO.builder()
        .cliente("Rossi S.r.l.")
        .quantita(3)
        .build();          // gli altri campi restano a null / 0
\`\`\`

> **Su una \`@Entity\` non mettere \`@Data\`.** Genera \`equals\` e \`hashCode\` su
> tutti i campi, relazioni comprese: con un \`@ManyToOne\` Hibernate finisce per
> caricare mezzo database (o cicla all'infinito) solo per confrontare due
> oggetti. Su un'entity: \`@Getter @Setter @NoArgsConstructor\`, e se ti serve
> \`equals\` scrivilo sull'id.
>
> Se i getter "non esistono" in compilazione, il processore di annotazioni non
> sta girando: in VS Code serve l'estensione Lombok, e in ogni caso \`task
> compile\` da terminale compila lo stesso, perché Maven ce l'ha configurato.

---

### 6.6 Jakarta Validation (\`jakarta.validation.constraints\`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| \`@NotNull\` | Campo DTO | Il valore non può essere \`null\`. |
| \`@NotBlank\` | Campo Stringa | La stringa non può essere \`null\`, vuota \`""\` o contenere solo spazi bianchi \`" "\`. |
| \`@NotEmpty\` | Campo Collection/String | La collezione o stringa non deve essere vuota. |
| \`@Min(valore)\` / \`@Max(valore)\` | Campo Numerico | Imposta i limiti numerici minimo e massimo ammessi. |
| \`@Size(min = X, max = Y)\` | Campo String/Collection | Controlla la lunghezza minima e massima di caratteri o elementi. |

#### Esempio completo — vincoli sul DTO, controllo nel controller, errore leggibile

I vincoli stanno sul DTO (**common-dto**), il \`@Valid\` nel controller del
**servizio**, e il gestore degli errori nello stesso servizio.

\`\`\`java
// demo/common-dto/src/main/java/.../OrdineDTO.java
package esame.common.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrdineDTO {

    private Long id;    // lo assegna il servizio: nessun vincolo

    @NotBlank(message = "il cliente e' obbligatorio")
    @Size(max = 120, message = "il nome del cliente supera i 120 caratteri")
    private String cliente;

    @Min(value = 1, message = "la quantita' deve essere almeno 1")
    private int quantita;
}
\`\`\`

\`\`\`java
// nel controller del servizio: @Valid fa scattare i vincoli
@PostMapping
@ResponseStatus(HttpStatus.CREATED)
public OrdineDTO crea(@Valid @RequestBody OrdineDTO nuovo) {
    return service.salva(nuovo);
}
\`\`\`

Senza altro, una richiesta non valida torna **400** con un corpo lungo e poco
leggibile. Una classe sola lo trasforma in un messaggio pulito — e fa una bella
figura in Swagger.

> 💡 **Generazione automatica con \`task new-handler\`**:
> \`\`\`bash
> task new-handler SERVICE=ordini-service
> \`\`\`
> Genera \`exception/GlobalExceptionHandler.java\` con \`@RestControllerAdvice\`, gestione di \`MethodArgumentNotValidException\` (400), \`ResponseStatusException\`, \`EntityNotFoundException\` (404) ed errori generici (500).

\`\`\`java
// demo/ordini-service/src/main/java/.../GestioneErrori.java
package esame.ordiniservice;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice          // vale per tutti i controller del modulo
public class GestioneErrori {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)     // 400
    public Map<String, String> vincoliViolati(MethodArgumentNotValidException e) {
        Map<String, String> errori = new HashMap<>();
        e.getBindingResult().getFieldErrors()
                .forEach(err -> errori.put(err.getField(), err.getDefaultMessage()));
        return errori;   // {"cliente": "il cliente e' obbligatorio"}
    }
}
\`\`\`

Nella UI Thymeleaf i vincoli si controllano con \`@Valid\` + \`BindingResult\`, e
il messaggio si mostra accanto al campo:

\`\`\`java
@PostMapping("/ordini")
public String crea(@Valid @ModelAttribute("nuovo") OrdineDTO nuovo,
                   BindingResult errori,          // DEVE stare subito dopo l'oggetto
                   Model model) {
    if (errori.hasErrors()) {
        model.addAttribute("ordini", ordiniClient.tutti());
        return "ordini";      // torna al form, coi messaggi
    }
    ordiniClient.crea(nuovo);
    return "redirect:/";
}
\`\`\`

\`\`\`html
<input type="text" th:field="*{cliente}">
<span th:if="\${#fields.hasErrors('cliente')}" th:errors="*{cliente}"></span>
\`\`\`

> \`@Valid\` senza la dipendenza \`validation\` nel pom non fa niente, in silenzio:
> l'annotazione compila e i vincoli non scattano. \`task add-dep
> SERVICE=<modulo> DEPS=validation\` (nei moduli generati c'è già).
>
> E \`BindingResult\` va **subito dopo** l'oggetto annotato con \`@Valid\`: se ci
> metti un altro parametro in mezzo, Spring lancia l'eccezione invece di
> passarti gli errori.

---

### 6.7 Thymeleaf: il cheat sheet delle pagine

Thymeleaf è il motore delle pagine della UI (\`<nome>-ui\`, quella che crei con
\`task new-service NAME=ordini-ui UI=1\`). Un template è HTML normale, che si
apre anche nel browser come file; gli attributi \`th:*\` dicono a Thymeleaf cosa
sostituire con i dati che il controller ha messo nel \`Model\`.

Tutto quello che c'è qui sotto è stato provato su questo template (Spring Boot
4.0.5, Thymeleaf 3.1): gli esempi sono copiati da pagine che girano, e dove
Thymeleaf si comporta in modo inatteso c'è scritto.

#### Come si aggancia a Spring Boot

| Cosa | Dove / come |
| :--- | :--- |
| La libreria | \`spring-boot-starter-thymeleaf\` nel pom del modulo UI (la mette \`new-service ... UI=1\`). Nient'altro da configurare. |
| Le pagine | \`src/main/resources/templates/\`. Il controller restituisce il percorso da lì, **senza** \`.html\` e **senza** barra iniziale: \`return "ordini/elenco";\` apre \`templates/ordini/elenco.html\`. |
| CSS, JS, immagini | \`src/main/resources/static/\`: \`static/css/app.css\` si carica come \`/css/app.css\`. |
| I testi | \`src/main/resources/messages.properties\`, letto da solo: \`#{chiave}\` nelle pagine. |
| Le pagine d'errore | \`templates/error/404.html\`, \`error/500.html\` (o \`error.html\` per tutte): Spring Boot le usa da solo, con \`\${status}\`, \`\${error}\`, \`\${path}\`. |
| La cache | Con devtools (ereditato dal pom padre) è già spenta: dopo \`task compile\` la pagina nuova si vede col refresh. |

Il giro di una pagina:

\`\`\`text
browser  GET /ordini?q=ros
   │
   ▼
@Controller  @GetMapping("/ordini")        prende i dati (dal Feign client)
   │         model.addAttribute("ordini", ...)
   │         return "ordini/elenco";
   ▼
Thymeleaf   templates/ordini/elenco.html   sostituisce i th:* con i dati del Model
   │
   ▼
browser     riceve HTML normale: di Thymeleaf non resta traccia
\`\`\`

#### Le cinque espressioni

| Sintassi | Cosa legge | Esempio | Risultato |
| :--- | :--- | :--- | :--- |
| \`\${...}\` | una variabile del \`Model\` (dentro c'è SpEL) | \`\${ordine.cliente}\` | chiama \`getCliente()\`, o \`cliente()\` se è un record |
| \`*{...}\` | un campo dell'oggetto scelto con \`th:object\` | \`<div th:object="\${ordine}">\` … \`*{cliente}\` | come \`\${ordine.cliente}\`, più corto |
| \`@{...}\` | un link, con parametri già codificati | \`@{/ordini/{id}(id=\${o.id})}\` | \`/ordini/2\` |
| | | \`@{/ordini(q=\${q}, pagina=2)}\` | \`/ordini?q=ros&pagina=2\` |
| \`#{...}\` | un testo di \`messages.properties\` | \`#{ordini.titolo}\` | \`Ordini in corso\` |
| | | \`#{ordini.saluto('Rossi', 3)}\` con \`ordini.saluto=Ciao {0}, hai {1} ordini\` | \`Ciao Rossi, hai 3 ordini\` |
| \`~{...}\` | un frammento di un altro template | \`~{fragments/layout :: menu}\` | il \`<nav>\` del layout |

#### Gli attributi

| Attributo | Cosa fa | Esempio |
| :--- | :--- | :--- |
| \`th:text\` | sostituisce il contenuto del tag; l'HTML nei dati viene **escapato** (\`<b>\` diventa testo) | \`<td th:text="\${o.cliente}">Rossi</td>\` |
| \`th:utext\` | come \`th:text\` ma **senza** escape: l'HTML passa com'è. Mai con testo scritto dagli utenti | \`<p th:utext="\${avviso}"></p>\` |
| \`th:each\` | ripete il tag per ogni elemento | \`<tr th:each="o, st : \${ordini}">\` |
| \`th:if\` / \`th:unless\` | tiene il tag se la condizione è vera / falsa (vedi sotto cosa conta come vero) | \`<p th:if="\${#lists.isEmpty(ordini)}">Nessun ordine.</p>\` |
| \`th:switch\` / \`th:case\` | uno fra tanti; \`th:case="*"\` è il resto | \`<td th:switch="\${o.stato.name()}"><span th:case="'NUOVO'">…\` |
| \`th:href\` \`th:src\` \`th:action\` | link, immagini, destinazione dei form: sempre con \`@{...}\` | \`<form th:action="@{/ordini}" method="post">\` |
| \`th:object\` | sceglie l'oggetto per le \`*{...}\` (un form, o un blocco di pagina) | \`<form th:object="\${ordine}">\` |
| \`th:field\` | lega un campo del form all'oggetto: scrive \`id\`, \`name\` e \`value\` (e \`selected\`/\`checked\`); alla POST Spring rimette il valore nell'oggetto | \`<input type="text" th:field="*{cliente}">\` |
| \`th:errors\` | i messaggi di validazione di un campo; se non ci sono errori il tag sparisce | \`<span th:errors="*{cliente}"></span>\` |
| \`th:errorclass\` | aggiunge una classe CSS al campo solo quando è sbagliato | \`<input th:field="*{cliente}" th:errorclass="campo-errato">\` |
| \`th:value\` | solo il \`value\`, senza legare niente (per un campo fuori da \`th:object\`) | \`<input name="q" th:value="\${q}">\` |
| \`th:classappend\` | aggiunge una classe a quelle che il tag ha già | \`<tr th:classappend="\${o.urgente} ? 'urgente'">\` |
| \`th:disabled\` \`th:checked\` \`th:selected\` \`th:readonly\` | attributi booleani: presenti se vero, spariscono se falso | \`th:disabled="*{stato.name() == 'CONSEGNATO'}"\` |
| \`th:data-*\` (e qualsiasi \`th:<attributo>\`) | scrive l'attributo con quel nome | \`<button th:data-id="*{id}">\` → \`data-id="2"\` |
| \`th:with\` | una variabile locale al tag | \`<p th:with="totale=*{quantita * prezzo}">\` |
| \`th:fragment\` | dà un nome a un pezzo di pagina, anche con parametri | \`<head th:fragment="head(titolo)">\` |
| \`th:replace\` / \`th:insert\` | mette il frammento **al posto** del tag / **dentro** il tag | \`<nav th:replace="~{fragments/layout :: menu}"></nav>\` |
| \`th:block\` | un contenitore che non finisce nell'HTML: per ripetere più tag insieme | \`<th:block th:each="o : \${ordini}">…</th:block>\` |
| \`th:remove="all"\` | toglie il tag: righe finte che servono solo aprendo il file nel browser | \`<tr th:remove="all"><td>Riga finta</td></tr>\` |
| \`th:inline="javascript"\` | dati Java dentro uno \`<script>\`, già trasformati in JSON | \`const ordini = /*[[\${ordini}]]*/ [];\` |
| \`[[...]]\` / \`[(...)]\` | un'espressione dentro il testo, con / senza escape | \`<p>Ciao [[\${nome}]]</p>\` |

#### Operatori e scorciatoie

| Cosa | Come si scrive | Nota |
| :--- | :--- | :--- |
| Concatenare | \`\${o.quantita} + ' pezzi'\` | |
| Sostituzione letterale | \`\\|Ordine n. \${o.id}\\|\` | fra due barre verticali: più leggibile del \`+\` |
| Condizione | \`\${o.urgente} ? 'sì' : 'no'\` | senza la parte \`: …\`, se è falso non scrive niente: comodo con \`th:classappend\` |
| Valore di riserva (Elvis) | \`\${o.note} ?: 'nessuna'\` | scatta solo con \`null\`: una stringa vuota resta vuota |
| Navigazione sicura | \`\${o.note?.toUpperCase()}\` | se \`note\` è \`null\` non esplode, scrive vuoto |
| Confronti | \`gt\` \`lt\` \`ge\` \`le\` \`eq\` \`ne\` (oppure \`>\` \`<\` \`>=\` \`<=\` \`==\` \`!=\`) | dentro un attributo HTML il \`<\` può rompere il tag: usa \`lt\` |
| Logici | \`and\` \`or\` \`not\` | |
| Metodi | \`\${o.stato.name()}\`, \`\${ordini.size()}\` | SpEL chiama qualsiasi metodo pubblico |
| Classi ed enum | \`\${T(esame.common.dto.Stato).values()}\` | funziona, ma un \`@ModelAttribute\` nel controller è più leggibile |
| Bean di Spring | \`\${@environment.getProperty('spring.application.name')}\` | \`@nomeDelBean\` |
| Proiezione | \`\${ordini.![quantita]}\` | la lista dei soli \`quantita\`: si passa a \`#aggregates\` e \`#lists\` |
| Parametri della richiesta | \`\${param.q}\` per scriverlo, \`\${param.q[0]}\` per confrontarlo | \`param.q\` è l'elenco dei valori di \`?q=\`; meglio ancora: rimettilo nel \`Model\` |
| Sessione | \`\${session.utente}\` | gli attributi messi con \`session.setAttribute(...)\` |

#### Gli oggetti di utilità (\`#...\`)

| Oggetto | Esempio | Risultato |
| :--- | :--- | :--- |
| \`#strings\` | \`\${#strings.abbreviate(o.note, 20)}\` | \`Consegnare al por...\` |
| | \`isEmpty(s)\`, \`toUpperCase(s)\`, \`contains(s, 'x')\`, \`replace(s, '-', '+')\`, \`substring(s, 1, 3)\` | |
| \`#numbers\` | \`\${#numbers.formatDecimal(o.prezzo, 1, 'POINT', 2, 'COMMA')}\` | \`1.234,50\` |
| | \`\${#numbers.formatDecimal(x, 1, 2)}\` | due decimali, separatore della lingua del browser |
| | \`\${#numbers.formatInteger(1234567, 1, 'POINT')}\` | \`1.234.567\` |
| \`#temporals\` | \`\${#temporals.format(o.consegna, 'dd/MM/yyyy')}\` | \`20/09/2026\` (per \`LocalDate\`, \`LocalDateTime\`) |
| | \`#temporals.createToday()\`, \`#temporals.day(data)\` | |
| \`#dates\` | \`\${#dates.format(data, 'dd/MM/yyyy')}\` | lo stesso, per il vecchio \`java.util.Date\` |
| \`#lists\` | \`isEmpty(l)\`, \`size(l)\`, \`contains(l, x)\`, \`sort(l)\` | |
| \`#aggregates\` | \`\${#aggregates.sum(ordini.![quantita])}\`, \`avg(...)\` | su una lista **vuota** restituisce \`null\`: usalo dentro un \`th:unless="\${#lists.isEmpty(...)}"\` |
| \`#fields\` | \`\${#fields.hasErrors('cliente')}\`, \`\${#fields.hasAnyErrors()}\` | solo dentro un \`th:object\` |
| \`#objects\` | \`\${#objects.nullSafe(x, 'riserva')}\` | come Elvis |

#### Il ciclo: la variabile di stato

\`th:each="o, st : \${ordini}"\` dà, oltre all'elemento \`o\`, lo stato \`st\` (se
non lo dichiari si chiama \`oStat\` da solo):

| \`st.\` | Valore |
| :--- | :--- |
| \`index\` | posizione contando da 0 |
| \`count\` | posizione contando da 1 |
| \`size\` | quanti sono in tutto |
| \`first\` / \`last\` | è il primo / l'ultimo |
| \`even\` / \`odd\` | pari / dispari, contando da 1 |
| \`current\` | l'elemento corrente |

#### Cosa conta come vero in \`th:if\`

| Valore | \`th:if\` |
| :--- | :--- |
| \`null\` | falso |
| \`false\`, e le stringhe \`"false"\`, \`"off"\`, \`"no"\` | falso |
| il numero \`0\` | falso |
| una stringa vuota \`""\` | **vero** |
| una lista vuota | **vero** |
| qualsiasi altra cosa | vero |

Quindi \`th:if="\${ordini}"\` è sempre vero, anche senza ordini: per le liste si
scrive \`th:if="\${#lists.isEmpty(ordini)}"\`, per le stringhe
\`th:unless="\${#strings.isEmpty(s)}"\`.

#### Esempio completo — elenco, dettaglio e form con validazione

Tutto nel modulo **UI** (\`ordini-ui\`). I dati arrivano da \`ordini-service\`
attraverso il \`@FeignClient\` \`OrdiniClient\` (vedi 6.3); qui conta cosa succede
fra controller e pagine.

\`\`\`java
// demo/ordini-ui/src/main/java/.../OrdineForm.java
// L'oggetto del form: un campo per ogni <input>, coi vincoli di validazione.
package esame.ordiniui;

import esame.common.dto.Stato;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;

@Data                                   // getter e setter: th:field li usa entrambi
public class OrdineForm {

    @NotBlank(message = "Il cliente è obbligatorio")
    private String cliente;

    @NotNull(message = "Quanti pezzi?")
    @Min(value = 1, message = "Almeno un pezzo")
    private Integer quantita;

    private Stato stato = Stato.NUOVO;  // il valore iniziale della <select>
    private boolean urgente;            // una checkbox

    // <input type="date"> manda 2026-10-01: senza questa riga Spring non sa leggerla.
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate consegna;
}
\`\`\`

> Anche un **record** va bene come oggetto del form: \`th:field\` lo legge e alla
> POST Spring lo costruisce col costruttore (provato con testo e numeri). Così
> puoi usare direttamente il DTO di \`common-dto\`, per esempio
> \`new OrdineDTO(null, null)\` nel metodo GET.

\`\`\`java
// demo/ordini-ui/src/main/java/.../OrdiniWebController.java
package esame.ordiniui;

import esame.common.dto.Stato;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller                        // pagine, non JSON: niente @RestController qui
@RequestMapping("/ordini")
@RequiredArgsConstructor
public class OrdiniWebController {

    private final OrdiniClient ordini;   // il @FeignClient verso ordini-service

    // Un metodo @ModelAttribute gira prima di ogni pagina di questo controller:
    // la <select> degli stati ce l'ha sempre, anche quando il form torna con errori.
    @ModelAttribute("stati")
    public Stato[] stati() {
        return Stato.values();
    }

    // GET /ordini  e  GET /ordini?q=ros
    @GetMapping
    public String elenco(@RequestParam(required = false) String q, Model model) {
        model.addAttribute("ordini", ordini.cerca(q));
        model.addAttribute("q", q);             // per rimetterlo nella casella di ricerca
        return "ordini/elenco";                 // templates/ordini/elenco.html
    }

    // GET /ordini/2
    @GetMapping("/{id}")
    public String dettaglio(@PathVariable Long id, Model model) {
        model.addAttribute("ordine", ordini.uno(id));
        return "ordini/dettaglio";
    }

    // Il form parte da un oggetto vuoto: senza, th:object non ha niente da
    // legare e la pagina va in errore.
    @GetMapping("/nuovo")
    public String nuovo(Model model) {
        model.addAttribute("ordine", new OrdineForm());
        return "ordini/form";
    }

    @PostMapping
    public String salva(@Valid @ModelAttribute("ordine") OrdineForm ordine,
                        BindingResult errori,        // SUBITO dopo l'oggetto validato
                        RedirectAttributes redirect) {
        if (errori.hasErrors()) {
            return "ordini/form";    // la stessa pagina: i dati inseriti e gli errori restano
        }
        ordini.crea(ordine);
        // Un attributo "flash" sopravvive al redirect e sparisce alla pagina dopo.
        redirect.addFlashAttribute("messaggio", "Ordine salvato");
        return "redirect:/ordini";   // dopo una POST: il refresh non rimanda il form
    }

    // I form HTML conoscono solo GET e POST: si cancella con una POST, e la
    // DELETE vera la fa il Feign client verso il servizio.
    @PostMapping("/{id}/elimina")
    public String elimina(@PathVariable Long id, RedirectAttributes redirect) {
        ordini.elimina(id);
        redirect.addFlashAttribute("messaggio", "Ordine eliminato");
        return "redirect:/ordini";
    }
}
\`\`\`

I pezzi comuni a tutte le pagine stanno in un file di frammenti:

\`\`\`html
<!-- demo/ordini-ui/src/main/resources/templates/fragments/layout.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:fragment="head(titolo)">
    <meta charset="UTF-8">
    <title th:text="\${titolo}">Titolo</title>
    <link rel="stylesheet" th:href="@{/css/app.css}">
</head>
<body>
    <nav th:fragment="menu">
        <a th:href="@{/ordini}">Ordini</a> |
        <a th:href="@{/ordini/nuovo}">Nuovo ordine</a>
    </nav>

    <!-- Il messaggio flash: c'è solo subito dopo un redirect. -->
    <p th:fragment="flash" th:if="\${messaggio}" class="flash" th:text="\${messaggio}">Salvato</p>
</body>
</html>
\`\`\`

L'elenco, con ricerca, tabella, formati e cancellazione:

\`\`\`html
<!-- demo/ordini-ui/src/main/resources/templates/ordini/elenco.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:replace="~{fragments/layout :: head(titolo='Ordini')}"></head>
<body>
    <nav th:replace="~{fragments/layout :: menu}"></nav>
    <p th:replace="~{fragments/layout :: flash}"></p>

    <h1 th:text="#{ordini.titolo}">Ordini</h1>

    <!-- GET: i campi finiscono nella query, ?q=... -->
    <form th:action="@{/ordini}" method="get">
        <input type="text" name="q" th:value="\${q}" placeholder="Cliente">
        <button type="submit">Cerca</button>
    </form>

    <p th:if="\${#lists.isEmpty(ordini)}">Nessun ordine.</p>

    <table th:unless="\${#lists.isEmpty(ordini)}">
        <tr>
            <th>#</th><th>Cliente</th><th>Pezzi</th><th>Stato</th><th>Consegna</th><th>Prezzo</th><th></th>
        </tr>
        <tr th:each="o, st : \${ordini}" th:classappend="\${o.urgente} ? 'urgente'">
            <td th:text="\${st.count}">1</td>
            <td><a th:href="@{/ordini/{id}(id=\${o.id})}" th:text="\${o.cliente}">Rossi</a></td>
            <td th:text="\${o.quantita}">3</td>
            <td th:switch="\${o.stato.name()}">
                <span th:case="'NUOVO'">da spedire</span>
                <span th:case="'SPEDITO'">in viaggio</span>
                <span th:case="*" th:text="\${o.stato}">altro</span>
            </td>
            <td th:text="\${o.consegna != null} ? \${#temporals.format(o.consegna, 'dd/MM/yyyy')} : '-'">20/09/2026</td>
            <td th:text="\${#numbers.formatDecimal(o.prezzo, 1, 'POINT', 2, 'COMMA')} + ' €'">12,50 €</td>
            <td>
                <form th:action="@{/ordini/{id}/elimina(id=\${o.id})}" method="post"
                      onsubmit="return confirm('Eliminare l\\'ordine?')">
                    <button type="submit">Elimina</button>
                </form>
            </td>
        </tr>
        <tr th:remove="all"><td>2</td><td>Riga finta, solo per l'anteprima</td></tr>
    </table>

    <p th:unless="\${#lists.isEmpty(ordini)}"
       th:text="|Ordini: \${#lists.size(ordini)}, pezzi in tutto: \${#aggregates.sum(ordini.![quantita])}|">Totale</p>
</body>
</html>
\`\`\`

Il dettaglio, con \`th:object\` e le espressioni \`*{...}\`:

\`\`\`html
<!-- demo/ordini-ui/src/main/resources/templates/ordini/dettaglio.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:replace="~{fragments/layout :: head(titolo='Dettaglio ordine')}"></head>
<body>
    <nav th:replace="~{fragments/layout :: menu}"></nav>

    <div th:object="\${ordine}">
        <h1 th:text="|Ordine n. *{id}|">Ordine n. 1</h1>
        <p>Cliente: <strong th:text="*{cliente}">Rossi</strong></p>
        <p th:with="totale=*{quantita * prezzo}">
            Totale: <span th:text="\${#numbers.formatDecimal(totale, 1, 2)}">37,50</span>
        </p>
        <p th:if="*{urgente}" class="urgente">Urgente!</p>
        <p>Note: <span th:text="*{note} ?: 'nessuna'">nessuna</span></p>
        <button type="button" th:data-id="*{id}"
                th:disabled="*{stato.name() == 'CONSEGNATO'}">Spedisci</button>
    </div>
</body>
</html>
\`\`\`

Il form, che serve sia la prima volta sia quando torna con gli errori:

\`\`\`html
<!-- demo/ordini-ui/src/main/resources/templates/ordini/form.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:replace="~{fragments/layout :: head(titolo='Nuovo ordine')}"></head>
<body>
    <nav th:replace="~{fragments/layout :: menu}"></nav>

    <form th:action="@{/ordini}" th:object="\${ordine}" method="post">
        <p th:if="\${#fields.hasAnyErrors()}" class="errore">Correggi i campi segnati.</p>

        <label>Cliente
            <input type="text" th:field="*{cliente}" th:errorclass="campo-errato">
        </label>
        <span class="errore" th:if="\${#fields.hasErrors('cliente')}" th:errors="*{cliente}">obbligatorio</span>

        <label>Pezzi <input type="number" th:field="*{quantita}"></label>
        <span class="errore" th:errors="*{quantita}"></span>

        <label>Stato
            <select th:field="*{stato}">
                <option th:each="s : \${stati}" th:value="\${s}" th:text="\${s}">NUOVO</option>
            </select>
        </label>

        <label><input type="checkbox" th:field="*{urgente}"> Urgente</label>

        <label>Consegna <input type="date" th:field="*{consegna}"></label>

        <button type="submit">Salva</button>
    </form>
</body>
</html>
\`\`\`

\`\`\`properties
# demo/ordini-ui/src/main/resources/messages.properties
ordini.titolo=Ordini in corso
ordini.saluto=Ciao {0}, hai {1} ordini
\`\`\`

Cosa esce, per capire cosa fa ogni pezzo:

- \`th:field="*{cliente}"\` diventa \`<input type="text" id="cliente" name="cliente" value="">\`;
  dopo una POST con errori, \`value\` è quello scritto dall'utente e la classe
  \`campo-errato\` è aggiunta.
- La \`<select>\` marca da sola come \`selected\` l'opzione uguale a \`stato\`.
- La checkbox diventa \`<input type="checkbox" id="urgente1" name="urgente" value="true">\`
  più un \`<input type="hidden" name="_urgente">\`: è quello che fa arrivare
  \`false\` quando la casella è vuota. Nota l'\`id\` con l'\`1\`, se ci attacchi una
  \`<label for=...>\`.
- \`th:errors\` scrive il \`message\` del vincolo (\`Il cliente è obbligatorio\`);
  senza errori il tag sparisce.
- Il messaggio flash compare alla prima pagina dopo il redirect, e al refresh
  successivo non c'è più.

#### Gli errori che fanno perdere tempo

| Cosa vedi | Perché | Rimedio |
| :--- | :--- | :--- |
| \`Neither BindingResult nor plain target object for bean name 'ordine'\` | il metodo GET non ha messo l'oggetto del form nel \`Model\` | \`model.addAttribute("ordine", new OrdineForm());\` |
| La stessa eccezione (o un 404) solo al primo invio del form, con l'indirizzo che finisce in \`;jsessionid=...\` | il browser non ha ancora il cookie di sessione: Tomcat mette la sessione nell'URL del redirect, e Spring non lo riconosce più come \`/\` | nell'\`application.yml\` della UI: \`server.servlet.session.tracking-modes: cookie\` (\`task new-service UI=1\` lo mette già) |
| \`Error resolving template [/ordini/elenco]\` | barra all'inizio del nome (in IntelliJ va, nel jar e in Docker no), oppure file fuori da \`templates/\`, oppure nome scritto diverso | \`return "ordini/elenco";\` e controlla il percorso del file |
| Il browser mostra la scritta \`ordini/elenco\` | la classe è \`@RestController\` | \`@Controller\` |
| Gli errori di validazione non compaiono | manca \`@Valid\`, o \`BindingResult\` non è il parametro subito dopo, o dopo gli errori fai \`redirect:\` | vedi il metodo \`salva\` qui sopra |
| Il messaggio non arriva dopo il redirect | \`model.addAttribute\` invece di \`redirect.addFlashAttribute\` | \`RedirectAttributes\` |
| \`EL1007E: Property or field 'cliente' cannot be found on null\` | l'oggetto è \`null\` | \`\${ordine?.cliente}\`, oppure un \`th:if\` prima |
| \`EL1008E: Property or field 'nome' cannot be found on object of type ...\` | il campo si chiama diversamente (in un record: il nome del componente) | guarda la classe o il record |
| \`th:if="\${lista}"\` è vero anche senza elementi | una lista vuota conta come vera | \`th:if="\${#lists.isEmpty(lista)}"\` |
| \`pezzi in tutto: null\` | \`#aggregates.sum\` su una lista vuota | dentro un \`th:unless="\${#lists.isEmpty(...)}"\` |
| \`Only variable expressions returning numbers or booleans are allowed in this context\` | Thymeleaf 3.1 non accetta testo dei dati dentro \`th:onclick\` e gli altri \`th:on*\` (per sicurezza) | l'\`onclick\` scritto normale, e i dati in un \`th:data-*\` |
| La pagina modificata non cambia | Spring legge i template da \`target/classes\` | \`task compile\` |
| Nella pagina d'errore \`\${message}\` è vuoto | Spring Boot nasconde il messaggio delle eccezioni | \`server.error.include-message: always\` in \`application.yml\` |
| Il servizio risponde 404 e la UI mostra una pagina 500 | il Feign client trasforma il 404 in \`FeignException.NotFound\` | \`try { … } catch (FeignException.NotFound e) { … }\` e mostra un messaggio |

---

## 7. Risoluzione Guidata delle 3 Tracce d'Esame

### Traccia 1: WMS Magazzino ("Spostati S.r.l.")
- **Obiettivo**: Gestione magazzino diviso in armadi (griglia $R \\times C$) contenenti ubicazioni con ingombro massimo.
- **Microservizi**:
  1. \`EUREKA-SERVER\` (Porta 8761)
  2. \`PRODUCT-SERVICE\` (Porta 8081) - Anagrafica prodotti CRUD + OpenAPI.
  3. \`CRM-SERVICE\` (Porta 8082) - Mock anagrafica clienti registrato su Eureka.
  4. \`WMS-UI-SERVICE\` (Porta 8080) - Gestione giacenze e movimentazioni merci.
- **Algoritmo di Ricerca Ubicazione Ottimale Vicina**:
  - *Problema*: Data un'ubicazione sorgente $U_{start}$ (armadio a riga $r_1$, colonna $c_1$) e una quantità $Q$ di un prodotto $P$ per il cliente $C$, trovare l'ubicazione $U_{dest}$ più vicina che abbia capienza libera $S_{libero} \\ge Q \\times Ingombro(P)$ e contenga lo stesso prodotto/cliente o sia vuota.
  - *Calcolo Distanza*: Distanza di Manhattan tra le coordinate degli armadi:
    $$d(A_1, A_2) = |r_1 - r_2| + |c_1 - c_2|$$
  - *Complessità Temporale*: $O(N_{armadi} \\times M_{ubicazioni})$, poiché per ciascun armadio si controllano le ubicazioni disponibili. Se i dati sono mantenuti in strutture in memoria (es. \`Map<Coordinate, Armadio>\`), la ricerca richiede tempo lineare proporzionale al numero totale di ubicazioni $O(U_{totale})$.

---

### Traccia 2: Catasto Comunale & Incentivi Edilizi
- **Obiettivo**: Informatizzazione bonus ristrutturazioni edilizie con miglioramento classe energetica (A-G).
- **Microservizi**:
  1. \`ALIQUOTE-STATALI-SERVICE\` (Read-only, lista aliquote per categoria A1, A3, B1).
  2. \`CATASTO-NAZIONALE-SERVICE\` (Anagrafica particelle edili e proprietari con credito fiscale maturato).
  3. \`COMUNE-APP-SERVICE\` (UI Web per apertura pratica 6 mesi "IN CORSO" e chiusura pratica "TERMINATA" con aggiornamento classe energetica e accredito fiscale al proprietario).

---

### Traccia 3: Prenotazione Ospedaliera ("Sant'Isidoro")
- **Obiettivo**: Gestione appuntamenti medici e integrazione con il sistema regionale delle prescrizioni.
- **Microservizi**:
  1. \`MOCK-REGIONALE-SERVICE\` (Read-only prescrizioni mediche).
  2. \`AGENDA-OSPEDALE-SERVICE\` (Anagrafica medici, orari e disponibilità visite).
  3. \`PRENOTAZIONI-UI\` (Interfaccia web paziente per scelta data/medico e conferma prenotazione).

---

## 8. Template Standard per l'Allegato Tecnico (8 Punti)

Copia ed adatta questa struttura per il file \`ALLEGATO_TECNICO.docx\` / \`ALLEGATO_TECNICO.pdf\` da consegnare:

\`\`\`markdown
# ALLEGATO TECNICO DI PROGETTO
Candidato: [NOME COGNOME]
Data: [DATA ESAME]

## 1. Analisi del Problema e Contesto Applicativo
[Breve sintesi degli obiettivi di business e dell'architettura a microservizi scelta].

## 2. Schema Concettuale e Logico della Base Dati
- Tabella \`prodotti\` (id, nome, descrizione, prezzo, ingombro) -> Servizio Product
- Tabella \`ubicazioni\` (id, armadio_riga, armadio_colonna, ingombro_max, ingombro_occupato, prodotto_id, cliente_id, quantita) -> Servizio WMS

## 3. Descrizione dei Moduli Implementati
- \`eureka-server\`: Naming Server (Porta 8761)
- \`anagrafica-service\`: Microservizio REST con OpenAPI (Porta 8081)
- \`main-ui-app\`: Web Application Thymeleaf/Spring Boot (Porta 8080)

## 4. Descrizione dell'Algoritmo (se richiesto dalla traccia)
[Descrizione dell'algoritmo di ricerca/calcolo con formula matematica e complessità temporale Big-O].

## 5. Istruzioni per il Test della Soluzione
1. Eseguire \`task docker-up\`
2. Aprire \`http://localhost:8761\` per verificare la registrazione dei servizi su Eureka.
3. Aprire \`http://localhost:8081/swagger-ui.html\` per testare gli endpoint REST.
4. Aprire \`http://localhost:8080\` per utilizzare l'interfaccia utente.
\`\`\`

---

## 9. Svolgimento Completo delle Domande Teoriche (A e B)

### Domanda Teorica A: Containerizzazione Docker, Compose, Sicurezza e Federazione

#### Part A1: Docker vs Macchine Virtuali (VM) & Docker Compose
- **Architettura Docker vs VM**:
  - Le **Macchine Virtuali (VM)** utilizzano un **Hypervisor** (es. ESXi, VirtualBox) per emulare l'hardware sottostante e richiedono un **Guest OS completo** per ciascuna istanza. Questo comporta un elevato consumo di RAM/CPU, dimensioni delle immagini di diversi GB e tempi di avvio nell'ordine dei minuti.
  - I **Container Docker** condividono il **Kernel del Sistema Operativo Host** e isolano i processi nello spazio utente tramite le funzionalità del kernel Linux (\`namespaces\` per l'isolamento e \`cgroups\` per la limitazione delle risorse). Conseguentemente, sono estremamente leggeri (dimensione in MB), si avviano in pochissimi secondi e consumano solo le risorse necessarie ai processi applicativi.
- **Ruolo di Docker Compose**:
  - Docker Compose è uno strumento di orchestrazione multi-container che definisce l'intera infrastruttura in un file descrittore dichiarativo \`docker-compose.yml\`.
  - Consente di specificare: immagini da compilare/scaricare, variabili d'ambiente, mappatura delle porte, dipendenze di avvio (\`depends_on\` con \`healthcheck\`), volumi per la persistenza dei dati e reti virtuali isolate.

#### Part A2: Sicurezza e Federazione dei Servizi
- **Autenticazione e Autorizzazione Centralizzata**:
  - Per rendere sicura la soluzione si introduce un **Identity Provider (IdP)** basato sullo standard **OAuth2 / OpenID Connect (OIDC)** (es. **Keycloak** o **Spring Authorization Server**).
  - Gli utenti (es. personale del comune o operatori) effettuano il login su Keycloak e ricevono un token digitale firmato **JWT (JSON Web Token)** contenente i ruoli dell'utente (es. \`ROLE_OPERATORE\`, \`ROLE_ADMIN\`).
- **Federazione e API Gateway**:
  - Si inserisce un **Spring Cloud Gateway** come punto di accesso unico (Single Point of Entry) per tutte le richieste esterne.
  - L'API Gateway intercetta le richieste, valida la firma del token JWT con la chiave pubblica di Keycloak e inoltra le chiamate ai microservizi downstream tramite il registro Eureka.
  - Ciascun microservizio funge da **OAuth2 Resource Server** e verifica i permessi a livello di singolo endpoint utilizzando annotazioni come \`@PreAuthorize("hasRole('ROLE_ADMIN')")\`.

---

### Domanda Teorica B: DB Relazionali vs NoSQL & Stack JEE vs Spring Boot

#### Part B1: Database Relazionali vs NoSQL & Integrazione Soluzione
- **Differenze Fondamentali**:
  - **Relazionali (SQL)**: Basati sulle proprietà **ACID** (Atomicità, Consistenza, Isolamento, Durabilità). Utilizzano uno schema rigido prefissato e relazioni espresse tramite chiavi esterne. Scalano principalmente in modo **verticale** (hardware più potente).
  - **NoSQL (Document, Key-Value, Column, Graph)**: Basati solitamente sul principio **BASE** (Basically Available, Soft-state, Eventual consistency). Non hanno uno schema fisso (schemaless), gestiscono dati non strutturati o semi-strutturati e scalano in modo **orizzontale** aggiungendo nuovi nodi al cluster.
- **Proposta di Integrazione NoSQL**:
  - **MongoDB (Document Store)**: Utilizzabile nel sistema WMS per memorizzare lo **storico delle movimentazioni merci** o le tracciature degli audit log. La flessibilità del formato JSON/BSON consente di aggiungere campi analitici variabilmente nel tempo senza dover eseguire complesse migrazioni di schema SQL (\`ALTER TABLE\`).
  - **Redis (Key-Value In-Memory)**: Utilizzabile per la **gestione delle sessioni web** o come **cache ad alte prestazioni** delle interrogazioni più frequenti al catalogo prodotti, riducendo drasticamente il carico sul database relazionale sottostante.

#### Part B2: Confronto Stack JEE Tradizionale vs Spring Boot

| Componente Architetturale | Stack JEE Tradizionale | Stack Spring Boot / Spring Cloud | Ruolo nel Sistema |
| :--- | :--- | :--- | :--- |
| **View (Interfaccia Utente)** | JSP (JavaServer Pages) / JSF (JavaServer Faces) | Thymeleaf / HTML5 + JavaScript (Fetch API) | Rendering dinamico delle pagine web e gestione form utente. |
| **Controller (Logica)** | Servlets / JAX-RS (Jersey, RESTEasy) | \`@RestController\` / \`@Controller\` (Spring MVC) | Intercettazione richieste HTTP, validazione DTO e orchestrazione risposte. |
| **Data Layer (Persistenza)** | JPA / EJB (Enterprise JavaBeans) Entity | Spring Data JPA / Hibernate Repositories | Astrazione dell'accesso ai dati, mapping ORM ed esecuzione query. |
| **Runtime / Application Server** | Application Server esterno (JBoss/WildFly, GlassFish, WebSphere) | Embedded Container (Tomcat / Netty autonomo) | Esecuzione dell'applicazione packaged come jar autosufficiente. |
| **Dependency Injection** | CDI (Contexts and Dependency Injection) | Spring IoC Container (\`@Autowired\`, \`@Component\`) | Gestione del ciclo di vita dei bean e inversione del controllo. |
` },
    { file: 'guida_setup_e_cheatsheet.md', testo: `# Guida 1: Setup & Cheat Sheet Operativo per l'Esame

Guida rapida e prassi operative per eseguire, collaudare e gestire in emergenza l'ambiente **Spring Boot Dockerized** il giorno della prova finale.

---

## 1. Verifiche Preliminari Ambiente Host

Prima di iniziare l'esame, apri il terminale e verifica la presenza degli strumenti:

\`\`\`bash
git --version
docker --version
docker compose version
task --version
java --version
\`\`\`

- **Docker Desktop / Docker Engine**: Deve essere in esecuzione.
- **Java 17 o più recente** (il template nasce su Java 25): \`task set-java\` allinea pom, Dockerfile e VS Code al JDK installato (quello di \`JAVA_HOME\`, se no quello del \`PATH\`). Lo fa da solo anche \`task wizard\`, all'inizio.
- **Task (\`go-task\`)**: Strumento per l'automazione dei comandi d'esame.

---

## 2. Modalità d'Avvio Principali

### A. Avvio Stack Completo Containerizzato (CONSIGLIATO PER LA DEMO)

Esegue in container Docker isolati tutti i moduli del progetto — Eureka, i tuoi servizi — e il database PostgreSQL:

\`\`\`bash
# Entra nella cartella di progetto
cd spring-boot-dockerized

# Compila l'intero progetto e avvia i container
task docker-up
\`\`\`

Per monitorare i log in tempo reale:
\`\`\`bash
task docker-logs
\`\`\`

Per arrestare i container conservando i dati del database:
\`\`\`bash
task docker-down
\`\`\`

Per ripartire da un database vuoto (rimuove anche i volumi):
\`\`\`bash
task docker-reset
\`\`\`

> ℹ️ Locale e Docker usano le stesse porte, ma non devi ricordartene: \`task docker-up\` ferma da solo lo stack locale prima di partire, e \`task dev\` spegne da solo i container (con \`docker compose down\`, i dati del database restano).

---

### B. Sviluppo Locale con Hot Reload (CONSIGLIATO MENTRE SVILUPPI)

Un solo comando libera le porte (chiudendo chi le tiene occupate), compila tutto e lancia Eureka e i tuoi servizi, nell'ordine giusto (Eureka per primo, e ne aspetta la porta prima degli altri). Se un tuo servizio usa PostgreSQL, avvia anche quello: basta mettere \`$usesPostgres = $true\` in \`scripts/dev.ps1\` (\`USES_POSTGRES=1\` in \`dev.sh\`).

\`\`\`bash
task dev
\`\`\`

I servizi girano in background: niente finestre sparse, un terminale solo. Per vedere l'output di tutti insieme, ogni riga prefissata dal nome del servizio:

\`\`\`bash
task logs
\`\`\`

\`Ctrl+C\` chiude solo la vista, i servizi restano su. Per uno solo: \`task logs SERVICE=<nome>\`, col nome breve che vedi in \`task status\`. I log restano comunque su file in \`.dev-logs/\`.

Dopo una modifica al codice, ricompila e i servizi interessati si riavviano da soli grazie a \`spring-boot-devtools\`:

\`\`\`bash
task compile
\`\`\`

Per fermare lo stack locale e liberare le porte (ferma anche il PostgreSQL avviato da \`task dev\`, conservando i dati):

\`\`\`bash
task dev-down
\`\`\`

Quando qualcosa non risponde, il primo comando da lanciare è:

\`\`\`bash
task status
\`\`\`

Dice chi occupa ogni porta (un tuo servizio, i container, o un'applicazione estranea), quali container girano e cosa si è registrato su Eureka.

**Perché non usare \`task docker-up\` mentre sviluppi**: \`docker compose build\` ricostruisce un'immagine per servizio, e poiché il \`Dockerfile\` copia i sorgenti prima di compilare, ogni singola modifica invalida la cache e fa ricompilare tutto in ogni immagine. Un ciclo costa minuti contro i ~20 secondi del build locale.

---

### C. Avvio Manuale dei Singoli Moduli

Se ti serve isolare un servizio e vederne l'output nel terminale:

\`\`\`bash
task run SERVICE=<modulo>
\`\`\`

Due scorciatoie per quello che c'è sempre:

\`\`\`bash
task run-eureka
\`\`\`

\`\`\`bash
task run-db
\`\`\`

\`Ctrl+C\` ferma il modulo. Per lo stack intero, in background, resta \`task dev\`.

---

## 3. Mappa delle Porte ed Endpoint OpenAPI / Swagger UI

Questo branch è il **template vuoto**: le uniche porte fisse sono quelle
dell'infrastruttura. Le altre le assegna \`task new-service\` (la prima libera
dopo l'ultima usata) e te le stampa \`task dev\` alla fine dell'avvio.

| Servizio | Porta Host | Endpoint / Dashboard | Swagger UI |
| :--- | :---: | :--- | :--- |
| **Eureka Naming Server** | \`8761\` | \`http://localhost:8761\` | N/A (dashboard Eureka) |
| **PostgreSQL** | \`5432\` | \`jdbc:postgresql://localhost:5432/esame\` (utente e password \`exam\`) | N/A |
| **I tuoi servizi REST** | \`8081\`, \`8082\`, ... | \`http://localhost:<porta>/api/...\` | \`http://localhost:<porta>/swagger-ui.html\` |
| **La tua UI** | la prima libera | \`http://localhost:<porta>\` | idem |

Per sapere in ogni momento chi sta su quale porta, e chi è registrato su Eureka:

\`\`\`bash
task status
\`\`\`

Per spostare una porta ovunque sia scritta (\`application.yml\`, compose, liste
di avvio):

\`\`\`bash
task set-port SERVICE=<modulo> PORT=<porta>
\`\`\`

### Il database

Il \`docker-compose.yml\` contiene **un** container PostgreSQL (database \`esame\`,
utente e password \`exam\`), che di suo non è collegato a nessun servizio: i
moduli creati da \`task new-service\` usano H2 in memoria. Per collegarne uno:

\`\`\`bash
task use-postgres SERVICE=<modulo>
\`\`\`

Con \`DBNAME=<nome>\` quel modulo ottiene un database tutto suo, sempre dentro
lo stesso container. Vedi GIORNO-ESAME.md, "Collegare un servizio a PostgreSQL".

Le credenziali non sono scolpite nella pietra:

\`\`\`bash
task db-config
\`\`\`

Senza variabili stampa nome, utente, password, porta e moduli collegati. Con
\`DBNAME=\`, \`USER=\`, \`PASSWORD=\` o \`PORT=\` le cambia in tutti i punti in cui
sono scritte (container, healthcheck, variabili dei moduli, \`application.yml\`,
script di init). Dopo un cambio di nome, utente o password serve un
\`task docker-reset\`: PostgreSQL crea utente e database solo al primo avvio.

E per non presentare tabelle vuote:

\`\`\`bash
task seed-data
\`\`\`

Accende i dati di prova: a ogni avvio le tabelle vuote si riempiono da sole,
con righe salvate passando da Hibernate (id, relazioni, enum e vincoli
rispettati). Prima prova su un H2 usa-e-getta e ti dice com'è andata.

---

## 3.1 Cheat Sheet Scaffolding & Generazione Rapida

Per non perdere ore a scrivere codice boilerplate e classi ripetitive durante l'esame, hai a disposizione questi comandi:

> 💡 **Modalità Interattiva Senza Parametri per TUTTI i Comandi**:
> Non ricordi i parametri a memoria? Nessun problema: **puoi lanciare qualsiasi comando senza argomenti** (es. \`task new-service\`, \`task new-entity\`, \`task add-relation\`, \`task new-client\`, \`task new-dto\`, \`task new-view\`, \`task new-auth\`, \`task new-handler\`, \`task add-dep\`, \`task set-port\`, \`task remove-service\`, \`task use-postgres\`, \`task consegna\`).
> Ognuno di essi aprirà un **wizard interattivo da terminale** con domande passo-passo, elenchi numerati dei moduli/entità tra cui scegliere e default intelligenti!

| Task | Sintassi ed Esempio | Che cosa genera |
| :--- | :--- | :--- |
| **\`task wizard\`** | \`task wizard\` | Crea l'intera architettura a microservizi guidandoti passo passo. |
| **\`task new-service\`** | \`task new-service NAME=ordini-service [UI=1] [NODB=1]\` | Crea un nuovo microservizio e lo collega a pom, Dockerfile, compose, porte ed editor. |
| **\`task new-entity\`** | \`task new-entity SERVICE=ordini-service NAME=Ordine FIELDS=... [DTO=1]\` | Genera in blocco **Entity JPA**, **Repository**, **Service CRUD** e **Controller REST** (anche basati su DTO se \`DTO=1\`). |
| **\`task add-relation\`** | \`task add-relation SERVICE=ordini-service FROM=Ordine TO=Cliente TYPE=many-to-one\` | Configura una relazione JPA (\`@ManyToOne\`, \`@OneToMany\`, \`@OneToOne\`, \`@ManyToMany\`) con \`fetch = LAZY\`, \`@JoinColumn\` e campo inverso. Interattivo se lanciato senza argomenti (\`task add-relation\`). |
| **\`task new-client\`** | \`task new-client FROM=ordini-ui TO=ordini-service DTO=OrdineDto [FIELDS=...]\` | Genera interfaccia \`@FeignClient(name="ORDINI-SERVICE")\` e, con \`FIELDS=\`, anche il DTO in \`common-dto\`. |
| **\`task new-dto\`** | \`task new-dto NAME=OrdineDto FIELDS=id:long,cliente:string:required [CLASS=1]\` | Genera un Java record DTO immutabile con validazioni in \`common-dto\`. |
| **\`task new-view\`** | \`task new-view SERVICE=ordini-ui NAME=Ordini FIELDS=cliente:string:required,quantita:int\` | Genera controller Spring MVC (\`OrdiniUiController\`) e template Thymeleaf (\`ordini.html\`) con form e tabella. |
| **\`task new-auth\`** | \`task new-auth SERVICE=ordini-service TYPE=inmemory\`<br>\`task new-auth SERVICE=ordini-service TYPE=db\`<br>\`task new-auth SERVICE=ordini-ui TYPE=form\` | Configura Spring Security: Basic Auth in memoria, con tabella utenti/ruoli su database, o Form Login con pagina web. |
| **\`task new-handler\`**| \`task new-handler SERVICE=ordini-service\` | Genera \`@RestControllerAdvice\` per gestire errori di validazione (400), non trovato (404) e 500 in formato JSON pulito. |
| **\`task seed-data\`** | \`task seed-data\` | Popola automaticamente con dati credibili le tabelle vuote al bootstrap. |
| **\`task db-schema\`** | \`task db-schema\` | Genera la tabella Markdown dello schema DB per l'allegato tecnico dell'esame. |
| **\`task add-dep\`** | \`task add-dep SERVICE=ordini-service DEPS=security,mail\` | Aggiunge starter Maven senza dover cercare versioni o groupId. |
| **\`task set-port\`** | \`task set-port SERVICE=ordini-service PORT=9080\` | Cambia la porta di un servizio ovunque sia scritta nel progetto. |
| **\`task remove-service\`** | \`task remove-service SERVICE=vecchio-service\` | Rimuove un modulo e lo scollega da pom, Dockerfile, compose e liste di avvio. |

### Tabella dei Tipi e Modificatori per \`FIELDS=\`

| Tipo nel comando | Tipo Java | Dettaglio DB / Validazione |
| :--- | :--- | :--- |
| \`string\` / \`string(N)\` | \`String\` | \`VARCHAR(255)\` o \`VARCHAR(N)\` + \`@Size(max=N)\` |
| \`int\` / \`integer\` | \`Integer\` | \`INTEGER\` |
| \`long\` | \`Long\` | \`BIGINT\` |
| \`decimal\` / \`double\` | \`BigDecimal\` | \`NUMERIC(12,2)\` |
| \`bool\` / \`boolean\` | \`Boolean\` | \`BOOLEAN\` |
| \`date\` | \`LocalDate\` | \`DATE\` |
| \`datetime\` | \`LocalDateTime\` | \`TIMESTAMP\` |
| \`email\` | \`String\` | \`@Email\` + \`VARCHAR(255)\` |
| \`text\` | \`String\` | \`@Lob\` (\`TEXT\`) |
| \`:required\` | vincolo | \`@NotNull\` / \`@NotBlank\` + \`nullable = false\` |
| \`:unique\` | vincolo | vincolo di unicità \`unique = true\` |

---

## 4. Collaudo Rapido

### Prima: il progetto è coerente?

\`\`\`bash
task check
\`\`\`

Non avvia niente: verifica che moduli, porte, \`Dockerfile\`, \`docker-compose.yml\`
e liste di avvio dicano la stessa cosa, e che le porte siano davvero usabili su
questa macchina. Se qualcosa non torna te lo dice qui, non a demo iniziata.

### Poi: i servizi si vedono fra loro?

\`\`\`bash
task status
\`\`\`

Nella sezione **REGISTRO EUREKA** devono comparire tutti i tuoi servizi. Se uno
manca, o è partito da pochi secondi, o non parte affatto: \`task logs
SERVICE=<nome>\`.

### Infine: gli endpoint rispondono?

Ogni servizio creato con \`task new-service\` nasce con un endpoint di prova e
con Swagger già collegato:

\`\`\`bash
curl http://localhost:<porta>/api/ping
\`\`\`

Swagger UI (\`http://localhost:<porta>/swagger-ui.html\`) è il modo più comodo
per provare gli endpoint veri: mostra lo schema esatto delle richieste e le
esegue dal browser, senza scrivere \`curl\` a mano.

L'ultimo collaudo, quello che conta, è percorrere il flusso completo dalla UI
come lo mostrerai alla commissione.

---

## 5. Cheat Sheet Risoluzione Emergenze Esame

### 🚨 Emergenza 1: "Porta 8080 / 8761 / 5432 già in uso"
Prima di tutto, guarda chi la occupa:
\`\`\`bash
task status
\`\`\`

Nella maggior parte dei casi non devi fare niente: **\`task dev\` libera lui le porte all'avvio**, chiudendo i suoi servizi rimasti appesi, i container dell'esame e le applicazioni estranee in ascolto. Restano intoccati solo i processi di sistema e l'infrastruttura di Docker, che ti vengono segnalati.

Per liberarle senza avviare nulla:
\`\`\`bash
task dev-down
\`\`\`
Come ultima risorsa, termina tutti i processi Java della macchina — **anche quelli estranei al progetto, IDE compreso**:
\`\`\`bash
task kill-java
\`\`\`

Perché conta: Tomcat non riesce a fare il bind nemmeno quando l'altro processo ascolta solo su \`127.0.0.1\`, e il servizio muore con \`Web server failed to start. Port N was already in use\`. E se lo stack è nei container, la porta è pubblicata ma \`http://localhost:8080\` continua a rispondere dall'altra applicazione, perché su Windows il bind più specifico vince.

Se su una di quelle porte gira qualcosa che ti serve viva, dillo e sposta la UI:
\`\`\`bash
task dev KEEPFOREIGN=1 UI_PORT=9080
\`\`\`

### 🚨 Emergenza 1-ter: "porta occupata da processo sconosciuto"

\`task dev\` dice che una porta è occupata, \`task status\` la segna **RISERVATA** e
nessun processo risulta in ascolto. Non c'è niente da chiudere: Windows si
riserva interi intervalli di porte (Hyper-V, WSL, **l'avvio di Docker
Desktop**), e dentro quegli intervalli non fa il bind nessuno — né un servizio
locale né un container, per cui anche \`task docker-up\` fallirebbe con
\`bind: An attempt was made to access a socket in a way forbidden by its access permissions\`.

Per vedere gli intervalli:
\`\`\`bash
netsh interface ipv4 show excludedportrange protocol=tcp
\`\`\`

Due strade: spostare il servizio fuori dagli intervalli,
\`\`\`bash
task set-port SERVICE=<modulo> PORT=<porta libera>
\`\`\`
oppure liberare le riserve, da terminale **amministratore** (chiude Docker):
\`\`\`bash
net stop winnat
\`\`\`
\`\`\`bash
net start winnat
\`\`\`

### 🚨 Emergenza 1-bis: "container ...-eureka-server-1 is unhealthy"
\`task docker-up\` si interrompe con \`dependency failed to start: container <cartella>-eureka-server-1 is unhealthy\`, ma nei log Eureka scrive \`Started Eureka Server\`. L'healthcheck usa \`curl\`, che l'immagine \`eclipse-temurin:25-jre\` non contiene. Il \`demo/Dockerfile\` di questo repo lo installa già; se aggiungi un healthcheck HTTP a un altro servizio vale la stessa regola. Per leggere l'esito delle probe, dalla cartella dei moduli:
\`\`\`bash
docker inspect $(docker compose ps -q eureka-server) --format "{{json .State.Health}}"
\`\`\`

### 🚨 Emergenza 2: "Docker Compose non aggiorna il codice modificato"
Se hai modificato il codice Java ma \`task docker-up\` usa la vecchia immagine cached:
\`\`\`bash
cd demo
docker compose build --no-cache
docker compose up -d
\`\`\`

### 🚨 Emergenza 3: "PostgreSQL non si connette o DDL-Auto fallisce"
Reset completo del volume del database:
\`\`\`bash
task docker-reset
\`\`\`
\`\`\`bash
task docker-up
\`\`\`

> ⚠️ \`task docker-reset\` **cancella i dati**. Per il semplice arresto usa \`task docker-down\`, che conserva il volume.

> ℹ️ Il volume è montato su \`/var/lib/postgresql\`, non sul percorso legacy \`/var/lib/postgresql/data\`: dalla versione 18 l'immagine tiene i dati in \`/var/lib/postgresql/<versione>/docker\`, e col mount vecchio il volume restava vuoto e il container non partiva.

### 🚨 Emergenza 4: "Eureka registra i servizi ma i Feign Client danno 500"
Ogni servizio tiene una copia locale del registro di Eureka, e il load balancer di Feign una copia di quella. Con i valori di Spring le due cache insieme fanno anche 30-60 secondi di "Load balancer does not contain an instance for the service ...". I moduli creati da \`task new-service\` le accorciano a 5 secondi (\`registry-fetch-interval-seconds\` e \`spring.cloud.loadbalancer.cache.ttl\` nell'\`application.yml\`), e Eureka rinfresca le sue risposte ogni 5: dopo l'avvio bastano pochi secondi. Se un modulo scritto a mano ha ancora il problema, copia quelle righe da un modulo generato.

### 🚨 Emergenza 5: "Errori 500 generici o validazioni @Valid non formattate nelle API REST"
Se inviando dati non validi le tue API REST rispondono con 500 o messaggi illeggibili invece di 400 Bad Request:
\`\`\`bash
task new-handler SERVICE=<modulo>
\`\`\`
Genera \`exception/GlobalExceptionHandler.java\` (\`@RestControllerAdvice\`) che intercetta \`MethodArgumentNotValidException\` (trasformandola in 400 con dettaglio campo per campo), \`ResponseStatusException\` (mantenendo lo status HTTP 404/409) ed eccezioni non gestite (formattate in un JSON standard).

---

## 6. L'editor

Apri **la cartella del repository**: e' un progetto Maven multi-modulo, e
l'editor deve vedere il pom aggregatore.

**VS Code** trova gia' nel repository \`.vscode/launch.json\` (un profilo di
debug per servizio, piu' il compound *Stack completo* che li avvia tutti in
ordine), \`.vscode/tasks.json\` (i comandi \`task\` dalla palette),
\`settings.json\` ed \`extensions.json\`. L'unica estensione indispensabile e'
**Extension Pack for Java**: senza, il tasto Debug non esiste. \`F5\` ->
*Stack completo* e hai tutti i servizi con i breakpoint attivi.

**Zed** ha \`.zed/debug.json\` (\`F4\` -> un servizio in debug, con i breakpoint),
\`.zed/tasks.json\` (palette -> *task: Spawn*) e \`.zed/settings.json\`. Serve
l'estensione *Java*: al primo file \`.java\` scarica jdtls, Lombok e il debugger,
quindi aprilo una volta con la rete (\`task offline\` controlla che ci siano).

**IntelliJ IDEA** non ha bisogno di niente: *File -> Open* sulla cartella del
repository.

\`launch.json\`, \`debug.json\` e i due \`tasks.json\` sono **generati**: li riscrivono
\`new-service\`, \`remove-service\` e \`set-port\`. Se li hai scavalcati modificando
i moduli a mano:

\`\`\`bash
task ide-sync
\`\`\`

Se restano indietro lo segnala \`task check\`, alla voce *editor (launch.json)*.

---

## 7. Prima e dopo: la rete dell'esame e la consegna

All'esame la rete passa da una whitelist di domini: Maven Central sì, il resto
non si sa. \`task rete\` dice, dominio per dominio, che cosa passa e che cosa
fare se no. La sera prima, con la connessione di casa:

\`\`\`bash
task offline-prep
\`\`\`

Scarica le dipendenze Maven in \`~/.m2\`, anche quelle dei moduli che creerai,
le immagini Docker di base e fa una prima build dei container. \`task offline\`
verifica lo stato e prova davvero una compilazione offline (\`mvnw -o\`).
Portati la cartella del progetto **e** la cartella \`~/.m2\` su una chiavetta: il
template è la cartella, non serve altro.

Se Docker Hub non passa, presenta con \`task dev\` più \`task run-db\` (il solo
PostgreSQL in container): non ricompila niente dentro Docker, quindi è il modo
che regge meglio.

A fine giornata:

\`\`\`bash
task consegna NOME=COGNOME_NOME
\`\`\`

Prepara \`consegna/\` con il progetto pronto da eseguire (i moduli senza
\`target/\`, accanto a pom e compose), l'allegato tecnico già compilato (moduli,
porte, endpoint, schema del database), le istruzioni di esecuzione, e un
archivio unico da consegnare: scompattato, parte con \`docker compose up --build\`.
Le parti dell'allegato da scrivere a mano (analisi, algoritmo, che cosa fa ogni
modulo) stanno in \`allegato.md\`: la consegna le mette al loro posto prima di
fare l'archivio, quindi si può rilanciare quante volte si vuole.
` },
    { file: 'README-ESAME-TTFCLOUD.md', testo: `# Documentazione Esame Spring Cloud — Biblioteca di quartiere

## Obiettivo

Questa soluzione informatizza catalogo e prestiti di una biblioteca di
quartiere: tre microservizi registrati su Eureka, due database PostgreSQL, una
penale per chi restituisce in ritardo e un'interfaccia web per il
bibliotecario. È la traccia che il corso del template (\`task learn\`) segue
lezione per lezione: ogni pezzo di codice mostrato nel corso sta qui.

## La traccia

> 1. Il **catalogo** contiene i libri: titolo, codice ISBN di 13 cifre, anno
>    di pubblicazione, genere (romanzo, saggio, giallo, fantasy, storico),
>    autore (nome, cognome, nazionalità) e se il libro è disponibile.
> 2. Il servizio dei **prestiti** registra chi prende un libro (la sua email),
>    il giorno del prestito e la scadenza: di norma 30 giorni, al massimo 60.
>    Un libro già in prestito non si può prestare di nuovo.
> 3. Alla restituzione il libro torna disponibile. Per ogni giorno di ritardo
>    si paga una **penale** di 0,50 euro, fino a un massimo di 20 euro.
> 4. Un'**interfaccia web** mostra il catalogo e i prestiti, con il ritardo e
>    la penale, e permette di registrare un prestito e una restituzione.
> 5. I servizi si registrano su un **naming server Eureka** e si chiamano per
>    nome. Catalogo e prestiti hanno ognuno il proprio database PostgreSQL.
> 6. L'intero sistema parte con **Docker Compose**.

## Architettura

| Modulo | Porta | Nome su Eureka | Database | Chiama |
| :--- | ---: | :--- | :--- | :--- |
| \`naming-server\` | 8761 | \`eureka-server\` | — | — |
| \`catalogo-service\` | 8081 | \`CATALOGO-SERVICE\` | PostgreSQL \`biblioteca\` | — |
| \`prestiti-service\` | 8082 | \`PRESTITI-SERVICE\` | PostgreSQL \`prestiti\` | \`CATALOGO-SERVICE\` |
| \`biblioteca-ui\` | 8090 | \`BIBLIOTECA-UI\` | — | \`CATALOGO-SERVICE\`, \`PRESTITI-SERVICE\` |

\`\`\`
biblioteca-ui  --Feign-->  CATALOGO-SERVICE  -->  PostgreSQL "biblioteca"
      |
      +-------Feign-->  PRESTITI-SERVICE  -->  PostgreSQL "prestiti"
                              |
                              +--Feign-->  CATALOGO-SERVICE
\`\`\`

In \`common-dto\` stanno i record che attraversano la rete: \`LibroDto\`,
\`PrestitoDto\` e \`NuovoPrestitoRequest\` (il corpo della POST, che la UI manda e
i prestiti ricevono). \`PrestitoEntity\` tiene solo \`libroId\`: la tabella dei
libri sta in un altro database, e una chiave esterna fra database non esiste.

Il progetto è stato montato con i comandi del template:

\`\`\`bash
task db-config DBNAME=biblioteca USER=bib PASSWORD=bib2026
task new-service NAME=catalogo-service
task use-postgres SERVICE=catalogo-service
task new-service NAME=prestiti-service
task use-postgres SERVICE=prestiti-service DBNAME=prestiti
task new-service NAME=biblioteca-ui UI=1 PORT=8090
task add-dep SERVICE=prestiti-service DEPS=test
task seed-data
\`\`\`

## Endpoint

| Metodo | Percorso | Servizio | Risponde |
| :--- | :--- | :--- | :--- |
| GET | \`/api/libri\` | catalogo | 200 |
| GET | \`/api/libri/disponibili\` | catalogo | 200 |
| GET | \`/api/libri/{id}\` | catalogo | 200, 404 |
| PUT | \`/api/libri/{id}/disponibilita?disponibile=\` | catalogo | 200, 404 |
| GET | \`/api/prestiti\` | prestiti | 200, con ritardo e penale a oggi |
| POST | \`/api/prestiti\` | prestiti | 201; 400; 404 libro inesistente; 409 già in prestito |
| PUT | \`/api/prestiti/{id}/restituzione\` | prestiti | 200; 404; 409 già chiuso |
| GET | \`/\` | biblioteca-ui | la pagina |
| POST | \`/prestiti\` | biblioteca-ui | il form del prestito, poi redirect |
| POST | \`/prestiti/{id}/restituzione\` | biblioteca-ui | il bottone della restituzione, poi redirect |

## L'algoritmo della penale

ritardo = max(0, giorni fra scadenza e riferimento), dove il riferimento è la
data di restituzione per un prestito chiuso e oggi per uno aperto;
penale = min(0,50 × ritardo; 20,00). Due funzioni pure in \`PrestitoService\`,
provate da \`PenaleTest\`:

\`\`\`bash
cd demo && ./mvnw -pl prestiti-service -am test
\`\`\`

## Avvio e collaudo

\`\`\`bash
task dev
\`\`\`

oppure, tutto in container, \`task docker-up\`. Poi:

\`\`\`bash
powershell -ExecutionPolicy Bypass -File test_e2e_biblioteca.ps1
\`\`\`

prova ogni flusso: Eureka e le health, il catalogo, un prestito (201), lo
stesso libro due volte (409), un libro inesistente (404), un'email sbagliata e
troppi giorni (400), la restituzione e la seconda restituzione (409), la penale
di ogni prestito con la formula della traccia, Swagger, e dalla pagina un form
sbagliato, un prestito e una restituzione.

| Indirizzo | Cosa |
| :--- | :--- |
| \`http://localhost:8090\` | l'interfaccia |
| \`http://localhost:8761\` | la dashboard Eureka |
| \`http://localhost:8081/swagger-ui.html\` | Swagger del catalogo |
| \`http://localhost:8082/swagger-ui.html\` | Swagger dei prestiti |

## Consegna

Le parti dell'allegato scritte a mano sono in \`allegato.md\`;
\`task consegna NOME=COGNOME_NOME\` le unisce a moduli, endpoint e schema del
database e prepara l'archivio.
` }
  ],
};

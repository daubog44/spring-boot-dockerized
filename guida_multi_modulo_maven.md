# Guida 3: Multi-Modulo Maven & Funzionamento Progetto

Guida teorica e pratica per comprendere la struttura **Multi-Module Maven**, il funzionamento del **Maven Reactor**, la gestione delle dipendenze e l'integrazione con **Docker**.

---

## 1. Cos'è un Progetto Multi-Modulo Maven e Perché si Usa

Un progetto **Multi-Module Maven** è una struttura aggregata composta da un **Parent POM** centrale e da molteplici **Sub-Moduli Maven** correlati.

### 🌟 Vantaggi per un'Architettura a Microservizi:
1. **Isolamento delle Dipendenze**: Ogni microservizio dichiara nel proprio `pom.xml` solo gli starter di cui ha realmente bisogno (un servizio con persistenza include Spring Data JPA e il driver del database; `naming-server` include solo Eureka Server).
2. **Centralizzazione delle Versioni (`dependencyManagement`)**: Le versioni di librerie, framework (Spring Boot, Spring Cloud, Lombok, Springdoc) e plugin sono definite un'unica volta nel Parent POM principale.
3. **Condivisione Pulita del Codice (`common-dto`)**: I DTO (Data Transfer Objects) comuni vengono inseriti in un modulo dedicato (`common-dto`) ed importati dagli altri servizi come dipendenza JAR interna, evitando la duplicazione del codice.
4. **Build Unificata o Singola**: È possibile compilare l'intero sistema con un unico comando (`./mvnw clean package`) oppure compilare ed avviare un singolo microservizio isolato.

---

## 2. Struttura del Parent POM e dei Sub-Moduli

In questo branch — il template vuoto — l'aggregatore contiene solo
l'infrastruttura; i moduli della traccia li aggiungi tu, e `task new-service`
li mette al posto giusto:

```
demo/ (Directory Root Parent)
├── pom.xml                   <-- Parent POM (packaging: pom)
├── common-dto/
│   └── pom.xml               <-- Sub-modulo DTO condivisi
├── naming-server/
│   └── pom.xml               <-- Sub-modulo Eureka Server
│
│   ... e, dopo `task new-service NAME=ordini-service`:
│
├── ordini-service/
│   └── pom.xml               <-- Sub-modulo Microservizio REST
└── ordini-ui/
    └── pom.xml               <-- Sub-modulo Frontend Thymeleaf
```

### 2.1 Il Parent POM (`demo/pom.xml`)

Il file Parent definisce il packaging `pom` e la lista dei moduli compresi nell'aggregatore:

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0" ...>
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>ttfcloud-esame-parent</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <packaging>pom</packaging> <!-- INDISPENSABILE: indica che è un parent aggregatore -->

    <!-- Elenco dei moduli da compilare: `task new-service` aggiunge qui la
         riga del modulo nuovo, `task remove-service` la toglie -->
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
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>org.springdoc</groupId>
                <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
                <version>${springdoc.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>
</project>
```

---

### 2.2 Un Sub-Modulo Figlio (es. `ordini-service/pom.xml`)

Ogni sub-modulo fa riferimento al Parent tramite il blocco `<parent>` ed eredita versioni e proprietà:

```xml
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
            <version>${project.version}</version>
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
```

---

## 3. Il Meccanismo del Maven Reactor

Quando si lancia un comando Maven dalla root del Parent (es. `./mvnw clean package`), Maven attiva il **Maven Reactor**.

### Come funziona il Reactor:
1. Legge il `pom.xml` Parent e scansiona tutti i sub-moduli elencati in `<modules>`.
2. Costruisce un **Grafo Orientato Acliclico (DAG)** delle dipendenze tra i moduli.
3. Determina l'ordine esatto di compilazione (**Reactor Build Order**).

Esempio di output del Reactor in console:
```text
[INFO] Reactor Build Order:
[INFO] 
[INFO] ttfcloud-esame-parent                                              [pom]
[INFO] common-dto                                                         [jar]
[INFO] naming-server                                                      [jar]
[INFO] ordini-service                                                     [jar]
[INFO] ordini-ui                                                          [jar]
```
> 📌 *Nota*: `common-dto` viene sempre compilato per primo perché tutti gli altri microservizi dipendono dai suoi DTO!

---

## 4. Comandi Utili Maven per Progetti Multi-Modulo

### 1. Build Completa di Tutti i Moduli
```bash
./mvnw clean package -Dmaven.test.skip=true
```

### 2. Avviare un Singolo Modulo con le sue Dipendenze (`-pl` e `-am`)
- `-pl` / `--projects`: Specifica il modulo target (es. `ordini-service`).
- `-am` / `--also-make`: Ordina a Maven di compilare prima tutti i moduli da cui il target dipende (es. `common-dto`).

```bash
# Esegue ordini-service ricompilando prima common-dto se necessario
./mvnw -pl ordini-service -am spring-boot:run
```

### 3. Compilare Solo un Singolo Modulo
```bash
./mvnw -pl ordini-service clean package -Dmaven.test.skip=true
```

> Nel lavoro di tutti i giorni questi comandi non li scrivi: `task compile`
> ricompila tutto (il Reactor salta quello che non è cambiato) e
> `task run SERVICE=<modulo>` fa esattamente il `-pl <modulo> -am
> spring-boot:run` qui sopra.

---

## 5. Integrazione con Docker Multi-Stage Build

Per evitare di avere un `Dockerfile` diverso per ciascun microservizio, il progetto usa un **Dockerfile Parameterizzato** situato nella cartella `demo`:

```dockerfile
# STAGE 1: Compilation Phase
FROM eclipse-temurin:25-jdk AS builder
WORKDIR /workspace

# Copia i file POM per sfruttare il caching delle dipendenze Docker
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY common-dto/pom.xml common-dto/pom.xml
COPY naming-server/pom.xml naming-server/pom.xml
# ... una riga per modulo: la aggiunge `task new-service`

# Argomento che definisce quale modulo compilare per l'immagine specifica
ARG MODULE="naming-server"

RUN chmod +x mvnw
RUN ./mvnw -B -pl ${MODULE} -am dependency:go-offline

# Copia i sorgenti Java ed esegue il packaging del solo modulo richiesto
COPY . .
RUN ./mvnw -B -pl ${MODULE} -am clean package -Dmaven.test.skip=true

# STAGE 2: Runtime Phase (Immagine finale ultra-leggera JRE)
FROM eclipse-temurin:25-jre
# curl serve all'healthcheck di Eureka in docker-compose.yml
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ARG MODULE="naming-server"
COPY --from=builder /workspace/${MODULE}/target/${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

In `docker-compose.yml`, ogni servizio passa il nome del proprio modulo come argomento di build (`MODULE`):

```yaml
  ordini-service:
    build:
      context: .
      args:
        MODULE: ordini-service
```

> Le sole righe che cambiano da modulo a modulo sono quella `COPY` del pom e
> il blocco nel compose: sono due dei sei posti che `task new-service` tiene
> allineati, e che `task check` verifica.

---

## 6. Aggiungere, spostare o togliere un modulo

### 6.1 Con un comando

```bash
task new-service NAME=ordini-service
```

È il modo giusto il giorno dell'esame: un modulo nuovo tocca **sei** posti che
devono restare d'accordo, e questo comando li fa tutti e sei.

| # | Posto | Cosa ci finisce |
| :---: | :--- | :--- |
| 1 | `demo/<nome>/` | `pom.xml`, `Main.java`, `application.yml`, un endpoint di prova |
| 2 | `demo/pom.xml` | la riga `<module><nome></module>` |
| 3 | `demo/Dockerfile` | la `COPY <nome>/pom.xml <nome>/pom.xml` |
| 4 | `demo/docker-compose.yml` | il blocco del servizio, con porta ed Eureka |
| 5 | `scripts/dev.ps1` | la riga nella lista dei servizi di `task dev` |
| 6 | `scripts/dev.sh` | la stessa riga, per la versione POSIX |

Dimenticarne uno dà errori che sembrano scollegati dalla causa: il modulo non
compila (manca il 2), compila ma `task dev` non lo avvia (manca il 5), parte in
locale e non in Docker (manca il 3 o il 4).

Gli altri due comandi della stessa famiglia:

```bash
task set-port SERVICE=ordini-service PORT=8090
```

```bash
task remove-service SERVICE=ordini-service
```

E, quando vuoi essere sicuro che sia tutto a posto:

```bash
task check
```

### 6.2 A mano, se ti serve capire cosa succede

Il modulo di per sé sono tre file. Il `pom.xml` eredita dal parent, e per
questo non contiene **nessuna versione**:

```xml
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
            <version>${project.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>
</project>
```

La classe `Main`, che accende discovery e client Feign:

```java
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
```

E l'`application.yml`, dove la porta si legge dall'ambiente (in Docker la passa
`docker-compose.yml`) e ricade sul valore locale:

```yaml
server:
  port: ${SERVER_PORT:8081}

spring:
  application:
    name: ORDINI-SERVICE

eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
  instance:
    prefer-ip-address: true
```

Poi restano i cinque collegamenti della tabella qui sopra: la riga nei
`<modules>`, la `COPY` nel `Dockerfile`, il blocco nel compose

```yaml
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
```

e le due righe nelle liste di avvio di `dev.ps1` e `dev.sh`.

> **Rinominare** un modulo non ha un comando suo: la strada più corta è
> `task remove-service SERVICE=<vecchio>` seguito da
> `task new-service NAME=<nuovo>`, e poi riportare il codice nella cartella
> nuova. Ricordati di cambiare anche il `package` delle classi e il
> `spring.application.name`, perché è quello il nome che gli altri moduli usano
> nei loro `@FeignClient`.

### 6.3 Dopo, in ogni caso: `task dev`

Un modulo nuovo non è in esecuzione, e il classpath dei servizi accesi è
fissato da quando sono partiti: `task compile` non basta, ci vuole un riavvio
vero.

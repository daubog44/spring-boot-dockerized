# Guida 3: Multi-Modulo Maven & Funzionamento Progetto

Guida teorica e pratica per comprendere la struttura **Multi-Module Maven**, il funzionamento del **Maven Reactor**, la gestione delle dipendenze e l'integrazione con **Docker**.

---

## 1. Cos'è un Progetto Multi-Modulo Maven e Perché si Usa

Un progetto **Multi-Module Maven** è una struttura aggregata composta da un **Parent POM** centrale e da molteplici **Sub-Moduli Maven** correlati.

### 🌟 Vantaggi per un'Architettura a Microservizi:
1. **Isolamento delle Dipendenze**: Ogni microservizio dichiara nel proprio `pom.xml` solo gli starter di cui ha realmente bisogno (es. solo `store-service` include Spring Data JPA e PostgreSQL; `naming-server` include solo Eureka Server).
2. **Centralizzazione delle Versioni (`dependencyManagement`)**: Le versioni di librerie, framework (Spring Boot, Spring Cloud, Lombok, Springdoc) e plugin sono definite un'unica volta nel Parent POM principale.
3. **Condivisione Pulita del Codice (`common-dto`)**: I DTO (Data Transfer Objects) comuni vengono inseriti in un modulo dedicato (`common-dto`) ed importati dagli altri servizi come dipendenza JAR interna, evitando la duplicazione del codice.
4. **Build Unificata o Singola**: È possibile compilare l'intero sistema con un unico comando (`./mvnw clean package`) oppure compilare ed avviare un singolo microservizio isolato.

---

## 2. Struttura del Parent POM e dei Sub-Moduli

```
demo/ (Directory Root Parent)
├── pom.xml                   <-- Parent POM (packaging: pom)
├── common-dto/
│   └── pom.xml               <-- Sub-modulo DTO Condivisi
├── naming-server/
│   └── pom.xml               <-- Sub-modulo Eureka Server
├── tourist-service/
│   └── pom.xml               <-- Sub-modulo Microservizio A
├── store-service/
│   └── pom.xml               <-- Sub-modulo Microservizio B
└── event-ui/
    └── pom.xml               <-- Sub-modulo Frontend UI
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

    <!-- Elenco dei moduli da compilare -->
    <modules>
        <module>common-dto</module>
        <module>naming-server</module>
        <module>tourist-service</module>
        <module>random-service</module>
        <module>store-service</module>
        <module>event-ui</module>
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

### 2.2 Un Sub-Modulo Figlio (es. `store-service/pom.xml`)

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

    <artifactId>store-service</artifactId>
    <name>store-service</name>

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
[INFO] tourist-service                                                    [jar]
[INFO] random-service                                                     [jar]
[INFO] store-service                                                      [jar]
[INFO] event-ui                                                           [jar]
```
> 📌 *Nota*: `common-dto` viene sempre compilato per primo perché tutti gli altri microservizi dipendono dai suoi DTO!

---

## 4. Comandi Utili Maven per Progetti Multi-Modulo

### 1. Build Completa di Tutti i Moduli
```bash
./mvnw clean package -Dmaven.test.skip=true
```

### 2. Avviare un Singolo Modulo con le sue Dipendenze (`-pl` e `-am`)
- `-pl` / `--projects`: Specifica il modulo target (es. `store-service`).
- `-am` / `--also-make`: Ordina a Maven di compilare prima tutti i moduli da cui il target dipende (es. `common-dto`).

```bash
# Esegue store-service ricompilando prima common-dto se necessario
./mvnw -pl store-service -am spring-boot:run
```

### 3. Compilare Solo un Singolo Modulo
```bash
./mvnw -pl tourist-service clean package -Dmaven.test.skip=true
```

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
COPY tourist-service/pom.xml tourist-service/pom.xml
COPY random-service/pom.xml random-service/pom.xml
COPY store-service/pom.xml store-service/pom.xml
COPY event-ui/pom.xml event-ui/pom.xml

# Argomento che definisce quale modulo compilare per l'immagine specifica
ARG MODULE="event-ui"

RUN chmod +x mvnw
RUN ./mvnw -B -pl ${MODULE} -am dependency:go-offline

# Copia i sorgenti Java ed esegue il packaging del solo modulo richiesto
COPY . .
RUN ./mvnw -B -pl ${MODULE} -am clean package -Dmaven.test.skip=true

# STAGE 2: Runtime Phase (Immagine finale ultra-leggera JRE)
FROM eclipse-temurin:25-jre
WORKDIR /app
ARG MODULE="event-ui"
COPY --from=builder /workspace/${MODULE}/target/${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

In `docker-compose.yml`, ogni servizio passa il nome del proprio modulo come argomento di build (`MODULE`):

```yaml
  store-service:
    build:
      context: .
      args:
        MODULE: store-service
```

---

## 6. Guida Passo-Passo per Aggiungere o Rinominate un Modulo all'Esame

Se il giorno dell'esame desideri aggiungere un nuovo microservizio (es. `wms-service`):

1. **Crea la cartella**: `demo/wms-service` e la struttura di package Java `src/main/java/com/example/...`.
2. **Crea il file `demo/wms-service/pom.xml`**:
   ```xml
   <project xmlns="http://maven.apache.org/POM/4.0.0" ...>
       <modelVersion>4.0.0</modelVersion>
       <parent>
           <groupId>com.example</groupId>
           <artifactId>ttfcloud-esame-parent</artifactId>
           <version>0.0.1-SNAPSHOT</version>
           <relativePath>../pom.xml</relativePath>
       </parent>
       <artifactId>wms-service</artifactId>
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
3. **Registra il modulo nel Parent POM (`demo/pom.xml`)**:
   ```xml
   <modules>
       ...
       <module>wms-service</module>
   </modules>
   ```
4. **Aggiungi il servizio in `docker-compose.yml`**:
   ```yaml
     wms-service:
       container_name: exam-wms-service
       build:
         context: .
         args:
           MODULE: wms-service
       environment:
         SERVER_PORT: 8084
         EUREKA_SERVER_URL: http://eureka-server:8761/eureka/
       ports:
         - "8084:8084"
       depends_on:
         eureka-server:
           condition: service_healthy
   ```

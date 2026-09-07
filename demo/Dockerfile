# Immagine di un modulo qualsiasi: quale, lo dice l'argomento MODULE, che
# docker-compose.yml passa per ogni servizio.
FROM eclipse-temurin:25-jdk AS builder
WORKDIR /workspace

# Prima i soli pom: cosi' il livello con le dipendenze scaricate resta in cache
# finche' non cambia un pom. Ogni modulo nuovo aggiunge qui la sua riga (lo fa
# da solo `task new-service`).
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY common-dto/pom.xml common-dto/pom.xml
COPY naming-server/pom.xml naming-server/pom.xml

ARG MODULE="naming-server"

RUN chmod +x mvnw
RUN ./mvnw -B -pl ${MODULE} -am dependency:go-offline

COPY . .

RUN ./mvnw -B -pl ${MODULE} -am clean package -Dmaven.test.skip=true

FROM eclipse-temurin:25-jre
# curl serve all'healthcheck di Eureka in docker-compose.yml.
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ARG MODULE="naming-server"
COPY --from=builder /workspace/${MODULE}/target/${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]

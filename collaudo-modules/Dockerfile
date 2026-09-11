FROM eclipse-temurin:25-jdk AS builder
WORKDIR /workspace

COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY common-dto/pom.xml common-dto/pom.xml
COPY naming-server/pom.xml naming-server/pom.xml
COPY product-service/pom.xml product-service/pom.xml
COPY crm-service/pom.xml crm-service/pom.xml
COPY wms-service/pom.xml wms-service/pom.xml
COPY wms-ui/pom.xml wms-ui/pom.xml

ARG MODULE="wms-ui"

RUN chmod +x mvnw
# La cache di Maven vive fuori dall'immagine e sopravvive alle build: cosi'
# una modifica ai pom non rimanda a scaricare tutto da capo, e il giorno
# dell'esame senza rete le dipendenze sono gia' qui (task offline-prep).
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -pl ${MODULE} -am dependency:go-offline

COPY . .

RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -pl ${MODULE} -am clean package -Dmaven.test.skip=true

FROM eclipse-temurin:25-jre
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ARG MODULE="wms-ui"
COPY --from=builder /workspace/${MODULE}/target/${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]

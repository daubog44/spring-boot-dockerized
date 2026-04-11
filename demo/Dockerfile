FROM eclipse-temurin:25-jdk AS builder
WORKDIR /workspace

COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY common-dto/pom.xml common-dto/pom.xml
COPY naming-server/pom.xml naming-server/pom.xml
COPY tourist-service/pom.xml tourist-service/pom.xml
COPY random-service/pom.xml random-service/pom.xml
COPY store-service/pom.xml store-service/pom.xml
COPY event-ui/pom.xml event-ui/pom.xml

ARG MODULE="event-ui"

RUN chmod +x mvnw
RUN ./mvnw -B -pl ${MODULE} -am dependency:go-offline

COPY common-dto common-dto
COPY naming-server naming-server
COPY tourist-service tourist-service
COPY random-service random-service
COPY store-service store-service
COPY event-ui event-ui
COPY tailwind.config.js tailwind.config.js

RUN ./mvnw -B -pl ${MODULE} -am clean package -Dmaven.test.skip=true

FROM eclipse-temurin:25-jre
WORKDIR /app
ARG MODULE="event-ui"
COPY --from=builder /workspace/${MODULE}/target/${MODULE}-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]

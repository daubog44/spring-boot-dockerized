# Stage 1: Build the JAR
FROM eclipse-temurin:25-jdk AS builder
WORKDIR /app

# Copy Maven wrapper and POM
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies to cache them
RUN ./mvnw dependency:go-offline -B || true

# Copy the actual source code
COPY src src

# Build Arguments to specify which package to isolate
ARG PKG="com.example.multicanalces"
ARG CLASS="Main"
ARG PKG_PATH="com/example/multicanalces"

# Package the application filtering by the specified package
RUN ./mvnw clean install -Dstart-class=${PKG}.${CLASS} -Dpkg.include=${PKG_PATH}/**/* -DskipTests

# Stage 2: Create the runtime image
FROM eclipse-temurin:25-jre
WORKDIR /app

# Copy only the compiled JAR from the builder
COPY --from=builder /app/target/demo-0.0.1-SNAPSHOT.jar app.jar

# Start the application
ENTRYPOINT ["java", "-jar", "app.jar"]

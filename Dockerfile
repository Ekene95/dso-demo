# --- Stage 1: Build (Maven) ---
FROM maven:3.9-eclipse-temurin-21-alpine AS build
WORKDIR /app
COPY . .
RUN mvn package -DskipTests

# --- Stage 2: Runtime (The Hardened Wolfi Image) ---
FROM kenzman/mpnt-wolfi-java:24.0.1 AS run

# Wolfi best practice: Use the user already defined in your base image YAML
# We don't need to RUN adduser because 'appuser' (UID 1000) exists in your base
WORKDIR /home/appuser

# Copy the artifact from the build stage
COPY --from=build /app/target/demo-0.0.1-SNAPSHOT.jar app.jar

# Run in the healthcheck
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD java -cp . HealthCheck

EXPOSE 8080

# Run the app using the absolute path to java
ENTRYPOINT ["java", "-jar", "app.jar"]

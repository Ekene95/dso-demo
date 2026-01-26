# --- Stage 1: Build (Maven) ---
# We still use a standard maven image to build, or you can use a Wolfi-maven image
FROM maven:3.9-eclipse-temurin-21-alpine AS build
WORKDIR /app
COPY . .
RUN mvn package -DskipTests

# --- Stage 2: Runtime (The Hardened Wolfi Image) ---
# Use the local image you just built and verified
FROM mpnt-wolfi-java:24.0.1-amd64 AS run

# Wolfi best practice: Use the user already defined in your base image YAML
# We don't need to RUN adduser because 'appuser' (UID 1000) exists in your base
WORKDIR /home/appuser

# Copy the artifact from the build stage
COPY --from=build /app/target/demo-0.0.1-SNAPSHOT.jar app.jar

# Compile during the build stage
# Run in the healthcheck
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD java -cp . HealthCheck

# Security Note: Wolfi images do not include 'curl' by default to reduce attack surface.
# To keep the image "Zero-CVE", it is better to use Java-based health checks 
# or ensure curl is added to your wolfi-java.yaml if strictly required.

EXPOSE 8080

# Run the app using the absolute path to java verified in your smoke test
ENTRYPOINT ["java", "-jar", "app.jar"]

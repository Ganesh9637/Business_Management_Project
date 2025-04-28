FROM maven:3.8.6-openjdk-17-slim AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline

COPY src ./src
RUN mvn package -DskipTests

FROM openjdk:17-slim
WORKDIR /app
COPY --from=build /app/target/BusinessProject-0.0.1-SNAPSHOT.jar app.jar

# Create a non-root user to run the application
RUN addgroup --system --gid 1001 appuser && \
    adduser --system --uid 1001 --gid 1001 appuser
USER appuser

EXPOSE 2330
ENTRYPOINT ["java", "-jar", "app.jar"]
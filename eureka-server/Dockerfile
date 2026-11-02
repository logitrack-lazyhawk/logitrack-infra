FROM maven:3.9-eclipse-temurin-25 AS builder
WORKDIR /app
COPY pom.xml ./
COPY src ./src
RUN mvn -B clean package -DskipTests

FROM eclipse-temurin:25-jre-noble
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/target/eureka-server-*.jar app.jar
USER 10001:10001
EXPOSE 8065
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]

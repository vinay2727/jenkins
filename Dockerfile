# FROM maven:3.8.3-openjdk-17 AS build
# WORKDIR /app
# COPY . .
# RUN mvn clean package -DskipTests

# FROM openjdk:17-jdk-slim
# WORKDIR /app
# COPY --from=build /app/target/*.jar app.jar
# EXPOSE 8080
# ENTRYPOINT ["java", "-jar", "app.jar

FROM openjdk:17-jdk
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

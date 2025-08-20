FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /src

COPY pom.xml .
RUN mvn -B -e -q -DskipTests dependency:go-offline

COPY src ./src

RUN mvn -B -DskipTests package

FROM eclipse-temurin:21-jre-alpine

RUN addgroup -S spring && adduser -S spring -G spring
USER spring

WORKDIR /app

COPY --chown=spring:spring target/spring-petclinic-*.jar app.jar

EXPOSE 8080
ENV JAVA_OPTS=""

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]

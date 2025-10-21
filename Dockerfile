FROM maven:3.9-eclipse-temurin-21 AS build

FROM eclipse-temurin:21-jre-alpine

ARG JMX_EXPORTER_VERSION="0.17.0"
ENV JMX_EXPORTER_PORT=9099
ENV JMX_CONFIG_PATH=/app/jmx_exporter_config.yaml

WORKDIR /app 

RUN apk update && apk add --no-cache curl

RUN curl -sL "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar" -o /app/jmx_prometheus_javaagent.jar

COPY jmx_exporter_config.yaml /app/jmx_exporter_config.yaml

COPY target/spring-petclinic-4.0.0-SNAPSHOT.jar /app/app.jar

RUN addgroup -S spring && adduser -S spring -G spring
RUN chown -R spring:spring /app

USER spring

EXPOSE 8080 ${JMX_EXPORTER_PORT}
ENV JAVA_OPTS=""

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -javaagent:/app/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_CONFIG_PATH} -jar /app/app.jar"]
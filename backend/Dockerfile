# Ảnh chạy backend cho staging. Build jar trước trên máy: backend> .\mvnw.cmd -DskipTests package
FROM eclipse-temurin:21-jre
RUN useradd --system --no-create-home viegym
WORKDIR /app
COPY target/backend-0.0.1-SNAPSHOT.jar app.jar
USER viegym
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

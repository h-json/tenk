# syntax=docker/dockerfile:1

# 1단계: jar 굽기 (JDK + Gradle)
# --platform=$BUILDPLATFORM: 빌드 단계는 "빌드하는 머신"의 네이티브 아키텍처로 돈다.
# (윈도우=amd64에서 arm64 타깃을 구울 때, Gradle 빌드를 느린 QEMU 에뮬레이션 대신 네이티브로 빠르게 수행.
#  jar는 아키텍처 중립이라 어디서 구워도 동일 → 런타임 단계만 타깃 arm64로 받으면 됨.)
FROM --platform=$BUILDPLATFORM eclipse-temurin:21-jdk AS build
WORKDIR /workspace
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
RUN chmod +x gradlew && ./gradlew --no-daemon dependencies
COPY src ./src
RUN ./gradlew --no-daemon bootJar

# 2단계: 실행 (JRE + jar)
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY --from=build /workspace/build/libs/*.jar app.jar
ENV SPRING_PROFILES_ACTIVE=prod
ENV TENK_UPLOAD_DIR=/app/uploads
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

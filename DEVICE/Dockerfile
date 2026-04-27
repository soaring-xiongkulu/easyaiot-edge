# 多阶段构建：仅 iot-system（iot-system-biz）
FROM maven:3.9.11-eclipse-temurin-21-alpine AS builder

RUN mkdir -p /root/.m2 && \
    cat > /root/.m2/settings.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>aliyun</id>
      <mirrorOf>central</mirrorOf>
      <name>Aliyun Maven</name>
      <url>https://maven.aliyun.com/nexus/content/groups/public/</url>
    </mirror>
  </mirrors>
  <localRepository>/root/.m2/repository</localRepository>
</settings>
EOF

WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests -Dmaven.test.skip=true -Drevision=1.0.0

FROM bellsoft/liberica-openjdk-rocky:21.0.8-cds AS runtime-base
RUN groupadd -r appgroup -g 1001 && useradd -r -u 1001 -g appgroup appuser
RUN mkdir -p /app/{logs,config,data,cache,temp,backup,message-queue} && chown -R appuser:appgroup /app
WORKDIR /app

ENV TZ=Asia/Shanghai
ENV LANG=C.UTF-8
ENV JAVA_OPTS="-Xms512m -Xmx512m -Djava.security.egd=file:/dev/./urandom"
ENV SPRING_PROFILES_ACTIVE="prod"

FROM runtime-base AS iot-system
COPY --from=builder /app/iot-system/iot-system-biz/target/iot-system-biz.jar app.jar
ENV SERVER_PORT=48099
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${SERVER_PORT}/actuator/health || exit 1
USER appuser
EXPOSE 48099
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

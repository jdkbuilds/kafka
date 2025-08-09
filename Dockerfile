
# Define the build arguments that will be passed in from the Jenkins pipeline.
# Default values are provided as a fallback.
ARG BUILDER_IMAGE=eclipse-temurin:21-jdk
ARG JRE_IMAGE=eclipse-temurin:21-jre
ARG JDK_IMAGE=eclipse-temurin:21-jdk

ARG ARTIFACT_FILENAME

# =============================================================================
# Stage 1: The Builder
# =============================================================================
FROM ${BUILDER_IMAGE} as builder

WORKDIR /app

COPY . .

RUN ./gradlew releaseTarGz -x test -x integrationTest --no-build-cache --no-configuration-cache --no-daemon

RUN ls -lR ./core/build/distributions/ && echo "DEBUG: ARTIFACT_FILENAME is |--->${ARTIFACT_FILENAME}<---|"

RUN mkdir -p /opt/kafka && tar -xzf ./core/build/distributions/${ARTIFACT_FILENAME} -C /opt/kafka --strip-components 1

# =============================================================================
# Stage 2: The JRE Runtime Image (for Production)
# =============================================================================
FROM ${JRE_IMAGE} AS JRE-IMAGE

ENV KAFKA_HOME=/opt/kafka
COPY --from=builder /opt/kafka $KAFKA_HOME

RUN groupadd -r kafka && useradd -r -g kafka kafka
RUN chown -R kafka:kafka $KAFKA_HOME
USER kafka

WORKDIR $KAFKA_HOME
CMD ["bin/kafka-server-start.sh", "config/kraft/server.properties"]


# =============================================================================
# Stage 3: The JDK Runtime Image (for Development/Diagnostics)
# =============================================================================
FROM ${JDK_IMAGE} AS JDK-IMAGE

ENV KAFKA_HOME=/opt/kafka
COPY --from=builder /opt/kafka $KAFKA_HOME

RUN groupadd -r kafka && useradd -r -g kafka kafka
RUN chown -R kafka:kafka $KAFKA_HOME
USER kafka

WORKDIR $KAFKA_HOME
CMD ["bin/kafka-server-start.sh", "config/kraft/server.properties"]

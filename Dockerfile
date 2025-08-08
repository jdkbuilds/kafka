# Define the build arguments that will be passed in from the Jenkins pipeline.
# Default values are provided as a fallback.
ARG BUILDER_IMAGE=eclipse-temurin:21-jdk
ARG JRE_IMAGE=eclipse-temurin:21-jre
ARG JDK_IMAGE=eclipse-temurin:21-jdk

# =============================================================================
# Stage 1: The Builder
# =============================================================================
FROM ${BUILDER_IMAGE} as builder

WORKDIR /app

COPY . .

RUN ./gradlew releaseTarGz -x test -x integrationTest --no-build-cache --no-configuration-cache --no-daemon

# CORRECTED LINE: Use a for loop to ensure the wildcard (*) is expanded correctly.
RUN mkdir /opt/kafka && for f in ./build/distributions/kafka_*.tgz; do tar -xzf "$f" -C /opt/kafka --strip-components 1; done


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

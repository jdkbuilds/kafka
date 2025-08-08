# =============================================================================
# Stage 1: The Builder
# Use a full JDK to build the Kafka project from the source context provided by Jenkins.
# =============================================================================
FROM eclipse-temurin:21-jdk as builder

# Set the working directory inside the container
WORKDIR /app

# Copy the entire source code (from the Jenkins workspace) into the builder
COPY . .

# Run the Gradle command to create the distribution tarball.
# We exclude tests here as this is for the 'notest' build pipeline.
RUN ./gradlew releaseTarGz -x test -x integrationTest --no-build-cache --no-configuration-cache --no-daemon

# Find the created tarball and unpack it into a clean /opt/kafka directory
# The wildcard (*) handles the version-specific name of the tarball.
RUN mkdir /opt/kafka && tar -xzf ./core/build/distributions/kafka_*.tgz -C /opt/kafka --strip-components 1


# =============================================================================
# Stage 2: The JRE Runtime Image (for Production)
# A lean, production-focused image with only the Java Runtime Environment.
# This stage MUST be named 'JRE-IMAGE' to match the Jenkins pipeline command.
# =============================================================================
FROM eclipse-temurin:21-jre AS JRE-IMAGE

ENV KAFKA_HOME=/opt/kafka

# Copy only the compiled Kafka application from the builder stage
COPY --from=builder /opt/kafka $KAFKA_HOME

# Create a dedicated non-root user for improved security
RUN groupadd -r kafka && useradd -r -g kafka kafka
RUN chown -R kafka:kafka $KAFKA_HOME
USER kafka

WORKDIR $KAFKA_HOME

# Default command to run when the container starts (using KRaft)
CMD ["bin/kafka-server-start.sh", "config/kraft/server.properties"]


# =============================================================================
# Stage 3: The JDK Runtime Image (for Development/Diagnostics)
# A larger image that includes the full JDK for troubleshooting.
# This stage MUST be named 'JDK-IMAGE' to match the Jenkins pipeline command.
# =============================================================================
FROM eclipse-temurin:21-jdk AS JDK-IMAGE

ENV KAFKA_HOME=/opt/kafka

# Copy the compiled Kafka application from the builder stage
COPY --from=builder /opt/kafka $KAFKA_HOME

# Create a dedicated non-root user for improved security
RUN groupadd -r kafka && useradd -r -g kafka kafka
RUN chown -R kafka:kafka $KAFKA_HOME
USER kafka

WORKDIR $KAFKA_HOME

# Default command to run when the container starts (using KRaft)
CMD ["bin/kafka-server-start.sh", "config/kraft/server.properties"]

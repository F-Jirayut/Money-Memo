FROM ghcr.io/cirruslabs/flutter:stable

USER root

ARG GRADLE_VERSION=8.14.3

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk-linux \
    ANDROID_SDK_ROOT=/opt/android-sdk-linux \
    GRADLE_USER_HOME=/home/flutter/.gradle \
    PUB_CACHE=/home/flutter/.pub-cache \
    GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION} \
    PATH=/opt/gradle/gradle-${GRADLE_VERSION}/bin:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-17-jdk \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        file \
        bash \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/gradle \
    && curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip \
    && unzip -q /tmp/gradle.zip -d /opt/gradle \
    && rm /tmp/gradle.zip

RUN yes | flutter doctor --android-licenses >/dev/null || true \
    && flutter config --no-analytics \
    && flutter precache --android

WORKDIR /workspace

CMD ["bash"]

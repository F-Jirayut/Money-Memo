FROM ghcr.io/cirruslabs/flutter:stable

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk-linux \
    ANDROID_SDK_ROOT=/opt/android-sdk-linux \
    GRADLE_USER_HOME=/home/flutter/.gradle \
    PUB_CACHE=/home/flutter/.pub-cache

RUN yes | flutter doctor --android-licenses >/dev/null || true \
    && sdkmanager \
        "platforms;android-36" \
        "build-tools;36.0.0" \
        "build-tools;35.0.0" \
        "ndk;28.2.13676358" \
        "cmake;3.22.1" \
    && flutter config --no-analytics \
    && flutter precache --android

WORKDIR /workspace

CMD ["bash"]

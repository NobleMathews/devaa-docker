FROM ubuntu

LABEL maintainer "elbonleon@gmail.com"

WORKDIR /

SHELL ["/bin/bash", "-c"]

# To avoid "tzdata" asking for geographic area
ARG DEBIAN_FRONTEND=noninteractive

# Version of tools
ARG ANDROID_BUILD_TOOLS_LEVEL=29.0.3
ARG GRADLE_VERSION=6.3
ARG ANDROID_API_LEVEL=29
ARG ANDROID_NDK_VERSION=21.1.6352462
# ARG ANDROID_COMPILE_SDK="27"
# ANDROID_SDK_TOOLS_REV="4333796"
# ANDROID_CMAKE_REV="3.6.4111459"
# ANDROID_CMAKE_REV_3_10="3.10.2.4988404"

# Dependencies and needed tools
# openjdk-11
RUN apt update -qq && apt install -qq -y openjdk-8-jdk vim git unzip libglu1 libpulse-dev libasound2 libc6  libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxi6  libxtst6 libnss3 wget

# Download gradle, install gradle and gradlew
RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp \
&& unzip -q -d /opt/gradle /tmp/gradle-${GRADLE_VERSION}-bin.zip \
&& mkdir /opt/gradlew \
&& /opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle wrapper --gradle-version ${GRADLE_VERSION} --distribution-type all -p /opt/gradlew  \
&& /opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle wrapper -p /opt/gradlew

# Download commandlinetools, install packages and accept all licenses
RUN mkdir /opt/android \
&& mkdir /opt/android/cmdline-tools \
&& wget -q 'https://dl.google.com/android/repository/commandlinetools-linux-6200805_latest.zip' -P /tmp \
&& unzip -q -d /opt/android/cmdline-tools /tmp/commandlinetools-linux-6200805_latest.zip \
&& yes Y | /opt/android/cmdline-tools/tools/bin/sdkmanager --install "build-tools;${ANDROID_BUILD_TOOLS_LEVEL}" "platforms;android-${ANDROID_API_LEVEL}" "platform-tools" "ndk;${ANDROID_NDK_VERSION}" \
&& yes Y | /opt/android/cmdline-tools/tools/bin/sdkmanager --licenses

#     && yes | sdkmanager 'extras;android;m2repository' \
#     && yes | sdkmanager 'extras;google;google_play_services' \
#     && yes | sdkmanager 'extras;google;m2repository' 

# RUN    yes | sdkmanager 'cmake;'$ANDROID_CMAKE_REV \
#        yes | sdkmanager --channel=3 --channel=1 'cmake;'$ANDROID_CMAKE_REV_3_10 \
#     && yes | sdkmanager 'ndk-bundle' 

# Environment variables to be used for build
ENV GRADLE_HOME=/opt/gradle/gradle-$GRADLE_VERSION
ENV ANDROID_HOME=/opt/android
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}
ENV PATH "$PATH:$GRADLE_HOME/bin:/opt/gradlew:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/tools/bin:$ANDROID_HOME/platform-tools:${ANDROID_NDK_HOME}"
ENV LD_LIBRARY_PATH "$ANDROID_HOME/emulator/lib64:$ANDROID_HOME/emulator/lib64/qt/lib"

# install/update basics and python
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    	software-properties-common \
    	vim \
    	curl \
    	wget \
    	git \
    	build-essential \
    	unzip \
    	apt-transport-https \
        python3.8 \
    	python3-venv \
    	python3-pip \
    	python3-setuptools \
        python3-dev \
    	gnupg \
    	g++ \
    	make \
    	gcc \
    	apt-utils \
        rsync \
    	file \
        dos2unix \
    	gettext && \
        apt-get clean && \
        rm -f /usr/bin/python /usr/bin/pip && \
        ln -s /usr/bin/python3.8 /usr/bin/python && \
        ln -s /usr/bin/pip3 /usr/bin/pip 

# Install .NET Core and Java for tools/builds
RUN cd /tmp && \
    wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update; \
    apt-get install -y openjdk-8-jdk apt-transport-https && \
    apt-get update && \
    rm packages-microsoft-prod.deb
RUN apt-get install -y dotnet-sdk-3.1

# Clone our setup and run scripts
RUN git clone https://github.com/microsoft/codeql-container /usr/local/startup_scripts
# RUN mkdir -p /usr/local/startup_scripts
# RUN ls -al /usr/local/startup_scripts
# COPY container /usr/local/startup_scripts/
RUN pip3 install -r /usr/local/startup_scripts/container/requirements.txt


# Install latest codeQL
ENV CODEQL_HOME /usr/local/codeql-home
# record the latest version of the codeql-cli
RUN python3 /usr/local/startup_scripts/container/get-latest-codeql-version.py > /tmp/codeql_version
RUN mkdir -p ${CODEQL_HOME} \
    ${CODEQL_HOME}/codeql-repo \
    # ${CODEQL_HOME}/codeql-go-repo \
    /opt/codeql

# get the latest codeql queries and record the HEAD
RUN git clone --depth 1 https://github.com/github/codeql ${CODEQL_HOME}/codeql-repo && \
    git --git-dir ${CODEQL_HOME}/codeql-repo/.git log --pretty=reference -1 > /opt/codeql/codeql-repo-last-commit
# RUN git clone --depth 1 https://github.com/github/codeql-go ${CODEQL_HOME}/codeql-go-repo && \
    # git --git-dir ${CODEQL_HOME}/codeql-go-repo/.git log --pretty=reference -1 > /opt/codeql/codeql-go-repo-last-commit

RUN CODEQL_VERSION=$(cat /tmp/codeql_version) && \
    wget -q https://github.com/github/codeql-cli-binaries/releases/download/${CODEQL_VERSION}/codeql-linux64.zip -O /tmp/codeql_linux.zip && \
    unzip /tmp/codeql_linux.zip -d ${CODEQL_HOME} && \
    rm /tmp/codeql_linux.zip

ENV PATH="${CODEQL_HOME}/codeql:${PATH}"

# RUN mkdir -p ${CODEQL_HOME}/codeql-repo/java/ql/test/query-tests/security/Devaa
# Pre-compile our queries to save time later
# RUN codeql query compile --threads=0 ${CODEQL_HOME}/codeql-repo/*/ql/src/codeql-suites/*.qls
# RUN codeql query compile --threads=0 ${CODEQL_HOME}/codeql-go-repo/ql/src/codeql-suites/*.qls

# RUN ln -s ${CODEQL_HOME}/codeql-repo/java/ql/test/query-tests/security/Devaa ~/home
# RUN codeql query compile --threads=0 ${CODEQL_HOME}/codeql-repo/java/ql/test/query-tests/security/Devaa/tests/*.ql

ENV PYTHONIOENCODING=utf-8
# ENTRYPOINT ["python3", "/usr/local/startup_scripts/container/startup.py"]

# Clean up
RUN rm /tmp/gradle-${GRADLE_VERSION}-bin.zip \
&& rm /tmp/commandlinetools-linux-6200805_latest.zip

# https://stackoverflow.com/questions/35128229/error-no-toolchains-found-in-the-ndk-toolchains-folder-for-abi-with-prefix-llv
RUN cd /opt/android/ndk/*/toolchains/ && \
    ln -s aarch64-linux-android-4.9 mips64el-linux-android &&\
    ln -s arm-linux-androideabi-4.9 mipsel-linux-android

# Install Powershell
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | tee /etc/apt/sources.list.d/microsoft.list && \
    apt-get install -y powershell

# Get DEVAA
RUN git clone --depth 1 https://github.com/NobleMathews/Devaa-Docker ${CODEQL_HOME}/codeql-repo/java/ql/test/query-tests/security/Devaa
ENV DEVAA_HOME /usr/local/codeql-home/codeql-repo/java/ql/test/query-tests/security/Devaa

# CMD cd ${DEVAA_HOME} && pwsh -File "${CODEQL_HOME}/codeql-repo/java/ql/test/query-tests/security/Devaa/pre_process.ps1" -giturl "https://github.com/shivasurya/nextcloud-android"  -testName "localfileinclusion"     
# cd ${DEVAA_HOME} && pwsh -File "${CODEQL_HOME}/codeql-repo/java/ql/test/query-tests/security/Devaa/pre_process.ps1" -giturl "https://github.com/irccloud/android,https://github.com/irccloud/android-websockets" -testName "xss" -hash "65aecefef1165d5fbdede51a21d045f787f70da2"     


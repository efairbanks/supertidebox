FROM ubuntu:20.04 AS build-common

RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
        git build-essential cmake yasm \
        && rm -rf /var/lib/apt/lists/*


FROM build-common AS supercollider
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
    libjack-jackd2-dev libsndfile1-dev libasound2-dev libavahi-client-dev \
    libicu-dev libreadline6-dev libfftw3-dev libxt-dev libudev-dev libcwiid-dev \
    pkg-config \
        && rm -rf /var/lib/apt/lists/*
WORKDIR /repos
RUN git clone --depth=1 --branch=3.11 --recurse-submodules https://github.com/supercollider/supercollider.git \
    && rm -rf /repos/supercollider/.git \
    && mkdir -p /repos/supercollider/build \
    && cd /repos/supercollider/build \
     && cmake -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/qt5/ \
    -DCMAKE_BUILD_TYPE=Release -DNATIVE=ON -DSC_QT=OFF -DSC_IDE=OFF \
    -DNO_X11=ON -DSC_EL=OFF -DSC_ABLETON_LINK=OFF .. \
     && make -j12
WORKDIR /repos
RUN git clone --depth=1 --recursive --branch "Version-3.11.0" \
    https://github.com/supercollider/sc3-plugins.git /repos/sc3-plugins \
    && mkdir -p /repos/sc3-plugins/build \
    && cd /repos/sc3-plugins/build \
    && cmake -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/ \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DSC_PATH=/repos/supercollider/ \
          -DBUILD_TESTING=OFF -DQUARKS=ON -DSUPERNOVA=ON .. \
    && make -j12


FROM build-common AS ffmpeg
# Build ffmpeg, ffserver
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
    libmp3lame-dev libjack-jackd2-dev \
        && rm -rf /var/lib/apt/lists/*
WORKDIR /repos
RUN git clone --depth 1 https://github.com/efairbanks/FFmpeg.git ffmpeg \
    && cd ffmpeg \
    && ./configure --enable-indev=jack --enable-libmp3lame --enable-nonfree \
            --prefix=/usr --disable-shared --enable-static \
    && make -j 12


FROM build-common as quarks
WORKDIR /repos
RUN git clone --depth=1 https://github.com/musikinformatik/SuperDirt \
    && git clone --depth=1 https://github.com/tidalcycles/Dirt-Samples \
    && rm -rf /repos/Dirt-Samples/.git \
    && git clone --depth=1 https://github.com/supercollider-quarks/Vowel


FROM build-common as webssh2
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
        --no-install-recommends \
        npm \
        && rm -rf /var/lib/apt/lists/*
WORKDIR /repos
RUN git clone https://github.com/billchurch/webssh2.git \
    && cd webssh2/app && git checkout 0.4.4 \
    && npm install --production
COPY configs/webssh_config.json /repos/webssh2/app/config.json


FROM build-common
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
        jackd xvfb npm nginx \
        supervisor libsndfile1-dev libsamplerate0-dev liblo-dev libasound2-dev \
        wget ghc emacs-nox haskell-mode zlib1g-dev xz-utils htop screen \
        openssh-server cabal-install libjack-jackd2-dev libmp3lame0 \
        && rm -rf /var/lib/apt/lists/*

COPY --from=ffmpeg /repos/ffmpeg /repos/ffmpeg
WORKDIR /repos/ffmpeg
RUN make install \
    && cd .. \
    && rm -fr ffmpeg

# Initialize and configure sshd
RUN mkdir /var/run/sshd
RUN echo 'root:algorave' | chpasswd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Expose sshd service
EXPOSE 22

# Expose ffserver streaming service
EXPOSE 8090

# Pull Tidal Emacs binding
RUN mkdir /repos/tidal
WORKDIR /repos/tidal
RUN wget https://raw.githubusercontent.com/tidalcycles/Tidal/1.7.8/tidal.el

ENV HOME /root
WORKDIR /root

RUN ln -s /repos /root/repos
RUN ln -s /work /root/work

# Install tidal
RUN DEBIAN_FRONTEND="noninteractive" apt update && apt -y install wget ghc \
    cabal-install libffi-dev \
    && rm -rf /var/cache/apk/*
RUN cabal update && cabal install tidal-1.7.8 && rm -rf .cabal/packages/hackage.haskell.org/

COPY --from=supercollider /repos/supercollider /repos/supercollider
RUN DEBIAN_FRONTEND="noninteractive" apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
        libxt-dev libfftw3-dev libavahi-client-dev libudev-dev libreadline6-dev \
        && rm -rf /var/lib/apt/lists/*
WORKDIR /repos/supercollider/build
RUN make install
RUN ldconfig

COPY --from=supercollider /repos/sc3-plugins /repos/sc3-plugins
WORKDIR /repos/sc3-plugins/build
RUN make install
RUN ldconfig
RUN mv /usr/local/share/SuperCollider/SC3plugins /usr/local/share/SuperCollider/Extensions/SC3plugins

# Install default configurations
COPY configs/emacsrc /root/.emacs
COPY configs/screenrc /root/.screenrc
COPY configs/ffserver.conf /root/ffserver.conf

# Install default Tidal files
COPY tidal/hello.tidal /root/hello.tidal

# Prepare scratch workspace for version control
RUN mkdir -p /work/scratchpool

# Install Tidebox supervisord config
COPY configs/tidebox.ini /etc/supervisor/conf.d/tidebox.conf

# Copy inital supercollider/superdirt startup file
COPY configs/firststart.scd /root/.config/SuperCollider/startup.scd


# Make dummy sclang_conf.yaml to force sclang to recompile class library
RUN touch /root/sclang_conf.yaml

# Install Quarks
WORKDIR /root

COPY --from=quarks /repos/SuperDirt /root/.local/share/SuperCollider/downloaded-quarks/SuperDirt
COPY --from=quarks /repos/Dirt-Samples /root/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples
COPY --from=quarks /repos/Vowel /root/.local/share/SuperCollider/downloaded-quarks/Vowel
# "echo |" is a workaround for https://github.com/supercollider/supercollider/issues/2655.
# Note: xvfb-run doesn't always clean up its X lock:
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=932070, so force it to run
# on screen :1 (with -n 1), a different screen from later xvfb-run (in
# supervisord config).
RUN echo | xvfb-run -n 1 sclang -l /root/sclang_conf.yaml

# Copy permanent supercollider/superdirt startup file
COPY configs/startup.scd /root/.config/SuperCollider/startup.scd

# Make dummy sclang_conf.yaml to force sclang to recompile class library
RUN touch /root/sclang_conf.yaml

# set root shell to screen
RUN echo "/usr/bin/screen" >> /etc/shells
RUN usermod -s /usr/bin/screen root

COPY --from=webssh2 /repos/webssh2 /repos/webssh2
# Expose WebSSH2.
EXPOSE 2222

# Set up nginx reverse-proxy.
COPY configs/nginx /etc/nginx/sites-available/reverse-proxy.conf
COPY configs/index.html configs/howler.core.min.js /var/www/html/
RUN rm /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/reverse-proxy.conf \
             /etc/nginx/sites-enabled/reverse-proxy.conf
EXPOSE 80

CMD ["/usr/bin/supervisord"]

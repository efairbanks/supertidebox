FROM ubuntu AS build-common

RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
		git build-essential cmake yasm \
		&& rm -rf /var/lib/apt/lists/*


# build supercollider
FROM build-common AS supercollider
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
	libjack-jackd2-dev libsndfile1-dev libasound2-dev libavahi-client-dev \
	libicu-dev libreadline6-dev libfftw3-dev libxt-dev libudev-dev libcwiid-dev \
	pkg-config \
		&& rm -rf /var/lib/apt/lists/*
WORKDIR /repos
RUN git clone --depth=1 --branch=3.8 https://github.com/supercollider/supercollider.git
WORKDIR /repos/supercollider
RUN git submodule init && git submodule update
RUN mkdir /repos/supercollider/build
WORKDIR /repos/supercollider/build
RUN cmake -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/qt5/ \
	-DCMAKE_BUILD_TYPE=Release -DNATIVE=ON -DSC_QT=OFF -DSC_IDE=OFF \
	-DNO_X11=ON -DSC_EL=OFF ..
RUN make -j12


FROM build-common AS ffmpeg
# Build & Install libmp3lame
WORKDIR /repos
RUN git clone --depth=1 https://github.com/rbrito/lame.git
WORKDIR lame
RUN ./configure --prefix=/usr
RUN make -j 12 install
WORKDIR /repos
RUN rm -fr lame

# Build ffmpeg, ffserver
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
	libjack-jackd2-dev \
		&& rm -rf /var/lib/apt/lists/*
WORKDIR /repos
RUN git clone --depth 1 https://github.com/efairbanks/FFmpeg.git ffmpeg
WORKDIR ffmpeg
RUN ./configure --enable-indev=jack --enable-libmp3lame --enable-nonfree --prefix=/usr --disable-shared --enable-static
RUN make -j 12


FROM build-common AS cabal
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
	cabal-install \
		&& rm -rf /var/lib/apt/lists/*
RUN cabal update
RUN cabal install tidal-1.7.8


FROM build-common as quarks
WORKDIR /repos
RUN git clone --depth=1 https://github.com/musikinformatik/SuperDirt
RUN git clone --depth=1 https://github.com/tidalcycles/Dirt-Samples
RUN git clone --depth=1 https://github.com/supercollider-quarks/Vowel


FROM build-common
MAINTAINER Eric Fairbanks <ericpfairbanks@gmail.com>

# Install dependencies and audio tools
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
		jackd xvfb \
		supervisor libsndfile1-dev libsamplerate0-dev liblo-dev libasound2-dev \
		wget ghc emacs-nox haskell-mode zlib1g-dev xz-utils htop screen \
		openssh-server cabal-install libjack-jackd2-dev libmp3lame0 \
		&& rm -rf /var/lib/apt/lists/*

COPY --from=ffmpeg /repos/ffmpeg /repos/ffmpeg
WORKDIR /repos/ffmpeg
RUN make install

#COPY --from=ffmpeg /repos/lame /repos/lame
#WORKDIR /repos/lame
#RUN make install

RUN rm -fr ffmpeg # lame

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
WORKDIR /repos
WORKDIR tidal
# Pin to version around 1.3.0.
RUN wget https://raw.githubusercontent.com/tidalcycles/Tidal/0f22cdb064455a354f7b9c31d9785da1617ef874/tidal.el

ENV HOME /root
WORKDIR /root

RUN ln -s /repos /root/repos
RUN ln -s /work /root/work

# Install tidal
COPY --from=cabal /root/.cabal /root/.cabal
COPY --from=cabal /root/.ghc /root/.ghc

COPY --from=supercollider /repos/supercollider /repos/supercollider
RUN DEBIAN_FRONTEND="noninteractive" apt update && DEBIAN_FRONTEND="noninteractive" apt -y install \
		libxt-dev libfftw3-dev libavahi-client-dev libudev-dev libreadline6-dev \
		&& rm -rf /var/lib/apt/lists/*
WORKDIR /repos/supercollider/build
RUN make install
RUN ldconfig

# https://github.com/supercollider/supercollider/issues/2882#issuecomment-303006967
RUN mv /usr/local/share/SuperCollider/SCClassLibrary/Common/GUI /usr/local/share/SuperCollider/SCClassLibrary/scide_scqt/GUI
RUN mv /usr/local/share/SuperCollider/SCClassLibrary/JITLib/GUI /usr/local/share/SuperCollider/SCClassLibrary/scide_scqt/JITLibGUI

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
COPY configs/firststart.scd /root/.sclang.sc

# Make dummy sclang_conf.yaml to force sclang to recompile class library
RUN touch /root/sclang_conf.yaml

# Install Quarks
WORKDIR /root
# "echo |" is a workaround for https://github.com/supercollider/supercollider/issues/2655.
# Note: xvfb-run doesn't always clean up its X lock:
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=932070, so force it to run
# on screen :1 (with -n 1), a different screen from later xvfb-run (in
# supervisord config).
RUN echo | xvfb-run -n 1 sclang -l sclang_conf.yaml

# Copy permanent supercollider/superdirt startup file
COPY configs/startup.scd /root/.sclang.sc

# Make dummy sclang_conf.yaml to force sclang to recompile class library
RUN touch /root/sclang_conf.yaml

# set root shell to screen
RUN echo "/usr/bin/screen" >> /etc/shells
RUN usermod -s /usr/bin/screen root

CMD ["/usr/bin/supervisord"]

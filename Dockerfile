FROM ubuntu

MAINTAINER Eric Fairbanks <ericpfairbanks@gmail.com>

# Install dependencies and audio tools
RUN apt-get update

# Install jackd by itself first without extras since installing alongside other tools seems to cause problems
RUN apt-get -y install jackd

# Install pretty much everything we need here
RUN DEBIAN_FRONTEND='noninteractive' apt-get -y install build-essential xvfb git yasm supervisor libsndfile1-dev libsamplerate0-dev liblo-dev libasound2-dev wget ghc emacs-nox haskell-mode zlib1g-dev xz-utils htop screen openssh-server cabal-install curl sudo

# Install jack libs last
RUN apt-get -y install libjack-jackd2-dev

# Build Dirt synth
WORKDIR /repos
RUN git clone --recursive https://github.com/tidalcycles/Dirt.git
WORKDIR Dirt
RUN make

# Build & Install libmp3lame
WORKDIR /repos
RUN git clone https://github.com/rbrito/lame.git
WORKDIR lame
RUN ./configure --prefix=/usr
RUN make install
WORKDIR /repos
RUN rm -fr lame

# Build & Install ffmpeg, ffserver
WORKDIR /repos
RUN git clone https://github.com/efairbanks/FFmpeg.git ffmpeg
WORKDIR ffmpeg
RUN ./configure --enable-indev=jack --enable-libmp3lame --enable-nonfree --prefix=/usr
RUN make install
WORKDIR /repos
RUN rm -fr ffmpeg

# Initialize and configure sshd
RUN mkdir /var/run/sshd
RUN echo 'root:algorave' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

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
RUN wget https://raw.githubusercontent.com/tidalcycles/Tidal/master/tidal.el

ENV HOME /root
WORKDIR /root

RUN ln -s /repos /root/repos
RUN ln -s /work /root/work

# Install tidal
RUN cabal update
RUN cabal install tidal-0.9.6

# build and install supercollider
RUN apt-get update
RUN apt-get -y install cmake build-essential libjack-jackd2-dev libsndfile1-dev libasound2-dev libavahi-client-dev libicu-dev libreadline6-dev libfftw3-dev libxt-dev libudev-dev libcwiid-dev pkg-config qt5-default qt5-qmake qttools5-dev qttools5-dev-tools qtdeclarative5-dev libqt5webkit5-dev qtpositioning5-dev libqt5sensors5-dev libqt5opengl5-dev
WORKDIR /repos
RUN git clone https://github.com/supercollider/supercollider.git
WORKDIR /repos/supercollider
RUN git checkout 3.8
RUN git submodule init && git submodule update
RUN mkdir /repos/supercollider/build
WORKDIR /repos/supercollider/build
RUN cmake -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/qt5/ ..
RUN make
RUN make install
RUN ldconfig

# Install supercollider plugins
WORKDIR /usr/share/SuperCollider/Extensions
RUN git clone https://github.com/musikinformatik/SuperDirt
RUN git clone https://github.com/tidalcycles/Dirt-Samples
RUN git clone https://github.com/supercollider-quarks/Vowel

# Install default configurations
COPY configs/emacsrc /root/.emacs
COPY configs/screenrc /root/.screenrc
COPY configs/ffserver.conf /root/ffserver.conf

# Install default Tidal files
COPY tidal/init.tidal /root/init.tidal
COPY tidal/hello.tidal /root/hello.tidal

# Prepare scratch workspace for version control
RUN sudo mkdir /work
WORKDIR /work
RUN mkdir /root/.ssh
ADD https://raw.githubusercontent.com/DoubleDensity/scratchpool/master/id_rsa-scratchpool /root/.ssh/id_rsa
COPY configs/sshconfig /root/.ssh/config
RUN ssh-keyscan -H github.com >> ~/.ssh/known_hosts
RUN git clone https://github.com/DoubleDensity/scratchpool.git
WORKDIR /work/scratchpool
RUN git config user.name "SuperTidebox User"
RUN git config user.email "supertidal@jankycloud.com"

# Install Tidebox supervisord config
COPY configs/tidebox.ini /etc/supervisor/conf.d/tidebox.conf

# Copy inital supercollider/superdirt startup file
COPY configs/firststart.scd /root/.sclang.sc

# Make dummy sclang_conf.yaml to force sclang to recompile class library
RUN touch /root/sclang_conf.yaml

# Install Quarks
WORKDIR /root
RUN xvfb-run sclang -l sclang_conf.yaml
#RUN xvfb-run sclang -l sclang_conf.yaml

# Copy permanent supercollider/superdirt startup file
COPY configs/startup.scd /root/.sclang.sc

# Make dummy sclang_conf.yaml to force sclang to recompile class library
RUN touch /root/sclang_conf.yaml

# set root shell to screen
RUN echo "/usr/bin/screen" >> /etc/shells
RUN usermod -s /usr/bin/screen root

CMD ["/usr/bin/supervisord"]

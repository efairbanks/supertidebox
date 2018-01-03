FROM ubuntu

MAINTAINER Eric Fairbanks <ericpfairbanks@gmail.com>

# Install dependencies and audio tools
RUN apt-get update

# Install jackd by itself first without extras since installing alongside other tools seems to cause problems
RUN apt-get -y install jackd

# Install pretty much everything we need here
RUN DEBIAN_FRONTEND='noninteractive' apt-get -y install build-essential supercollider xvfb git yasm supervisor libsndfile1-dev libsamplerate0-dev liblo-dev libasound2-dev wget ghc emacs-nox haskell-mode zlib1g-dev xz-utils htop screen openssh-server cabal-install curl sudo

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
RUN git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
WORKDIR ffmpeg
RUN ./configure --enable-indev=jack --enable-libjack --enable-libmp3lame --enable-nonfree --prefix=/usr
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
RUN wget https://raw.github.com/yaxu/Tidal/master/tidal.el

ENV HOME /home/tidal
WORKDIR /home/tidal

RUN ln -s /repos /home/tidal/repos
RUN ln -s /work /home/tidal/work

# Install tidal
RUN cabal update
RUN cabal install tidal

# Install default configurations
COPY configs/emacsrc /home/tidal/.emacs
COPY configs/screenrc /home/tidal/.screenrc
COPY configs/ffserver.conf /home/tidal/ffserver.conf

# Install default Tidal files
COPY tidal/init.tidal /home/tidal/init.tidal
COPY tidal/hello.tidal /home/tidal/hello.tidal

# Prepare scratch workspace for version control
RUN sudo mkdir /work
WORKDIR /work
RUN mkdir /home/tidal/.ssh
ADD https://raw.githubusercontent.com/DoubleDensity/scratchpool/master/id_rsa-scratchpool /home/tidal/.ssh/id_rsa
COPY configs/sshconfig /home/tidal/.ssh/config
RUN ssh-keyscan -H github.com >> ~/.ssh/known_hosts
RUN git clone https://github.com/DoubleDensity/scratchpool.git
WORKDIR /work/scratchpool
RUN git config user.name "SuperTidebox User"
RUN git config user.email "supertidal@jankycloud.com"

# Install Tidebox supervisord config
COPY configs/tidebox.ini /etc/supervisor/conf.d/tidebox.conf

# Copy sclang startup file
COPY configs/sclang.sc /root/.sclang.sc

CMD ["/usr/bin/supervisord"]

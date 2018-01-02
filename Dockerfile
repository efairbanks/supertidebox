FROM ubuntu

MAINTAINER Eric Fairbanks <ericpfairbanks@gmail.com>

# Install dependencies and audio tools
RUN apt-get update
RUN DEBIAN_FRONTEND='noninteractive' apt-get -y install build-essential jackd supercollider xvfb git yasm supervisor libsndfile1-dev libsamplerate0-dev liblo-dev libasound2-dev libjack-dev libjack0 wget ghc emacs-nox haskell-mode zlib1g-dev xz-utils htop screen openssh-server cabal-install curl sudo
RUN apt-get -y install zsh

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

# Install Tidebox supervisord config
#COPY configs/tidebox.ini /etc/supervisord.d/tidebox.ini
COPY configs/tidebox.ini /etc/supervisor/conf.d/tidebox.conf

# Initialize and configure sshd
RUN ssh-keygen -b 1024 -t rsa -f /etc/ssh/ssh_host_key
RUN ssh-keygen -b 1024 -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -b 1024 -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN sed -i 's/UsePAM\syes/UsePAM no/' /etc/ssh/sshd_config

# Expose sshd service
EXPOSE 22

# Expose ffserver streaming service
EXPOSE 8090

# Pull Tidal Emacs binding
RUN mkdir /repos/tidal
WORKDIR /repos
WORKDIR tidal
RUN wget https://raw.github.com/yaxu/Tidal/master/tidal.el

# Create and configure Tidal user
RUN useradd tidal -s /bin/zsh
RUN echo 'tidal:livecoding' | chpasswd
RUN echo "tidal ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER tidal

ENV HOME /home/tidal
WORKDIR /home/tidal

RUN sudo ln -s /repos /home/tidal/repos
RUN sudo ln -s /work /home/tidal/work
RUN sudo chmod 600 /repos
RUN sudo chmod -R 777 /home/tidal
#RUN sudo chmod 600 /work

# Install tidal
RUN cabal update
RUN cabal install tidal

#ENV TERM xterm

# Install Oh-My-Zsh
RUN curl -OL https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh
RUN bash install.sh

# Disable Zsh automatic window titling
RUN sed -i 's/# DISABLE_AUTO_TITLE="true"/DISABLE_AUTO_TITLE="true"/g' /home/tidal/.zshrc

# Install default configurations
COPY configs/emacsrc /home/tidal/.emacs
COPY configs/screenrc /home/tidal/.screenrc
COPY configs/ffserver.conf /home/tidal/ffserver.conf

# Install default Tidal files
COPY tidal/init.tidal /home/tidal/init.tidal
COPY tidal/hello.tidal /home/tidal/hello.tidal

# Prepare scratch workspace for version control
RUN sudo mkdir /work
RUN sudo chown -R tidal:tidal /work
WORKDIR /work
RUN mkdir /home/tidal/.ssh
ADD https://raw.githubusercontent.com/DoubleDensity/scratchpool/master/id_rsa-scratchpool /home/tidal/.ssh/id_rsa
RUN sudo chmod 600 /home/tidal/.ssh/id_rsa
RUN sudo chown tidal.tidal /home/tidal/.ssh/id_rsa
COPY configs/sshconfig /home/tidal/.ssh/config
RUN sudo chmod 600 /home/tidal/.ssh/config
RUN sudo chown tidal.tidal /home/tidal/.ssh/config
RUN ssh-keyscan -H github.com >> ~/.ssh/known_hosts
RUN git clone https://github.com/DoubleDensity/scratchpool.git
WORKDIR /work/scratchpool
RUN git config user.name "Tidebox User"
RUN git config user.email "tidal@jankycloud.com"

# Set Tidal shell to Screen
USER root
RUN echo "/usr/bin/screen" >> /etc/shells
RUN usermod -s /usr/bin/screen tidal
RUN chown -R tidal.tidal /home/tidal/*.tidal

CMD ["/usr/bin/supervisord"]

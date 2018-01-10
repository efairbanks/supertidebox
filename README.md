# SuperTidebox

SuperTidebox is based on Buttetsu Batou's [Tidebox](https://github.com/DoubleDensity/tidebox).

> A complete Tidal musical live coding and audio streaming environment inside Docker _(now with SuperDirt!)_

## First, the obligatory video demonstration

[![A video demonstrating SuperTidebox usage.](https://img.youtube.com/vi/vrvNYqQNZfI/0.jpg)](https://www.youtube.com/watch?v=vrvNYqQNZfI)


## What is Tidal?

According to the official [homepage](http://tidal.lurk.org):

"Tidal is a language for live coding pattern(s). It provides a way to express music with very flexible timing, providing a little language for describing patterns as discrete sequences (which can be polyphonic and polymetric), some generators of continuous patterns (e.g. sinewaves, sawtooths) and a wide range of pattern transformations."

If you are interested in more detail about the theory and execution of Tidal, Buttetsu and myself highly suggest you read [this paper](https://raw.githubusercontent.com/yaxu/Tidal/master/doc/farm/farm.pdf) from its creator [Alex McLean](https://twitter.com/yaxu).

For an example of the types of patterns and techniques which are possible in Tidal, _I_ would have you listen to the album [RISC Chip](http://shop.conditional.club/album/risc-chip) from [Kindohm](https://twitter.com/kindohm). Kindohm also puts the code used in his albums [up on Github](https://github.com/kindohm/risc-chip), which is pretty darn cool.

## What is SuperDirt?

[SuperDirt](https://github.com/musikinformatik/SuperDirt) is a drop-in replacement for the classic OSC-controlled Tidal sampler [Dirt](https://github.com/tidalcycles/Dirt). It runs inside the multimedia live coding framework known as [SuperCollider](https://github.com/supercollider/supercollider).

SuperCollider has a long history of being integrated into other projects because its synthesis engine, known as `scsynth`, is incredibly powerful and hyper efficient. The integration of SuperCollider into Tidal makes it possible to combine powerful, custom-built effects and softsynths with the flexibilty and efficiency of the Dirt sampler.

Moving from Dirt to SuperDirt is like going from recording with a 4-track to a modern DAW, except that in this case you can build your own features and instruments.

## Why SuperTidebox?

In early 2016, [Buttetsu Batou A.K.A. DoubleDensity](https://github.com/DoubleDensity) created Tidebox as no-fuss way for people to spin up a working environment for playing with Tidal. No pesky building tools from source, no hardware requirements, and no fussing with application startup. Since then, a large portion of the community has moved from using Tidal with the classic Dirt sampler to SuperDirt for the aforementioned reasons.

I was hoping to simply fork Tidebox and make a pull request, but I could not get SuperCollider to cooperate on Fedora, so here we are. SuperTidebox is _(for the moment)_ as close to being a 1:1 Tidebox-like experience as I could manage, but on Ubuntu and with SuperDirt.

## Getting started

1. [Install docker](https://docs.docker.com/engine/installation/#supported-platforms)
2. `git clone https://github.com/efairbanks/supertidebox.git`
3. `cd supertidebox`
4. `./deploy.sh`
5. `ssh localhost -p 2222` _(password is *algorave*)_
6. Point your browser to [http://localhost:8090/stream.mp3](http://localhost:8090/stream.mp3)
7. Jam out!

## Utilities

* `destroy.sh` destroys the last deployed instance of SuperTidebox
* `build.sh` builds the SuperTidebox image
* `run.sh` runs the SuperTidebox image in a new container
* `deploy.sh` runs the previous three helper scripts in order
> *Note:* Any of the files included in `./config` or `./tidal` will be updated in the image/container when you run `./build.sh` or `./deploy.sh`. Feel free to customize these to meet your needs.

## Tips & tricks

* When you ssh in, you will be placed in a customized [screen](https://www.gnu.org/software/screen/manual/screen.html) session
* `ctrl-C ctrl-C` executes line
* `ctrl-C ctrl-E` executes block
* `ctrl-A ,` and `ctrl-A .` cycle through windows
* `ctrl-A D` disconnects

## Caveats

* Sometimes, when building, sclang will have trouble pulling down SuperDirt. This may lead to a lack of audio, sclang errors, or a mysterious lack of audio. A pre-built version of supertidebox is currently in the works to circumvent this, but for the moment just rebuild and it should work.
* Currently, jack and sclang are not cooperating with the version of docker that ships with Mac OS, and this is untested in Windows. If you are having consistent issues with jack or sclang starting, I recommend running docker in linux or in a linux VM. Investigations into these issues are underway.
* FFMpeg dropped ffserver. This uses a forked copy of an older version of FFMpeg. This should be fine, but alternatives should be considered.
* There's some latency when streaming over ffmpeg. It's gonna happen. If you fall too far out of sync, refresh the page.
* This project is brand new. If you encounter issues, _*please*_ let me know about them. I want this to be useful to the community, not just me.

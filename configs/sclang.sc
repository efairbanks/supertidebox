s.boot;
s.waitForBoot {{f=LocalIn.ar(2).tanh;k=Latch.kr(f[0].abs,Impulse.kr(1/4));LocalOut.ar(f+CombC.ar(Blip.ar([4,6],100*k+50,0.9),1,k*0.3,50*f));f}.play;};

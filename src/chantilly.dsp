// chantilly - a drum synthesizer
// Copyright (C) 2017 Daniel Appelt

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

declare name "chantilly";
declare version "0.1.0";
declare author "Daniel Appelt";
declare license "GPL3";
declare copyright "Copyright (C) 2017 Daniel Appelt";

import("stdfaust.lib");

// Oscillators
// triangle, sine, pulse, sawtooth
// TODO: sample&hold (pitch determines hold time), noise (neg. pitch: pink, pos.: blue), closed hh/open hh/crash sample

// no.pink_noise
// no.noise
// sample&hold: sAndH is a standard Faust function: _ : sAndH(t) : _

// Oscillator waveform
osc1_sel = nentry("h:[1]Osc 1/[0]Shape", 0, 0, 3, 1);
osc1_osc(f) = (osc1_sel == 0) * os.triangle(f), (osc1_sel == 1) * os.oscsin(f), (osc1_sel == 2) * os.square(f), (osc1_sel == 3) * os.sawtooth(f) :> _;

// C-11..E10, TODO: chromatic slider / display
osc1_f = hslider("h:[1]Osc 1/[1]Pitch [style:knob]", 50, 0.007984, 20000, 0.01) : si.smoo;

// transposition: 0 half tones -> 1*freq, 12 half tones -> 2*freq => 1 + ht/12 => 1 + cents/1200
osc1_d = hslider("h:[1]Osc 1/[2]Detune [style:knob]", 0, -50, 50, 1) : si.smoo;

// Select envelope 1 or 2 for pitch modulation. Scale it using env slider and velocity.
osc1_env_sel = nentry("h:[1]Osc 1/[3]Pitch Env", 1, 1, 2, 1);
osc1_env = hslider("h:[1]Osc 1/[4]Pitch Env [style:knob]", 0, -1, 1, 0.01);
osc1_vel = hslider("h:[1]Osc 1/[5]Pitch Vel [style:knob]", 0, -1, 1, 0.01); // TODO

// env1, and env2 deliver values in [0..1], osc1_env allows scaling this with [-1..1]
// TODO: osc1_vel must be controllable by velocity
osc1_mod = (osc1_vel + osc1_env) * ((osc1_env_sel == 1) * env1 + (osc1_env_sel == 2) * env2);
// detune range: -50..50 cents, mod range: -100..100 cents
osc1_freq = osc1_f * (1 + osc1_d / 1200 + osc1_mod / 12);

// FM (0..100%), linear scale up to times 8
// https://en.wikipedia.org/wiki/Frequency_modulation_synthesis
fm_index = hslider("h:[1]Osc 1/[6]FM [style:knob]", 0, 0, 8, 0.01);

// Select env 1 or 2 for FM modulation
fm_env_sel = nentry("h:[1]Osc 1/[7]FM Env", 1, 1, 2, 1);
fm_env = hslider("h:[1]Osc 1/[8]FM Env [style:knob]", 0, -1, 1, 0.01);
fm_vel = hslider("h:[1]Osc 1/[9]FM Vel [style:knob]", 0, -1, 1, 0.01); // TODO

// env1, and env2 deliver values in [0..1], fm_env allows scaling this with [-1..1]
// TODO: fm_vel must be controllable by velocity
fm_mod = (fm_vel + fm_env) * ((fm_env_sel == 1) * env1 + (fm_env_sel == 2) * env2);

// TODO: Oscillator 2 is just a copy of Oscillator 1 without FM
osc2_sel = nentry("h:[2]Osc 2/[0]Shape", 0, 0, 3, 1);
osc2_osc(f) = (osc2_sel == 0) * os.triangle(f), (osc2_sel == 1) * os.oscsin(f), (osc2_sel == 2) * os.square(f), (osc2_sel == 3) * os.sawtooth(f) :> _;

osc2_f = hslider("h:[2]Osc 2/[1]Pitch [style:knob]", 50, 0.007984, 20000, 0.01) : si.smoo;
osc2_d = hslider("h:[2]Osc 2/[2]Detune [style:knob]", 0, -50, 50, 1) : si.smoo;

osc2_env_sel = nentry("h:[2]Osc 2/[3]Pitch Env", 1, 1, 2, 1);
osc2_env = hslider("h:[2]Osc 2/[4]Pitch Env [style:knob]", 0, -1, 1, 0.01);
osc2_vel = hslider("h:[2]Osc 2/[5]Pitch Vel [style:knob]", 0, -1, 1, 0.01); // TODO

osc2_mod = (osc2_vel + osc2_env) * ((osc2_env_sel == 1) * env1 + (osc2_env_sel == 2) * env2);
osc2_freq = osc2_f * (1 + osc2_d / 1200 + osc2_mod / 12);

osc2 = osc2_freq : osc2_osc;
// TODO: is this the correct formula for FM with osc1 carrier, and osc2 modulator?
osc1 = osc1_freq * (1 + fm_index * (1 + fm_mod) * osc2) : osc1_osc;

// Ring modulation, see https://en.wikipedia.org/wiki/Ring_modulation
rmod = osc1 * osc2;

// Create a short sawtooth signal for "crack" amplitude modulation
crack_freq = hslider("h:[3]Crack/[0]Crack Speed [style:knob]", 100, 1, 5000, 0.1);
crack_length = hslider("h:[3]Crack/[1]Crack Length [style:knob]", 3, 0, 10000, 1); // TODO: max should be Infinity

// samples per cycle: SR / crack_freq, requested length in samples: crack_length * SR / crack_freq
crack = ba.if(ba.countdown(crack_length * ma.SR / crack_freq, gain : ba.impulsify) > 0, (crack_freq : os.sawtooth) + 1 / 2, 1);

// Mixer
osc1_lev = hslider("h:[4]Mixer/[0]Osc 1 [style:knob]", 0.5, 0, 1, 0.001) : si.smoo;
osc2_lev = hslider("h:[4]Mixer/[1]Osc 2 [style:knob]", 0.5, 0, 1, 0.001) * (1 + osc2_amp_mod) : si.smoo;
rmod_lev = hslider("h:[4]Mixer/[2]RMod [style:knob]", 0, 0, 1, 0.001) : si.smoo;
crack_lev = hslider("h:[4]Mixer/[3]Crack [style:knob]", 0, 0, 1, 0.001) : si.smoo;

// Separate amplitude modulation of osc2 via envelope / velocity
osc2_amp_sel = nentry("h:[4]Mixer/[4]Osc2 Env", 1, 1, 2, 1);
osc2_amp_env = hslider("h:[4]Mixer/[5]Osc2 Env [style:knob]", 0, -1, 1, 0.01);
osc2_amp_vel = hslider("h:[4]Mixer/[6]Osc2 Vel [style:knob]", 0, -1, 1, 0.01); // TODO
osc2_amp_mod = (osc2_amp_vel + osc2_amp_env) * ((osc2_amp_sel == 1) * env1 + (osc2_amp_sel == 2) * env2);

// Envelopes
// TODO: Add shape parameter, time sliders should be logarithmic
env1_a = hslider("h:[6]Envelopes/h:Env 1/[0]Attack [style:knob]", 0, 0, 8, 0.05) : si.smoo;
env1_d = hslider("h:[6]Envelopes/h:Env 1/[1]Decay [style:knob]", 0.2, 0, 16, 0.05) : si.smoo;
env1_r = hslider("h:[6]Envelopes/h:Env 1/[2]Release [style:knob]", 0, 0, 16, 0.05) : si.smoo;
env1 = en.adsr(env1_a, env1_d, 0, env1_r, gain);

// TODO: This is a copy of env1
env2_a = hslider("h:[6]Envelopes/h:Env 2/[0]Attack [style:knob]", 0, 0, 8, 0.05) : si.smoo;
env2_d = hslider("h:[6]Envelopes/h:Env 2/[0]Decay [style:knob]", 0.2, 0, 16, 0.05) : si.smoo;
env2_r = hslider("h:[6]Envelopes/h:Env 2/[0]Release [style:knob]", 0, 0, 16, 0.05) : si.smoo;
env2 = en.adsr(env2_a, env2_d, 0, env2_r, gain);

gain = button("Hit");

// Mix osc1, osc2, and RMod and apply crack AM as requested
// TODO: should crack AM be added to or replace a portion of the original signal (which it does currently).
process = osc1_lev * osc1, osc2_lev * osc2, rmod_lev * rmod :> _  * (1 - crack_lev + crack_lev * crack) * gain;

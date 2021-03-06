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
// triangle, sine (actually it's a cosine), pulse, sawtooth
// TODO: sample&hold (pitch determines hold time), noise (neg. pitch: pink, pos.: blue), closed hh/open hh/crash sample
// noise: first try..no.noise + "neg. f" lowpass + "pos. freq" highpass
// sample&hold: sAndH is a standard Faust function: _ : sAndH(t) : _
osc(i, fMult) = fMult * freq : wf with {
    // Please note that we try to phase shift triangle, sine, square, and saw so that
    // they start with maximum amplitude. This way, we can create the typical click sound
    // at the beginning. If you don't want the click, turn env2 attack up.
    // TODO: I guess, os.triangle and the likes are constantly producing a signal so that currently the
    // phase shifts are not really working as intended.

    // Here, phase shift is done using @ delay. See sawNp(N,freq,phase) definition inside oscillators library.
    // TODO: Currently, the phase shift only works as expected starting from a pitch around 2 Hz, as we
    // restrict the delay to 8191 samples.
    shape(0) = os.triangle : @(max(0, min(8191, int(0.25 * ma.SR/freq))));
    // Effectively, we use cosine here in order to start the sine wave with maximum amplitude.
    shape(1) = os.oscrc;
    shape(2) = os.square;
    shape(3) = os.sawtooth;
    // Create filtered noise with respect to the selected pitch frequency.
    // TODO: Find correct split frequency. Freq. range is logarithmic.
    shape(4) = _, no.noise <: (_ > 141, !), fi.lowpass(2), fi.highpass(2) : select2;
    // ba.latch samples no.noise at positive zero crossings of os.triangle
    shape(5) = _, ! : os.triangle, no.noise : ba.latch;

    // Shape / waveform selection. The par block applies a "solo" to the selected shape. wf multiplexes a given
    // frequency signal into the par block. The soloed result of the block gets mixed into a mono signal.
    sel = nentry("h:[%i]Osc %i/[0]Shape", 1, 1, 6, 1) - 1;
    wf = _ <: par(j, 6, (sel == j) * shape(j)) :> _;

    // C-11..E10
    // TODO: logarithmic scale. See
    // https://github.com/grame-cncm/faust/blob/master/architecture/faust/gui/MetaDataUI.h#L294
    // TODO: chromatic slider / display
    f = hslider("h:[%i]Osc %i/[1]Pitch [unit: Hz][scale:log][style:knob]", 50, 0.007984, 20000, 0.01) : si.smoo;
    // transposition: 0 half tones -> 1*freq, 12 half tones -> 2*freq => 1 + ht/12 => 1 + cents/1200
    d = hslider("h:[%i]Osc %i/[2]Detune [unit: half tones][style:knob]", 0, -50, 50, 1) : si.smoo;

    // Select envelope 1 or 2 for pitch modulation. Scale it using env slider and velocity.
    env_sel = nentry("h:[%i]Osc %i/[3]Pitch Env", 1, 1, 2, 1);
    env = hslider("h:[%i]Osc %i/[4]Pitch Env [style:knob]", 0, -1, 1, 0.01);
    vel = hslider("h:[%i]Osc %i/[5]Pitch Vel [style:knob]", 0, -1, 1, 0.01); // TODO

    // env1, and env2 deliver values in [0..1], osc1_env allows scaling this with [-1..1]
    // TODO: osc1_vel must be controllable by velocity
    mod = (vel + env) * ((env_sel == 1) * env1 + (env_sel == 2) * env2);
    // detune range: -50..50 cents, mod range: -100..100 cents
    freq = f * (1 + d / 1200 + mod / 12);
};

osc2 = osc(2, 1);

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

// TODO: is this the correct formula for FM with osc1 carrier, and osc2 modulator?
osc1 = osc(1, (1 + fm_index * (1 + fm_mod) * osc2));

// Ring modulation, see https://en.wikipedia.org/wiki/Ring_modulation
rmod = osc1 * osc2;

// Create a short sawtooth signal for "crack" amplitude modulation
crack_freq = hslider("h:[3]Crack/[0]Crack Speed [unit: Hz][scale:log][style:knob]", 100, 1, 5000, 0.1);
crack_length = hslider("h:[3]Crack/[1]Crack Length [unit: cycles][scale:log][style:knob]", 3, 1, 10000, 1); // TODO: max should be Infinity

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

// Mix osc1, osc2, and RMod and apply crack AM as requested
// TODO: should crack AM be added to or replace a portion of the original signal (which it does currently).
mix = osc1_lev * osc1, osc2_lev * osc2, rmod_lev * rmod :> *(1 - crack_lev + crack_lev * crack);

// Filter section
// Filter types: fi.resonlp, fi.resonhp, fi.resonbp, fi.notchw
// TODO: EQ-Lo- / Hi-Shelf / EQ-Bell-Type
flt_sel = nentry("h:[5]Filter/[0]Type", 1, 1, 4, 1);

flt_f = hslider("h:[5]Filter/[1]Cutoff [unit: Hz][scale:log][style:knob]", 1000, 11.56, 18794, 1) : si.smoo;
flt_res = hslider("h:[5]Filter/[2]Resonance [style:knob]", 30, 10, 50, 0.01) : si.smoo;

// TODO: notch filter width should be selected depending on the "sounds frequency"
flt_flt(f) = (flt_sel == 1) * fi.resonlp(f, flt_res, 1), (flt_sel == 2) * fi.resonhp(f, flt_res, 1), (flt_sel == 3) * fi.resonbp(f, flt_res, 1), (flt_sel == 4) * fi.bandstop(1, f-100, f+100) :> _;

flt_env_sel = nentry("h:[5]Filter/[3]Env", 1, 1, 2, 1);
flt_env = hslider("h:[5]Filter/[4]Env [style:knob]", 0, -1, 1, 0.01);
flt_vel = hslider("h:[5]Filter/[5]Vel [style:knob]", 0, -1, 1, 0.01); // TODO

flt_mod = (flt_vel + flt_env) * ((flt_env_sel == 1) * env1 + (flt_env_sel == 2) * env2);
flt_freq = flt_f * (1 + flt_mod / 12);

// TODO: drive, triangle LFO mod
// cubicnl
// Cubic nonlinearity distortion. cubicnl is a standard Faust library.
// Usage:
// _ : cubicnl(drive,offset) : _
// _ : cubicnl_nodc(drive,offset) : _

// Amplifier
// Volume -Inf..0 db, Vel, Pan
// amp_lev = hslider("h:[6]Amplifier/[0]Volume [style:knob]", 0.5, 0, 1, 0.001) : si.smoo;
amp_env = hslider("h:[6]Amplifier/[0]Volume [style:knob]", 0.5, -1, 1, 0.01);
amp_vel = hslider("h:[6]Amplifier/[1]Vel [style:knob]", 0, -1, 1, 0.01); // TODO
amp_mod = (amp_vel + amp_env) * env2;
// TODO: add MIDI implementation. See
// https://github.com/grame-cncm/faust/blob/master/architecture/faust/gui/MidiUI.h#L462
// https://github.com/grame-cncm/faust/blob/master/examples/misc/midiTester.dsp#L11
// http://musinf.univ-st-etienne.fr/lac2017/pdfs/09_C_B_137724.pdf
key = 48; // TODO: make it a parameter
gain = button("h:[6]Amplifier/[2]Hit [midi:keyon %key]") * hslider("h:[6]Amplifier/[3]Velocity [midi:keyon %key]", 0, 0, 1, 1/128);

// Envelopes
env(i) = en.adsr(a, d, gain, r, gain) with {
    // TODO: Add shape parameter, time sliders should be logarithmic
    // See https://github.com/grame-cncm/faust/blob/master-dev/libraries/envelopes.lib
    // and https://github.com/grame-cncm/faust/blob/master-dev/libraries/basics.lib
    a = hslider("h:[7]Envelopes/h:Env %i/[0]Attack [unit: s][scale:log][style:knob]", 0.001, 0.001, 8, 0.001) : si.smoo;
    d = hslider("h:[7]Envelopes/h:Env %i/[1]Decay [unit: s][scale:log][style:knob]", 0.2, 0.001, 16, 0.001) : si.smoo;
    r = hslider("h:[7]Envelopes/h:Env %i/[2]Release [unit: s][scale:log][style:knob]", 0.001, 0.001, 16, 0.001) : si.smoo;
};

env1 = env(1);
env2 = env(2);

process = mix <: flt_flt(flt_freq) :> *(amp_mod);

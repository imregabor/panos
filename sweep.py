#!/usr/bin/env python3
#
# Correlate two audio tracks to find best match.
#
#  - Use 'to-pcm.sh' to convert to 16 bit signed big endian or
#
#    ffmpeg -y -i "<IN_VIDEO_OR_AUDIO>" -acodec pcm_s16be -f s16be -ac 1 -ar 16000 "<PCM_FILE>"
#
#  - Create a settins JSON and pass it as a CLI argument; contents:
#
#      "osr" :    Output sample rate, try 100
#      "of" :     Overlap factor for energy downsampling, try something between 0 and 1
#      "dtmin" :  Smallest offset to probe
#      "dtmax" :  Largest offset to probe
#      "dtstep" : Probe steps; ideally matches osr, so try 0.01
#
#      "pcm1file" : First input file
#      "ss1" :      Start second in first input; it will be set to 0
#      "es1" :      End second of first input, no more samples will be processed
#
#      "pcm2file", "ss2", "es2" : Same for second input
#
#  - Typical ffmpeg command line to produce synced video based on identified delay:
#
#    ffmpeg -ss <DELAY_S> -i "<IN_VIDEO>" -itsoffset 0 -i "<IN_AUDIO>" -c:v copy -map 0:v:0 -map 1:a:0 -t <TOTAL_LENGTH_S> "<OUT_VIDEO>"
#
#  - Example of a more complex multi video overlay
#
#    ffmpeg \
#      -i '<AUDIO>' \
#      -f lavfi -i color=c=black:s=960x932 \
#      -itsoffset <OFFSET1_to_audio> -i '<VIDEO1>' \
#      -itsoffset <OFFSET2_to_audio> -i '<VIDEO2>' \
#      -itsoffset <OFFSET3_to_audio> -i '<VIDEO3>' \
#      -filter_complex "[2:v] scale=960:540 [v1s]; \
#        [3:v] scale=480:392 [v2s]; \
#        [4:v] scale=480:392 [v3s]; \
#        [1:v][v1s] overlay=x=0:y=0 [3v]; \
#        [3v][v2s] overlay=x=0:y=540 [4v]; \
#        [4v][v3s] overlay=x=480:y=540 [5v]" \
#      -map "[5v]" -map "0:a:0" \
#      -t <TOTAL_LENGTH> \
#      out.mp4
#


import array
import sys
import matplotlib.pyplot as plt
import numpy as np
import argparse
import json

# Input sample rate
sr=16000

# Intensity sample rate for calculating correlation
csr=100


of=0.5

def readPcm(filename, ss = 0, es = 9999999, isr=16000, osr=100, of=0.5):
  '''
  Read PCM file and calculate windowed, subsampled average energy.

  Arguments:
    filename: Mono 16 bitsigned big endian PCM file to read
    ss: Initial silence in seconds; set energy to 0 in the beginning of the clip
    es: End point in seconds; cut clip after this point
    isr: Input (PCM file) sample rate
    osr: Output array sample rate
    of:  Overlay factor for subsampling; 0 for no overlapl,  0.5 for 50% overtlap on both sides

  '''

  # See https://stackoverflow.com/questions/5030919/how-to-read-write-binary-16-bit-data-in-python-2-x
  pcm = array.array('h')
  print(f'Start reading {filename}')
  with open(filename, 'rb') as f:
    try:
      pcm.fromfile(f, 100000000)
    except EOFError:
      pass

  if sys.byteorder == "little":
    pcm.byteswap()

  print(f'  Read {len(pcm)} samples from {filename}; resample energies from {isr} to {osr}; ss: {ss}, es: {es}')

  ret=[]
  while True:
    if len(ret) / osr < ss:
      ret.append(0)
      #elif len(pcm) / isr - len(ret) / osr < es:
    elif len(ret) / osr > es:
      break
    else:
      si = max(0, round((len(ret) - of) * isr / osr))
      ei = round((len(ret) + 1 + of) * isr / osr)
      if ei >= len(pcm):
        break
      sum = 0
      for sample in pcm[si:ei]:
        sum = sum + sample * sample;
      ret.append(sum / (ei - si))

  print(f'  Calculated {len(ret)} windowed average energy samples')
  print()
  return ret

parser = argparse.ArgumentParser(description = 'Downsampled energy based audio correlation')

parser.add_argument('settingsJson', help = 'Setting JSON file')
args = parser.parse_args()

print(f'Read settings from {args.settingsJson}')
with open(args.settingsJson, 'r') as f:
  settings = json.load(f)

print(f'  Done: {settings}')
print()

i1 = readPcm(
  settings['pcm1file'],
  ss = settings['ss1'] if 'ss1' in settings else 0,
  es = settings['es1'] if 'es1' in settings else 9999999,
  osr = settings['osr'] if 'osr' in settings else csr,
  of = settings['of'] if 'of' in settings else of)

i2 = readPcm(
  settings['pcm2file'],
  ss = settings['ss2'] if 'ss2' in settings else 0,
  es = settings['es2'] if 'es2' in settings else 9999999,
  osr = settings['osr'] if 'osr' in settings else csr,
  of = settings['of'] if 'of' in settings else of)

da = []
ca = []
bestd = 0
bestv = 0

dtmin = settings['dtmin'] if 'dtmin' in settings else 0
dtmax = settings['dtmax'] if 'dtmax' in settings else 10
dtstep = settings['dtstep'] if 'dtstep' in settings else 0.01

fig, axs = plt.subplots(2, sharex = True)
fig.suptitle('Time series')
axs[0].plot(i1)
axs[0].set_title(settings['pcm1file'])
axs[1].plot(i2)
axs[1].set_title(settings['pcm2file'])
plt.show()


print(f'Sweep dt between {dtmin} s and {dtmax} s with step {dtstep} s')

for d in np.arange(dtmin, dtmax, dtstep):
  # d: current delay (of i2) in seconds

  i1s = round(d * csr) if d >= 0 else 0
  i2s = 0 if d >= 0 else round(-d * csr)

  ct = min(len(i1) - i1s, len(i2) - i2s)
  val = 0;
  for i in range(0, ct):
    val = val + i1[ i1s + i ] * i2[ i2s + i ]
  val = val / ct

  da.append(d)
  ca.append(val)
  if val > bestv:
    bestv = val
    bestd = d
  print(f'Delay: {d} Corr: {val}')

print()
print(f'Best delay (offset) of second PCM to match first: {bestd} s')


plt.plot(da, ca)
#plt.plot(i1)
plt.show()

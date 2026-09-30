import array
import pathlib
import struct
import sys
import wave

root = pathlib.Path(__file__).resolve().parent.parent
with wave.open(str(root / 'Tests/Reference-1kHz-stereo-minus20dBFS.wav')) as source:
    assert source.getframerate() == 48000 and source.getsampwidth() == 2
    data = array.array('h', source.readframes(source.getnframes()))
    if sys.byteorder == 'little':
        data.byteswap()
    comm = struct.pack('>HIH', source.getnchannels(), source.getnframes(), 16) + bytes.fromhex('400ebb80000000000000')
    sound = struct.pack('>II', 0, 0) + data.tobytes()
payload = b'AIFFCOMM' + struct.pack('>I', len(comm)) + comm + b'SSND' + struct.pack('>I', len(sound)) + sound
dest = root / 'build/Reference-中文.aiff'
dest.parent.mkdir(exist_ok=True)
dest.write_bytes(b'FORM' + struct.pack('>I', len(payload)) + payload)

def split():
    # Split badapplevocalsonlycut.wav into multiple wav files,
    # each containing a 2 second (120 frame) segment of audio.

    import os
    from pydub import AudioSegment
    from pydub.utils import make_chunks
    from tqdm import tqdm

    os.makedirs("BadApple", exist_ok=True)
    song = AudioSegment.from_wav("badapplevocalsonlycut1385.wav")
    chunk_length_ms = 889  # pydub calculates in millisec
    # Calculate chunk length in ms for 2 beats at 138.5 BPM
    # 1 beat = 60 / BPM seconds, so 2 beats = 2 * (60 / BPM) seconds
    beats = 2
    bpm = 138.5
    chunk_length_ms = int(beats * (60 / bpm) * 1000)
    chunks = make_chunks(song, chunk_length_ms)
    for i, chunk in enumerate(tqdm(chunks)):
        chunk = chunk.set_frame_rate(33100)
        chunk.export(f"BadApple/chunk{i:03d}.wav", format="wav")


if __name__ == "__main__":
    split()

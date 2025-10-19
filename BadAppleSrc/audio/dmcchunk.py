import os
import argparse

#!/usr/bin/env python3
# dmcchunk.py
# Split BadAppleSongMapped.dmc into 8KB (8192 byte) chunks.


CHUNK_SIZE = 8192  # bytes


def split_file(
    inpath: str,
    out_prefix: str = None,
    chunk_size: int = CHUNK_SIZE,
    out_path: str = None,
):
    if not os.path.isfile(inpath):
        raise FileNotFoundError(f"input not found: {inpath}")

    if out_prefix is None:
        base = os.path.basename(inpath)
        name, _ = os.path.splitext(base)
        out_prefix = name

    total = os.path.getsize(inpath)
    num_chunks = (total + chunk_size - 1) // chunk_size
    digits = max(3, len(str(max(0, num_chunks - 1))))

    with open(inpath, "rb") as rf:
        idx = 0
        while True:
            data = rf.read(chunk_size)
            if not data:
                break
            outname = f"{out_prefix}.dmc{idx}"
            with open(out_path + os.sep + outname, "wb") as wf:
                wf.write(data)
            print(f"Wrote {outname} ({len(data)} bytes)")
            idx += 1

    print(f"Completed: {idx} chunks written from {inpath}")


def main():
    split_file(
        "BadAppleSongMapped.dmc", "BadAppleSongMapped", CHUNK_SIZE, out_path="dpcm8kb"
    )


if __name__ == "__main__":
    main()

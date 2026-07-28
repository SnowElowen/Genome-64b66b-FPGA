#!/usr/bin/env python3
"""SnowGenome v0.2 scalar golden model.

The RTL input contract is 16 bases per beat. Lane 0 occupies dna_data[1:0].
A/C/G/T use 00/01/10/11. Unknown N consumes a read position but clears the
known mask, so every k-mer containing N is invalid.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from typing import Iterable, Sequence

BASE_TO_BITS = {"A": 0b00, "C": 0b01, "G": 0b10, "T": 0b11}
BITS_TO_BASE = "ACGT"
COMPLEMENT = {"A": "T", "C": "G", "G": "C", "T": "A", "N": "N"}


@dataclass(frozen=True)
class KmerEvent:
    read_id: int
    end_position: int
    sequence: str
    forward: int
    reverse_complement: int
    canonical: int
    target_hits: tuple[int, ...]


def reverse_complement(sequence: str) -> str:
    return "".join(COMPLEMENT[base] for base in reversed(sequence))


def pack_kmer(sequence: str) -> int:
    value = 0
    for base in sequence:
        if base not in BASE_TO_BITS:
            raise ValueError("pack_kmer accepts only A/C/G/T")
        value = (value << 2) | BASE_TO_BITS[base]
    return value


def canonical_kmer(sequence: str) -> tuple[int, int, int]:
    forward = pack_kmer(sequence)
    reverse = pack_kmer(reverse_complement(sequence))
    return forward, reverse, min(forward, reverse)


def pack_beat(sequence: str, lanes: int = 16) -> tuple[int, int, int]:
    """Return packed_data, known_mask, base_count for one contiguous beat."""
    if len(sequence) > lanes:
        raise ValueError(f"beat exceeds {lanes} bases")

    packed = 0
    known_mask = 0
    for lane, base in enumerate(sequence.upper()):
        if base in BASE_TO_BITS:
            packed |= BASE_TO_BITS[base] << (2 * lane)
            known_mask |= 1 << lane
        elif base != "N":
            raise ValueError(f"unsupported base {base!r}")
    return packed, known_mask, len(sequence)


def iter_kmers(
    sequence: str,
    read_id: int,
    targets: Sequence[int],
    k: int = 15,
) -> Iterable[KmerEvent]:
    sequence = sequence.upper()
    for end_position in range(k - 1, len(sequence)):
        window = sequence[end_position - k + 1 : end_position + 1]
        if "N" in window:
            continue
        forward, reverse, canonical = canonical_kmer(window)
        hits = tuple(index for index, target in enumerate(targets) if canonical == target)
        yield KmerEvent(
            read_id=read_id,
            end_position=end_position,
            sequence=window,
            forward=forward,
            reverse_complement=reverse,
            canonical=canonical,
            target_hits=hits,
        )


def parse_target(sequence: str, k: int) -> int:
    sequence = sequence.upper()
    if len(sequence) != k:
        raise ValueError(f"target {sequence!r} is not {k} bases")
    if "N" in sequence:
        raise ValueError("targets cannot contain N")
    return canonical_kmer(sequence)[2]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("sequence", help="A/C/G/T/N read sequence")
    parser.add_argument("--read-id", type=int, default=1)
    parser.add_argument("--k", type=int, default=15)
    parser.add_argument(
        "--target",
        action="append",
        default=[],
        help="target k-mer sequence; may be supplied more than once",
    )
    args = parser.parse_args()

    targets = [parse_target(target, args.k) for target in args.target]
    events = [asdict(event) for event in iter_kmers(args.sequence, args.read_id, targets, args.k)]
    print(json.dumps(events, indent=2))


if __name__ == "__main__":
    main()

# SnowGenome-64b66b v0.2

A reproducible FPGA genomics streaming front-end for deterministic 2-bit DNA ingest, vector rolling k-mer generation, canonical exact-target screening, and downstream candidate-event production.

## v0.2 architecture

The public core consumes a normalized **32-bit DNA beat at 312.5 MHz**:

```text
16 packed bases/cycle
    -> read-boundary and N-mask enforcement
    -> 16 fixed-slice rolling 15-mers
    -> 16 forward/reverse-complement canonicalizers
    -> four-target local banks
    -> 16-lane target-hit matrix
```

Base encoding is `A=00`, `C=01`, `G=10`, and `T=11`. Lane 0 is stored in `dna_data_i[1:0]`. `dna_known_i[lane]=0` represents `N/unknown`: the base still consumes a read position, but every k-mer containing it is invalid.

## Physical contract

- Default vector width: **16 bases/cycle**
- Default k-mer length: **K=15**
- Public core clock: **312.5 MHz / 3.200 ns**
- Input source: a normalized adapter outside this repository's critical physical build
- Non-final beats must contain exactly 16 bases
- Final beats may contain 1-16 bases
- `read_start_i` clears k-mer history before the current beat
- No k-mer may cross a read boundary
- Exact-target comparison uses `min(forward, reverse-complement)`
- Target tables are split into local banks of four targets; each replicated k-mer bit drives four equality comparators rather than the complete target table
- Hit matrix mapping: `hit_matrix[(lane * TARGET_COUNT) + target]`
- Consumers must gate hit bits with `target_lane_valid_o[lane]`

The public RTL contains four registered stages:

```text
S0 vector k-mer register
S1 canonical k-mer register
S2 local-bank replication register
S3 target-result register
```

An accepted input beat reaches `S3` three clock intervals later. A registered adapter source launching into `S0` therefore sees a four-cycle source-FF-to-result-FF path: **12.800 ns at 312.5 MHz**. These are architectural cycle counts, not post-route timing claims.

## Repository boundary

This public repository contains normalized RTL, simulation, a scalar Python golden model, a generic clock constraint, and report-generation Tcl.

The following artifacts are intentionally not published:

- Board pin and GT channel placement
- GTH Wizard/XCI and wrapper constants
- QPLL/CDR/gearbox phase ownership
- Pblock, BEL, LOC, and fixed-route constraints
- Manual routing Tcl
- Private deterministic-latency physical models

The public XDC is therefore a timing contract only. It is not the production ZU15EG physical constraint set.

## Files

- `rtl/dna/ssg_vector_kmer16.v`: 14-base history plus 16 new bases, producing 16 fixed-slice k-mers
- `rtl/kmer/ssg_canonical_lane.v`: reverse complement plus canonical selection for one lane
- `rtl/kmer/ssg_vector_canonical16.v`: 16 registered canonical lanes
- `rtl/filter/ssg_target_bank16.v`: four-target local banks and registered hit matrix
- `rtl/top/snowgenome_top.v`: normalized v0.2 top
- `model/snowgenome_golden.py`: read-boundary-aware, N-aware scalar reference
- `tb/tb_snowgenome_top.v`: exact checks for target hit, read boundary, and N suppression
- `xdc/snowgenome_core_312m_public.xdc`: generic public clock contract
- `tcl/*.tcl`: reproducible project and report flow

## Validation boundary

The testbench checks:

1. The first beat of a read only produces lanes 14 and 15 for `K=15`.
2. A known target is found at the exact expected lane.
3. An `N` invalidates every overlapping k-mer.
4. A new read cannot inherit history from the preceding read.
5. `read_id`, base position, and `read_end` remain cycle-aligned.

Post-route closure must still be established on the target Vivado build. Required evidence is:

```text
WNS >= +0.100 ns
WHS >= +0.050 ns
unconstrained paths = 0
target compare path <= 2 LUT levels
local target-bank data fanout <= 4
```

The previous scalar implementation remains preserved on the `archive/v0.1-scalar-reference` branch.

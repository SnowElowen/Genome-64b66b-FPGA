# Public / Private Physical Boundary

The public repository is limited to the normalized DNA-core contract and reproducible functional verification.

## Public

- Synthesizable normalized RTL
- Testbench and scalar golden model
- Generic `3.200 ns` core-clock constraint
- Generic synthesis, implementation, timing-report, utilization, and netlist-export Tcl

## Private

- Board pin assignments
- GT channel and reference-clock placement
- Wizard/XCI files and generated wrappers
- QPLL/CDR/gearbox phase ownership
- RX/TX buffer-bypass implementation details
- Pblock, BEL, LOC, and fixed-route constraints
- Manual routing Tcl
- Production BIT/LTX and hardware-specific debug artifacts

No private physical constraint should be copied into the public XDC or public Tcl flow.

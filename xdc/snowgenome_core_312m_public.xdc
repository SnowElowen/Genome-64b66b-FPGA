# PUBLIC TIMING CONTRACT ONLY.
# Production GT pin, placement, phase, Pblock, BEL/LOC and manual-route
# constraints are intentionally excluded from this repository.
create_clock -name dna_core_312m -period 3.200 [get_ports clk_i]
set_clock_uncertainty 0.030 [get_clocks dna_core_312m]

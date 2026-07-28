set repo_root [file normalize [file join [file dirname [info script]] ..]]
open_project $repo_root/build/snowgenome.xpr
reset_run impl_1
launch_runs impl_1 -to_step route_design -jobs 8
wait_on_run impl_1
open_run impl_1
file mkdir $repo_root/reports/timing
file mkdir $repo_root/reports/utilization
file mkdir $repo_root/reports/clocks
report_timing_summary -file $repo_root/reports/timing/post_impl_timing_summary.rpt
report_timing -max_paths 50 -sort_by group -file $repo_root/reports/timing/post_impl_timing_top50.rpt
report_high_fanout_nets -file $repo_root/reports/timing/post_impl_high_fanout_nets.rpt
report_utilization -file $repo_root/reports/utilization/post_impl_utilization.rpt
report_design_analysis -file $repo_root/reports/timing/post_impl_design_analysis.rpt
report_clocks -file $repo_root/reports/clocks/report_clocks.rpt
report_clock_interaction -file $repo_root/reports/clocks/report_clock_interaction.rpt
report_exceptions -file $repo_root/reports/timing/post_impl_exceptions.rpt
report_drc -file $repo_root/reports/timing/post_impl_drc.rpt
write_checkpoint -force $repo_root/build/snowgenome_post_route.dcp

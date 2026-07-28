set repo_root [file normalize [file join [file dirname [info script]] ..]]
set proj_dir  [file join $repo_root build]
file mkdir $proj_dir

create_project snowgenome $proj_dir -part xczu15eg-ffvb1156-2-i -force

add_files [list \
    $repo_root/rtl/common/ssg_pipe_reg.v \
    $repo_root/rtl/kmer/ssg_reverse_complement.v \
    $repo_root/rtl/kmer/ssg_canonical_lane.v \
    $repo_root/rtl/dna/ssg_vector_kmer16.v \
    $repo_root/rtl/kmer/ssg_vector_canonical16.v \
    $repo_root/rtl/filter/ssg_target_bank16.v \
    $repo_root/rtl/top/snowgenome_top.v \
]

add_files -fileset sim_1 [list \
    $repo_root/tb/tb_snowgenome_top.v \
]

add_files -fileset constrs_1 [list \
    $repo_root/xdc/snowgenome_core_312m_public.xdc \
]

set_property top snowgenome_top [current_fileset]
set_property top tb_snowgenome_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

`timescale 1ns/1ps

module snowgenome_top #(
    parameter integer K = 15,
    parameter integer LANES = 16,
    parameter integer TARGET_COUNT = 16,
    parameter integer TARGET_BANK_SIZE = 4,
    parameter [TARGET_COUNT*(2*K)-1:0] TARGET_KMERS =
        {(TARGET_COUNT*(2*K)){1'b0}}
)(
    input  wire                               clk_i,
    input  wire                               rst_i,

    input  wire                               dna_valid_i,
    input  wire [2*LANES-1:0]                 dna_data_i,
    input  wire [LANES-1:0]                   dna_known_i,
    input  wire [4:0]                         base_count_i,
    input  wire                               read_start_i,
    input  wire                               read_end_i,
    input  wire [31:0]                        read_id_i,

    output wire                               target_beat_valid_o,
    output wire [LANES-1:0]                   target_lane_valid_o,
    output wire [LANES*TARGET_COUNT-1:0]      target_hit_matrix_o,
    output wire [31:0]                        target_beat_base_pos_o,
    output wire [31:0]                        target_read_id_o,
    output wire                               target_read_end_o,
    output wire                               protocol_error_o
);
    wire                         s0_beat_valid_w;
    wire [LANES-1:0]             s0_lane_valid_w;
    wire [LANES*(2*K)-1:0]       s0_forward_kmers_w;
    wire [31:0]                  s0_beat_base_pos_w;
    wire [31:0]                  s0_read_id_w;
    wire                         s0_read_end_w;

    wire                         s1_beat_valid_w;
    wire [LANES-1:0]             s1_lane_valid_w;
    wire [LANES*(2*K)-1:0]       s1_canonical_kmers_w;
    wire [31:0]                  s1_beat_base_pos_w;
    wire [31:0]                  s1_read_id_w;
    wire                         s1_read_end_w;

    ssg_vector_kmer16 #(
        .K(K),
        .LANES(LANES)
    ) u_vector_kmer16 (
        .clk_i             (clk_i),
        .rst_i             (rst_i),
        .dna_valid_i       (dna_valid_i),
        .dna_data_i        (dna_data_i),
        .dna_known_i       (dna_known_i),
        .base_count_i      (base_count_i),
        .read_start_i      (read_start_i),
        .read_end_i        (read_end_i),
        .read_id_i         (read_id_i),
        .beat_valid_o      (s0_beat_valid_w),
        .kmer_valid_o      (s0_lane_valid_w),
        .forward_kmers_o   (s0_forward_kmers_w),
        .beat_base_pos_o   (s0_beat_base_pos_w),
        .read_id_o         (s0_read_id_w),
        .read_end_o        (s0_read_end_w),
        .protocol_error_o  (protocol_error_o)
    );

    ssg_vector_canonical16 #(
        .K(K),
        .LANES(LANES)
    ) u_vector_canonical16 (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .beat_valid_i       (s0_beat_valid_w),
        .lane_valid_i       (s0_lane_valid_w),
        .forward_kmers_i    (s0_forward_kmers_w),
        .beat_base_pos_i    (s0_beat_base_pos_w),
        .read_id_i          (s0_read_id_w),
        .read_end_i         (s0_read_end_w),
        .beat_valid_o       (s1_beat_valid_w),
        .lane_valid_o       (s1_lane_valid_w),
        .canonical_kmers_o  (s1_canonical_kmers_w),
        .beat_base_pos_o    (s1_beat_base_pos_w),
        .read_id_o          (s1_read_id_w),
        .read_end_o         (s1_read_end_w)
    );

    ssg_target_bank16 #(
        .K(K),
        .LANES(LANES),
        .TARGET_COUNT(TARGET_COUNT),
        .BANK_SIZE(TARGET_BANK_SIZE),
        .TARGET_KMERS(TARGET_KMERS)
    ) u_target_bank16 (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .beat_valid_i       (s1_beat_valid_w),
        .lane_valid_i       (s1_lane_valid_w),
        .canonical_kmers_i  (s1_canonical_kmers_w),
        .beat_base_pos_i    (s1_beat_base_pos_w),
        .read_id_i          (s1_read_id_w),
        .read_end_i         (s1_read_end_w),
        .beat_valid_o       (target_beat_valid_o),
        .lane_valid_o       (target_lane_valid_o),
        .hit_matrix_o       (target_hit_matrix_o),
        .beat_base_pos_o    (target_beat_base_pos_o),
        .read_id_o          (target_read_id_o),
        .read_end_o         (target_read_end_o)
    );
endmodule

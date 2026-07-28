`timescale 1ns/1ps

module ssg_target_bank16 #(
    parameter integer K = 15,
    parameter integer LANES = 16,
    parameter integer TARGET_COUNT = 16,
    parameter integer BANK_SIZE = 4,
    parameter [TARGET_COUNT*(2*K)-1:0] TARGET_KMERS =
        {(TARGET_COUNT*(2*K)){1'b0}}
)(
    input  wire                               clk_i,
    input  wire                               rst_i,

    input  wire                               beat_valid_i,
    input  wire [LANES-1:0]                   lane_valid_i,
    input  wire [LANES*(2*K)-1:0]             canonical_kmers_i,
    input  wire [31:0]                        beat_base_pos_i,
    input  wire [31:0]                        read_id_i,
    input  wire                               read_end_i,

    output wire                               beat_valid_o,
    output reg  [LANES-1:0]                   lane_valid_o,
    output reg  [LANES*TARGET_COUNT-1:0]      hit_matrix_o,
    output wire [31:0]                        beat_base_pos_o,
    output wire [31:0]                        read_id_o,
    output wire                               read_end_o
);
    localparam integer W = 2*K;
    localparam integer BANK_COUNT = (TARGET_COUNT + BANK_SIZE - 1) / BANK_SIZE;
    localparam integer META_W = 65;

    wire [LANES*BANK_COUNT*W-1:0] bank_kmers_w;
    wire [LANES*BANK_COUNT-1:0]   bank_valid_w;

    genvar gl;
    genvar gb;
    generate
        for (gl = 0; gl < LANES; gl = gl + 1) begin : g_lane_bank_copy
            for (gb = 0; gb < BANK_COUNT; gb = gb + 1) begin : g_bank_copy
                ssg_pipe_reg #(
                    .W(W)
                ) u_bank_copy (
                    .clk_i   (clk_i),
                    .rst_i   (rst_i),
                    .d_i     (canonical_kmers_i[(gl*W) +: W]),
                    .valid_i (lane_valid_i[gl]),
                    .q_o     (bank_kmers_w[((gl*BANK_COUNT+gb)*W) +: W]),
                    .valid_o (bank_valid_w[(gl*BANK_COUNT)+gb])
                );
            end
        end
    endgenerate

    wire [LANES*TARGET_COUNT-1:0] hit_comb_w;

    genvar gc_lane;
    genvar gc_bank;
    genvar gc_slot;
    generate
        for (gc_lane = 0; gc_lane < LANES; gc_lane = gc_lane + 1) begin : g_compare_lane
            for (gc_bank = 0; gc_bank < BANK_COUNT; gc_bank = gc_bank + 1) begin : g_compare_bank
                for (gc_slot = 0; gc_slot < BANK_SIZE; gc_slot = gc_slot + 1) begin : g_compare_slot
                    if ((gc_bank*BANK_SIZE + gc_slot) < TARGET_COUNT) begin : g_target_present
                        localparam integer TARGET_INDEX = gc_bank*BANK_SIZE + gc_slot;
                        wire [W-1:0] target_w;
                        wire [W-1:0] bank_kmer_w;

                        assign target_w =
                            TARGET_KMERS[(TARGET_INDEX*W) +: W];
                        assign bank_kmer_w =
                            bank_kmers_w[((gc_lane*BANK_COUNT+gc_bank)*W) +: W];
                        assign hit_comb_w[(gc_lane*TARGET_COUNT)+TARGET_INDEX] =
                            (bank_kmer_w == target_w);
                    end
                end
            end
        end
    endgenerate

    wire [META_W-1:0] meta_s1_w;
    wire [META_W-1:0] meta_s2_w;
    wire meta_valid_s1_w;
    wire meta_valid_s2_w;

    ssg_pipe_reg #(
        .W(META_W)
    ) u_meta_s1 (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .d_i     ({read_end_i, read_id_i, beat_base_pos_i}),
        .valid_i (beat_valid_i),
        .q_o     (meta_s1_w),
        .valid_o (meta_valid_s1_w)
    );

    ssg_pipe_reg #(
        .W(META_W)
    ) u_meta_s2 (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .d_i     (meta_s1_w),
        .valid_i (meta_valid_s1_w),
        .q_o     (meta_s2_w),
        .valid_o (meta_valid_s2_w)
    );

    assign beat_valid_o     = meta_valid_s2_w;
    assign read_end_o       = meta_s2_w[64];
    assign read_id_o        = meta_s2_w[63:32];
    assign beat_base_pos_o  = meta_s2_w[31:0];

    integer lane_i;
    always @(posedge clk_i) begin
        if (rst_i) begin
            lane_valid_o <= {LANES{1'b0}};
            hit_matrix_o <= {(LANES*TARGET_COUNT){1'b0}};
        end else begin
            hit_matrix_o <= hit_comb_w;
            for (lane_i = 0; lane_i < LANES; lane_i = lane_i + 1) begin
                lane_valid_o[lane_i] <= bank_valid_w[lane_i*BANK_COUNT];
            end
        end
    end
endmodule

`timescale 1ns/1ps

module ssg_vector_canonical16 #(
    parameter integer K = 15,
    parameter integer LANES = 16
)(
    input  wire                         clk_i,
    input  wire                         rst_i,

    input  wire                         beat_valid_i,
    input  wire [LANES-1:0]             lane_valid_i,
    input  wire [LANES*(2*K)-1:0]       forward_kmers_i,
    input  wire [31:0]                  beat_base_pos_i,
    input  wire [31:0]                  read_id_i,
    input  wire                         read_end_i,

    output reg                          beat_valid_o,
    output wire [LANES-1:0]             lane_valid_o,
    output wire [LANES*(2*K)-1:0]       canonical_kmers_o,
    output reg  [31:0]                  beat_base_pos_o,
    output reg  [31:0]                  read_id_o,
    output reg                          read_end_o
);
    genvar gl;
    generate
        for (gl = 0; gl < LANES; gl = gl + 1) begin : g_canonical_lane
            ssg_canonical_lane #(
                .K(K)
            ) u_canonical_lane (
                .clk_i              (clk_i),
                .rst_i              (rst_i),
                .kmer_valid_i       (lane_valid_i[gl]),
                .forward_kmer_i     (forward_kmers_i[(gl*(2*K)) +: (2*K)]),
                .canonical_valid_o  (lane_valid_o[gl]),
                .canonical_kmer_o   (canonical_kmers_o[(gl*(2*K)) +: (2*K)])
            );
        end
    endgenerate

    always @(posedge clk_i) begin
        if (rst_i) begin
            beat_valid_o      <= 1'b0;
            beat_base_pos_o   <= 32'd0;
            read_id_o         <= 32'd0;
            read_end_o        <= 1'b0;
        end else begin
            beat_valid_o      <= beat_valid_i;
            beat_base_pos_o   <= beat_base_pos_i;
            read_id_o         <= read_id_i;
            read_end_o        <= read_end_i;
        end
    end
endmodule

`timescale 1ns/1ps

module ssg_canonical_lane #(
    parameter integer K = 15
)(
    input  wire              clk_i,
    input  wire              rst_i,
    input  wire              kmer_valid_i,
    input  wire [2*K-1:0]    forward_kmer_i,
    output reg               canonical_valid_o,
    output reg  [2*K-1:0]    canonical_kmer_o
);
    wire [2*K-1:0] reverse_kmer_w;
    wire take_forward_w;

    ssg_reverse_complement #(
        .K(K)
    ) u_reverse_complement (
        .kmer_i    (forward_kmer_i),
        .rc_kmer_o (reverse_kmer_w)
    );

    assign take_forward_w = (forward_kmer_i <= reverse_kmer_w);

    always @(posedge clk_i) begin
        if (rst_i) begin
            canonical_valid_o <= 1'b0;
            canonical_kmer_o  <= {(2*K){1'b0}};
        end else begin
            canonical_valid_o <= kmer_valid_i;
            canonical_kmer_o  <= take_forward_w ? forward_kmer_i : reverse_kmer_w;
        end
    end
endmodule

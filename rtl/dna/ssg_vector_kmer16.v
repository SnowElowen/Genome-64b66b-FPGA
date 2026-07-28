`timescale 1ns/1ps

module ssg_vector_kmer16 #(
    parameter integer K = 15,
    parameter integer LANES = 16
)(
    input  wire                         clk_i,
    input  wire                         rst_i,

    input  wire                         dna_valid_i,
    input  wire [2*LANES-1:0]           dna_data_i,
    input  wire [LANES-1:0]             dna_known_i,
    input  wire [4:0]                   base_count_i,
    input  wire                         read_start_i,
    input  wire                         read_end_i,
    input  wire [31:0]                  read_id_i,

    output reg                          beat_valid_o,
    output reg  [LANES-1:0]             kmer_valid_o,
    output reg  [LANES*(2*K)-1:0]       forward_kmers_o,
    output reg  [31:0]                  beat_base_pos_o,
    output reg  [31:0]                  read_id_o,
    output reg                          read_end_o,
    output reg                          protocol_error_o
);
    localparam integer HISTORY_BASES = K - 1;
    localparam integer HISTORY_BITS  = 2 * HISTORY_BASES;
    localparam integer WINDOW_BASES  = HISTORY_BASES + LANES;
    localparam integer WINDOW_BITS   = 2 * WINDOW_BASES;

    reg [HISTORY_BITS-1:0] history_r;
    reg [HISTORY_BASES-1:0] history_known_r;
    reg [31:0] next_base_pos_r;
    reg [31:0] active_read_id_r;
    reg        active_read_r;

    wire [2*LANES-1:0] beat_chrono_w;
    wire [LANES-1:0]   known_chrono_w;
    wire [LANES-1:0]   present_chrono_w;

    genvar gb;
    generate
        for (gb = 0; gb < LANES; gb = gb + 1) begin : g_input_reorder
            assign beat_chrono_w[(2*(LANES-1-gb)) +: 2] = dna_data_i[(2*gb) +: 2];
            assign present_chrono_w[LANES-1-gb] = (base_count_i > gb);
            assign known_chrono_w[LANES-1-gb] = dna_known_i[gb] & present_chrono_w[LANES-1-gb];
        end
    endgenerate

    wire [HISTORY_BITS-1:0] history_eff_w =
        read_start_i ? {HISTORY_BITS{1'b0}} : history_r;
    wire [HISTORY_BASES-1:0] history_known_eff_w =
        read_start_i ? {HISTORY_BASES{1'b0}} : history_known_r;

    wire [WINDOW_BITS-1:0]  base_window_w  = {history_eff_w, beat_chrono_w};
    wire [WINDOW_BASES-1:0] known_window_w = {history_known_eff_w, known_chrono_w};

    wire [LANES*(2*K)-1:0] lane_kmers_w;
    wire [LANES-1:0]       lane_known_w;

    genvar gl;
    generate
        for (gl = 0; gl < LANES; gl = gl + 1) begin : g_kmer_lane
            assign lane_kmers_w[(gl*(2*K)) +: (2*K)] =
                base_window_w[(WINDOW_BITS-1-(2*gl)) -: (2*K)];
            assign lane_known_w[gl] =
                &known_window_w[(WINDOW_BASES-1-gl) -: K];
        end
    endgenerate

    wire count_legal_w = (base_count_i >= 5'd1) && (base_count_i <= LANES);
    wire state_legal_w = read_start_i ? ~active_read_r : active_read_r;
    wire partial_legal_w = read_end_i | (base_count_i == LANES);
    wire contract_legal_w = count_legal_w & state_legal_w & partial_legal_w;
    wire accept_w = dna_valid_i & contract_legal_w;
    wire [31:0] current_base_pos_w = read_start_i ? 32'd0 : next_base_pos_r;
    wire [31:0] current_read_id_w = read_start_i ? read_id_i : active_read_id_r;

    always @(posedge clk_i) begin
        if (rst_i) begin
            history_r          <= {HISTORY_BITS{1'b0}};
            history_known_r    <= {HISTORY_BASES{1'b0}};
            next_base_pos_r    <= 32'd0;
            active_read_id_r   <= 32'd0;
            active_read_r      <= 1'b0;

            beat_valid_o       <= 1'b0;
            kmer_valid_o       <= {LANES{1'b0}};
            forward_kmers_o    <= {(LANES*(2*K)){1'b0}};
            beat_base_pos_o    <= 32'd0;
            read_id_o          <= 32'd0;
            read_end_o         <= 1'b0;
            protocol_error_o   <= 1'b0;
        end else begin
            beat_valid_o       <= accept_w;
            kmer_valid_o       <= accept_w ? lane_known_w : {LANES{1'b0}};
            forward_kmers_o    <= lane_kmers_w;
            beat_base_pos_o    <= current_base_pos_w;
            read_id_o          <= current_read_id_w;
            read_end_o         <= accept_w & read_end_i;
            protocol_error_o   <= dna_valid_i & ~contract_legal_w;

            if (accept_w) begin
                if (read_start_i) begin
                    active_read_id_r <= read_id_i;
                end

                if (read_end_i) begin
                    history_r        <= {HISTORY_BITS{1'b0}};
                    history_known_r  <= {HISTORY_BASES{1'b0}};
                    next_base_pos_r  <= 32'd0;
                    active_read_r    <= 1'b0;
                end else begin
                    history_r        <= beat_chrono_w[HISTORY_BITS-1:0];
                    history_known_r  <= known_chrono_w[HISTORY_BASES-1:0];
                    next_base_pos_r  <= current_base_pos_w + LANES;
                    active_read_r    <= 1'b1;
                end
            end
        end
    end
endmodule

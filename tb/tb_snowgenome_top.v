`timescale 1ps/1ps

module tb_snowgenome_top;
    localparam integer K = 15;
    localparam integer LANES = 16;
    localparam integer TARGET_COUNT = 4;
    localparam integer W = 2*K;
    localparam real CLK_PERIOD_PS = 3200.0;

    localparam [W-1:0] TARGET0 = 30'h06C6C6C6; // ACGTACGTACGTACG
    localparam [W-1:0] TARGET1 = 30'h15555555; // CCCCCCCCCCCCCCC
    localparam [W-1:0] TARGET2 = 30'h00156ABF; // AAAACCCCGGGGTTT
    localparam [W-1:0] TARGET3 = 30'h09F29C36; // AGCTTAGGCTAATCG
    localparam [TARGET_COUNT*W-1:0] TARGET_KMERS =
        {TARGET3, TARGET2, TARGET1, TARGET0};

    reg clk_i = 1'b0;
    reg rst_i = 1'b1;

    reg                         dna_valid_i = 1'b0;
    reg [2*LANES-1:0]           dna_data_i = {(2*LANES){1'b0}};
    reg [LANES-1:0]             dna_known_i = {LANES{1'b0}};
    reg [4:0]                   base_count_i = 5'd0;
    reg                         read_start_i = 1'b0;
    reg                         read_end_i = 1'b0;
    reg [31:0]                  read_id_i = 32'd0;

    wire                        target_beat_valid_o;
    wire [LANES-1:0]            target_lane_valid_o;
    wire [LANES*TARGET_COUNT-1:0] target_hit_matrix_o;
    wire [31:0]                 target_beat_base_pos_o;
    wire [31:0]                 target_read_id_o;
    wire                        target_read_end_o;
    wire                        protocol_error_o;

    integer output_count;

    always #(CLK_PERIOD_PS/2.0) clk_i = ~clk_i;

    snowgenome_top #(
        .K(K),
        .LANES(LANES),
        .TARGET_COUNT(TARGET_COUNT),
        .TARGET_BANK_SIZE(4),
        .TARGET_KMERS(TARGET_KMERS)
    ) dut (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .dna_valid_i            (dna_valid_i),
        .dna_data_i             (dna_data_i),
        .dna_known_i            (dna_known_i),
        .base_count_i           (base_count_i),
        .read_start_i           (read_start_i),
        .read_end_i             (read_end_i),
        .read_id_i              (read_id_i),
        .target_beat_valid_o     (target_beat_valid_o),
        .target_lane_valid_o     (target_lane_valid_o),
        .target_hit_matrix_o     (target_hit_matrix_o),
        .target_beat_base_pos_o  (target_beat_base_pos_o),
        .target_read_id_o        (target_read_id_o),
        .target_read_end_o       (target_read_end_o),
        .protocol_error_o        (protocol_error_o)
    );

    task drive_single_beat_read;
        input [31:0] id;
        input [31:0] packed_bases;
        input [15:0] known_mask;
        begin
            @(negedge clk_i);
            dna_valid_i  = 1'b1;
            dna_data_i   = packed_bases;
            dna_known_i  = known_mask;
            base_count_i = 5'd16;
            read_start_i = 1'b1;
            read_end_i   = 1'b1;
            read_id_i    = id;
        end
    endtask

    task drive_idle;
        begin
            @(negedge clk_i);
            dna_valid_i  = 1'b0;
            dna_data_i   = 32'd0;
            dna_known_i  = 16'd0;
            base_count_i = 5'd0;
            read_start_i = 1'b0;
            read_end_i   = 1'b0;
            read_id_i    = 32'd0;
        end
    endtask

    always @(negedge clk_i) begin
        if (!rst_i) begin
            if (protocol_error_o) begin
                $fatal(1, "Unexpected protocol_error_o");
            end

            if (target_beat_valid_o) begin
                output_count = output_count + 1;

                if (target_beat_base_pos_o !== 32'd0) begin
                    $fatal(1, "Single-beat read must start at base position zero");
                end
                if (target_read_end_o !== 1'b1) begin
                    $fatal(1, "Single-beat read must preserve read_end");
                end
                if (target_lane_valid_o[13:0] !== 14'd0) begin
                    $fatal(1, "First beat generated a cross-boundary k-mer");
                end

                case (target_read_id_o)
                    32'd1: begin
                        if (target_lane_valid_o[15:14] !== 2'b11) begin
                            $fatal(1, "Read 1 must produce exactly lanes 14 and 15");
                        end
                        if (!target_hit_matrix_o[(14*TARGET_COUNT)+0]) begin
                            $fatal(1, "Read 1 lane 14 missed TARGET0");
                        end
                    end

                    32'd2: begin
                        if (target_lane_valid_o[15:14] !== 2'b00) begin
                            $fatal(1, "N-containing k-mers were not suppressed");
                        end
                    end

                    32'd3: begin
                        if (target_lane_valid_o[15:14] !== 2'b11) begin
                            $fatal(1, "Read 3 must produce exactly lanes 14 and 15");
                        end
                        if (!target_hit_matrix_o[(14*TARGET_COUNT)+1]) begin
                            $fatal(1, "Read 3 lane 14 missed TARGET1");
                        end
                        if (!target_hit_matrix_o[(15*TARGET_COUNT)+1]) begin
                            $fatal(1, "Read 3 lane 15 missed TARGET1");
                        end
                    end

                    default: begin
                        $fatal(1, "Unexpected output read_id=%0d", target_read_id_o);
                    end
                endcase
            end
        end
    end

    initial begin
        output_count = 0;

        repeat (8) @(posedge clk_i);
        @(negedge clk_i);
        rst_i = 1'b0;

        // Packed lane order is lane0 in bits [1:0], lane15 in bits [31:30].
        drive_single_beat_read(32'd1, 32'hE4E4E4E4, 16'hFFFF);

        // Same physical bases as all-C, but lane7 is N/unknown.
        drive_single_beat_read(32'd2, 32'h55555555, 16'hFF7F);

        drive_single_beat_read(32'd3, 32'h55555555, 16'hFFFF);
        drive_idle();

        repeat (12) @(posedge clk_i);

        if (output_count != 3) begin
            $fatal(1, "Expected 3 output beats, observed %0d", output_count);
        end

        $display("PASS: vector16 read-boundary, N-mask, canonical target screening");
        $finish;
    end
endmodule

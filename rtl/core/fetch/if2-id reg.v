module if2_id_reg(
    input  wire        clk,
    input  wire        rst,
    input  wire        stall_if2_id,   // 为 1 时保持
    input  wire        flush_if2_id,   // 为 1 时清零
    input  wire [31:0] pc_in,
    input  wire [31:0] inst_in,
    output reg  [31:0] pc_out,
    output reg  [31:0] inst_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out   <= 32'b0;
            inst_out <= 32'b0;
        end else if (flush_if2_id) begin
            pc_out   <= 32'b0;
            inst_out <= 32'b0;
        end else if (stall_if2_id) begin
            pc_out   <= pc_out;
            inst_out <= inst_out;
        end else begin
            pc_out   <= pc_in;
            inst_out <= inst_in;
        end
    end

endmodule
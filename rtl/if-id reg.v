module if_id_reg(
    input  wire        clk,
    input  wire        rst,
    input  wire        stall_if_id,   // 当为1时，锁住 IF/ID，不接收新指令
    input  wire        flush_if_id,   // 当为1时，清空本级，注入 NOP
    input  wire [31:0] pc_in,
    input  wire [31:0] inst_in,
    output reg  [31:0] pc_out,
    output reg  [31:0] inst_out
);

    // 增强的 IF/ID 寄存器：支持 stall（保持）与 flush（清空）控制
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out   <= 32'b0;
            inst_out <= 32'b0;
        end else if (flush_if_id) begin
            pc_out   <= 32'b0;
            inst_out <= 32'b0;
        end else if (stall_if_id) begin
            pc_out   <= pc_out;    // 保持不变
            inst_out <= inst_out;
        end else begin
            pc_out   <= pc_in;
            inst_out <= inst_in;
        end
    end

endmodule

module pc_reg(
    input wire clk,
    input wire rst,
    input wire stall_pc,         // 当为1时，保持 PC 不更新
    input wire [31:0] pc_next,
    output reg [31:0] pc
);

// 带时钟使能的 PC 寄存器，使用与工程其余部分一致的同步复位信号 `rst`
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 32'h0000_0000;
    end else if (stall_pc) begin
        pc <= pc;
    end else begin
        pc <= pc_next;
    end
end

endmodule
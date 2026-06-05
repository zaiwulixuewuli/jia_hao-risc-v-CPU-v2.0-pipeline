module if1_if2_reg(
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,   // 为 1 时保持
    input  wire        flush,   // 为 1 时清零（注入 NOP 对应的 PC，不重要）
    input  wire [31:0] pc_in,   // 来自 PC 寄存器的当前 PC
    output reg  [31:0] pc_out   // 送入 IF2 阶段，与同步 ROM 指令对齐
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc_out <= 32'h0;
        else if (flush)
            pc_out <= 32'h0;        // 冲刷时 PC 无关紧要
        else if (!stall)
            pc_out <= pc_in;
    end

endmodule
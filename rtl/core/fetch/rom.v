module rom(
    input  wire        clk,
    input  wire        stall,           // 新增：停顿信号，高电平时保持输出不变
    input  wire [31:0] addr,
    output reg  [31:0] inst
);

    parameter ROM_SIZE = 32;
    reg [31:0] rom_mem [0:ROM_SIZE-1];
    integer i;

    initial begin
        for (i = 0; i < ROM_SIZE; i = i + 1) begin
            rom_mem[i] = 32'h00000013; // NOP
        end

        // 测试程序（保持不变）
        rom_mem[0] = 32'h00a00013;
        rom_mem[1] = 32'h00000233;
        rom_mem[2] = 32'h01420193;
        rom_mem[3] = 32'h00302823;
        rom_mem[4] = 32'h01002283;
        rom_mem[5] = 32'h00528313;
        rom_mem[6] = 32'h003303b3;
        rom_mem[7] = 32'h00039863;
        rom_mem[8] = 32'h3e700393;
        rom_mem[9] = 32'h37800313;
        rom_mem[10] = 32'h00000013;
        rom_mem[11] = 32'h00000463;
        rom_mem[12] = 32'h01002083;
        rom_mem[13] = 32'h00100413;
    end

    // 同步读取：仅在非停顿周期锁存地址并输出指令
    always @(posedge clk) begin
        if (!stall) begin
            inst <= (addr[6:2] < ROM_SIZE) ? rom_mem[addr[6:2]] : 32'h00000013;
        end
        // 当 stall 为高时，inst 保持原值不变
    end

endmodule
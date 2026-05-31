module id_ex_reg (
    input wire clk,
    input wire rst,
    
    // ==========================================
    // 0. 中央交警系统的控制线
    // ==========================================
    input wire flush_id_ex,          // 当为 1 时，清空本级，注入一个 NOP 气泡
    
    // ==========================================
    // 1. WB 阶段需要的物资 (一路向右透传)
    // ==========================================
    input  wire        id_reg_write,  // 是否需要写回寄存器
    input  wire        id_mem_to_reg, // 写回的数据是否来自内存 (1:来自内存, 0:来自ALU)
    output reg         ex_reg_write,
    output reg         ex_mem_to_reg,
    input  wire        id_jal,
    input  wire        id_jalr,
    input  wire        id_rd_from_pc,
    input  wire        id_lui_sel,
    input  wire        id_auipc_sel,
    output reg         ex_jal,
    output reg         ex_jalr,
    output reg         ex_rd_from_pc,
    output reg         ex_lui_sel,
    output reg         ex_auipc_sel,
    
    // ==========================================
    // 2. MEM 阶段需要的物资 (一路向右透传)
    // ==========================================
    input  wire        id_mem_read,   // 读内存使能 (用来判断是否是 lw)
    input  wire        id_mem_write,  // 写内存使能 (sw)
    input  wire        id_branch,     // 是否是 B 类跳转指令
    input  wire [2:0]  id_mem_type,
    output reg         ex_mem_read,
    output reg         ex_mem_write,
    output reg         ex_branch,
    output reg [2:0]   ex_mem_type,
    input  wire [2:0]  id_br_type,
    output reg [2:0]   ex_br_type,
    
    // ==========================================
    // 3. EX 阶段（当下）直接需要的控制物资
    // ==========================================
    input  wire [3:0]  id_alu_op,     // 告诉 ALU 做加减乘除哪种运算
    input  wire        id_alu_src,    // ALU 的第二路输入选谁 (0:读出来的寄存器, 1:立即数)
    output reg  [3:0]  ex_alu_op,
    output reg         ex_alu_src,
    
    // ==========================================
    // 4. 数据与寄存器编号物资
    // ==========================================
    input  wire [31:0] id_pc,         // 当前指令的 PC 值
    input  wire [31:0] id_rdata1,     // 寄存器堆读出的数据 1
    input  wire [31:0] id_rdata2,     // 寄存器堆读出的数据 2
    input  wire [31:0] id_imm,        // 解出来的立即数
    input  wire [4:0]  id_rs1,        // 源寄存器 1 编号 (Forwarding 单元强热需要！)
    input  wire [4:0]  id_rs2,        // 源寄存器 2 编号 (Forwarding 单元强热需要！)
    input  wire [4:0]  id_rd,         // 目的寄存器编号
    
    output reg  [31:0] ex_pc,
    output reg  [31:0] ex_rdata1,
    output reg  [31:0] ex_rdata2,
    output reg  [31:0] ex_imm,
    output reg  [4:0]  ex_rs1,
    output reg  [4:0]  ex_rs2,
    output reg  [4:0]  ex_rd
);

    // ==========================================
    // 时序核心：时钟沿到来时的行为
    // ==========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 异步复位：芯片刚上电，所有人统统归零
            ex_reg_write     <= 1'b0;
            ex_mem_to_reg    <= 1'b0;
            ex_mem_read      <= 1'b0;
            ex_mem_write     <= 1'b0;
            ex_branch        <= 1'b0;
            ex_alu_op        <= 4'b0;
            ex_alu_src       <= 1'b0;
            ex_pc            <= 32'b0;
            ex_rdata1        <= 32'b0;
            ex_rdata2        <= 32'b0;
            ex_imm           <= 32'b0;
            ex_rs1           <= 5'b0;
            ex_rs2           <= 5'b0;
            ex_rd            <= 5'b0;
            ex_jal           <= 1'b0;
            ex_jalr          <= 1'b0;
            ex_rd_from_pc    <= 1'b0;
            ex_lui_sel       <= 1'b0;
            ex_auipc_sel     <= 1'b0;
            ex_mem_type      <= 3'b0;
            ex_br_type       <= 3'b0;
        end 
        else if (flush_id_ex) begin
            // 【硬核大招：物理清洗】
            // 当交警判定出现 lw->B类冲突，或者跳转成功要清空时：
            // 数据变成什么其实无所谓，关键是【控制信号必须全部卡死为 0】！
            // 这样它就变成了一条绝对无害的 NOP 指令气泡，绝不会错误地去写内存或寄存器。
            ex_reg_write     <= 1'b0;
            ex_mem_to_reg    <= 1'b0;
            ex_mem_read      <= 1'b0;
            ex_mem_write     <= 1'b0;
            ex_branch        <= 1'b0;
            ex_alu_op        <= 4'b0;
            ex_alu_src       <= 1'b0;
            // 数据寄存器顺手清零，防止意外产生功耗
            ex_pc            <= 32'b0;
            ex_rdata1        <= 32'b0;
            ex_rdata2        <= 32'b0;
            ex_imm           <= 32'b0;
            ex_rs1           <= 5'b0;
            ex_rs2           <= 5'b0;
            ex_rd            <= 5'b0;
            ex_jal           <= 1'b0;
            ex_jalr          <= 1'b0;
            ex_rd_from_pc    <= 1'b0;
            ex_lui_sel       <= 1'b0;
            ex_auipc_sel     <= 1'b0;
            ex_mem_type      <= 3'b0;
            ex_br_type       <= 3'b0;
        end 
        else begin
            // 正常流动：两手一捏，无脑锁存交接物资
            ex_reg_write     <= id_reg_write;
            ex_mem_to_reg    <= id_mem_to_reg;
            ex_mem_read      <= id_mem_read;
            ex_mem_write     <= id_mem_write;
            ex_branch        <= id_branch;
            ex_alu_op        <= id_alu_op;
            ex_alu_src       <= id_alu_src;
            ex_pc            <= id_pc;
            ex_rdata1        <= id_rdata1;
            ex_rdata2        <= id_rdata2;
            ex_imm           <= id_imm;
            ex_rs1           <= id_rs1;
            ex_rs2           <= id_rs2;
            ex_rd            <= id_rd;
            ex_jal           <= id_jal;
            ex_jalr          <= id_jalr;
            ex_rd_from_pc    <= id_rd_from_pc;
            ex_lui_sel       <= id_lui_sel;
            ex_auipc_sel     <= id_auipc_sel;
            ex_mem_type      <= id_mem_type;
            ex_br_type       <= id_br_type;
        end
    end

endmodule
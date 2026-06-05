module forward_passing(
    input  wire [31:0] ex_rdata1_in,
    input  wire [31:0] ex_rdata2_in,
    input  wire [4:0]  ex_rs1,
    input  wire [4:0]  ex_rs2,

    input  wire        mem_reg_write,
    input  wire [4:0]  mem_rd,
    input  wire [31:0] mem_wb_data,       // 通常为 ALU 结果或 load 数据（需由外部传入正确的 load 数据）

    input  wire        wb_reg_write,
    input  wire [4:0]  wb_rd,
    input  wire [31:0] wb_wb_data,

    // 新增：MEM 阶段 load 转发
    input  wire        mem_mem_read,       // MEM 阶段是否为 load
    input  wire [31:0] mem_read_data,      // 从 dmem 读出的异步数据

    output wire [31:0] ex_rdata1_out,
    output wire [31:0] ex_rdata2_out
);
    // MEM 阶段非 load 写寄存器（ALU 指令）的匹配
    wire mem_alu_match_rs1 = mem_reg_write && !mem_mem_read && (mem_rd != 5'b0) && (mem_rd == ex_rs1);
    wire mem_alu_match_rs2 = mem_reg_write && !mem_mem_read && (mem_rd != 5'b0) && (mem_rd == ex_rs2);

    // MEM 阶段 load 的匹配（数据来自 mem_read_data）
    wire mem_load_match_rs1 = mem_mem_read && (mem_rd != 5'b0) && (mem_rd == ex_rs1);
    wire mem_load_match_rs2 = mem_mem_read && (mem_rd != 5'b0) && (mem_rd == ex_rs2);

    // 综合 MEM 阶段匹配（load 优先使用 mem_read_data）
    wire mem_match_rs1 = mem_alu_match_rs1 || mem_load_match_rs1;
    wire mem_match_rs2 = mem_alu_match_rs2 || mem_load_match_rs2;
    wire [31:0] mem_fwd_data_rs1 = mem_load_match_rs1 ? mem_read_data : mem_wb_data;
    wire [31:0] mem_fwd_data_rs2 = mem_load_match_rs2 ? mem_read_data : mem_wb_data;

    // WB 匹配
    wire wb_match_rs1 = wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs1) && !mem_match_rs1;
    wire wb_match_rs2 = wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs2) && !mem_match_rs2;

    assign ex_rdata1_out = mem_match_rs1 ? mem_fwd_data_rs1 : (wb_match_rs1 ? wb_wb_data : ex_rdata1_in);
    assign ex_rdata2_out = mem_match_rs2 ? mem_fwd_data_rs2 : (wb_match_rs2 ? wb_wb_data : ex_rdata2_in);
endmodule
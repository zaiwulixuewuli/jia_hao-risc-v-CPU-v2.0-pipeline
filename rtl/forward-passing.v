// forward-passing.v
// 实现从 MEM 与 WB 到 EX 的前向通路（MEM 优先于 WB）
module forward_passing(
	// EX 阶段原始读数（来自 id_ex_reg）
	input  wire [31:0] ex_rdata1_in,
	input  wire [31:0] ex_rdata2_in,
	input  wire [4:0]  ex_rs1,
	input  wire [4:0]  ex_rs2,

	// MEM 阶段（较高优先级）——写回相关信号
	input  wire        mem_reg_write, // MEM 阶段是否要写寄存器
	input  wire [4:0]  mem_rd,        // MEM 阶段目的寄存器编号
	input  wire [31:0] mem_wb_data,   // MEM 阶段可用于转发的数据（通常为 ALU 结果或从内存读出的数据）

	// WB 阶段（较低优先级）——写回相关信号
	input  wire        wb_reg_write,  // WB 阶段是否要写寄存器
	input  wire [4:0]  wb_rd,         // WB 阶段目的寄存器编号
	input  wire [31:0] wb_wb_data,    // WB 阶段写回的数据

	// 输出：经前向通路后的 EX 操作数
	output wire [31:0] ex_rdata1_out,
	output wire [31:0] ex_rdata2_out
);

	// 匹配条件：目标寄存器非零且编号相同
	wire mem_match_rs1 = mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs1);
	wire mem_match_rs2 = mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs2);

	wire wb_match_rs1  = wb_reg_write  && (wb_rd  != 5'b0) && (wb_rd  == ex_rs1) && !mem_match_rs1;
	wire wb_match_rs2  = wb_reg_write  && (wb_rd  != 5'b0) && (wb_rd  == ex_rs2) && !mem_match_rs2;

	// 优先使用 MEM，其次 WB，最后使用原始从寄存器堆读出的值
	assign ex_rdata1_out = mem_match_rs1 ? mem_wb_data : (wb_match_rs1 ? wb_wb_data : ex_rdata1_in);
	assign ex_rdata2_out = mem_match_rs2 ? mem_wb_data : (wb_match_rs2 ? wb_wb_data : ex_rdata2_in);

endmodule


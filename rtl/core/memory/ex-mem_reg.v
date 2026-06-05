// ex-mem_reg.v
// EX -> MEM pipeline register
module ex_mem_reg(
    input  wire        clk,
    input  wire        rst,

    // From EX stage
    input  wire        ex_reg_write,
    input  wire        ex_mem_to_reg,
    input  wire        ex_mem_read,
    input  wire        ex_mem_write,
    input  wire [2:0]  ex_mem_type,
    input  wire        ex_branch,
    input  wire [2:0]  ex_br_type,
    input  wire [31:0] ex_pc,
    input  wire [31:0] ex_alu_result,
    input  wire [31:0] ex_rdata2,
    input  wire [4:0]  ex_rd,
    input  wire        ex_jal,
    input  wire        ex_jalr,
    input  wire        ex_rd_from_pc,
    input  wire        ex_lui_sel,
    input  wire        ex_auipc_sel,
    input  wire [31:0] ex_imm,

    // To MEM stage
    output reg         mem_reg_write,
    output reg         mem_mem_to_reg,
    output reg         mem_mem_read,
    output reg         mem_mem_write,
    output reg [2:0]   mem_mem_type,
    output reg         mem_branch,
    output reg [2:0]   mem_br_type,
    output reg [31:0]  mem_pc,
    output reg [31:0]  mem_alu_result,
    output reg [31:0]  mem_rdata2,
    output reg [4:0]   mem_rd,
    output reg         mem_jal,
    output reg         mem_jalr,
    output reg         mem_rd_from_pc,
    output reg         mem_lui_sel,
    output reg         mem_auipc_sel,
    output reg [31:0]  mem_imm
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_reg_write   <= 1'b0;
            mem_mem_to_reg  <= 1'b0;
            mem_mem_read    <= 1'b0;
            mem_mem_write   <= 1'b0;
            mem_mem_type    <= 3'b0;
            mem_branch      <= 1'b0;
            mem_br_type     <= 3'b0;
            mem_pc          <= 32'b0;
            mem_alu_result  <= 32'b0;
            mem_rdata2      <= 32'b0;
            mem_rd          <= 5'b0;
            mem_jal         <= 1'b0;
            mem_jalr        <= 1'b0;
            mem_rd_from_pc  <= 1'b0;
            mem_lui_sel     <= 1'b0;
            mem_auipc_sel   <= 1'b0;
            mem_imm         <= 32'b0;
        end else begin
            mem_reg_write   <= ex_reg_write;
            mem_mem_to_reg  <= ex_mem_to_reg;
            mem_mem_read    <= ex_mem_read;
            mem_mem_write   <= ex_mem_write;
            mem_mem_type    <= ex_mem_type;
            mem_branch      <= ex_branch;
            mem_br_type     <= ex_br_type;
            mem_pc          <= ex_pc;
            mem_alu_result  <= ex_alu_result;
            mem_rdata2      <= ex_rdata2;
            mem_rd          <= ex_rd;
            mem_jal         <= ex_jal;
            mem_jalr        <= ex_jalr;
            mem_rd_from_pc  <= ex_rd_from_pc;
            mem_lui_sel     <= ex_lui_sel;
            mem_auipc_sel   <= ex_auipc_sel;
            mem_imm         <= ex_imm;
        end
    end

endmodule

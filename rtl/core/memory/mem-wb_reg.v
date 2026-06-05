// mem-wb_reg.v
// MEM -> WB pipeline register
module mem_wb_reg(
    input  wire        clk,
    input  wire        rst,

    // From MEM stage
    input  wire        mem_reg_write,
    input  wire        mem_mem_to_reg,
    input  wire [4:0]  mem_rd,
    input  wire [31:0] mem_alu_result,
    input  wire [31:0] mem_read_data,
    input  wire [31:0] mem_pc,
    input  wire [31:0] mem_imm,
    input  wire        mem_rd_from_pc,
    input  wire        mem_lui_sel,
    input  wire        mem_auipc_sel,

    // To WB stage
    output reg         wb_reg_write,
    output reg         wb_mem_to_reg,
    output reg [4:0]   wb_rd,
    output reg [31:0]  wb_alu_result,
    output reg [31:0]  wb_mem_read_data,
    output reg [31:0]  wb_pc,
    output reg [31:0]  wb_imm,
    output reg         wb_rd_from_pc,
    output reg         wb_lui_sel,
    output reg         wb_auipc_sel
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_reg_write     <= 1'b0;
            wb_mem_to_reg    <= 1'b0;
            wb_rd            <= 5'b0;
            wb_alu_result    <= 32'b0;
            wb_mem_read_data <= 32'b0;
            wb_pc            <= 32'b0;
            wb_imm           <= 32'b0;
            wb_rd_from_pc    <= 1'b0;
            wb_lui_sel       <= 1'b0;
            wb_auipc_sel     <= 1'b0;
        end else begin
            wb_reg_write     <= mem_reg_write;
            wb_mem_to_reg    <= mem_mem_to_reg;
            wb_rd            <= mem_rd;
            wb_alu_result    <= mem_alu_result;
            wb_mem_read_data <= mem_read_data;
            wb_pc            <= mem_pc;
            wb_imm           <= mem_imm;
            wb_rd_from_pc    <= mem_rd_from_pc;
            wb_lui_sel       <= mem_lui_sel;
            wb_auipc_sel     <= mem_auipc_sel;
        end
    end

endmodule

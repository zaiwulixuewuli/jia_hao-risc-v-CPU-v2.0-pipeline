module write_back (
    input  wire [31:0] ex_pc,
    input  wire [31:0] ex_imm,
    input  wire [31:0] alu_result,
    input  wire [31:0] mem_read_data,
    input  wire        ex_mem_to_reg,
    input  wire        ex_rd_from_pc,
    input  wire        ex_lui_sel,
    input  wire        ex_auipc_sel,
    output wire [31:0] reg_write_data
);

    wire [31:0] alu_or_mem = (ex_mem_to_reg == 1'b1) ? mem_read_data : alu_result;
    wire [31:0] pc_plus_4   = ex_pc + 32'd4;
    wire [31:0] lui_data    = ex_imm;
    wire [31:0] auipc_data  = ex_pc + ex_imm;

    assign reg_write_data = (ex_lui_sel == 1'b1) ? lui_data :
                            (ex_auipc_sel == 1'b1) ? auipc_data :
                            (ex_rd_from_pc == 1'b1) ? pc_plus_4 : alu_or_mem;

endmodule

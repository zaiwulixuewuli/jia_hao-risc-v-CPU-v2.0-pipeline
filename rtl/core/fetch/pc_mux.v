module pc_mux (
    input  wire [31:0] current_pc,
    input  wire [31:0] ex_pc,
    input  wire [31:0] ex_imm,
    input  wire [31:0] alu_result,
    input  wire        alu_zero,
    input  wire        ex_branch,
    input  wire [2:0]  ex_br_type,
    input  wire        ex_jal,
    input  wire        ex_jalr,
    output reg  [31:0] pc_next,
    output reg         branch_taken
);

    always @(*) begin
        if (ex_branch) begin
            case (ex_br_type)
                3'b000:  branch_taken = alu_zero;          // BEQ
                3'b001:  branch_taken = ~alu_zero;         // BNE
                3'b100:  branch_taken = alu_result[0];     // BLT
                3'b101:  branch_taken = ~alu_result[0];    // BGE
                3'b110:  branch_taken = alu_result[0];     // BLTU
                3'b111:  branch_taken = ~alu_result[0];    // BGEU
                default: branch_taken = 1'b0;
            endcase
        end else begin
            branch_taken = 1'b0;
        end

        if (ex_jalr) begin
            pc_next = (alu_result & 32'hFFFFFFFE);
        end else if (ex_jal) begin
            pc_next = ex_pc + ex_imm;
        end else if (branch_taken) begin
            pc_next = ex_pc + ex_imm;
        end else begin
            pc_next = current_pc + 32'd4;
        end
    end

endmodule

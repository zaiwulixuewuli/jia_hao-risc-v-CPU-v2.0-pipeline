module hazard_handler(
    input  wire [4:0]  id_rs1, id_rs2,
    input  wire [4:0]  ex_rd,
    input  wire        ex_mem_read,
    input  wire        ex_branch, ex_jal, ex_jalr,
    input  wire        branch_taken,

    output wire        stall_pc,
    output wire        stall_if1_if2,
    output wire        stall_if2_id,
    output wire        stalldd,
    output wire        flush_if1_if2,
    output wire        flush_if2_id,
    output wire        flush_id_ex
);
    wire ex_load  = ex_mem_read && (ex_rd != 5'b0) &&
                    ((ex_rd == id_rs1) || (ex_rd == id_rs2));
    wire load_use = ex_load;                    // 仅 EX 级 Load 导致停顿
    wire branch_flush = branch_taken || ex_jal || ex_jalr;

    assign stall_pc      = load_use;
    assign stall_if1_if2 = load_use;
    assign stall_if2_id  = load_use;
    assign stalldd       = load_use;

    assign flush_if1_if2 = 1'b0;                // 永远不冲刷 IF1/IF2
    assign flush_if2_id  = branch_flush;        // 分支时冲刷 IF2/ID
    //assign flush_id_ex   = load_use || branch_flush; // Load-Use 或分支时冲刷 ID/EX
    assign flush_id_ex   = branch_flush; // Load-Use 或分支时冲刷 ID/EX
endmodule
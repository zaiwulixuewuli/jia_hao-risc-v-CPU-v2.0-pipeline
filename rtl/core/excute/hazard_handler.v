module hazard_handler (
    input  wire        clk,
    input  wire        rst,
    // ... 原有输入 ...
    input  wire [4:0]  id_rs1, id_rs2,
    input  wire [4:0]  ex_rd,
    input  wire        ex_mem_read,
    input  wire        ex_branch, ex_jal, ex_jalr,
    input  wire        branch_taken,
    input  wire        ex_mem_write,
    input  wire [31:0] ex_addr,
    input  wire        id_mem_read,
    input  wire [31:0] id_addr,
    // 输出
    output wire        stall_pc,
    output wire        stall_if1_if2,
    output wire        stall_if2_id,
    output wire        stalldd,
    output wire        stall_id_ex,
    output wire        flush_if1_if2,
    output wire        flush_if2_id,
    output wire        flush_id_ex
);

    wire ex_load  = ex_mem_read && (ex_rd != 5'b0) &&
                    ((ex_rd == id_rs1) || (ex_rd == id_rs2));
    wire load_use = ex_load;
    wire store_load_hazard = ex_mem_write && id_mem_read && (ex_addr == id_addr);
    wire need_stall = load_use || store_load_hazard;

    // 单周期脉冲生成
    reg stall_active;
    always @(posedge clk or posedge rst) begin
        if (rst) stall_active <= 1'b0;
        else if (need_stall && !stall_active) stall_active <= 1'b1;
        else if (stall_active) stall_active <= 1'b0;
    end

    assign stall_pc      = stall_active;
    assign stall_if1_if2 = stall_active;
    assign stall_if2_id  = stall_active;
    assign stalldd       = stall_active;
    assign stall_id_ex   = stall_active;

    wire branch_flush = branch_taken || ex_jal || ex_jalr;
    assign flush_if1_if2 = 1'b0;
    assign flush_if2_id  = branch_flush;
    assign flush_id_ex   = branch_flush;

endmodule
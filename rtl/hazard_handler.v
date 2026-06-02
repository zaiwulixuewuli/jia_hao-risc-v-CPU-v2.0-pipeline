// hazard_handler.v
module hazard_handler(

    //input  wire        clk,
    //input  wire        rst,

    // ID 阶段信息
    input  wire [4:0]  id_rs1,
    input  wire [4:0]  id_rs2,
    //input  wire        id_mem_read,

    // EX 阶段信息
    input  wire [4:0]  ex_rd,
    input  wire        ex_mem_read,
    input  wire        ex_branch,  
    input  wire        ex_jal,
    input  wire        ex_jalr,
    input  wire        branch_taken,

    // 控制输出 (全部改为 wire，由组合逻辑驱动)
    output wire        stall_pc,
    output wire        stall_if_id,
    output wire        stalldd, 
    output wire        flush_if_id,
    output wire        flush_id_ex
);

    // -------------------------------------------------------------------------
    // 1. 组合逻辑：冒险检测
    // -------------------------------------------------------------------------
    
    // 检测 load-use hazard (必须是组合逻辑)
    wire load_use_hazard = ex_mem_read && (ex_rd != 5'b0) && 
                           ((ex_rd == id_rs1) || (ex_rd == id_rs2));

    // 检测分支预测错误/跳转
    wire branch_flush = branch_taken || ex_jal || ex_jalr;

    // 检测先 branch 后 load (年轻指令是 load)
    //wire branch_then_load = ex_branch && id_mem_read;
    wire branch_then_load = 0;

  
    // Stall 信号：load_use 冲突 或 分支后保守等待 时触发
    // 注意：如果是组合逻辑直接给值，生效就是实时的，立刻阻塞下一个时钟沿的更新
    assign stall_pc    = load_use_hazard ;
    assign stall_if_id = load_use_hazard ;
    assign stalldd     = load_use_hazard; // 仅限 load-use

    // Flush 信号：
    // IF/ID 仅在分支时清空
    assign flush_if_id = branch_flush;
    // ID/EX 在分支时清空，或者在 load-use hazard 时插入气泡 (极其重要)
    assign flush_id_ex = branch_flush || load_use_hazard;

endmodule

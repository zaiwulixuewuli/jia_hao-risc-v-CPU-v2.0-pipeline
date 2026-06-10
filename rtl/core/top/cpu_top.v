module cpu_top(
    input wire clk,
    input wire rst
);

    // ----------------------------------------------------
    // 内部连线声明 (Wires)
    // ----------------------------------------------------
    wire [31:0] pc;
    wire [31:0] inst;
    // IF/ID pipeline register outputs
    wire [31:0] pc_ifid;
    wire [31:0] inst_ifid;
    
    wire [4:0]  rs1, rs2, rd;
    wire [31:0] imm;
    wire        alu_src;
    wire        reg_we;
    wire [3:0]  alu_op;
    wire        branch;
    wire [2:0]  br_type;
    wire        branch_taken;
    wire [31:0] pc_next;
    wire [31:0] pc_if2;
    wire [31:0] reg_data1, reg_data2;
    wire [31:0] alu_operand_a;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;
    wire        alu_zero;

    // EX/MEM -> MEM stage signals
    wire        mem_reg_write;
    wire        mem_mem_to_reg;
    wire        mem_mem_read;
    wire        mem_mem_write;
    wire [2:0]  mem_mem_type;
    wire        mem_branch;
    wire [2:0]  mem_br_type;
    wire [31:0] mem_pc;
    wire [31:0] mem_alu_result;
    wire [31:0] mem_rdata2;
    wire [4:0]  mem_rd;
    wire        mem_jal;
    wire        mem_jalr;
    wire        mem_rd_from_pc;
    wire        mem_lui_sel;
    wire        mem_auipc_sel;
    wire [31:0] mem_imm;

    // MEM/WB -> WB stage signals
    wire        wb_reg_write;
    wire        wb_mem_to_reg;
    wire [4:0]  wb_rd;
    wire [31:0] wb_alu_result;
    wire [31:0] wb_mem_read_data;
    wire [31:0] wb_pc;
    wire [31:0] wb_imm;
    wire        wb_rd_from_pc;
    wire        wb_lui_sel;
    wire        wb_auipc_sel;
    
    // 内存相关信号
    wire        mem_read;
    wire        mem_we;
    wire [2:0]  mem_type;
    wire        mem_to_reg;
    wire [31:0] mem_read_data;
    wire [31:0] reg_write_data;
    
    // J 类指令相关信号
    wire        jal;
    wire        jalr;
    wire        rd_from_pc;
    
    // Hazard / pipeline control signals
    wire stall_pc;
    wire stall_if1_if2;
    wire stall_if2_id;
    wire stall_id_ex;            // 新增：ID/EX 停顿信号
    wire flush_if1_if2;
    wire flush_if2_id;
    wire flush_id_ex;
    wire stalldd;
    
    wire        lui_sel;
    wire        auipc_sel;

    // ========== 新增信号：store-load 精确地址冲突检测 ==========
    wire        ex_mem_write;
    wire [31:0] ex_addr;
    wire [31:0] id_addr;

    // ----------------------------------------------------
    // 1. 取指阶段 (Fetch)
    // ----------------------------------------------------
    pc_reg u_pc_reg (
        .clk(clk),
        .rst(rst),
        .stall_pc(stall_pc),
        .pc_next(pc_next),
        .pc(pc)
    );

    rom u_rom (
        .addr(pc),
        .inst(inst),
        .clk(clk),
        .stall(stall_if1_if2)
    );

    if1_if2_reg u_if1_if2 (
        .clk(clk), .rst(rst),
        .stall(stall_if1_if2),
        .flush(flush_if1_if2),
        .pc_in(pc),
        .pc_out(pc_if2)
    );

    if2_id_reg u_if2_id (
        .clk(clk),
        .rst(rst),
        .stall_if2_id(stall_if2_id),
        .flush_if2_id(flush_if2_id),
        .pc_in(pc_if2),
        .inst_in(inst),
        .pc_out(pc_ifid),
        .inst_out(inst_ifid)
    );

    // ----------------------------------------------------
    // 2. 译码阶段 (Decode)
    // ----------------------------------------------------
    decoder u_decoder (
        .inst(inst_ifid),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm(imm),
        .alu_src(alu_src),
        .reg_we(reg_we),
        .alu_op(alu_op),
        .branch(branch),
        .br_type(br_type),
        .mem_read(mem_read),
        .mem_we(mem_we),
        .mem_type(mem_type),
        .mem_to_reg(mem_to_reg),
        .jal(jal),
        .jalr(jalr),
        .rd_from_pc(rd_from_pc),
        .lui_sel(lui_sel),
        .auipc_sel(auipc_sel)
    );

    // ----------------------------------------------------
    // 3. 寄存器堆 (Register File)
    // ----------------------------------------------------
    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .we(wb_reg_write && (wb_rd != 5'b0)),
        .waddr(wb_rd),
        .wdata(reg_write_data),
        .raddr1(rs1),
        .rdata1(reg_data1),
        .raddr2(rs2),
        .rdata2(reg_data2)
    );

    // ========== ID 级前向通路（用于地址计算） ==========
    wire [31:0] forward_rs1;
    wire mem_match_rs1_id = mem_reg_write && (mem_rd != 5'b0) && (mem_rd == rs1);
    wire wb_match_rs1_id  = wb_reg_write  && (wb_rd  != 5'b0) && (wb_rd  == rs1) && !mem_match_rs1_id;
    assign forward_rs1 = mem_match_rs1_id ? mem_alu_result :
                         (wb_match_rs1_id ? (wb_mem_to_reg ? wb_mem_read_data : wb_alu_result) : reg_data1);
    assign id_addr = forward_rs1 + imm;

    // ------------------------------
    // ID/EX pipeline register
    // ------------------------------
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    wire        ex_mem_read;
    wire [2:0]  ex_mem_type;
    wire        ex_branch;
    wire [2:0]  ex_br_type;
    wire [3:0]  ex_alu_op;
    wire        ex_alu_src;
    wire [31:0] ex_pc;
    wire [31:0] ex_rdata1;
    wire [31:0] ex_rdata2;
    wire [31:0] ex_imm;
    wire [4:0]  ex_rs1;
    wire [4:0]  ex_rs2;
    wire [4:0]  ex_rd;
    wire        ex_jal;
    wire        ex_jalr;
    wire        ex_rd_from_pc;
    wire        ex_lui_sel;
    wire        ex_auipc_sel;

    id_ex_reg u_id_ex (
        .clk(clk),
        .rst(rst),
        .flush_id_ex(flush_id_ex),
        .stall_id_ex(stall_id_ex),      // 使用 stall_id_ex

        .id_reg_write(reg_we),
        .id_mem_to_reg(mem_to_reg),
        .ex_reg_write(ex_reg_write),
        .ex_mem_to_reg(ex_mem_to_reg),

        .id_jal(jal),
        .id_jalr(jalr),
        .id_rd_from_pc(rd_from_pc),
        .id_lui_sel(lui_sel),
        .id_auipc_sel(auipc_sel),
        .ex_jal(ex_jal),
        .ex_jalr(ex_jalr),
        .ex_rd_from_pc(ex_rd_from_pc),
        .ex_lui_sel(ex_lui_sel),
        .ex_auipc_sel(ex_auipc_sel),

        .id_mem_read(mem_read),
        .id_mem_write(mem_we),
        .id_branch(branch),
        .id_mem_type(mem_type),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_branch(ex_branch),
        .ex_mem_type(ex_mem_type),
        .id_br_type(br_type),
        .ex_br_type(ex_br_type),

        .id_alu_op(alu_op),
        .id_alu_src(alu_src),
        .ex_alu_op(ex_alu_op),
        .ex_alu_src(ex_alu_src),

        .id_pc(pc_ifid),
        .id_rdata1(reg_data1),
        .id_rdata2(reg_data2),
        .id_imm(imm),
        .id_rs1(rs1),
        .id_rs2(rs2),
        .id_rd(rd),

        .ex_pc(ex_pc),
        .ex_rdata1(ex_rdata1),
        .ex_rdata2(ex_rdata2),
        .ex_imm(ex_imm),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .ex_rd(ex_rd)
    );

    // ----------------------------------------------------
    // 4. 执行阶段 (Execute)
    // ----------------------------------------------------
    wire [31:0] ex_rdata1_fwd;
    wire [31:0] ex_rdata2_fwd;

    forward_passing u_forward (
        .ex_rdata1_in(ex_rdata1),
        .ex_rdata2_in(ex_rdata2),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .mem_reg_write(mem_reg_write),
        .mem_rd(mem_rd),
        .mem_wb_data(mem_alu_result),
        .mem_mem_read(mem_mem_read),
        .mem_read_data(mem_read_data),
        .wb_reg_write(wb_reg_write),
        .wb_rd(wb_rd),
        .wb_wb_data(wb_mem_to_reg ? wb_mem_read_data : wb_alu_result),
        .ex_rdata1_out(ex_rdata1_fwd),
        .ex_rdata2_out(ex_rdata2_fwd)
    );
    assign alu_operand_a = (ex_auipc_sel == 1'b1) ? ex_pc: ex_rdata1_fwd;//选择数据，如果是1那就是auipc指令。嗯。
    assign alu_operand_b = (ex_alu_src == 1'b1) ? ex_imm : ex_rdata2_fwd;//选择数据，如果是1那就是立即数

    alu u_alu (
        .a(alu_operand_a),
        .b(alu_operand_b),
        .alu_op(ex_alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    assign ex_addr = alu_result;

    // =========================================================================
    // 5. 内存阶段 (Memory Access)
    // =========================================================================
    ex_mem_reg u_ex_mem_reg (
        .clk(clk),
        .rst(rst),
        .ex_reg_write(ex_reg_write),
        .ex_mem_to_reg(ex_mem_to_reg),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_mem_type(ex_mem_type),
        .ex_branch(ex_branch),
        .ex_br_type(ex_br_type),
        .ex_pc(ex_pc),
        .ex_alu_result(alu_result),
        .ex_rdata2(ex_rdata2_fwd),
        .ex_rd(ex_rd),
        .ex_jal(ex_jal),
        .ex_jalr(ex_jalr),
        .ex_rd_from_pc(ex_rd_from_pc),
        .ex_lui_sel(ex_lui_sel),
        .ex_auipc_sel(ex_auipc_sel),
        .ex_imm(ex_imm),
        .mem_reg_write(mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .mem_mem_read(mem_mem_read),
        .mem_mem_write(mem_mem_write),
        .mem_mem_type(mem_mem_type),
        .mem_branch(mem_branch),
        .mem_br_type(mem_br_type),
        .mem_pc(mem_pc),
        .mem_alu_result(mem_alu_result),
        .mem_rdata2(mem_rdata2),
        .mem_rd(mem_rd),
        .mem_jal(mem_jal),
        .mem_jalr(mem_jalr),
        .mem_rd_from_pc(mem_rd_from_pc),
        .mem_lui_sel(mem_lui_sel),
        .mem_auipc_sel(mem_auipc_sel),
        .mem_imm(mem_imm)
    );

    mem_io u_mem_io (
        .clk(clk),
        .mem_we(mem_mem_write),
        .mem_type(mem_mem_type),
        .addr(mem_alu_result),
        .write_data(mem_rdata2),
        .read_data(mem_read_data)
    );

    mem_wb_reg u_mem_wb_reg (
        .clk(clk),
        .rst(rst),
        .mem_reg_write(mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .mem_rd(mem_rd),
        .mem_alu_result(mem_alu_result),
        .mem_read_data(mem_read_data),
        .mem_pc(mem_pc),
        .mem_imm(mem_imm),
        .mem_rd_from_pc(mem_rd_from_pc),
        .mem_lui_sel(mem_lui_sel),
        .mem_auipc_sel(mem_auipc_sel),
        .wb_reg_write(wb_reg_write),
        .wb_mem_to_reg(wb_mem_to_reg),
        .wb_rd(wb_rd),
        .wb_alu_result(wb_alu_result),
        .wb_mem_read_data(wb_mem_read_data),
        .wb_pc(wb_pc),
        .wb_imm(wb_imm),
        .wb_rd_from_pc(wb_rd_from_pc),
        .wb_lui_sel(wb_lui_sel),
        .wb_auipc_sel(wb_auipc_sel)
    );

    // =========================================================================
    // 6. 写回阶段 (Write Back)
    // =========================================================================
    write_back u_write_back (
        .ex_pc(wb_pc),
        .ex_imm(wb_imm),
        .alu_result(wb_alu_result),
        .mem_read_data(wb_mem_read_data),
        .ex_mem_to_reg(wb_mem_to_reg),
        .ex_rd_from_pc(wb_rd_from_pc),
        .ex_lui_sel(wb_lui_sel),
        .ex_auipc_sel(wb_auipc_sel),
        .reg_write_data(reg_write_data)
    );

    // =========================================================================
    // 7. PC 更新逻辑
    // =========================================================================
    pc_mux u_pc_mux (
        .current_pc(pc),
        .ex_pc(ex_pc),
        .ex_imm(ex_imm),
        .alu_result(alu_result),
        .alu_zero(alu_zero),
        .ex_branch(ex_branch),
        .ex_br_type(ex_br_type),
        .ex_jal(ex_jal),
        .ex_jalr(ex_jalr),
        .pc_next(pc_next),
        .branch_taken(branch_taken)
    );

    // =========================================================================
    // 8. 冒险处理单元 - 支持 store-load 精确地址冲突，包含 stall_id_ex 输出
    // =========================================================================
    hazard_handler u_hazard (
        .rst(rst),
        .clk(clk),
        .id_rs1(rs1),
        .id_rs2(rs2),
        .ex_rd(ex_rd),
        .ex_mem_read(ex_mem_read),
        .ex_branch(ex_branch),
        .ex_jal(ex_jal),
        .ex_jalr(ex_jalr),
        .branch_taken(branch_taken),

        .ex_mem_write(ex_mem_write),
        .ex_addr(ex_addr),
        .id_mem_read(mem_read),
        .id_addr(id_addr),

        .stall_pc(stall_pc),
        .stall_if1_if2(stall_if1_if2),
        .stall_if2_id(stall_if2_id),
        .stalldd(stalldd),
        .stall_id_ex(stall_id_ex),   // 新增连接
        .flush_if1_if2(flush_if1_if2),
        .flush_if2_id(flush_if2_id),
        .flush_id_ex(flush_id_ex)
    );

endmodule
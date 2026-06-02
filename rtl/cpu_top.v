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
    
    wire [31:0] reg_data1, reg_data2;
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
    wire        mem_read;      // 【修复】：补全顶层译码阶段的读使能信号
    wire        mem_we;        // 内存写使能 (来自译码器)
    wire [2:0]  mem_type;      // 内存读写宽度类型 (来自译码器)
    wire        mem_to_reg;    // 写回寄存器数据源选择 (来自译码器)
    wire [31:0] mem_read_data; // 从内存读出的数据
    wire [31:0] reg_write_data; // 实际写回寄存器的数据（ALU结果或内存数据）
    
    // J 类指令相关信号
    wire        jal;           // JAL 指令标志
    wire        jalr;          // JALR 指令标志
    wire        rd_from_pc;    // 寄存器数据源选择：1 = PC+4（用于 JAL/JALR 的返回地址）

    // Hazard / pipeline control signals
    wire stall_pc;
    wire stall_if_id;
    wire flush_if_id;
    wire flush_id_ex;
    
    // LUI/AUIPC 指令相关信号
    wire        lui_sel;       // LUI 指令标志
    wire        auipc_sel;     // AUIPC 指令标志

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
        .inst(inst)
    );

    // IF-ID pipeline register: 将取指阶段的 PC/INST 保持到译码阶段
    if_id_reg u_if_id (
        .clk(clk),
        .rst(rst),
        .stall_if_id(stall_if_id),
        .flush_if_id(flush_if_id),
        .pc_in(pc),
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
        .mem_read(mem_read),   // 【修复】：对齐了原模块未引出的读能使引脚
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
    // 3. 寄存器堆堆叠 (Register File)
    // ----------------------------------------------------
    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .we(wb_reg_write && (wb_rd != 5'b0)),
        .waddr(wb_rd),
        .wdata(reg_write_data), // 核心：把 ALU 结果或内存数据写回 (来自 WB stage)
        .raddr1(rs1),
        .rdata1(reg_data1),
        .raddr2(rs2),
        .rdata2(reg_data2)
    );

    // ------------------------------
    // ID/EX pipeline register 和相关信号
    // ------------------------------
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    wire        ex_mem_read;
    wire        ex_mem_write;
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

        // WB 控制信号
        .id_reg_write(reg_we),
        .id_mem_to_reg(mem_to_reg),
        .ex_reg_write(ex_reg_write),
        .ex_mem_to_reg(ex_mem_to_reg),

        // J 类型与写回相关信号
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

        // MEM 控制信号
        .id_mem_read(mem_read), // 【修复】：连线使用顶层声明好的 mem_read
        .id_mem_write(mem_we),
        .id_branch(branch),
        .id_mem_type(mem_type),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_branch(ex_branch),
        .ex_mem_type(ex_mem_type),
        .id_br_type(br_type),
        .ex_br_type(ex_br_type),

        // EX 控制信号
        .id_alu_op(alu_op),
        .id_alu_src(alu_src),
        .ex_alu_op(ex_alu_op),
        .ex_alu_src(ex_alu_src),

        // 数据与寄存器编号
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
    // 4. 执行阶段 (Execute) 与 核心控制 MUX
    // ----------------------------------------------------
    // 前向通路：优先从 MEM 转发，其次从 WB 转发，最后使用寄存器堆读出的原始值
    wire [31:0] ex_rdata1_fwd;
    wire [31:0] ex_rdata2_fwd;

    // 前向通路的源信号：来自 EX/MEM 与 MEM/WB pipeline register 的输出
    wire mem_forward_enable = mem_reg_write && !mem_mem_to_reg;
    wire [31:0] mem_forward_data = mem_alu_result;
    wire wb_forward_enable = wb_reg_write;
    wire [31:0] wb_forward_data = wb_mem_to_reg ? wb_mem_read_data : wb_alu_result;

    forward_passing u_forward (
        .ex_rdata1_in(ex_rdata1),
        .ex_rdata2_in(ex_rdata2),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .mem_reg_write(mem_forward_enable),
        .mem_rd(mem_rd),
        .mem_wb_data(mem_forward_data),
        .wb_reg_write(wb_forward_enable),
        .wb_rd(wb_rd),
        .wb_wb_data(wb_forward_data),
        .ex_rdata1_out(ex_rdata1_fwd),
        .ex_rdata2_out(ex_rdata2_fwd)
    );

    // 核心数据选择选择器
    assign alu_operand_b = (ex_alu_src == 1'b1) ? ex_imm : ex_rdata2_fwd;

    alu u_alu (
        .a(ex_rdata1_fwd),
        .b(alu_operand_b),
        .alu_op(ex_alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );
    
    // =========================================================================
    // 5. 内存阶段 (Memory Access)
    // =========================================================================
    // EX -> MEM register: 把 EX 的输出锁存在 MEM-stage 可见
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
        .ex_rdata2(ex_rdata2_fwd), // 【修复点】：应当传递经过 Forward 之后的最新数据，避免 Store 脏数据冒险
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

    // MEM stage memory access 使用 EX/MEM 中的地址与写数据
    mem_io u_mem_io (
        .clk(clk),
        .mem_we(mem_mem_write),
        .mem_type(mem_mem_type),
        .addr(mem_alu_result),
        .write_data(mem_rdata2),
        .read_data(mem_read_data)
    );

    // MEM -> WB register: 把 MEM 的结果锁存到 WB 阶段
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
    // 6. 写回阶段 (Write Back) - 数据选择器
    // 支持：Load/Store, JAL/JALR, LUI/AUIPC
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
    // 7. PC 更新逻辑（支持条件分支、无条件跳转、间接跳转）
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

    // Hazard unit: 处理 load-use、branch-then-load 的 stall，以及分支/跳转时的 flush
    hazard_handler u_hazard (
        .id_rs1(rs1),
        .id_rs2(rs2),
        .ex_rd(ex_rd),
        .ex_mem_read(ex_mem_read),
        .ex_branch(ex_branch),
        .ex_jal(ex_jal),
        .ex_jalr(ex_jalr),
        .branch_taken(branch_taken),
        .stall_pc(stall_pc),
        .stall_if_id(stall_if_id),
        .flush_if_id(flush_if_id),
        .flush_id_ex(flush_id_ex)
    );

endmodule

# jia_hao-risc-v-CPU-pipeline



## v2.1 更新说明 / v2.1 Update Note

Based on the v2.0 5‑stage pipeline, v2.1 upgrades the CPU core to a **6‑stage pipeline** (IF1 → IF2 → ID → EX → MEM → WB).
基于 v2.0 的五级流水线架构，v2.1 将 CPU 内核升级为 **六级流水线**（IF1 → IF2 → ID → EX → MEM → WB）。

Both instruction memory (ROM) and data memory (DMEM) have been fully migrated to **synchronous read interfaces**.
指令存储器（ROM）与数据存储器（DMEM）已全面迁移至 **同步读取接口**。

This lays a critical foundation for future integration of I‑Cache and D‑Cache.
这为未来集成 I‑Cache 与 D‑Cache 奠定了关键基础。

**Write Forwarding** logic has been added to completely eliminate Store‑Load data hazards.
新增了 **写转发（Write Forwarding）** 逻辑，以彻底消除 Store‑Load 数据冒险。

A hidden defect where the synchronous ROM output was not frozen during pipeline stalls has been fixed.
修复了流水线停顿时同步 ROM 输出未冻结的隐患。

This guarantees correct fetch alignment under any stall or flush condition.
这确保了在任何停顿或冲刷条件下取指始终对齐。

Rigorously verified with a comprehensive stress‑test, v2.1 now stably supports correct execution of all 37 RV32I integer instructions.
经地狱级压力测试验证，v2.1 现已稳定支持 RV32I 全部 37 条整数指令的正确执行。
2026.6.5







以嘉豪之名，我们搭建了第一个 5 级流水线 RISC-V CPU。
*In the name of Jia_hao, we have built our first 5-stage pipelined RISC-V CPU.*

本项目是一个使用 Verilog HDL 编写的简易单核五级流水线 CPU 核心。
*This project is a simple single-core 5-stage pipelined CPU core written in Verilog HDL.*

在先前 v1.0 单周期版本的基础上，v2.0 版本升级为了经典的 **5 级流水线架构**。该版本引入了数据前推（Forwarding）与冲突检测处理（Hazard Handling）机制，用以解决流水线执行中的数据冲突与控制冲突，能够在更高的时钟频率下稳定运行。
*Based on the single-cycle v1.0 version, v2.0 upgrades the core to a classic **5-stage pipeline architecture**. This version introduces data forwarding (bypassing) and hazard detection & handling mechanisms to resolve data and control hazards, enabling stable execution at higher clock frequencies.*

本设计实现了 RISC-V RV32I 基础整数指令集（排除系统调用和环境指令，共 37 条指令），适合用于计算机体系结构、流水线冲突处理机制的学习与数字系统设计实践。
*This design implements the RISC-V RV32I base integer instruction set (excluding system calls and environmental instructions, with 37 instructions in total). It is suitable for learning computer architecture, pipeline hazard resolution, and practicing digital logic design.*

---

## 1. 设计特性 / Design Features

* **核心架构 / Core Architecture**：单核 5 级流水线 (IF - 译码 ID - 执行 EX - 访存 MEM - 写回 WB)
*Single-core 5-stage pipeline (Fetch, Decode, Execute, Memory, Write-back)*
* **硬件描述语言 / Hardware Description Language**：Verilog HDL
* **冲突解决机制 / Hazard Resolution**：
  * **数据冲突前推 / Data Forwarding**：通过前推单元（`forward-passing.v`），将 EX/MEM 和 MEM/WB 阶段的数据直接旁路传递至 ALU 输入端，最大限度减少数据相关导致的流水线暂停。
  *Data Forwarding: The forwarding unit bypasses data from EX/MEM and MEM/WB stages directly to ALU inputs to minimize pipeline stalls due to data dependencies.*
  * **流水线暂停与冲刷 / Pipeline Stall & Flush**：通过冲突处理器（`hazard_handler.v`）检测 Load-Use 等无法通过前推解决的数据冲突（触发 Stall）以及分支/跳转指令引起的控制冲突（触发 Flush）。
  *Pipeline Stall & Flush: The hazard handler detects data hazards that cannot be resolved via forwarding (e.g., Load-Use, triggering Stall) and control hazards from branches/jumps (triggering Flush).*
* **指令集架构 / Instruction Set Architecture (ISA)**：RISC-V RV32I 基础整数指令集（共 37 条，不包含系统指令如 `ECALL`、`EBREAK` 及 `FENCE`）
*RISC-V RV32I base integer instruction set (37 instructions in total, excluding system instructions such as `ECALL`, `EBREAK`, and `FENCE`)*

---

## 2. 目录结构 / Directory Structure

项目目录结构如下，所有 Verilog 源代码均存放于 `rtl/` 文件夹中：
*The project directory structure is as follows, with all Verilog source code located in the `rtl/` folder:*

```text
.
├── rtl/                    # 硬件描述语言源代码 (RTL) / Hardware Description Language Source Code
│   ├── alu.v               # 算术逻辑单元 / Arithmetic Logic Unit
│   ├── cpu_top.v           # CPU 顶层模块，负责连接所有子模块 / CPU Top Module, connects all sub-modules
│   ├── decoder.v           # 译码器与立即数产生模块 / Decoder & Immediate Generator
│   ├── dmem.v              # 数据存储器模块 / Data Memory Module
│   ├── ex-mem_reg.v        # EX/MEM 流水线寄存器 / EX/MEM Pipeline Register
│   ├── forward-passing.v   # 数据前推（旁路）模块 / Forwarding (Bypassing) Unit
│   ├── hazard_handler.v    # 冲突检测与处理模块 / Hazard Detection & Handling Unit
│   ├── id-ex reg.v         # ID/EX 流水线寄存器 / ID/EX Pipeline Register
│   ├── if-id reg.v         # IF/ID 流水线寄存器 / IF/ID Pipeline Register
│   ├── mem-io.v            # 存储器与输入输出控制接口 / Memory & I/O Interface Module
│   ├── mem-wb_reg.v        # MEM/WB 流水线寄存器 / MEM/WB Pipeline Register
│   ├── pc_mux.v            # 程序计数器多路选择器 / Program Counter Multiplexer
│   ├── pc_reg.v            # 程序计数器寄存器 / Program Counter Register
│   ├── regfile.v           # 通用寄存器堆模块 / Register File Module
│   ├── rom.v               # 只读指令存储器模块 / Read-Only Instruction Memory Module
│   └── write_back.v        # 写回级多路选择器 / Write-back Multiplexer Stage
├── tb/                     # 测试平台文件夹 / Testbench Folder
│   └── tb_cpu.v            # CPU 仿真测试激励文件 / CPU Simulation Testbench File
├── LICENSE                 # 开源协议文件 / Open Source License File
└── README.md               # 项目说明文档 / Project README Document
```

---

## 3. 模块说明 / Module Descriptions

相比 v1.0 版本，v2.0 增加了流水线寄存器和冲突控制逻辑：
*Compared to v1.0, v2.0 introduces pipeline registers and hazard control logic:*

* **流水线寄存器 / Pipeline Registers (`if-id reg.v`, `id-ex reg.v`, `ex-mem_reg.v`, `mem-wb_reg.v`)**
在相邻的流水线阶段之间传递指令、控制信号和中间运算结果，实现了在每个时钟上升沿推进流水线。支持由冲突检测逻辑控制的保持（Stall）和清除（Flush）操作。
*Pass instructions, control signals, and intermediate execution results between adjacent pipeline stages to advance the pipeline on every rising clock edge. Supports Stall and Flush operations controlled by the hazard detection logic.*

* **数据前推模块 / Forwarding Unit (`forward-passing.v`)**
检测当前译码指令的数据源（RS1/RS2）与后续阶段（EX/MEM、MEM/WB）写回的目标寄存器（RD）之间的相关性。如果存在冲突，则直接将后续阶段的数据前推至 ALU 输入端，避免产生不必要的流水线暂停。
*Detects hazards between the source registers (RS1/RS2) of the currently decoded instruction and the destination registers (RD) of instructions in the later stages (EX/MEM, MEM/WB). It forwards the data directly to the ALU inputs to avoid unnecessary pipeline stalls.*

* **冲突检测与处理模块 / Hazard Handler (`hazard_handler.v`)**
负责监控流水线中的各种冲突状态：
  1. 当遇到 "Load-Use" 数据冲突时，生成 Stall 信号暂停前端流水线，并向 `id-ex` 寄存器插入气泡（Bubble）。
  2. 当遇到分支跳转或无条件跳转指令成功跳转时，生成 Flush 信号清除已经错误读入的指令。
*Monitors various hazards in the pipeline:*
*1. Upon detecting a "Load-Use" data hazard, it generates Stall signals to pause the front stages and inserts a bubble into the `id-ex` register.*
*2. Upon a taken branch or unconditional jump, it generates Flush signals to discard misfetched instructions.*

* **程序计数器选择器 / PC Multiplexer (`pc_mux.v`)**
根据当前流水线的跳转与分支判断结果，从 PC+4、分支目标地址或跳转目标地址中选择下一周期正确的取指地址。
*Selects the correct next instruction fetch address from PC+4, branch target, or jump target based on the jump and branch outcome of the pipeline.*

* **存储器接口 / Memory-I/O Interface (`mem-io.v`)**
实现 CPU 核与数据存储器（dmem）以及潜在外设之间的数据通路转换，规范流水线访存阶段的数据读写。
*Coordinates data transactions between the CPU core, data memory, and potentially external I/O devices, structuring data reads and writes in the memory stage.*

* **写回控制 / Write-back Stage (`write_back.v`)**
在流水线的最后一级进行多路选择，将 ALU 计算结果、存储器读取数据或 PC+4/PC+立即数等正确的数据路由回寄存器堆。
*Acts as a multiplexer in the final pipeline stage, routing the correct write-back data (ALU result, memory data, or PC targets) back to the register file.*

---

## 4. 仿真与验证 / Simulation and Verification

本项目的流水线架构兼容主流 EDA 和编译仿真工具，可以使用与之前相同的方法进行验证。
*The pipelined architecture of this project is compatible with mainstream EDA and simulation tools, and can be verified using the same methods as before.*

### 推荐工具链 / Recommended Toolchain

* **开源方案 / Open-source Solution**：Icarus Verilog (编译/Compilation) + GTKWave (波形查看/Waveform Viewer)
* **商业或集成方案 / Commercial or Integrated Solutions**：Vivado / ModelSim / Quartus

### 简易仿真步骤（以 Icarus Verilog 为例）/ Simple Simulation Steps (Taking Icarus Verilog as an Example)

在终端中进入项目根目录，运行以下命令：
*Enter the project root directory in the terminal and run the following commands:*

```bash
# 1. 编译所有 RTL 源文件及仿真文件
# Compile all RTL source files and simulation files
# 注：若文件名中存在空格，请确保在命令行中进行了正确转义或用双引号包裹
iverilog -o cpu_sim rtl/*.v tb/tb_cpu.v

# 2. 运行仿真（通常仿真文件会配置输出 .vcd 波形文件）
# Run the simulation (the simulation file is typically configured to output a .vcd waveform file)
vvp cpu_sim

# 3. 使用 GTKWave 打开波形图观察流水线执行与冲突处理过程
# Open the waveform file with GTKWave to observe pipelined execution and hazard handling
gtkwave wave.vcd
```
```

# jia_hao-risc-v-CPU-pipeline

以嘉豪之名，我们成功搭建并迭代了高性能的 **6 级流水线** RISC-V CPU。
*In the name of Jia_hao, we have built and iterated a high-performance **6-stage pipelined** RISC-V CPU.*

本项目是一个使用 Verilog HDL 编写的单核处理器核心，完整实现了 RISC-V RV32I 基础整数指令集（共 37 条指令，不含系统调用）。项目历经单周期、5 级流水线，现已演进至具备全同步存储接口、层次化目录结构的 6 级流水线架构，是深入学习计算机体系结构、流水线冲突控制（Stall/Flush/Forwarding）以及高性能微处理器研发的绝佳硬核实践。
*This project is a single-core CPU written in Verilog HDL, implementing the 37 core instructions of the RISC-V RV32I ISA. Evolving into a 6-stage pipeline with synchronous memory interfaces and a strictly layered directory structure, it serves as an excellent reference for studying pipeline hazards and advanced microprocessor design.*

---

## 🚀 v2.1 核心特性与技术升级 / v2.1 Key Upgrades

> 💡 **当前最新稳定版本 (Current Stable Version): v2.1** | *Release Date: 2026.06.05*

* **纵向切分：全新的 6 级流水线架构 / 6-Stage Pipeline**
基于先前的 5 级架构，核心进一步升级为 6 级流水线：**IF1（取指1） → IF2（取指2） → ID（译码） → EX（执行） → MEM（访存） → WB（写回）**。
*The core has been upgraded to a 6-stage pipeline to achieve higher clock frequencies.*
* **全同步存储接口 / Synchronous Memory Interfaces**
指令存储器（ROM）与数据存储器（DMEM）全面迁移至**同步读取接口（Synchronous Read）**。这一重构解决了异步读难以在真实 FPGA/ASIC 上物理实现的缺陷，并为未来集成 **I-Cache（指令缓存）** 与 **D-Cache（数据缓存）** 奠定了关键基础。
*Both ROM and DMEM now use synchronous read interfaces, laying a critical foundation for future integration of I-Cache and D-Cache.*
* **硬核冲突消除：写转发机制 / Write Forwarding**
在数据通路中新增了写转发（Write Forwarding）逻辑，彻底消除了硬件底层的 Store-Load 数据冒险。
*Added Write Forwarding logic to completely eliminate store-load data hazards.*
* **精确对齐控制：冻结隐患修复 / Stall & Flush Precision**
修复了旧版本中流水线停顿时同步 ROM 输出未冻结的隐藏缺陷。通过重构控制逻辑，确保了在任何地狱级压力测试的 Stall（暂停）或 Flush（冲刷）组合条件下，取指地址（PC）与机器码输出始终**绝对对齐**。
*Fixed a defect where synchronous ROM output was not frozen during stalls, guaranteeing correct fetch alignment under any extreme stall/flush conditions.*

---

## 1. 目录结构 / Directory Structure

所有核心硬件描述语言（RTL）源文件已按流水线阶段进行标准模块化分层：
*All RTL source files are structured into decoupled directories corresponding to pipeline stages:*

```text
rtl/core
├─ fetch/                       # 1 & 2. 取指阶段 / Fetch Stage (IF1 & IF2)
│  ├─ pc_reg.v                  # 程序计数器 / Program Counter Register
│  ├─ pc_mux.v                  # PC 多路选择器 (分支/跳转目标计算)
│  ├─ rom.v                     # 指令存储器 (全同步读取接口)
│  ├─ if1-if2_reg.v             # IF1 -> IF2 流水线寄存器
│  └─ if2-id reg.v              # IF2 -> ID 流水线寄存器
│
├─ decode/                      # 3. 译码阶段 / Decode Stage (ID)
│  ├─ decoder.v                 # 译码器与立即数产生模块
│  └─ regfile.v                 # 通用寄存器堆 (x0 硬编码为 0)
│
├─ excute/                      # 4. 执行阶段 / Execute Stage (EX)
│  ├─ alu.v                     # 算术逻辑单元 / ALU
│  ├─ forward-passing.v         # 数据前推（旁路）模块
│  ├─ hazard_handler.v          # 冲突检测与处理单元 (Stall/Flush 核心控制)
│  └─ id-ex reg.v               # ID -> EX 流水线寄存器
│
├─ memory/                      # 5. 访存阶段 / Memory Stage (MEM)
│  ├─ dmem.v                    # 数据存储器 (全同步读取接口)
│  ├─ mem-io.v                  # 存储器与输入输出控制接口
│  ├─ ex-mem_reg.v              # EX -> MEM 流水线寄存器
│  └─ mem-wb_reg.v              # MEM -> WB 流水线寄存器
│
├─ writeback/                   # 6. 写回阶段 / Write-back Stage (WB)
│  └─ write_back.v              # 写回级多路选择数据路由
│
└─ top/                         # 顶层架构 / Top Architecture
   └─ cpu_top.v                 # CPU 顶层模块 (完成上述所有子模块的互连例化)

```

---

## 2. 核心模块设计说明 / Module Descriptions

### 流水线控制核心 / Pipeline Control Cores

* **冲突检测与处理模块 / Hazard Handler (`excute/hazard_handler.v`)**
流水线的“安全大脑”。实时监控全级数据相关性：
1. **Load-Use 冲突**：自动触发 Stall 信号冻结前端流水线（PC 与取指寄存器保持），并向后级流水线插入气泡（Bubble）。
2. **控制冲突（分支跳转）**：静态预测失败时，瞬间生成 Flush 信号，精确清空已经读入流水线的错误指令，同时配合 `fetch/pc_mux.v` 修正取指路径。
*Monitors pipeline hazards. It inserts stalls/bubbles for Load-Use conflicts and flushes misfetched instructions upon branch/jump mispredictions.*


* **数据前推模块 / Forwarding Unit (`excute/forward-passing.v`)**
流水线的“高速超车通道”。检测当前 ID 级指令的源寄存器（RS1/RS2）与正在后级执行/访存的指令目标寄存器（RD）的相关性。一旦匹配，直接将未写回的新数据旁路（Bypassing）前推至 ALU 输入端，实现绝大多数数据相关指令的**零延迟连续执行**。
*Bypasses advanced execution results from later stages directly to ALU inputs, eliminating unnecessary pipeline stalls.*

### 数据通路与接口 / Datapath & Interfaces

* **存储器接口处理 / Memory-I/O Interface (`memory/mem-io.v`)**
伴随 v2.1 升级，该部分统一了同步时序。负责规范管理 6 级流水线中访存级（MEM）的时序对齐，确保存储器读写指令（Load/Store）在同步钟沿触发下的严格安全与正确性。
* **写回控制 / Write-back Stage (`writeback/write_back.v`)**
流水线的收尾网关。在最终的 WB 级进行高速多路选择，将 ALU 计算结果、同步存储器读取的数据或跳转 PC 目标地址，精准、稳定地路由并写回通用寄存器堆 `regfile.v`。

---

## 3. 仿真与验证 / Simulation and Verification

本项目提供了一套**地狱级压力测试用例（Comprehensive Stress-Test）**，混合了密集的数据相关（Raw Hazards）、Load-Use 冲突、连续条件分支与无条件跳转，能完美压榨并验证 6 级流水线的稳定性。

### 推荐工具链 / Recommended Toolchain

* **开源方案**：Icarus Verilog (编译) + GTKWave (波形查看)
* **商业方案**：Vivado / ModelSim / Quartus

### 简易仿真步骤（以 Icarus Verilog 为例）

在终端中进入项目根目录，直接运行以下命令：

```bash
# 1. 编译所有分层 RTL 源文件及压力测试仿真文件
iverilog -o cpu_sim rtl/core/**/*.v tb/tb_cpu.v

# 2. 运行仿真（自动生成包含全级流水线信号的 wave.vcd）
vvp cpu_sim

# 3. 使用 GTKWave 打开波形图
gtkwave wave.vcd

```

> **提示**：在 GTKWave 中，你可以清晰地观察到 6 条指令同时在 `IF1, IF2, ID, EX, MEM, WB` 阶段并行重叠、`forward-passing` 信号动态拉高、以及控制流改变时 `hazard_handler` 瞬间清空（Flush）前几级流水线的宏观运作过程。

---

## 4. 版本演进历史 / Version Evolution History

### v2.1 版本（当前版本）

* **架构**：全面重构为分层目录，升级为 6 级流水线（IF1 → IF2 → ID → EX → MEM → WB）。
* **特性**：ROM/DMEM 切换为全同步存储接口，引入 Store-Load 写转发机制，完美攻克 Stall/Flush 状态下的取指对齐隐患。

### v2.0 版本

* **架构**：引入经典 5 级流水线（IF → ID → EX → MEM → WB），结束了单周期时代。
* **特性**：首次构建 `forward-passing` 和 `hazard_handler`，攻克了基础数据冒险和控制冒险。

### v1.0 版本

* **架构**：最基础的单周期（Single-Cycle）处理器架构，验证了 37 条 RV32I 基础指令集的译码与执行逻辑，是本项目的逻辑起点。

---

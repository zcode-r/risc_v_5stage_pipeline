`timescale 1ns/1ps

import riscv_pkg::*;

module riscv_top #(
    parameter int MEM_DEPTH=1024,
    parameter string HEX_FILE="program.hex"
) (
    input logic clk,
    input logic reset
);

// ============================================================================
// STAGE 1: INSTRUCTION FETCH (IF)
// ============================================================================
logic stall_if;
logic stall_id;
logic flush_ex;

logic [31:0] if_pc_curr;
logic [31:0] if_pc_next;
logic [31:0] if_pc_plus4;
logic [31:0] if_inst;

logic        pc_src;
logic [31:0] branch_target;

logic [31:0] writeback_data;
logic [4:0]  wb_rd;
logic        wb_reg_write;

assign if_pc_plus4 = if_pc_curr + 4;
assign if_pc_next  = (pc_src) ? branch_target : if_pc_plus4;

always_ff @(posedge clk or posedge reset) begin
    if(reset) if_pc_curr<=32'h00000000;
    else if(!stall_if) if_pc_curr<=if_pc_next;
end

instruction_mem #(
    .MEM_DEPTH(MEM_DEPTH),
    .HEX_FILE ("program.hex")
) u_imem (
    .addr(if_pc_curr),
    .inst(if_inst)
);

// ============================================================================
// PIPELINE REGISTER 1: IF/ID (Between Fetch and Decode)
// ============================================================================
logic [31:0] id_pc;
logic [31:0] id_inst;

always_ff @(posedge clk or posedge reset) begin
    if (reset || pc_src) begin
        id_pc   <= 32'h00000000;
        id_inst <= 32'h00000000;
    end else if(!stall_id) begin
        id_pc   <= if_pc_curr;
        id_inst <= if_inst;
    end
end

// ============================================================================
// STAGE 2: INSTRUCTION DECODE (ID)
// ============================================================================
logic [6:0] opcode;
logic [4:0] rs1,rs2,rd;
logic [2:0] funct3;
logic funct7_b5;

logic [31:0] imm_out;
logic [31:0] rdata1,rdata2;

logic [1:0] alu_op_type;
logic is_i_type;
logic alu_src;
logic mem_to_reg;
logic reg_write;
logic mem_read;
logic mem_write;
logic branch;
logic jump;
alu_op_e alu_ctrl;

assign opcode=id_inst[6:0];
assign rd=id_inst[11:7];
assign funct3=id_inst[14:12];
assign rs1=id_inst[19:15];
assign rs2=id_inst[24:20];
assign funct7_b5=id_inst[30];

control_unit u_ctrl (
    .opcode     (opcode),
    .alu_op_type(alu_op_type),
    .is_i_type  (is_i_type),
    .alu_src    (alu_src),
    .mem_to_reg (mem_to_reg),
    .reg_write  (reg_write),
    .mem_read   (mem_read),
    .mem_write  (mem_write),
    .branch     (branch),
    .jump       (jump)
);

alu_control u_alu_ctrl (
    .alu_op_type(alu_op_type),
    .funct3     (funct3),
    .funct7_b5  (funct7_b5),
    .is_i_type  (is_i_type),
    .alu_ctrl   (alu_ctrl)
);

imm_gen u_imm_gen (
    .inst   (id_inst),
    .imm_out(imm_out)
);

reg_file #(
    .DATA_WIDTH(32),
    .REG_COUNT (32)
) u_reg_file (
    .clk   (clk),
    .reset (reset),
    .wen   (wb_reg_write),
    .waddr (wb_rd),
    .wdata (writeback_data),
    .raddr1(rs1),
    .rdata1(rdata1),
    .raddr2(rs2),
    .rdata2(rdata2)
);

// ============================================================================
// PIPELINE REGISTER 2: ID/EX (Between Decode and Execute)
// ============================================================================
logic [31:0] ex_pc;
logic [31:0] ex_rdata1, ex_rdata2;
logic [31:0] ex_imm_out;
logic [4:0]  ex_rs1, ex_rs2, ex_rd;

logic        ex_alu_src;
alu_op_e     ex_alu_ctrl;
logic        ex_mem_read;
logic        ex_mem_write;
logic        ex_branch;
logic        ex_jump;
logic        ex_reg_write;
logic        ex_mem_to_reg;

always_ff @(posedge clk or posedge reset) begin
    if (reset || flush_ex) begin
        ex_pc          <= 32'b0;
        ex_rdata1      <= 32'b0;
        ex_rdata2      <= 32'b0;
        ex_imm_out     <= 32'b0;
        ex_rs1         <= 5'b0;
        ex_rs2         <= 5'b0;
        ex_rd          <= 5'b0;
        
        ex_alu_src     <= 1'b0;
        ex_alu_ctrl    <= ALU_ADD;
        ex_mem_read    <= 1'b0;
        ex_mem_write   <= 1'b0;
        ex_branch      <= 1'b0;
        ex_jump        <= 1'b0;
        ex_reg_write   <= 1'b0;
        ex_mem_to_reg  <= 1'b0;
    end else begin
        ex_pc          <= id_pc;
        ex_rdata1      <= rdata1;
        ex_rdata2      <= rdata2;
        ex_imm_out     <= imm_out;
        ex_rs1         <= rs1;
        ex_rs2         <= rs2;
        ex_rd          <= rd;
        
        ex_alu_src     <= alu_src;
        ex_alu_ctrl    <= alu_ctrl;
        ex_mem_read    <= mem_read;
        ex_mem_write   <= mem_write;
        ex_branch      <= branch;
        ex_jump        <= jump;
        ex_reg_write   <= reg_write;
        ex_mem_to_reg  <= mem_to_reg;
    end
end

// ============================================================================
// STAGE 3: EXECUTE (EX)
// ============================================================================
logic [1:0]  forward_a, forward_b;
logic [31:0] ex_alu_operand_a;
logic [31:0] ex_rs2_forwarded;
logic [31:0] ex_alu_operand_b;
logic        ex_alu_zero;
logic [31:0] ex_alu_result;

forwarding_unit u_fwd_unit (
    .ex_rs1       (ex_rs1),
    .ex_rs2       (ex_rs2),
    .mem_rd       (mem_rd),
    .mem_reg_write(mem_reg_write),
    .wb_rd        (wb_rd),
    .wb_reg_write (wb_reg_write),
    .forward_a    (forward_a),
    .forward_b    (forward_b)
);

always_comb begin
    case (forward_a)
        2'b10:   ex_alu_operand_a = mem_alu_result;
        2'b01:   ex_alu_operand_a = writeback_data;
        default: ex_alu_operand_a = ex_rdata1;
    endcase
end

always_comb begin
    case (forward_b)
        2'b10:   ex_rs2_forwarded = mem_alu_result;
        2'b01:   ex_rs2_forwarded = writeback_data;
        default: ex_rs2_forwarded = ex_rdata2;
    endcase
end

assign ex_alu_operand_b = (ex_alu_src) ? ex_imm_out : ex_rs2_forwarded;

assign branch_target = ex_pc + ex_imm_out;
assign pc_src        = (ex_branch & ex_alu_zero) | ex_jump;

alu #(
    .DATA_WIDTH(32)
) u_alu (
    .a       (ex_alu_operand_a),
    .b       (ex_alu_operand_b),
    .alu_op  (ex_alu_ctrl),
    .alu_out (ex_alu_result),
    .zero    (ex_alu_zero),
    .sign    (),
    .overflow(),
    .carry   (),
    .ltu     ()
);

// ============================================================================
// HAZARD MANAGEMENT UNIT INSTANCE
// ============================================================================
hazard_unit u_hazard_unit (
    .id_rs1     (rs1),
    .id_rs2     (rs2),
    .ex_rd      (ex_rd),
    .ex_mem_read(ex_mem_read),
    .pc_src     (pc_src),
    .stall_if   (stall_if),
    .stall_id   (stall_id),
    .flush_ex   (flush_ex)
);

// ============================================================================
// PIPELINE REGISTER 3: EX/MEM (Between Execute and Memory)
// ============================================================================
logic [31:0] mem_pc;
logic [31:0] mem_alu_result;
logic [31:0] mem_write_data;
logic [4:0]  mem_rd;

logic        mem_mem_read;
logic        mem_mem_write;
logic        mem_reg_write;
logic        mem_mem_to_reg;
logic        mem_jump;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        mem_pc         <= 32'b0;
        mem_alu_result <= 32'b0;
        mem_write_data <= 32'b0;
        mem_rd         <= 5'b0;
        
        mem_mem_read   <= 1'b0;
        mem_mem_write  <= 1'b0;
        mem_reg_write  <= 1'b0;
        mem_mem_to_reg <= 1'b0;
        mem_jump       <= 1'b0;
    end else begin
        mem_pc         <= ex_pc;
        mem_alu_result <= ex_alu_result;
        mem_write_data <= ex_rs2_forwarded; // Updated to forwarded value
        mem_rd         <= ex_rd;
        
        mem_mem_read   <= ex_mem_read;
        mem_mem_write  <= ex_mem_write;
        mem_reg_write  <= ex_reg_write;
        mem_mem_to_reg <= ex_mem_to_reg;
        mem_jump       <= ex_jump;
    end
end

// ============================================================================
// STAGE 4: MEMORY ACCESS (MEM)
// ============================================================================
logic [31:0] mem_rdata;

data_mem #(
    .MEM_DEPTH(MEM_DEPTH)
) u_dmem (
    .clk      (clk),
    .reset    (reset),
    .mem_read (mem_mem_read),
    .mem_write(mem_mem_write),
    .addr     (mem_alu_result),
    .wdata    (mem_write_data),
    .rdata    (mem_rdata)
);

// ============================================================================
// PIPELINE REGISTER 4: MEM/WB (Between Memory and Writeback)
// ============================================================================
logic [31:0] wb_pc;
logic [31:0] wb_alu_result;
logic [31:0] wb_mem_rdata;

logic        wb_mem_to_reg;
logic        wb_jump;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        wb_pc          <= 32'b0;
        wb_alu_result  <= 32'b0;
        wb_mem_rdata   <= 32'b0;
        wb_rd          <= 5'b0;
        
        wb_reg_write   <= 1'b0;
        wb_mem_to_reg  <= 1'b0;
        wb_jump        <= 1'b0;
    end else begin
        wb_pc          <= mem_pc;
        wb_alu_result  <= mem_alu_result;
        wb_mem_rdata   <= mem_rdata;
        wb_rd          <= mem_rd;
        
        wb_reg_write   <= mem_reg_write;
        wb_mem_to_reg  <= mem_mem_to_reg;
        wb_jump        <= mem_jump;
    end
end

// ============================================================================
// STAGE 5: WRITEBACK (WB)
// ============================================================================
assign writeback_data = (wb_jump)       ? (wb_pc + 4) : 
                        (wb_mem_to_reg) ? wb_mem_rdata : 
                                          wb_alu_result;

endmodule
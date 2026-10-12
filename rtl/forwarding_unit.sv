`timescale 1ns/1ps

module forwarding_unit (
    // Source registers needed in Stage 3 (EX)
    input  logic [4:0] ex_rs1,
    input  logic [4:0] ex_rs2,

    // Stage 4 (MEM) destination register & write enable
    input  logic [4:0] mem_rd,
    input  logic       mem_reg_write,

    // Stage 5 (WB) destination register & write enable
    input  logic [4:0] wb_rd,
    input  logic       wb_reg_write,

    // MUX Select Outputs for ALU Operands
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    always_comb begin
        // Default: No forwarding (use values passed from ID/EX)
        forward_a = 2'b00;
        forward_b = 2'b00;

        // ====================================================================
        // 1. FORWARDING FOR OPERAND A (ex_rs1)
        // ====================================================================
        
        // Hazard 1: EX/MEM Hazard (Instruction in Stage 4 produces value needed in Stage 3)
        if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs1)) begin
            forward_a = 2'b10;
        end
        // Hazard 2: MEM/WB Hazard (Instruction in Stage 5 produces value needed in Stage 3)
        // (Only forward if EX/MEM hazard didn't already match!)
        else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs1)) begin
            forward_a = 2'b01;
        end

        // ====================================================================
        // 2. FORWARDING FOR OPERAND B (ex_rs2)
        // ====================================================================
        
        // Hazard 1: EX/MEM Hazard
        if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs2)) begin
            forward_b = 2'b10;
        end
        // Hazard 2: MEM/WB Hazard
        else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs2)) begin
            forward_b = 2'b01;
        end
    end

endmodule
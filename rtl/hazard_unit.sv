`timescale 1ns/1ps

module hazard_unit (
    // Inputs from ID Stage (Instruction currently decoding)
    input  logic [4:0] id_rs1,
    input  logic [4:0] id_rs2,

    // Inputs from EX Stage (Instruction currently executing)
    input  logic [4:0] ex_rd,
    input  logic       ex_mem_read, // 1 if EX instruction is a Load (LW)
    input  logic       pc_src,      // 1 if Branch/Jump is taken in EX stage

    // Outputs to control pipeline stages
    output logic       stall_if,    // Freeze Program Counter & IF stage
    output logic       stall_id,    // Freeze IF/ID Pipeline Register
    output logic       flush_ex     // Clear ID/EX Register to NOP
);

    always_comb begin
        // Default: Normal pipeline flow (No stalls or flushes)
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_ex = 1'b0;

        // ====================================================================
        // 1. LOAD-USE HAZARD DETECTION
        // ====================================================================
        // If instruction in EX is a LOAD (LW) AND its destination register (ex_rd)
        // matches either source register needed by instruction in ID (id_rs1 / id_rs2)...
        if (ex_mem_read && (ex_rd != 5'b0) && ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            stall_if = 1'b1; // Hold PC constant
            stall_id = 1'b1; // Keep current instruction in IF/ID
            flush_ex = 1'b1; // Insert NOP bubble into ID/EX
        end

        // ====================================================================
        // 2. CONTROL HAZARD DETECTION (Branch Taken)
        // ====================================================================
        // If a branch/jump is taken in EX stage, nuke the instruction currently in ID
        else if (pc_src) begin
            flush_ex = 1'b1; // Flush the speculatively fetched instruction
        end
    end

endmodule
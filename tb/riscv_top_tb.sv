`timescale 1ns/1ps

module riscv_top_tb;

    logic clk;
    logic reset;

    // Instantiate Top Module
    riscv_top #(
        .MEM_DEPTH(1024),
        .HEX_FILE ("program.hex")
    ) dut (
        .clk  (clk),
        .reset(reset)
    );

    // 100MHz Clock Generation
    always #5 clk <= ~clk;

    int cycle_cnt;

    initial begin
        clk       = 0;
        reset     = 1;
        cycle_cnt = 0;

        $display("=======================================================================");
        $display("          STARTING COMBINED PIPELINED RISC-V CPU SIMULATION            ");
        $display("=======================================================================");

        // Hold reset for 2 clock cycles
        #15;
        reset = 0;

        // Run for 25 cycles so all combined instructions exit Writeback (WB)
        repeat (25) begin
            @(posedge clk);
            #1; // Delta delay for signal settling
            cycle_cnt++;
            $display("[Cycle %2d] IF_PC:0x%08h | ID_Inst:0x%08h | x1:%0d x2:%0d x3:%0d x4:%0d x5:%0d x6:%0d x9:%0d",
                     cycle_cnt,
                     dut.if_pc_curr,
                     dut.id_inst,
                     dut.u_reg_file.registers[1],
                     dut.u_reg_file.registers[2],
                     dut.u_reg_file.registers[3],
                     dut.u_reg_file.registers[4],
                     dut.u_reg_file.registers[5],
                     dut.u_reg_file.registers[6],
                     dut.u_reg_file.registers[9]);
        end

        // NOW VERIFY FINAL STATE AFTER 25 CYCLES
        $display("=======================================================================");
        $display("                   VERIFYING COMBINED CPU TEST STATE                   ");
        $display("=======================================================================");

        assert(dut.u_reg_file.registers[1] === 32'd5)
            else $error("[FAILED] x1 should be 5, got %0d", dut.u_reg_file.registers[1]);

        assert(dut.u_reg_file.registers[2] === 32'd10)
            else $error("[FAILED] x2 should be 10, got %0d", dut.u_reg_file.registers[2]);

        assert(dut.u_reg_file.registers[3] === 32'd15)
            else $error("[FAILED] x3 should be 15, got %0d", dut.u_reg_file.registers[3]);

        assert(dut.u_reg_file.registers[4] === 32'd25)
            else $error("[FAILED] x4 should be 25, got %0d", dut.u_reg_file.registers[4]);

        assert(dut.u_reg_file.registers[5] === 32'd25)
            else $error("[FAILED] x5 (LW) should be 25, got %0d", dut.u_reg_file.registers[5]);

        assert(dut.u_reg_file.registers[6] === 32'd30)
            else $error("[FAILED] x6 (Stall test) should be 30, got %0d", dut.u_reg_file.registers[6]);

        assert(dut.u_reg_file.registers[7] === 32'd32)
            else $error("[FAILED] x7 should be 32, got %0d", dut.u_reg_file.registers[7]);

        assert(dut.u_reg_file.registers[8] === 32'd0)
            else $error("[FAILED] x8 should be 0 (Flushed branch instruction executed!), got %0d", dut.u_reg_file.registers[8]);

        assert(dut.u_reg_file.registers[9] === 32'd42)
            else $error("[FAILED] x9 (Branch target) should be 42, got %0d", dut.u_reg_file.registers[9]);

        $display("[SUCCESS] All Combined Forwarding, Load-Use Stall, Memory, and Branch Flush tests PASSED!");
        $display("=======================================================================");
        $finish;
    end

endmodule
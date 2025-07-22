// Testbench for JTAG-AXI Bridge Top Module
// Author: FPGA Engineer
// Date: 2025-07-23
// Description: SystemVerilog testbench for top-level JTAG-AXI bridge system

`timescale 1ns / 1ps

module tb_jtag_axi_top;

    // Parameters
    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;
    localparam BASE_ADDR = 32'h43C00000;
    localparam CLK_PERIOD = 10; // 100MHz clock
    
    // DUT signals
    logic                        sys_clk;
    logic                        sys_resetn;
    logic [31:0]                 ext_status_reg;
    logic [31:0]                 control_reg_out;
    logic [31:0]                 data_reg_out;
    logic [31:0]                 test_reg_out;
    logic                        interrupt_out;
    logic [7:0]                  debug_gpio;
    
    // Test variables
    logic [31:0] test_data;
    logic [31:0] read_data;
    integer test_count;
    integer error_count;
    
    // Clock generation
    initial begin
        sys_clk = 0;
        forever #(CLK_PERIOD/2) sys_clk = ~sys_clk;
    end
    
    // DUT instantiation
    Jtag_Axi_Top #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .BASE_ADDR(BASE_ADDR)
    ) dut (
        .sys_clk(sys_clk),
        .sys_resetn(sys_resetn),
        .ext_status_reg(ext_status_reg),
        .control_reg_out(control_reg_out),
        .data_reg_out(data_reg_out),
        .test_reg_out(test_reg_out),
        .interrupt_out(interrupt_out),
        .debug_gpio(debug_gpio)
    );
    
    // Task for reset
    task reset_system();
        begin
            $display("[%0t] Applying system reset", $time);
            sys_resetn = 0;
            ext_status_reg = 32'h0;
            #(CLK_PERIOD * 10);
            sys_resetn = 1;
            #(CLK_PERIOD * 5);
            $display("[%0t] System reset completed", $time);
        end
    endtask
    
    // Task to simulate JTAG write operation
    task simulate_jtag_write(input [31:0] addr, input [31:0] data);
        begin
            $display("[%0t] JTAG Write: Addr=0x%08x, Data=0x%08x", $time, addr, data);
            
            // Access the internal JTAG bridge signals through hierarchical reference
            // This simulates the JTAG shift and update sequence
            
            // Simulate JTAG command shift (simplified)
            // In real scenario, this would be done through BSCANE2 primitive
            force dut.u_jtag_axi_bridge.cmd_reg = 32'h00000001; // Write command
            force dut.u_jtag_axi_bridge.addr_reg = addr;
            force dut.u_jtag_axi_bridge.data_reg = data;
            force dut.u_jtag_axi_bridge.axi_write_req = 1'b1;
            
            // Wait for transaction completion
            wait(dut.u_jtag_axi_bridge.axi_write_done);
            #(CLK_PERIOD);
            
            // Release forced signals
            release dut.u_jtag_axi_bridge.cmd_reg;
            release dut.u_jtag_axi_bridge.addr_reg;
            release dut.u_jtag_axi_bridge.data_reg;
            release dut.u_jtag_axi_bridge.axi_write_req;
            
            #(CLK_PERIOD * 2);
            $display("[%0t] JTAG Write completed", $time);
        end
    endtask
    
    // Task to simulate JTAG read operation
    task simulate_jtag_read(input [31:0] addr, output [31:0] data);
        begin
            $display("[%0t] JTAG Read: Addr=0x%08x", $time, addr);
            
            // Simulate JTAG read command shift
            force dut.u_jtag_axi_bridge.cmd_reg = 32'h00000002; // Read command
            force dut.u_jtag_axi_bridge.addr_reg = addr;
            force dut.u_jtag_axi_bridge.axi_read_req = 1'b1;
            
            // Wait for transaction completion
            wait(dut.u_jtag_axi_bridge.axi_read_done);
            #(CLK_PERIOD);
            
            // Get read data
            data = dut.u_jtag_axi_bridge.read_data_reg;
            
            // Release forced signals
            release dut.u_jtag_axi_bridge.cmd_reg;
            release dut.u_jtag_axi_bridge.addr_reg;
            release dut.u_jtag_axi_bridge.axi_read_req;
            
            #(CLK_PERIOD * 2);
            $display("[%0t] JTAG Read completed: Data=0x%08x", $time, data);
        end
    endtask
    
    // Task for register write test
    task test_register_write(input [31:0] addr, input [31:0] data, input string reg_name);
        begin
            test_count++;
            $display("\n=== Test %0d: Write to %s Register ===", test_count, reg_name);
            simulate_jtag_write(BASE_ADDR + addr, data);
            #(CLK_PERIOD * 5);
            
            // Verify the write through output ports
            case (addr)
                32'h00: begin // Control register
                    if (control_reg_out !== data) begin
                        $error("Control register write failed: Expected=0x%08x, Got=0x%08x", data, control_reg_out);
                        error_count++;
                    end else begin
                        $display("Control register write successful: 0x%08x", control_reg_out);
                    end
                end
                32'h08: begin // Data register
                    if (data_reg_out !== data) begin
                        $error("Data register write failed: Expected=0x%08x, Got=0x%08x", data, data_reg_out);
                        error_count++;
                    end else begin
                        $display("Data register write successful: 0x%08x", data_reg_out);
                    end
                end
                32'h0C: begin // Test register
                    if (test_reg_out !== data) begin
                        $error("Test register write failed: Expected=0x%08x, Got=0x%08x", data, test_reg_out);
                        error_count++;
                    end else begin
                        $display("Test register write successful: 0x%08x", test_reg_out);
                    end
                end
            endcase
        end
    endtask
    
    // Task for register read test
    task test_register_read(input [31:0] addr, input [31:0] expected_data, input string reg_name);
        begin
            test_count++;
            $display("\n=== Test %0d: Read from %s Register ===", test_count, reg_name);
            simulate_jtag_read(BASE_ADDR + addr, read_data);
            
            if (read_data !== expected_data) begin
                $error("%s register read failed: Expected=0x%08x, Got=0x%08x", reg_name, expected_data, read_data);
                error_count++;
            end else begin
                $display("%s register read successful: 0x%08x", reg_name, read_data);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("Starting JTAG-AXI Bridge Top Module Testbench");
        $display("=============================================");
        
        test_count = 0;
        error_count = 0;
        
        // Initialize
        reset_system();
        
        // Test 1: Write to Control Register
        test_register_write(32'h00, 32'h12345678, "Control");
        
        // Test 2: Write to Data Register
        test_register_write(32'h08, 32'hABCDEF00, "Data");
        
        // Test 3: Write to Test Register
        test_register_write(32'h0C, 32'hDEADBEEF, "Test");
        
        // Test 4: Read back Control Register
        test_register_read(32'h00, 32'h12345678, "Control");
        
        // Test 5: Read back Data Register
        test_register_read(32'h08, 32'hABCDEF00, "Data");
        
        // Test 6: Read back Test Register
        test_register_read(32'h0C, 32'hDEADBEEF, "Test");
        
        // Test 7: Read Status Register
        ext_status_reg = 32'h55AA33CC;
        #(CLK_PERIOD * 2);
        test_register_read(32'h04, 32'h55AA33CC, "Status");
        
        // Test 8: Test interrupt functionality
        test_count++;
        $display("\n=== Test %0d: Interrupt Test ===", test_count);
        simulate_jtag_write(BASE_ADDR + 32'h00, 32'h00000001); // Set bit 0 in control register
        #(CLK_PERIOD * 2);
        if (interrupt_out !== 1'b1) begin
            $error("Interrupt test failed: Expected=1, Got=%0b", interrupt_out);
            error_count++;
        end else begin
            $display("Interrupt test successful: interrupt_out=%0b", interrupt_out);
        end
        
        // Test 9: Clear interrupt
        simulate_jtag_write(BASE_ADDR + 32'h00, 32'h00000000); // Clear bit 0 in control register
        #(CLK_PERIOD * 2);
        if (interrupt_out !== 1'b0) begin
            $error("Interrupt clear failed: Expected=0, Got=%0b", interrupt_out);
            error_count++;
        end else begin
            $display("Interrupt clear successful: interrupt_out=%0b", interrupt_out);
        end
        
        // Test 10: Invalid address test
        test_count++;
        $display("\n=== Test %0d: Invalid Address Test ===", test_count);
        simulate_jtag_write(BASE_ADDR + 32'h10, 32'h12345678); // Invalid address
        #(CLK_PERIOD * 5);
        // Check that no registers were affected
        if (control_reg_out === 32'h12345678 || data_reg_out === 32'h12345678 || test_reg_out === 32'h12345678) begin
            $error("Invalid address test failed: Registers were modified");
            error_count++;
        end else begin
            $display("Invalid address test successful: No registers modified");
        end
        
        // Test summary
        #(CLK_PERIOD * 10);
        $display("\n=== Test Summary ===");
        $display("Total tests: %0d", test_count);
        $display("Errors: %0d", error_count);
        
        if (error_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $display("\nFinal Register Values:");
        $display("Control Register: 0x%08x", control_reg_out);
        $display("Data Register:    0x%08x", data_reg_out);
        $display("Test Register:    0x%08x", test_reg_out);
        $display("Debug GPIO:       0x%02x", debug_gpio);
        
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // Monitor for debugging
    initial begin
        $monitor("[%0t] control_reg=0x%08x, data_reg=0x%08x, test_reg=0x%08x, interrupt=%0b, debug_gpio=0x%02x", 
                 $time, control_reg_out, data_reg_out, test_reg_out, interrupt_out, debug_gpio);
    end

endmodule

// Simple Testbench for JTAG-AXI LED Control System
// Author: FPGA Engineer
// Date: 2025-07-23
// Description: SystemVerilog testbench for simple LED control system

`timescale 1ns / 1ps

module tb_simple_jtag_led;

    // Parameters
    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;
    localparam BASE_ADDR = 32'h43C00000;
    localparam CLK_PERIOD = 10; // 100MHz clock
    
    // DUT signals
    logic                        sys_clk;
    logic                        sys_resetn;
    logic [3:0]                  led_pins;
    
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
        .led_pins(led_pins)
    );
    
    // Task for reset
    task reset_system();
        begin
            $display("[%0t] Applying system reset", $time);
            sys_resetn = 0;
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
            
            // Simulate JTAG command shift (simplified)
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
    
    // Task for LED test
    task test_led_pattern(input [3:0] pattern, input string pattern_name);
        begin
            test_count++;
            $display("\n=== Test %0d: LED Pattern '%s' (0b%04b) ===", test_count, pattern_name, pattern);
            
            // Write pattern to LED register
            simulate_jtag_write(BASE_ADDR, {28'h0, pattern});
            #(CLK_PERIOD * 5);
            
            // Verify LED outputs
            if (led_pins !== pattern) begin
                $error("LED pattern test failed: Expected=0b%04b, Got=0b%04b", pattern, led_pins);
                error_count++;
            end else begin
                $display("LED pattern test successful: LEDs=0b%04b", led_pins);
            end
            
            // Read back and verify
            simulate_jtag_read(BASE_ADDR, read_data);
            if (read_data[3:0] !== pattern) begin
                $error("LED register read failed: Expected=0x%01x, Got=0x%01x", pattern, read_data[3:0]);
                error_count++;
            end else begin
                $display("LED register read successful: 0x%01x", read_data[3:0]);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("Starting Simple JTAG-AXI LED Control Testbench");
        $display("=================================================");
        
        test_count = 0;
        error_count = 0;
        
        // Initialize
        reset_system();
        
        // Test different LED patterns
        test_led_pattern(4'b0000, "All OFF");
        test_led_pattern(4'b1111, "All ON");
        test_led_pattern(4'b1010, "Alternating 1");
        test_led_pattern(4'b0101, "Alternating 2");
        test_led_pattern(4'b0001, "LED0 Only");
        test_led_pattern(4'b0010, "LED1 Only");
        test_led_pattern(4'b0100, "LED2 Only");
        test_led_pattern(4'b1000, "LED3 Only");
        test_led_pattern(4'b1100, "LED3&2");
        test_led_pattern(4'b0011, "LED1&0");
        
        // Test invalid address
        test_count++;
        $display("\n=== Test %0d: Invalid Address Test ===", test_count);
        logic [3:0] led_before = led_pins;
        simulate_jtag_write(BASE_ADDR + 32'h4, 32'hDEADBEEF); // Invalid address
        #(CLK_PERIOD * 5);
        if (led_pins !== led_before) begin
            $error("Invalid address test failed: LEDs changed unexpectedly");
            error_count++;
        end else begin
            $display("Invalid address test successful: LEDs unchanged");
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
        
        $display("\nFinal LED State: 0b%04b", led_pins);
        
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // Monitor for LED changes
    initial begin
        $monitor("[%0t] LED State: 0b%04b (LED3=%b, LED2=%b, LED1=%b, LED0=%b)", 
                 $time, led_pins, led_pins[3], led_pins[2], led_pins[1], led_pins[0]);
    end

endmodule

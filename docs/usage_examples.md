# JTAG-AXI Bridge Usage Examples

## Quick Start Guide

### 1. Vivado Hardware Manager Example

```tcl
# Load the script in Vivado Hardware Manager
source scripts/vivado_jtag_access.tcl

# Register addresses (Base: 0x43C00000)
set base_addr 0x43C00000

# Example 1: Write to Control Register
jtag_axi_write [expr $base_addr + 0x00] 0x12345678

# Example 2: Write to Data Register  
jtag_axi_write [expr $base_addr + 0x08] 0xABCDEF00

# Example 3: Read from Status Register
set status [jtag_axi_read [expr $base_addr + 0x04]]
puts "Status Register: 0x$status"

# Example 4: Comprehensive test
example_write_read_test
```

### 2. Python Tool Examples

```bash
# Register base address
BASE_ADDR=0x43C00000

# Write to Control Register (offset 0x00)
python python/jtag_axi_debug.py --action write --addr $((BASE_ADDR + 0x00)) --data 0x12345678

# Write to Data Register (offset 0x08)
python python/jtag_axi_debug.py --action write --addr $((BASE_ADDR + 0x08)) --data 0xABCDEF00

# Read from Status Register (offset 0x04)
python python/jtag_axi_debug.py --action read --addr $((BASE_ADDR + 0x04))

# Run comprehensive register test suite
python python/jtag_axi_debug.py --action test

# Play updated SVF file with register addresses
python python/jtag_axi_debug.py --action svf --svf svf/jtag_axi_test.svf
```

### 3. SVF File Usage

```bash
# Using OpenOCD to play SVF file
openocd -f interface/ftdi/ft2232h.cfg -f target/xc7z020.cfg -c "svf svf/jtag_axi_test.svf"

# Using other JTAG tools that support SVF
# Example with UrJTAG:
# jtag> svf svf/jtag_axi_test.svf
```

## Integration Examples

### SystemVerilog Testbench Example

```systemverilog
module tb_jtag_axi_bridge;
    
    // Clock and reset
    logic axi_aclk = 0;
    logic axi_aresetn = 0;
    
    // AXI-Lite interface
    logic [31:0] m_axi_awaddr;
    logic [2:0]  m_axi_awprot;
    logic        m_axi_awvalid;
    logic        m_axi_awready = 1;
    
    logic [31:0] m_axi_wdata;
    logic [3:0]  m_axi_wstrb;
    logic        m_axi_wvalid;
    logic        m_axi_wready = 1;
    
    logic [1:0]  m_axi_bresp = 0;
    logic        m_axi_bvalid = 0;
    logic        m_axi_bready;
    
    logic [31:0] m_axi_araddr;
    logic [2:0]  m_axi_arprot;
    logic        m_axi_arvalid;
    logic        m_axi_arready = 1;
    
    logic [31:0] m_axi_rdata = 32'hDEADBEEF;
    logic [1:0]  m_axi_rresp = 0;
    logic        m_axi_rvalid = 0;
    logic        m_axi_rready;
    
    // DUT instantiation
    Jtag_Axi_Bridge dut (
        .axi_aclk(axi_aclk),
        .axi_aresetn(axi_aresetn),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );
    
    // Clock generation
    always #5 axi_aclk = ~axi_aclk;
    
    // Test sequence
    initial begin
        // Reset
        axi_aresetn = 0;
        #100;
        axi_aresetn = 1;
        #100;
        
        // Your test sequence here
        $finish;
    end
    
    // AXI response simulation
    always @(posedge axi_aclk) begin
        if (m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready) begin
            #20 m_axi_bvalid <= 1;
            #10 m_axi_bvalid <= 0;
        end
        
        if (m_axi_arvalid && m_axi_arready) begin
            #20 m_axi_rvalid <= 1;
            #10 m_axi_rvalid <= 0;
        end
    end
    
endmodule
```

## Configuration Examples

### OpenOCD Configuration

Create `openocd.cfg`:

```tcl
# OpenOCD configuration for JTAG-AXI Bridge
adapter driver ftdi
ftdi_vid_pid 0x0403 0x6010
ftdi_layout_init 0x0088 0x008b

# Target configuration (example for Zynq-7000)
set _CHIPNAME zynq
set _TARGETNAME $_CHIPNAME.cpu

jtag newtap $_CHIPNAME tap -irlen 6 -ircapture 0x1 -irmask 0x03 \
    -expected-id 0x23727093

target create $_TARGETNAME cortex_a -chain-position $_CHIPNAME.tap

# Enable TCL interface
tcl_port 6666

init
```

### Vivado Project Integration

```tcl
# Add to your Vivado project constraints
create_clock -period 10.000 -name axi_aclk [get_ports axi_aclk]

# JTAG clock constraints (if needed)
create_clock -period 100.000 -name jtag_tck [get_pins u_jtag_bridge/u_bscane2/TCK]
set_clock_groups -asynchronous -group [get_clocks axi_aclk] -group [get_clocks jtag_tck]

# I/O constraints for your specific board
# (Add your specific pin assignments here)
```

## Advanced Usage

### Custom Python Script

```python
#!/usr/bin/env python3
import sys
sys.path.append('python')
from jtag_axi_debug import JTAGAXIBridge, OpenOCDInterface

# Create custom test
def memory_test():
    jtag_if = OpenOCDInterface()
    bridge = JTAGAXIBridge(jtag_if)
    
    if bridge.connect():
        # Write pattern
        for i in range(16):
            addr = 0x1000 + i * 4
            data = 0xA5A5A5A5 + i
            bridge.write(addr, data)
        
        # Read back and verify
        for i in range(16):
            addr = 0x1000 + i * 4
            expected = 0xA5A5A5A5 + i
            actual = bridge.read(addr)
            if actual != expected:
                print(f"FAIL at {addr:08x}: expected {expected:08x}, got {actual:08x}")
                return False
        
        print("Memory test PASSED")
        return True
    
    return False

if __name__ == '__main__':
    memory_test()
```

### Automated Testing Script

```bash
#!/bin/bash
# automated_test.sh

echo "Starting JTAG-AXI Bridge automated tests..."

# Test 1: Basic connectivity
echo "Test 1: Basic connectivity"
python python/jtag_axi_debug.py --action write --addr 0x0 --data 0x12345678
if [ $? -eq 0 ]; then
    echo "PASS: Basic write test"
else
    echo "FAIL: Basic write test"
    exit 1
fi

# Test 2: Read/Write verification
echo "Test 2: Read/Write verification"
python python/jtag_axi_debug.py --action test
if [ $? -eq 0 ]; then
    echo "PASS: Read/Write verification"
else
    echo "FAIL: Read/Write verification"
    exit 1
fi

# Test 3: SVF playback
echo "Test 3: SVF playback"
python python/jtag_axi_debug.py --action svf --svf svf/jtag_axi_test.svf
if [ $? -eq 0 ]; then
    echo "PASS: SVF playback"
else
    echo "FAIL: SVF playback"
    exit 1
fi

echo "All tests completed successfully!"
```

## Troubleshooting Common Issues

### Issue 1: JTAG Connection Failed

**Symptoms**: Cannot connect to JTAG adapter

**Solutions**:
1. Check JTAG cable connections
2. Verify OpenOCD configuration
3. Check device power and configuration

```bash
# Debug JTAG connection
openocd -f your_config.cfg -c "init; jtag_name; exit"
```

### Issue 2: AXI Transaction Timeout

**Symptoms**: Operations hang or timeout

**Solutions**:
1. Check AXI slave readiness
2. Verify clock and reset signals
3. Increase timeout values

### Issue 3: Data Corruption

**Symptoms**: Read data doesn't match written data

**Solutions**:
1. Check AXI data width configuration
2. Verify endianness
3. Check for timing violations

## Performance Optimization

### Maximize Throughput

```python
# Batch operations for better performance
def batch_write(bridge, base_addr, data_list):
    for i, data in enumerate(data_list):
        bridge.write(base_addr + i*4, data)
        # Minimal delay between operations
        time.sleep(0.001)
```

### Reduce Latency

1. Use appropriate JTAG clock frequency
2. Minimize delays in software
3. Optimize AXI slave response time

This completes the comprehensive JTAG-AXI Bridge implementation with all four requested components and supporting documentation.

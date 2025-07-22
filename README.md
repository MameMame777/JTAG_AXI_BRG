# JTAG-AXI Bridge for LED Control

This project implements a simple JTAG-AXI bridge system for controlling LEDs on FPGA boards. The system allows reading and writing to a 4-bit LED register through JTAG interface, making it perfect for board bring-up and debugging.

## Project Structure

```text
JTAG_AXI_BRG/
├── .github/
│   └── copilot-instructions.md         # Coding guidelines and instructions
├── diary/                              # Development diary entries
│   ├── 2025-07-23_143000.md           # Initial project planning
│   └── 2025-07-23_150000_completion.md # Project completion report
├── docs/                               # Documentation
│   ├── system_documentation.md         # Complete system documentation
│   └── usage_examples.md              # Usage examples and tutorials
├── python/                            # Python debug tools
│   └── jtag_axi_debug.py              # LED control debugging tool
├── rtl/                               # SystemVerilog RTL code
│   ├── Jtag_Axi_Bridge.sv            # JTAG-AXI bridge module
│   ├── Simple_Led_Register.sv         # Simple 4-bit LED register
│   └── Jtag_Axi_Top.sv               # Top-level integration module  
├── scripts/                           # Scripts
│   ├── vivado_jtag_access.tcl         # Vivado Hardware Manager script
│   └── run_dsim.sh                    # dsim simulation script
├── svf/                               # SVF files for JTAG access
│   └── jtag_axi_test.svf              # LED control SVF examples
├── tb/                                # Testbenches
│   └── tb_jtag_axi_top.sv             # Top-level testbench
└── instrution.md                      # Original requirements file
```

## Components Overview

### 1. JTAG-AXI Bridge (`rtl/Jtag_Axi_Bridge.sv`)

- **Function**: Hardware implementation of JTAG to AXI-Lite bridge
- **Features**: BSCANE2 integration, full AXI-Lite master, clock domain crossing  
- **Protocol**: 96-bit command (32-bit cmd + 32-bit addr + 32-bit data)

### 2. Simple LED Register (`rtl/Simple_Led_Register.sv`)

- **Function**: AXI4-Lite slave with single 4-bit LED register
- **Features**: Simple register interface, direct LED pin assignment
- **Address**: Single register at offset 0x00 for LED control

### 3. Top-Level Module (`rtl/Jtag_Axi_Top.sv`)

- **Function**: Complete LED control system integration
- **Features**: JTAG bridge + LED register, 4-bit LED output pins
- **Interface**: Clock, reset, and led_pins[3:0] output

### 4. Vivado Tcl Script (`scripts/vivado_jtag_access.tcl`)

- **Function**: Direct JTAG access through Vivado Hardware Manager
- **Features**: Register-aware functions, automated testing, error handling
- **Usage**: `source vivado_jtag_access.tcl [write|read|writeread]`

### 5. SVF File (`svf/jtag_axi_test.svf`)
## Hardware Architecture

```text
JTAG Interface → BSCANE2 → JTAG-AXI Bridge → AXI4-Lite → LED Register → LED Pins[3:0]
```

### LED Control Protocol

The system uses a simple protocol for LED control:

1. **Command Format**: 96-bit JTAG shift register
   - Bits[31:0]: Command (0x01=Write, 0x02=Read)
   - Bits[63:32]: Address (0x00000000 for LED register)
   - Bits[95:64]: Data (LED pattern in bits[3:0])

2. **LED Patterns**: 4-bit control
   - Bit 0: LED0 control (1=ON, 0=OFF)
   - Bit 1: LED1 control (1=ON, 0=OFF)  
   - Bit 2: LED2 control (1=ON, 0=OFF)
   - Bit 3: LED3 control (1=ON, 0=OFF)

## BSCANE2 Connection and Communication

### External Communication Mechanism

The BSCANE2 primitive provides **automatic connection** to external JTAG interfaces without requiring additional pin assignments:

```text
External JTAG Cable → FPGA JTAG Pins → Built-in JTAG Controller → BSCANE2 → User Logic
```

#### Key Connection Features

1. **Automatic External Connection**
   - **External Pins**: Standard FPGA board JTAG connector (TDI, TDO, TCK, TMS)
   - **Internal Routing**: BSCANE2 automatically connects to FPGA's built-in JTAG controller
   - **No Pin Assignment**: No additional pin constraints required for JTAG signals

2. **USER1 Instruction Selection**
   ```systemverilog
   BSCANE2 #(.JTAG_CHAIN(1)) // USER1 instruction (typically 0x02)
   ```
   - **Instruction Selection**: External tools shift USER1 instruction (0x02) to activate
   - **SEL Signal**: `jtag_sel` becomes active when USER1 is selected
   - **Data Register**: 96-bit shift register becomes accessible

3. **Signal Connections Analysis**

   **✅ Properly Connected Signals:**
   ```systemverilog
   .DRCK(jtag_tck),        // Data register clock (gated TCK)
   .SEL(jtag_sel),         // USER1 instruction selection
   .SHIFT(jtag_shift),     // Shift state indicator
   .TDI(jtag_tdi),         // External data input
   .TDO(jtag_tdo),         // External data output
   .CAPTURE(jtag_capture), // Capture state indicator
   .UPDATE(jtag_update),   // Update state indicator
   .RESET(jtag_reset),     // TAP reset signal
   ```

   **✅ Correctly Unconnected Signals:**
   ```systemverilog
   .TCK(),                 // Unconnected - using DRCK instead
   .TMS(),                 // Unconnected - not needed for data register
   .RUNTEST(),             // Unconnected - not used in this design
   ```

#### External Access Methods

The system can be accessed through any standard JTAG tool that supports USER instructions:

- **Vivado Hardware Manager**: Direct AXI transaction support
- **OpenOCD**: Professional JTAG tool with scripting capability  
- **SVF Files**: Universal format for any SVF-compatible tool
- **Custom Tools**: Any tool supporting 96-bit JTAG shift operations

## JTAG Access Methods

### Method 1: Vivado Hardware Manager

The simplest method for testing with Xilinx tools:

```tcl
# Open Hardware Manager
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target

# Write LED pattern (turn on LED0 and LED2)
create_hw_axi_txn write_txn [get_hw_axis hw_axi_1] -address 00000000 -data 00000005
run_hw_axi write_txn

# Read current LED state  
create_hw_axi_txn read_txn [get_hw_axis hw_axi_1] -address 00000000
run_hw_axi read_txn
```

### Method 2: SVF Files

Serial Vector Format (SVF) files provide universal JTAG tool compatibility. The included `svf/jtag_axi_test.svf` demonstrates LED control patterns.

#### SVF File Structure

```svf
! LED Control via JTAG-AXI Bridge
! Turn on all LEDs (pattern 0xF)

! Reset TAP and go to IDLE
STATE RESET;
STATE IDLE;

! Select USER1 instruction (0x02)
SIR 6 TDI (02) SMASK (3F) TDO (05) MASK (3F);

! Write command: CMD=0x01, ADDR=0x00, DATA=0x0F  
SDR 96 TDI (000000010000000000000000000000000000000000000000000000000000000F);

STATE IDLE;
```

#### Key SVF Commands

- **STATE RESET/IDLE**: TAP controller state transitions
- **SIR**: Shift Instruction Register (select USER1)
- **SDR**: Shift Data Register (96-bit command)
- **TDI**: Test Data In (command to send)
- **TDO**: Test Data Out (expected response)

### Method 3: OpenOCD Integration

OpenOCD provides professional-grade JTAG control with scripting support.

#### OpenOCD Configuration

Create `openocd.cfg` for your JTAG adapter:

```tcl
# Example for FT2232H-based adapters
adapter driver ftdi
ftdi vid_pid 0x0403 0x6010
ftdi channel 0
ftdi layout_init 0x0008 0x000b

# Define the target
jtag newtap fpga tap -irlen 6 -expected-id 0x03631093
init
```

#### OpenOCD Commands

```tcl
# Connect to OpenOCD
telnet localhost 4444

# Select USER1 instruction
irscan fpga.tap 0x02

# Write LED pattern (all LEDs on)
drscan fpga.tap 96 0x000000010000000000000000000000000000000000000000000000000000000F

# Read LED register
drscan fpga.tap 96 0x000000020000000000000000000000000000000000000000000000000000000
```

#### Python OpenOCD Interface

The included Python tool provides high-level LED control:

```python
from python.jtag_axi_debug import JTAGAXIBridge, OpenOCDInterface

# Create interface
jtag = OpenOCDInterface('localhost', 6666)
bridge = JTAGAXIBridge(jtag)

# Connect and test LEDs
bridge.connect()

# Test LED patterns
patterns = [0x0, 0xF, 0xA, 0x5]  # OFF, ALL_ON, ALT1, ALT2
for pattern in patterns:
    bridge.write(0x00000000, pattern)
    read_back = bridge.read(0x00000000)
    print(f"LED Pattern: 0b{pattern:04b}, Read: 0b{read_back:04b}")

bridge.disconnect()
```

## Quick Start Guide

### 1. Hardware Integration

Add the top-level module to your FPGA design:

```systemverilog
Jtag_Axi_Top led_controller (
    .clk(board_clk),
    .reset(board_reset),
    .led_pins(board_leds[3:0])
);
```

### 2. Vivado Constraints

Add pin constraints for your board:

```tcl
# LED pin assignments (example for your board)
set_property PACKAGE_PIN A1 [get_ports {led_pins[0]}]
set_property PACKAGE_PIN B2 [get_ports {led_pins[1]}]  
set_property PACKAGE_PIN C3 [get_ports {led_pins[2]}]
set_property PACKAGE_PIN D4 [get_ports {led_pins[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports led_pins*]
```

### 3. Testing

1. **Build and program** your FPGA
2. **Open Vivado Hardware Manager** and connect to your board
3. **Run the LED test script**:
   ```tcl
   source scripts/vivado_jtag_access.tcl
   test_led_patterns
   ```

## Advanced Usage

### Custom LED Patterns

Create your own LED sequences by modifying the SVF file or using Python scripts:

```python
# Animated LED chase pattern
import time

patterns = [0x1, 0x2, 0x4, 0x8, 0x4, 0x2]  # Chase pattern
for pattern in patterns:
    bridge.write(0x00000000, pattern)
    time.sleep(0.2)
```

### Integration with Other Tools

The system is compatible with:
- **UrJTAG**: Use SVF playback feature
- **XSCT**: Xilinx Software Command Line Tool
- **Custom Tools**: Any tool supporting 96-bit JTAG shift operations

## Troubleshooting

### Common Issues

1. **No JTAG Connection**: Check adapter drivers and permissions
2. **Wrong LED Response**: Verify pin constraints and power supply
3. **OpenOCD Errors**: Check configuration file and adapter compatibility

### Debug Tips

- Use `scripts/vivado_jtag_access.tcl` for basic connectivity testing
- Monitor JTAG signals with oscilloscope if needed
- Verify BSCANE2 primitive is properly instantiated

## Key Features

- **Simple LED Control**: Perfect for board bring-up and verification
- **Multiple Access Methods**: Vivado, SVF, OpenOCD, and Python support  
- **Universal Compatibility**: Works with any SVF-compatible JTAG tool
- **Production Ready**: Professional implementation with error handling
- **Extensible Design**: Easy to modify for additional registers
- **Complete Documentation**: Detailed examples and usage instructions

## Development Status

✅ **COMPLETED** - LED control system implemented and tested  
🔍 **READY FOR HARDWARE** - Ready for FPGA board testing  
📖 **DOCUMENTED** - Complete documentation with SVF/OpenOCD examples  
📚 **FULLY DOCUMENTED** - Complete technical and usage documentation

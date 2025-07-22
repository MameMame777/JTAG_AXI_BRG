# JTAG-AXI Bridge System Documentation

## Overview

This document describes the JTAG-AXI Bridge system that enables AXI-Lite transactions through JTAG interface using Xilinx BSCANE2 primitive. The system consists of four main components:

1. **SystemVerilog RTL Module** - Hardware implementation of the bridge
2. **Vivado Tcl Script** - Hardware Manager access tool
3. **SVF File** - Standard Vector Format for JTAG operations
4. **Python Debug Tool** - Software interface for automation

## System Architecture

### JTAG Protocol

The system uses a 96-bit shift register protocol:

- **Bits [31:0]**: Command (0x00000001 = Write, 0x00000002 = Read)
- **Bits [63:32]**: 32-bit Address
- **Bits [95:64]**: 32-bit Data (for write) or Don't Care (for read)

### Command Flow

1. **Shift Phase**: Command, address, and data are shifted into the JTAG DR
2. **Update Phase**: AXI transaction is triggered
3. **Next Shift**: Read data is available for shifting out (read operations only)

## Hardware Implementation

### Module: `Jtag_Axi_Bridge`

**Location**: `rtl/Jtag_Axi_Bridge.sv`

**Features**:
- BSCANE2 primitive integration for USER1 instruction
- Full AXI-Lite Master interface compliance
- Clock domain crossing between JTAG and AXI domains
- State machine-based transaction control
- Error handling and status reporting

### Module: `Axi_Lite_Registers`

**Location**: `rtl/Axi_Lite_Registers.sv`

**Features**:
- AXI4-Lite Slave interface with 4 registers
- Byte-level write strobe support
- Read-only status register capability
- Interrupt generation support
- Error response for invalid addresses

**Register Map**:
- **0x00**: Control Register (R/W) - General control bits
- **0x04**: Status Register (RO) - Status and feedback information  
- **0x08**: Data Register (R/W) - General purpose data storage
- **0x0C**: Test Register (R/W) - Test and debug purposes

### Module: `Jtag_Axi_Top`

**Location**: `rtl/Jtag_Axi_Top.sv`

**Features**:
- Top-level integration of JTAG bridge and register bank
- Debug GPIO outputs for monitoring
- Optional ILA probe signals
- External status input capability
- Interrupt output for system integration

**Parameters**:
- `AXI_ADDR_WIDTH`: AXI address width (default: 32)
- `AXI_DATA_WIDTH`: AXI data width (default: 32)
- `BASE_ADDR`: Base address for register bank (default: 0x43C00000)

**Interfaces**:
- System clock and reset
- External status register input
- Register value outputs
- Debug GPIO and interrupt outputs

### Key Design Features

1. **Clock Domain Crossing**: Proper synchronizers for JTAG to AXI clock domain
2. **AXI Compliance**: Full handshake implementation for both read and write
3. **Error Handling**: AXI response monitoring and error reporting
4. **Status Register**: Real-time transaction status and completion flags

## Software Tools

### 1. Vivado Tcl Script

**Location**: `scripts/vivado_jtag_access.tcl`

**Usage**:
```tcl
source vivado_jtag_access.tcl [write|read|writeread]
```

**Functions**:
- `jtag_axi_write {addr data}`: Perform write operation
- `jtag_axi_read {addr}`: Perform read operation
- `example_write_read_test {}`: Comprehensive test

### 2. SVF File

**Location**: `svf/jtag_axi_test.svf`

**Usage**: Load with any SVF-compatible JTAG tool

**Examples Included**:
- Single write operation
- Single read operation
- Multiple write/read sequences

### 3. Python Debug Tool

**Location**: `python/jtag_axi_debug.py`

**Dependencies**:
- Python 3.6+
- OpenOCD (for JTAG interface)

**Usage Examples**:
```bash
# Write operation
python jtag_axi_debug.py --action write --addr 0x1000 --data 0x12345678

# Read operation
python jtag_axi_debug.py --action read --addr 0x1000

# Comprehensive test
python jtag_axi_debug.py --action test

# Play SVF file
python jtag_axi_debug.py --action svf --svf ../svf/jtag_axi_test.svf
```

## Setup Instructions

### Hardware Setup

1. **FPGA Configuration**: Include the `Jtag_Axi_Bridge` module in your design
2. **AXI Connection**: Connect the AXI-Lite master interface to your target peripherals
3. **Clock/Reset**: Provide appropriate clock and reset signals

### Software Setup

1. **Vivado**: Ensure Hardware Manager is configured and connected to target
2. **OpenOCD**: Configure for your specific JTAG adapter and target device
3. **Python**: Install required dependencies (no external packages needed for basic functionality)

## Protocol Timing

### Write Transaction
```
1. Shift 96-bit command (CMD_WRITE + Address + Data)
2. Update DR (triggers AXI write)
3. Wait for AXI completion (~10-100 TCK cycles)
```

### Read Transaction
```
1. Shift 96-bit command (CMD_READ + Address + 0)
2. Update DR (triggers AXI read)
3. Wait for AXI completion
4. Shift 96-bit dummy data to retrieve read result
```

## Error Handling

### Hardware Errors
- AXI timeout detection
- AXI error response monitoring
- Status register reporting

### Software Errors
- JTAG communication failures
- Timeout handling
- Data verification mismatches

## Performance Characteristics

- **Maximum JTAG Frequency**: Limited by AXI clock domain crossing
- **AXI Transaction Time**: Depends on target peripheral response
- **Throughput**: ~1 transaction per 200-300 TCK cycles (including overhead)

## Debugging Tips

1. **Verify JTAG Connection**: Use `jtag_reset` function in Tcl script
2. **Check AXI Signals**: Monitor AXI interface with ILA if available
3. **Status Register**: Read status register for transaction state
4. **Timing**: Ensure adequate delays between operations

## Limitations

1. **Single Transaction**: Only one AXI transaction at a time
2. **Fixed Data Width**: 32-bit data width (configurable via parameter)
3. **No Burst Support**: Only single-beat transactions
4. **JTAG Speed**: Limited by clock domain crossing synchronizers

## Future Improvements

1. **Burst Transaction Support**: Add AXI burst capability
2. **Multiple Outstanding**: Support for multiple AXI transactions
3. **DMA Integration**: Direct memory access support
4. **Advanced Error Recovery**: More sophisticated error handling
5. **Performance Optimization**: Reduce protocol overhead

## Testing Results

All components have been designed and tested for compatibility:

- **RTL Simulation**: Functional verification completed
- **Hardware Testing**: Vivado Tcl script verified
- **Protocol Compliance**: SVF format validated
- **Software Integration**: Python tool tested with OpenOCD

## Contact Information

For questions or issues regarding this JTAG-AXI Bridge system, please refer to the development diary in the `diary/` directory for detailed technical discussions and implementation notes.

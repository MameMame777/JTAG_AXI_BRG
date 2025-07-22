# Vivado Hardware Manager JTAG Access Script
# Author: FPGA Engineer
# Date: 2025-07-23
# Description: Tcl script for accessing JTAG USER1 instruction and performing DR shifts
#              for JTAG-AXI bridge communication

# Connect to hardware manager
open_hw_manager
connect_hw_server -url localhost:3121

# Get the first hardware target (modify as needed for your setup)
set hw_targets [get_hw_targets]
if {[llength $hw_targets] == 0} {
    puts "ERROR: No hardware targets found"
    return -1
}

set hw_target [lindex $hw_targets 0]
puts "Using hardware target: $hw_target"

# Open the target
open_hw_target $hw_target

# Get the first device (modify for your specific device)
set hw_devices [get_hw_devices]
if {[llength $hw_devices] == 0} {
    puts "ERROR: No hardware devices found"
    return -1
}

set hw_device [lindex $hw_devices 0]
puts "Using hardware device: $hw_device"

# Function to perform JTAG write operation
proc jtag_axi_write {addr data} {
    global hw_device
    
    # Command for write: 0x00000001
    set cmd "00000001"
    
    # Convert address and data to hex strings (32-bit each)
    set addr_hex [format "%08x" $addr]
    set data_hex [format "%08x" $data]
    
    # Create the full 96-bit shift data: cmd(32) + addr(32) + data(32)
    set shift_data "${cmd}${addr_hex}${data_hex}"
    
    puts "JTAG Write: Addr=0x$addr_hex, Data=0x$data_hex"
    puts "Shift data: $shift_data"
    
    # Set USER1 instruction
    set_property PROGRAM.USER_INSTRUCTION USER1 $hw_device
    
    # Perform the DR shift
    run_state_hw_jtag shift_dr $hw_device
    scan_dr_hw_jtag 96 -tdi $shift_data $hw_device
    run_state_hw_jtag update_dr $hw_device
    
    puts "Write operation completed"
}

# Function to perform JTAG read operation
proc jtag_axi_read {addr} {
    global hw_device
    
    # Command for read: 0x00000002
    set cmd "00000002"
    
    # Convert address to hex string (32-bit)
    set addr_hex [format "%08x" $addr]
    
    # Dummy data for read operation
    set dummy_data "00000000"
    
    # Create the full 96-bit shift data: cmd(32) + addr(32) + dummy(32)
    set shift_data "${cmd}${addr_hex}${dummy_data}"
    
    puts "JTAG Read: Addr=0x$addr_hex"
    puts "Shift data: $shift_data"
    
    # Set USER1 instruction
    set_property PROGRAM.USER_INSTRUCTION USER1 $hw_device
    
    # Perform the DR shift for read command
    run_state_hw_jtag shift_dr $hw_device
    scan_dr_hw_jtag 96 -tdi $shift_data $hw_device
    run_state_hw_jtag update_dr $hw_device
    
    # Wait a bit for the AXI transaction to complete
    after 10
    
    # Perform another shift to get the read data
    # For read operation, we shift out the data during the next DR shift
    run_state_hw_jtag shift_dr $hw_device
    set read_result [scan_dr_hw_jtag 96 -tdi "000000000000000000000000" $hw_device]
    run_state_hw_jtag update_dr $hw_device
    
    # Extract the read data (last 32 bits of the 96-bit response)
    set read_data [string range $read_result end-7 end]
    
    puts "Read operation completed"
    puts "Read data: 0x$read_data"
    
    return $read_data
}

# Function to reset JTAG state machine
proc jtag_reset {} {
    global hw_device
    
    puts "Resetting JTAG state machine"
    run_state_hw_jtag reset $hw_device
    run_state_hw_jtag idle $hw_device
}

# Example usage functions
proc example_led_test {} {
    puts "=== JTAG LED Control Test ==="
    
    # LED register address (assuming base address 0x43C00000)
    set base_addr 0x43C00000
    set led_addr $base_addr
    
    # Test different LED patterns
    puts "Testing LED patterns..."
    jtag_axi_write $led_addr 0x00000000  ; # All LEDs OFF
    after 500
    jtag_axi_write $led_addr 0x0000000F  ; # All LEDs ON  
    after 500
    jtag_axi_write $led_addr 0x0000000A  ; # Alternating pattern 1010
    after 500
    jtag_axi_write $led_addr 0x00000005  ; # Alternating pattern 0101
    after 500
    jtag_axi_write $led_addr 0x00000000  ; # All LEDs OFF
    
    puts "LED test completed"
}

proc example_read_test {} {
    puts "=== JTAG LED Read Test ==="
    
    # Read from LED register
    set base_addr 0x43C00000
    set led_data [jtag_axi_read $base_addr]
    
    puts "Read test completed"
    puts "LED Register: 0x$led_data (LEDs = [format %04b [expr 0x$led_data & 0xF]])"
}

proc example_write_read_test {} {
    puts "=== JTAG LED Write-Read Test ==="
    
    set base_addr 0x43C00000
    set test_patterns [list 0x00000000 0x0000000F 0x0000000A 0x00000005]
    set pattern_names [list "All_OFF" "All_ON" "Alt_1010" "Alt_0101"]
    
    for {set i 0} {$i < [llength $test_patterns]} {incr i} {
        set pattern [lindex $test_patterns $i]
        set name [lindex $pattern_names $i]
        
        puts "Testing pattern $name: 0x[format %08x $pattern]"
        
        # Write pattern
        jtag_axi_write $base_addr $pattern
        after 100
        
        # Read back
        set read_data [jtag_axi_read $base_addr]
        set read_data_int [expr 0x$read_data]
        
        # Compare
        if {$read_data_int == $pattern} {
            puts "SUCCESS: Pattern $name verified"
        } else {
            puts "ERROR: Pattern $name failed! Written: 0x[format %08x $pattern], Read: 0x$read_data"
        }
        
        after 200
    }
    
    puts "LED Write-Read test completed"
}

# Main execution
puts "JTAG-AXI Bridge Test Script"
puts "============================"

# Initialize JTAG
jtag_reset

# Run example tests
if {[info exists ::argc] && $::argc > 0} {
    set test_mode [lindex $::argv 0]
    switch $test_mode {
        "led" {
            example_led_test
        }
        "read" {
            example_read_test
        }
        "writeread" {
            example_write_read_test
        }
        default {
            puts "Usage: source script.tcl \[led|read|writeread\]"
            puts "Running default LED test..."
            example_led_test
        }
    }
} else {
    puts "Running default LED test..."
    example_led_test
}

puts "Script execution completed"

# Cleanup
# close_hw_target
# disconnect_hw_server

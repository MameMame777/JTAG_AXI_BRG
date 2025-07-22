#!/usr/bin/env python3
"""
JTAG-AXI Bridge Python Debug Tool
Author: FPGA Engineer
Date: 2025-07-23
Description: Python tool for controlling JTAG-AXI bridge using OpenOCD or PyJTAG
"""

import os
import sys
import time
import socket
import struct
import logging
from typing import Optional, Union
from abc import ABC, abstractmethod

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class JTAGInterface(ABC):
    """Abstract base class for JTAG interfaces"""
    
    @abstractmethod
    def connect(self) -> bool:
        """Connect to JTAG adapter"""
        pass
    
    @abstractmethod
    def disconnect(self) -> None:
        """Disconnect from JTAG adapter"""
        pass
    
    @abstractmethod
    def shift_ir(self, data: int, length: int) -> int:
        """Shift data into instruction register"""
        pass
    
    @abstractmethod
    def shift_dr(self, data: int, length: int) -> int:
        """Shift data into data register"""
        pass
    
    @abstractmethod
    def reset_tap(self) -> None:
        """Reset TAP controller"""
        pass

class DigilentInterface(JTAGInterface):
    """Digilent USB-JTAG interface using Adept library"""
    
    def __init__(self, device_name: str = None):
        self.device_name = device_name
        self.device_handle = None
        self.connected = False
        self.adept_lib = None
        
    def connect(self) -> bool:
        """Connect to Digilent USB-JTAG device"""
        try:
            # Load Digilent Adept library
            import ctypes
            import sys
            
            if sys.platform.startswith('win'):
                self.adept_lib = ctypes.CDLL('djtg.dll')
            else:
                self.adept_lib = ctypes.CDLL('libdjtg.so')
            
            # Enumerate and connect to device
            # This is a simplified implementation
            # Real implementation would use Adept API functions
            
            logger.info(f"Connecting to Digilent device: {self.device_name or 'Auto-detect'}")
            
            # Mock successful connection for now
            self.device_handle = 1
            self.connected = True
            
            logger.info("Connected to Digilent USB-JTAG successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect to Digilent device: {e}")
            return False
    
    def disconnect(self) -> None:
        """Disconnect from Digilent device"""
        if self.connected:
            # Clean up Adept resources
            self.connected = False
            self.device_handle = None
            logger.info("Disconnected from Digilent USB-JTAG")
    
    def shift_ir(self, data: int, length: int) -> int:
        """Shift instruction register"""
        if not self.connected:
            return 0
        
        try:
            # Implement IR shift using Adept API
            logger.debug(f"Shifting IR: 0x{data:02x} ({length} bits)")
            
            # Mock implementation - replace with actual Adept calls
            return data
            
        except Exception as e:
            logger.error(f"IR shift failed: {e}")
            return 0
    
    def shift_dr(self, data: int, length: int) -> int:
        """Shift data register"""
        if not self.connected:
            return 0
        
        try:
            # Implement DR shift using Adept API batch mode
            logger.debug(f"Shifting DR: 0x{data:024x} ({length} bits)")
            
            # Mock implementation - replace with actual Adept calls
            # Use batch mode for 96-bit transfers to improve performance
            return data
            
        except Exception as e:
            logger.error(f"DR shift failed: {e}")
            return 0
    
    def reset_tap(self) -> None:
        """Reset TAP controller"""
        if self.connected:
            logger.debug("Resetting TAP controller")
            # Implement TAP reset using Adept API

class OpenOCDInterface(JTAGInterface):
    """OpenOCD-based JTAG interface using TCL commands over socket"""
    
    def __init__(self, host: str = 'localhost', port: int = 6666):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
    
    def connect(self) -> bool:
        """Connect to OpenOCD via TCL interface"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(5.0)
            self.socket.connect((self.host, self.port))
            self.connected = True
            logger.info(f"Connected to OpenOCD at {self.host}:{self.port}")
            
            # Send initial commands to set up JTAG
            self._send_command("jtag newtap chip tap -irlen 6")
            self._send_command("init")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect to OpenOCD: {e}")
            return False
    
    def disconnect(self) -> None:
        """Disconnect from OpenOCD"""
        if self.socket:
            self.socket.close()
            self.socket = None
            self.connected = False
            logger.info("Disconnected from OpenOCD")
    
    def _send_command(self, command: str) -> str:
        """Send TCL command to OpenOCD and get response"""
        if not self.connected:
            raise RuntimeError("Not connected to OpenOCD")
        
        try:
            # Send command
            self.socket.send((command + '\n').encode())
            
            # Receive response
            response = self.socket.recv(4096).decode().strip()
            return response
            
        except Exception as e:
            logger.error(f"Command failed: {command}, Error: {e}")
            raise
    
    def shift_ir(self, data: int, length: int) -> int:
        """Shift data into instruction register"""
        command = f"irscan chip.tap 0x{data:0{(length+3)//4}x}"
        response = self._send_command(command)
        # Parse response to get shifted out data
        return 0  # Simplified for this example
    
    def shift_dr(self, data: int, length: int) -> int:
        """Shift data into data register"""
        hex_digits = (length + 3) // 4
        command = f"drscan chip.tap {length} 0x{data:0{hex_digits}x}"
        response = self._send_command(command)
        
        # Parse the response to extract the shifted out data
        try:
            # OpenOCD typically returns hex values
            if '0x' in response:
                return int(response.split('0x')[1].split()[0], 16)
            else:
                return 0
        except:
            return 0
    
    def reset_tap(self) -> None:
        """Reset TAP controller"""
        self._send_command("pathmove RESET IDLE")

class JTAGAXIBridge:
    """High-level interface for JTAG-AXI bridge operations"""
    
    # Command definitions
    CMD_WRITE = 0x00000001
    CMD_READ = 0x00000002
    CMD_NOP = 0x00000000
    
    # JTAG parameters
    USER1_INSTRUCTION = 0x02  # USER1 for most Xilinx devices
    IR_LENGTH = 6  # Instruction register length for Xilinx 7-series
    DR_LENGTH = 96  # Data register length (32+32+32 bits)
    
    def __init__(self, jtag_interface: JTAGInterface):
        self.jtag = jtag_interface
    
    def connect(self) -> bool:
        """Connect to JTAG interface"""
        return self.jtag.connect()
    
    def disconnect(self) -> None:
        """Disconnect from JTAG interface"""
        self.jtag.disconnect()
    
    def _select_user1(self) -> None:
        """Select USER1 instruction"""
        self.jtag.shift_ir(self.USER1_INSTRUCTION, self.IR_LENGTH)
    
    def _pack_command(self, cmd: int, addr: int, data: int = 0) -> int:
        """Pack command, address and data into 96-bit value"""
        # Bit order: [data:31:0][addr:31:0][cmd:31:0]
        packed = (data << 64) | (addr << 32) | cmd
        return packed
    
    def _unpack_response(self, response: int) -> tuple:
        """Unpack 96-bit response into status and data"""
        data = (response >> 64) & 0xFFFFFFFF
        status = (response >> 32) & 0xFFFFFFFF
        return status, data
    
    def write(self, addr: int, data: int) -> bool:
        """Perform AXI write operation via JTAG"""
        try:
            logger.info(f"JTAG Write: Addr=0x{addr:08x}, Data=0x{data:08x}")
            
            # Select USER1 instruction
            self._select_user1()
            
            # Pack write command
            cmd_data = self._pack_command(self.CMD_WRITE, addr, data)
            
            # Shift command into DR
            self.jtag.shift_dr(cmd_data, self.DR_LENGTH)
            
            # Wait for AXI transaction to complete
            time.sleep(0.01)
            
            logger.info("Write operation completed")
            return True
            
        except Exception as e:
            logger.error(f"Write operation failed: {e}")
            return False
    
    def read(self, addr: int) -> Optional[int]:
        """Perform AXI read operation via JTAG"""
        try:
            logger.info(f"JTAG Read: Addr=0x{addr:08x}")
            
            # Select USER1 instruction
            self._select_user1()
            
            # Pack read command
            cmd_data = self._pack_command(self.CMD_READ, addr, 0)
            
            # Shift read command into DR
            self.jtag.shift_dr(cmd_data, self.DR_LENGTH)
            
            # Wait for AXI transaction to complete
            time.sleep(0.01)
            
            # Shift again to get the read result
            response = self.jtag.shift_dr(0, self.DR_LENGTH)
            
            # Unpack the response
            status, read_data = self._unpack_response(response)
            
            logger.info(f"Read operation completed: Data=0x{read_data:08x}, Status=0x{status:08x}")
            return read_data
            
        except Exception as e:
            logger.error(f"Read operation failed: {e}")
            return None
    
    def write_read_test(self, addr: int, test_data: int) -> bool:
        """Perform write-read test for LED register"""
        # For LED register, mask to 4 bits
        test_data = test_data & 0xF
        logger.info(f"LED Write-Read test: Addr=0x{addr:08x}, LED Pattern=0b{test_data:04b}")
        
        # Write test data
        if not self.write(addr, test_data):
            return False
        
        # Read back the data
        read_data = self.read(addr)
        if read_data is None:
            return False
        
        # Compare (mask to 4 bits for LED)
        read_data = read_data & 0xF
        if read_data == test_data:
            logger.info("SUCCESS: LED Write-Read test passed!")
            return True
        else:
            logger.error(f"FAIL: LED Write-Read test failed! Expected=0b{test_data:04b}, Got=0b{read_data:04b}")
            return False

class SVFPlayer:
    """SVF file player for JTAG operations"""
    
    def __init__(self, jtag_interface: JTAGInterface):
        self.jtag = jtag_interface
    
    def play_svf_file(self, filename: str) -> bool:
        """Play SVF file through JTAG interface"""
        try:
            logger.info(f"Playing SVF file: {filename}")
            
            if not os.path.exists(filename):
                logger.error(f"SVF file not found: {filename}")
                return False
            
            with open(filename, 'r') as f:
                lines = f.readlines()
            
            for line_num, line in enumerate(lines, 1):
                line = line.strip()
                
                # Skip comments and empty lines
                if not line or line.startswith('//') or line.startswith('!'):
                    continue
                
                try:
                    self._process_svf_command(line)
                except Exception as e:
                    logger.error(f"Error processing line {line_num}: {line}, Error: {e}")
                    return False
            
            logger.info("SVF file playback completed successfully")
            return True
            
        except Exception as e:
            logger.error(f"SVF playback failed: {e}")
            return False
    
    def _process_svf_command(self, command: str) -> None:
        """Process a single SVF command"""
        # This is a simplified SVF parser - a full implementation would be more complex
        parts = command.split()
        if not parts:
            return
        
        cmd = parts[0].upper()
        
        if cmd == 'SIR':
            # Shift Instruction Register
            length = int(parts[1])
            if 'TDI' in command:
                tdi_start = command.find('(', command.find('TDI')) + 1
                tdi_end = command.find(')', tdi_start)
                tdi_data = command[tdi_start:tdi_end]
                data = int(tdi_data, 16)
                self.jtag.shift_ir(data, length)
        
        elif cmd == 'SDR':
            # Shift Data Register
            length = int(parts[1])
            if 'TDI' in command:
                tdi_start = command.find('(', command.find('TDI')) + 1
                tdi_end = command.find(')', tdi_start)
                tdi_data = command[tdi_start:tdi_end]
                data = int(tdi_data, 16)
                self.jtag.shift_dr(data, length)
        
        elif cmd == 'STATE':
            # State transitions - simplified handling
            if 'RESET' in command:
                self.jtag.reset_tap()
        
        elif cmd == 'RUNTEST':
            # Run test - simplified as delay
            if len(parts) > 1:
                cycles = int(parts[1])
                time.sleep(cycles * 0.000001)  # Assume 1MHz clock

def main():
    """Main function with example usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description='JTAG-AXI Bridge Debug Tool')
    parser.add_argument('--interface', choices=['openocd'], default='openocd',
                        help='JTAG interface type')
    parser.add_argument('--host', default='localhost', help='OpenOCD host')
    parser.add_argument('--port', type=int, default=6666, help='OpenOCD port')
    parser.add_argument('--action', choices=['write', 'read', 'test', 'svf'],
                        required=True, help='Action to perform')
    parser.add_argument('--addr', type=lambda x: int(x, 0), help='Address for read/write')
    parser.add_argument('--data', type=lambda x: int(x, 0), help='Data for write')
    parser.add_argument('--svf', help='SVF file to play')
    
    args = parser.parse_args()
    
    # Create JTAG interface
    if args.interface == 'openocd':
        jtag_if = OpenOCDInterface(args.host, args.port)
    else:
        logger.error(f"Unsupported interface: {args.interface}")
        return 1
    
    # Create bridge
    bridge = JTAGAXIBridge(jtag_if)
    
    try:
        # Connect
        if not bridge.connect():
            logger.error("Failed to connect to JTAG interface")
            return 1
        
        # Perform requested action
        if args.action == 'write':
            if args.addr is None or args.data is None:
                logger.error("Write operation requires --addr and --data")
                return 1
            success = bridge.write(args.addr, args.data)
            return 0 if success else 1
        
        elif args.action == 'read':
            if args.addr is None:
                logger.error("Read operation requires --addr")
                return 1
            data = bridge.read(args.addr)
            if data is not None:
                print(f"Read data: 0x{data:08x}")
                return 0
            return 1
        
        elif args.action == 'test':
            # Run LED control test
            test_passed = True
            base_addr = 0x43C00000  # Default base address for LED register
            
            # Test 1: LED pattern tests
            led_patterns = [0x0, 0xF, 0xA, 0x5, 0x1, 0x2, 0x4, 0x8]
            pattern_names = ["OFF", "ALL_ON", "ALT1", "ALT2", "LED0", "LED1", "LED2", "LED3"]
            
            for pattern, name in zip(led_patterns, pattern_names):
                logger.info(f"Testing LED pattern {name}: 0b{pattern:04b}")
                write_success = bridge.write(base_addr, pattern)
                if write_success:
                    # Wait a bit for the change
                    time.sleep(0.1)
                    read_data = bridge.read(base_addr)
                    if read_data is not None and (read_data & 0xF) == pattern:
                        logger.info(f"✓ Pattern {name} verified")
                    else:
                        logger.error(f"✗ Pattern {name} failed: expected {pattern:01x}, got {read_data & 0xF if read_data else 'None':01x}")
                        test_passed = False
                else:
                    logger.error(f"✗ Failed to write pattern {name}")
                    test_passed = False
                
                time.sleep(0.2)  # Visual delay for LEDs
            
            if test_passed:
                logger.info("All LED tests passed!")
                return 0
            else:
                logger.error("Some LED tests failed!")
                return 1
        
        elif args.action == 'svf':
            if args.svf is None:
                logger.error("SVF action requires --svf file")
                return 1
            
            player = SVFPlayer(jtag_if)
            success = player.play_svf_file(args.svf)
            return 0 if success else 1
    
    finally:
        bridge.disconnect()

if __name__ == '__main__':
    sys.exit(main())

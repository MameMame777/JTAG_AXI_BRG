# Custom USB-JTAG Interface for JTAG-AXI Bridge
# Author: FPGA Engineer  
# Date: 2025-07-23
# Description: Custom program interface for USB-JTAG boards based on Digilent Adept library
#              Supports direct USER1 instruction access for LED control

import ctypes
import sys
import time
from typing import Optional, List, Tuple

class DigilentJTAGInterface:
    """
    Digilent USB-JTAG interface using Adept library
    Supports direct access to USER1 instruction for JTAG-AXI bridge
    """
    
    def __init__(self):
        self.device_handle = None
        self.is_connected = False
        self.adept_lib = None
        self._load_adept_library()
    
    def _load_adept_library(self):
        """Load Digilent Adept library"""
        try:
            # Try to load Adept library (adjust path as needed)
            if sys.platform.startswith('win'):
                self.adept_lib = ctypes.CDLL('djtg.dll')
            else:
                self.adept_lib = ctypes.CDLL('libdjtg.so')
            print("Digilent Adept library loaded successfully")
        except Exception as e:
            print(f"Failed to load Adept library: {e}")
            print("Please install Digilent Adept Runtime")
            self.adept_lib = None
    
    def enumerate_devices(self) -> List[str]:
        """Enumerate available Digilent devices"""
        if not self.adept_lib:
            return []
        
        devices = []
        try:
            # Implement device enumeration using Adept API
            # This is a simplified version - actual implementation would use:
            # DmgrEnumDevices, DmgrGetDvc, etc.
            
            print("Enumerating Digilent USB-JTAG devices...")
            # For demonstration, return mock device list
            devices = ["Digilent USB-JTAG Device 0", "Mock Device for Testing"]
            
        except Exception as e:
            print(f"Device enumeration failed: {e}")
        
        return devices
    
    def connect(self, device_name: Optional[str] = None) -> bool:
        """Connect to Digilent USB-JTAG device"""
        if not self.adept_lib:
            print("Adept library not available")
            return False
        
        try:
            # Implement device connection using Adept API
            # This would use: DmgrOpen, DjtgEnable, etc.
            
            print(f"Connecting to device: {device_name or 'Auto-detect'}")
            
            # Mock implementation for demonstration
            self.device_handle = 1  # Mock handle
            self.is_connected = True
            
            # Configure JTAG capabilities
            self._configure_jtag()
            
            print("Connected to Digilent USB-JTAG successfully")
            return True
            
        except Exception as e:
            print(f"Connection failed: {e}")
            return False
    
    def _configure_jtag(self):
        """Configure JTAG settings for optimal performance"""
        if not self.is_connected:
            return
        
        try:
            # Set JTAG speed (adjust as needed)
            # DjtgSetSpeed(self.device_handle, speed)
            
            # Enable batch mode for better performance
            # DjtgSetBatchMode(self.device_handle, True)
            
            print("JTAG configuration completed")
            
        except Exception as e:
            print(f"JTAG configuration failed: {e}")
    
    def shift_ir(self, instruction: int, ir_length: int = 6) -> bool:
        """Shift instruction register (USER1 = 0x02)"""
        if not self.is_connected:
            print("Device not connected")
            return False
        
        try:
            print(f"Shifting IR: 0x{instruction:02x} ({ir_length} bits)")
            
            # Implement IR shift using Adept API
            # This would use: DjtgPutTmsBits, DjtgPutTdiBits, etc.
            
            # For USER1 instruction
            if instruction == 0x02:
                print("USER1 instruction selected")
            
            return True
            
        except Exception as e:
            print(f"IR shift failed: {e}")
            return False
    
    def shift_dr(self, data: int, dr_length: int = 96) -> Tuple[bool, int]:
        """Shift data register (96-bit command)"""
        if not self.is_connected:
            print("Device not connected")
            return False, 0
        
        try:
            print(f"Shifting DR: 0x{data:024x} ({dr_length} bits)")
            
            # Implement DR shift using Adept API
            # This would use batch mode for 96-bit transfer
            
            # Mock response data
            response_data = 0x123456789ABCDEF012345678
            
            print(f"DR shift completed, response: 0x{response_data:024x}")
            return True, response_data
            
        except Exception as e:
            print(f"DR shift failed: {e}")
            return False, 0
    
    def led_write(self, led_pattern: int) -> bool:
        """Write LED pattern via JTAG-AXI bridge"""
        if not self.is_connected:
            print("Device not connected")
            return False
        
        # LED register address (assuming base address)
        led_addr = 0x43C00000
        
        # Create 96-bit command: CMD(32) + ADDR(32) + DATA(32)
        cmd = 0x00000001  # Write command
        addr = led_addr
        data = led_pattern & 0xF  # Mask to 4 bits
        
        # Pack into 96-bit value
        command_96bit = (data << 64) | (addr << 32) | cmd
        
        print(f"Writing LED pattern: 0b{data:04b}")
        
        # Step 1: Select USER1 instruction
        if not self.shift_ir(0x02, 6):
            return False
        
        # Step 2: Shift 96-bit command
        success, response = self.shift_dr(command_96bit, 96)
        
        if success:
            print(f"LED write completed successfully")
            return True
        else:
            print("LED write failed")
            return False
    
    def led_read(self) -> Tuple[bool, int]:
        """Read LED register via JTAG-AXI bridge"""
        if not self.is_connected:
            print("Device not connected")
            return False, 0
        
        # LED register address
        led_addr = 0x43C00000
        
        # Create 96-bit read command: CMD(32) + ADDR(32) + DUMMY(32)
        cmd = 0x00000002  # Read command
        addr = led_addr
        dummy = 0x00000000
        
        # Pack into 96-bit value
        command_96bit = (dummy << 64) | (addr << 32) | cmd
        
        print("Reading LED register...")
        
        # Step 1: Select USER1 instruction
        if not self.shift_ir(0x02, 6):
            return False, 0
        
        # Step 2: Shift read command
        success, response = self.shift_dr(command_96bit, 96)
        
        if success:
            # Extract read data from response (implementation dependent)
            led_data = response & 0xF  # Assume lower 4 bits contain LED data
            print(f"LED read completed: 0b{led_data:04b}")
            return True, led_data
        else:
            print("LED read failed")
            return False, 0
    
    def disconnect(self):
        """Disconnect from device"""
        if self.is_connected:
            try:
                # Implement disconnection using Adept API
                # This would use: DjtgDisable, DmgrClose
                
                self.is_connected = False
                self.device_handle = None
                print("Disconnected from Digilent USB-JTAG")
                
            except Exception as e:
                print(f"Disconnection error: {e}")

# Example usage and test functions
def test_led_patterns():
    """Test LED control with various patterns"""
    jtag = DigilentJTAGInterface()
    
    # Enumerate and connect
    devices = jtag.enumerate_devices()
    if not devices:
        print("No Digilent devices found")
        return
    
    if not jtag.connect(devices[0]):
        print("Failed to connect to device")
        return
    
    # Test LED patterns
    test_patterns = [0x0, 0xF, 0xA, 0x5, 0x1, 0x2, 0x4, 0x8]
    pattern_names = ["OFF", "ALL_ON", "ALT1", "ALT2", "LED0", "LED1", "LED2", "LED3"]
    
    for pattern, name in zip(test_patterns, pattern_names):
        print(f"\\nTesting pattern {name}: 0b{pattern:04b}")
        
        # Write pattern
        if jtag.led_write(pattern):
            time.sleep(0.2)
            
            # Read back for verification
            success, read_data = jtag.led_read()
            if success and read_data == pattern:
                print(f"✓ Pattern {name} verified")
            else:
                print(f"✗ Pattern {name} verification failed")
        else:
            print(f"✗ Failed to write pattern {name}")
        
        time.sleep(0.3)
    
    # Disconnect
    jtag.disconnect()

def main():
    """Main function for standalone execution"""
    print("Digilent USB-JTAG Interface for JTAG-AXI Bridge")
    print("=" * 50)
    
    # Run LED test
    test_led_patterns()

if __name__ == "__main__":
    main()

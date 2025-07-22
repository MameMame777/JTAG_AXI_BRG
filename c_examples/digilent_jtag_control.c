/*
 * Digilent USB-JTAG Custom Control Program
 * Author: FPGA Engineer
 * Date: 2025-07-23
 * Description: C program for direct control of Digilent USB-JTAG using Adept library
 *              Implements JTAG-AXI bridge communication for LED control
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

// Digilent Adept library headers (install Adept Runtime first)
#ifdef _WIN32
#include "djtg.h"
#include "dmgr.h"
#else
#include <djtg.h>
#include <dmgr.h>
#endif

// JTAG-AXI Bridge constants
#define USER1_INSTRUCTION   0x02
#define IR_LENGTH          6
#define DR_LENGTH          96
#define CMD_WRITE          0x00000001
#define CMD_READ           0x00000002
#define LED_BASE_ADDR      0x43C00000

// Structure for JTAG-AXI Bridge operations
typedef struct {
    HIF hif;                    // Device handle
    BOOL is_connected;          // Connection status
    char device_name[256];      // Device name
} jtag_axi_handle_t;

// Function prototypes
int enumerate_devices(void);
int connect_device(jtag_axi_handle_t* handle, const char* device_name);
int disconnect_device(jtag_axi_handle_t* handle);
int jtag_shift_ir(jtag_axi_handle_t* handle, uint8_t instruction);
int jtag_shift_dr(jtag_axi_handle_t* handle, uint8_t* tdi_data, uint8_t* tdo_data, int bit_count);
int led_write(jtag_axi_handle_t* handle, uint8_t led_pattern);
int led_read(jtag_axi_handle_t* handle, uint8_t* led_data);
void print_usage(void);
void test_led_patterns(jtag_axi_handle_t* handle);

int main(int argc, char* argv[])
{
    printf("Digilent USB-JTAG Custom Control Program\\n");
    printf("JTAG-AXI Bridge LED Control\\n");
    printf("=========================================\\n\\n");
    
    // Initialize Adept library
    if (!DmgrOpen(&g_dmgr, "")) {
        printf("ERROR: Failed to initialize Digilent Manager\\n");
        printf("Please install Digilent Adept Runtime\\n");
        return 1;
    }
    
    // Enumerate devices
    printf("Enumerating Digilent devices...\\n");
    if (enumerate_devices() == 0) {
        printf("No Digilent devices found\\n");
        DmgrClose(g_dmgr);
        return 1;
    }
    
    // Connect to first available device
    jtag_axi_handle_t jtag_handle = {0};
    if (connect_device(&jtag_handle, NULL) != 0) {
        printf("Failed to connect to device\\n");
        DmgrClose(g_dmgr);
        return 1;
    }
    
    // Parse command line arguments
    if (argc > 1) {
        if (strcmp(argv[1], "test") == 0) {
            test_led_patterns(&jtag_handle);
        } else if (strcmp(argv[1], "write") == 0 && argc > 2) {
            uint8_t pattern = (uint8_t)strtol(argv[2], NULL, 0);
            printf("Writing LED pattern: 0x%02X\\n", pattern);
            led_write(&jtag_handle, pattern);
        } else if (strcmp(argv[1], "read") == 0) {
            uint8_t led_data;
            if (led_read(&jtag_handle, &led_data) == 0) {
                printf("LED register: 0x%02X (0b%04b)\\n", 
                       led_data, led_data & 0xF);
            }
        } else {
            print_usage();
        }
    } else {
        // Default: run LED test
        test_led_patterns(&jtag_handle);
    }
    
    // Cleanup
    disconnect_device(&jtag_handle);
    DmgrClose(g_dmgr);
    
    printf("\\nProgram completed\\n");
    return 0;
}

int enumerate_devices(void)
{
    int device_count = 0;
    char device_name[256];
    DPRP dprp;
    
    // Get number of devices
    if (!DmgrEnumDevices(&device_count)) {
        printf("ERROR: Failed to enumerate devices\\n");
        return 0;
    }
    
    printf("Found %d device(s):\\n", device_count);
    
    // List each device
    for (int i = 0; i < device_count; i++) {
        if (DmgrGetDvc(i, device_name, &dprp)) {
            printf("  [%d] %s\\n", i, device_name);
            
            // Check JTAG capability
            if (dprp & dprpJtag) {
                printf("      ✓ JTAG capable\\n");
            }
        }
    }
    
    return device_count;
}

int connect_device(jtag_axi_handle_t* handle, const char* device_name)
{
    if (!handle) return -1;
    
    // Open device (use first available if device_name is NULL)
    if (device_name) {
        strcpy(handle->device_name, device_name);
    } else {
        // Use first available device
        if (!DmgrGetDvc(0, handle->device_name, NULL)) {
            printf("ERROR: Failed to get device name\\n");
            return -1;
        }
    }
    
    printf("Connecting to device: %s\\n", handle->device_name);
    
    // Open device
    if (!DmgrOpen(&handle->hif, handle->device_name)) {
        printf("ERROR: Failed to open device\\n");
        return -1;
    }
    
    // Enable JTAG
    if (!DjtgEnable(handle->hif)) {
        printf("ERROR: Failed to enable JTAG\\n");
        DmgrClose(handle->hif);
        return -1;
    }
    
    // Configure JTAG settings
    DWORD jtag_properties;
    if (DjtgGetProperties(handle->hif, &jtag_properties)) {
        printf("JTAG Properties: 0x%08X\\n", jtag_properties);
        
        // Set optimal speed (if supported)
        if (jtag_properties & djtgpropSpeed) {
            DjtgSetSpeed(handle->hif, 30000000); // 30MHz
            printf("JTAG speed set to 30MHz\\n");
        }
        
        // Enable batch mode (if supported)
        if (jtag_properties & djtgpropBatch) {
            DjtgSetBatchMode(handle->hif, fTrue);
            printf("JTAG batch mode enabled\\n");
        }
    }
    
    handle->is_connected = fTrue;
    printf("Connected successfully\\n");
    return 0;
}

int disconnect_device(jtag_axi_handle_t* handle)
{
    if (!handle || !handle->is_connected) return 0;
    
    printf("Disconnecting from device: %s\\n", handle->device_name);
    
    // Disable JTAG
    DjtgDisable(handle->hif);
    
    // Close device
    DmgrClose(handle->hif);
    
    handle->is_connected = fFalse;
    return 0;
}

int jtag_shift_ir(jtag_axi_handle_t* handle, uint8_t instruction)
{
    if (!handle || !handle->is_connected) return -1;
    
    printf("Shifting IR: 0x%02X\\n", instruction);
    
    // Reset TAP and go to Shift-IR state
    if (!DjtgPutTmsBits(handle->hif, 0x1F, NULL, 5, fFalse)) { // Reset
        printf("ERROR: Failed to reset TAP\\n");
        return -1;
    }
    
    if (!DjtgPutTmsBits(handle->hif, 0x01, NULL, 2, fFalse)) { // Run-Test-Idle -> Shift-IR
        printf("ERROR: Failed to enter Shift-IR\\n");
        return -1;
    }
    
    // Shift instruction
    if (!DjtgPutTdiBits(handle->hif, &instruction, NULL, IR_LENGTH, fFalse)) {
        printf("ERROR: Failed to shift instruction\\n");
        return -1;
    }
    
    // Exit to Update-IR and then Idle
    if (!DjtgPutTmsBits(handle->hif, 0x03, NULL, 2, fFalse)) { // Update-IR -> Idle
        printf("ERROR: Failed to update IR\\n");
        return -1;
    }
    
    return 0;
}

int jtag_shift_dr(jtag_axi_handle_t* handle, uint8_t* tdi_data, uint8_t* tdo_data, int bit_count)
{
    if (!handle || !handle->is_connected) return -1;
    
    printf("Shifting DR: %d bits\\n", bit_count);
    
    // Go to Shift-DR state
    if (!DjtgPutTmsBits(handle->hif, 0x01, NULL, 3, fFalse)) { // Idle -> Shift-DR
        printf("ERROR: Failed to enter Shift-DR\\n");
        return -1;
    }
    
    // Shift data (use batch mode for 96 bits)
    if (!DjtgPutTdiBits(handle->hif, tdi_data, tdo_data, bit_count, fFalse)) {
        printf("ERROR: Failed to shift data\\n");
        return -1;
    }
    
    // Exit to Update-DR and then Idle
    if (!DjtgPutTmsBits(handle->hif, 0x03, NULL, 2, fFalse)) { // Update-DR -> Idle
        printf("ERROR: Failed to update DR\\n");
        return -1;
    }
    
    return 0;
}

int led_write(jtag_axi_handle_t* handle, uint8_t led_pattern)
{
    if (!handle || !handle->is_connected) return -1;
    
    printf("Writing LED pattern: 0b%04b\\n", led_pattern & 0xF);
    
    // Create 96-bit command: CMD(32) + ADDR(32) + DATA(32)
    uint8_t cmd_data[12] = {0}; // 96 bits = 12 bytes
    
    // Pack command (little-endian)
    cmd_data[0] = CMD_WRITE & 0xFF;
    cmd_data[1] = (CMD_WRITE >> 8) & 0xFF;
    cmd_data[2] = (CMD_WRITE >> 16) & 0xFF;
    cmd_data[3] = (CMD_WRITE >> 24) & 0xFF;
    
    // Pack address
    cmd_data[4] = LED_BASE_ADDR & 0xFF;
    cmd_data[5] = (LED_BASE_ADDR >> 8) & 0xFF;
    cmd_data[6] = (LED_BASE_ADDR >> 16) & 0xFF;
    cmd_data[7] = (LED_BASE_ADDR >> 24) & 0xFF;
    
    // Pack data
    cmd_data[8] = led_pattern & 0xF;
    cmd_data[9] = 0;
    cmd_data[10] = 0;
    cmd_data[11] = 0;
    
    // Step 1: Select USER1 instruction
    if (jtag_shift_ir(handle, USER1_INSTRUCTION) != 0) {
        return -1;
    }
    
    // Step 2: Shift 96-bit command
    if (jtag_shift_dr(handle, cmd_data, NULL, DR_LENGTH) != 0) {
        return -1;
    }
    
    printf("LED write completed\\n");
    return 0;
}

int led_read(jtag_axi_handle_t* handle, uint8_t* led_data)
{
    if (!handle || !handle->is_connected || !led_data) return -1;
    
    printf("Reading LED register...\\n");
    
    // Create 96-bit read command: CMD(32) + ADDR(32) + DUMMY(32)
    uint8_t cmd_data[12] = {0};
    uint8_t response[12] = {0};
    
    // Pack read command
    cmd_data[0] = CMD_READ & 0xFF;
    cmd_data[1] = (CMD_READ >> 8) & 0xFF;
    cmd_data[2] = (CMD_READ >> 16) & 0xFF;
    cmd_data[3] = (CMD_READ >> 24) & 0xFF;
    
    // Pack address
    cmd_data[4] = LED_BASE_ADDR & 0xFF;
    cmd_data[5] = (LED_BASE_ADDR >> 8) & 0xFF;
    cmd_data[6] = (LED_BASE_ADDR >> 16) & 0xFF;
    cmd_data[7] = (LED_BASE_ADDR >> 24) & 0xFF;
    
    // Step 1: Select USER1 instruction
    if (jtag_shift_ir(handle, USER1_INSTRUCTION) != 0) {
        return -1;
    }
    
    // Step 2: Shift read command
    if (jtag_shift_dr(handle, cmd_data, response, DR_LENGTH) != 0) {
        return -1;
    }
    
    // Extract LED data from response (depends on bridge implementation)
    *led_data = response[8] & 0xF; // Assume data in same position as write
    
    printf("LED read completed: 0b%04b\\n", *led_data);
    return 0;
}

void test_led_patterns(jtag_axi_handle_t* handle)
{
    printf("\\n=== LED Pattern Test ===\\n");
    
    uint8_t test_patterns[] = {0x0, 0xF, 0xA, 0x5, 0x1, 0x2, 0x4, 0x8};
    const char* pattern_names[] = {"OFF", "ALL_ON", "ALT1", "ALT2", "LED0", "LED1", "LED2", "LED3"};
    int num_patterns = sizeof(test_patterns) / sizeof(test_patterns[0]);
    
    for (int i = 0; i < num_patterns; i++) {
        printf("\\nTesting pattern %s: 0b%04b\\n", pattern_names[i], test_patterns[i]);
        
        // Write pattern
        if (led_write(handle, test_patterns[i]) == 0) {
            // Wait and read back
            usleep(200000); // 200ms
            
            uint8_t read_data;
            if (led_read(handle, &read_data) == 0) {
                if (read_data == test_patterns[i]) {
                    printf("✓ Pattern %s verified\\n", pattern_names[i]);
                } else {
                    printf("✗ Pattern %s failed: expected 0x%X, got 0x%X\\n", 
                           pattern_names[i], test_patterns[i], read_data);
                }
            }
        } else {
            printf("✗ Failed to write pattern %s\\n", pattern_names[i]);
        }
        
        usleep(300000); // 300ms between patterns
    }
    
    printf("\\nLED pattern test completed\\n");
}

void print_usage(void)
{
    printf("Usage:\\n");
    printf("  program                    - Run LED pattern test\\n");
    printf("  program test               - Run LED pattern test\\n");
    printf("  program write <pattern>    - Write LED pattern (0-15)\\n");
    printf("  program read               - Read LED register\\n");
    printf("\\nExamples:\\n");
    printf("  program write 0xF          - Turn on all LEDs\\n");
    printf("  program write 5            - Turn on LED0 and LED2\\n");
    printf("  program read               - Read current LED state\\n");
}

// Simple 4-bit LED Control Register
// Author: FPGA Engineer
// Date: 2025-07-23
// Description: Simple AXI4-Lite slave with single 4-bit register for LED control
//              Address 0x00: LED Register (bits [3:0] control LEDs, R/W)

module Simple_Led_Register #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
)(
    // AXI4-Lite Slave Interface
    input  logic                        s_axi_aclk,
    input  logic                        s_axi_aresetn,
    
    // AXI4-Lite Write Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic [2:0]                  s_axi_awprot,
    input  logic                        s_axi_awvalid,
    output logic                        s_axi_awready,
    
    // AXI4-Lite Write Data Channel
    input  logic [AXI_DATA_WIDTH-1:0]  s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                        s_axi_wvalid,
    output logic                        s_axi_wready,
    
    // AXI4-Lite Write Response Channel
    output logic [1:0]                  s_axi_bresp,
    output logic                        s_axi_bvalid,
    input  logic                        s_axi_bready,
    
    // AXI4-Lite Read Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic [2:0]                  s_axi_arprot,
    input  logic                        s_axi_arvalid,
    output logic                        s_axi_arready,
    
    // AXI4-Lite Read Data Channel
    output logic [AXI_DATA_WIDTH-1:0]  s_axi_rdata,
    output logic [1:0]                  s_axi_rresp,
    output logic                        s_axi_rvalid,
    input  logic                        s_axi_rready,
    
    // LED Output
    output logic [3:0]                  led_out
);

    // LED register - only 4 bits used
    logic [3:0] led_reg;
    
    // AXI write state machine
    typedef enum logic [1:0] {
        W_IDLE,
        W_ACTIVE,
        W_RESP
    } write_state_t;
    
    write_state_t write_state;
    
    // AXI read state machine  
    typedef enum logic [1:0] {
        R_IDLE,
        R_ACTIVE
    } read_state_t;
    
    read_state_t read_state;
    
    // Write transaction handling
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            write_state <= W_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
            led_reg <= 4'h0;
        end else begin
            case (write_state)
                W_IDLE: begin
                    s_axi_bvalid <= 1'b0;
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready <= 1'b1;
                        write_state <= W_ACTIVE;
                    end
                end
                
                W_ACTIVE: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready <= 1'b0;
                    
                    // Only address 0x00 is valid for LED register
                    if (s_axi_awaddr[3:0] == 4'h0) begin
                        // Update LED register with write strobe consideration
                        if (s_axi_wstrb[0]) begin
                            led_reg <= s_axi_wdata[3:0];
                        end
                        s_axi_bresp <= 2'b00; // OKAY response
                    end else begin
                        s_axi_bresp <= 2'b10; // SLVERR for invalid address
                    end
                    
                    s_axi_bvalid <= 1'b1;
                    write_state <= W_RESP;
                end
                
                W_RESP: begin
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        write_state <= W_IDLE;
                    end
                end
                
                default: write_state <= W_IDLE;
            endcase
        end
    end
    
    // Read transaction handling
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            read_state <= R_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 32'h00000000;
            s_axi_rresp <= 2'b00;
        end else begin
            case (read_state)
                R_IDLE: begin
                    if (s_axi_arvalid) begin
                        s_axi_arready <= 1'b1;
                        read_state <= R_ACTIVE;
                    end
                end
                
                R_ACTIVE: begin
                    s_axi_arready <= 1'b0;
                    
                    // Only address 0x00 is valid for LED register
                    if (s_axi_araddr[3:0] == 4'h0) begin
                        s_axi_rdata <= {28'h0000000, led_reg}; // Zero-pad upper bits
                        s_axi_rresp <= 2'b00; // OKAY response
                    end else begin
                        s_axi_rdata <= 32'h00000000;
                        s_axi_rresp <= 2'b10; // SLVERR for invalid address
                    end
                    
                    s_axi_rvalid <= 1'b1;
                    
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        read_state <= R_IDLE;
                    end
                end
                
                default: read_state <= R_IDLE;
            endcase
        end
    end
    
    // LED output assignment
    assign led_out = led_reg;

endmodule

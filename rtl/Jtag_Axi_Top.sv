// JTAG-AXI Bridge Top Level Module
// Author: FPGA Engineer
// Date: 2025-07-23
// Description: Top-level module integrating JTAG-AXI bridge with simple 4-bit LED register
//              This module provides a complete JTAG to LED control system

module Jtag_Axi_Top #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter BASE_ADDR = 32'h43C00000  // Example base address for Zynq PL
)(
    // System Clock and Reset
    input  logic                        sys_clk,
    input  logic                        sys_resetn,
    
    // LED outputs for board connection
    output logic [3:0]                  led_pins
);

    // Internal AXI4-Lite bus between JTAG bridge and LED register
    logic [AXI_ADDR_WIDTH-1:0]  axi_awaddr;
    logic [2:0]                  axi_awprot;
    logic                        axi_awvalid;
    logic                        axi_awready;
    
    logic [AXI_DATA_WIDTH-1:0]  axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0] axi_wstrb;
    logic                        axi_wvalid;
    logic                        axi_wready;
    
    logic [1:0]                  axi_bresp;
    logic                        axi_bvalid;
    logic                        axi_bready;
    
    logic [AXI_ADDR_WIDTH-1:0]  axi_araddr;
    logic [2:0]                  axi_arprot;
    logic                        axi_arvalid;
    logic                        axi_arready;
    
    logic [AXI_DATA_WIDTH-1:0]  axi_rdata;
    logic [1:0]                  axi_rresp;
    logic                        axi_rvalid;
    logic                        axi_rready;
    
    // JTAG-AXI Bridge instance
    Jtag_Axi_Bridge #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) u_jtag_axi_bridge (
        // AXI-Lite Master Interface
        .axi_aclk(sys_clk),
        .axi_aresetn(sys_resetn),
        
        // AXI-Lite Write Address Channel
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awprot(axi_awprot),
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awready(axi_awready),
        
        // AXI-Lite Write Data Channel
        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wready(axi_wready),
        
        // AXI-Lite Write Response Channel
        .m_axi_bresp(axi_bresp),
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bready(axi_bready),
        
        // AXI-Lite Read Address Channel
        .m_axi_araddr(axi_araddr),
        .m_axi_arprot(axi_arprot),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),
        
        // AXI-Lite Read Data Channel
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready)
    );
    
    // Simple LED Register instance
    Simple_Led_Register #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) u_led_register (
        // AXI4-Lite Slave Interface
        .s_axi_aclk(sys_clk),
        .s_axi_aresetn(sys_resetn),
        
        // AXI4-Lite Write Address Channel
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awprot(axi_awprot),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        
        // AXI4-Lite Write Data Channel
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        
        // AXI4-Lite Write Response Channel
        .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        
        // AXI4-Lite Read Address Channel
        .s_axi_araddr(axi_araddr),
        .s_axi_arprot(axi_arprot),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        
        // AXI4-Lite Read Data Channel
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready),
        
        // LED Output
        .led_out(led_pins)
    );

endmodule

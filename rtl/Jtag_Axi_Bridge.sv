// JTAG-AXI Bridge Module
// Author: FPGA Engineer
// Date: 2025-07-23
// Description: JTAG to AXI-Lite bridge using BSCANE2 primitive
//              Supports 32-bit command + 32-bit data protocol

module Jtag_Axi_Bridge #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
)(
    // AXI-Lite Master Interface
    input  logic                        axi_aclk,
    input  logic                        axi_aresetn,
    
    // AXI-Lite Write Address Channel
    output logic [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output logic [2:0]                  m_axi_awprot,
    output logic                        m_axi_awvalid,
    input  logic                        m_axi_awready,
    
    // AXI-Lite Write Data Channel
    output logic [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output logic [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,
    
    // AXI-Lite Write Response Channel
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,
    
    // AXI-Lite Read Address Channel
    output logic [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output logic [2:0]                  m_axi_arprot,
    output logic                        m_axi_arvalid,
    input  logic                        m_axi_arready,
    
    // AXI-Lite Read Data Channel
    input  logic [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready
);

    // JTAG signals from BSCANE2
    logic jtag_tdi;
    logic jtag_tdo;
    logic jtag_tck;
    logic jtag_shift;
    logic jtag_update;
    logic jtag_capture;
    logic jtag_reset;
    logic jtag_sel;
    
    // BSCANE2 primitive instantiation for USER1 instruction
    BSCANE2 #(
        .JTAG_CHAIN(1)  // USER1 instruction
    ) u_bscane2 (
        .CAPTURE(jtag_capture),
        .DRCK(jtag_tck),        // Data register clock (shifted TCK)
        .RESET(jtag_reset),
        .RUNTEST(),             // Unconnected - not used
        .SEL(jtag_sel),
        .SHIFT(jtag_shift),
        .TCK(),                 // Unconnected - using DRCK instead
        .TDI(jtag_tdi),
        .TMS(),                 // Unconnected - not needed for data register
        .UPDATE(jtag_update),
        .TDO(jtag_tdo)
    );
    
    // Command definitions
    localparam CMD_WRITE = 32'h00000001;
    localparam CMD_READ  = 32'h00000002;
    localparam CMD_NOP   = 32'h00000000;
    
    // State machine for JTAG protocol
    typedef enum logic [2:0] {
        IDLE,
        SHIFT_CMD,
        SHIFT_ADDR,
        SHIFT_DATA,
        EXECUTE,
        WAIT_RESP,
        SHIFT_OUT
    } jtag_state_t;
    
    jtag_state_t jtag_state, jtag_next_state;
    
    // Shift registers
    logic [31:0] shift_reg_cmd;
    logic [31:0] shift_reg_addr;
    logic [31:0] shift_reg_data;
    logic [31:0] shift_reg_out;
    logic [5:0]  shift_count;
    
    // Command registers
    logic [31:0] cmd_reg;
    logic [31:0] addr_reg;
    logic [31:0] data_reg;
    logic [31:0] read_data_reg;
    logic [31:0] status_reg;
    
    // AXI transaction control
    logic axi_write_req;
    logic axi_read_req;
    logic axi_write_done;
    logic axi_read_done;
    logic axi_transaction_error;
    
    // Synchronizers for clock domain crossing
    logic [2:0] jtag_update_sync;
    logic [2:0] jtag_shift_sync;
    logic jtag_update_pulse;
    logic jtag_shift_active;
    
    // Clock domain crossing for JTAG signals
    always_ff @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            jtag_update_sync <= 3'b0;
            jtag_shift_sync <= 3'b0;
        end else begin
            jtag_update_sync <= {jtag_update_sync[1:0], jtag_update};
            jtag_shift_sync <= {jtag_shift_sync[1:0], jtag_shift};
        end
    end
    
    assign jtag_update_pulse = jtag_update_sync[1] && !jtag_update_sync[2];
    assign jtag_shift_active = jtag_shift_sync[1];
    
    // JTAG shift register logic
    always_ff @(posedge jtag_tck or posedge jtag_reset) begin
        if (jtag_reset) begin
            shift_reg_cmd <= 32'h0;
            shift_reg_addr <= 32'h0;
            shift_reg_data <= 32'h0;
            shift_count <= 6'h0;
        end else if (jtag_sel && jtag_shift) begin
            if (shift_count < 32) begin
                // Shift in command
                shift_reg_cmd <= {jtag_tdi, shift_reg_cmd[31:1]};
                shift_count <= shift_count + 1;
            end else if (shift_count < 64) begin
                // Shift in address
                shift_reg_addr <= {jtag_tdi, shift_reg_addr[31:1]};
                shift_count <= shift_count + 1;
            end else if (shift_count < 96) begin
                // Shift in data or shift out read data
                if (cmd_reg == CMD_READ) begin
                    shift_reg_out <= {1'b0, shift_reg_out[31:1]};
                end else begin
                    shift_reg_data <= {jtag_tdi, shift_reg_data[31:1]};
                end
                shift_count <= shift_count + 1;
            end
        end else if (jtag_sel && jtag_capture) begin
            shift_count <= 6'h0;
            // Load read data for output during next shift
            if (cmd_reg == CMD_READ) begin
                shift_reg_out <= read_data_reg;
            end
        end
    end
    
    // TDO output logic
    always_comb begin
        if (jtag_sel && jtag_shift && shift_count >= 64 && cmd_reg == CMD_READ) begin
            jtag_tdo = shift_reg_out[0];
        end else begin
            jtag_tdo = 1'b0;
        end
    end
    
    // Command capture and execution
    always_ff @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            cmd_reg <= CMD_NOP;
            addr_reg <= 32'h0;
            data_reg <= 32'h0;
            axi_write_req <= 1'b0;
            axi_read_req <= 1'b0;
        end else begin
            if (jtag_update_pulse) begin
                cmd_reg <= shift_reg_cmd;
                addr_reg <= shift_reg_addr;
                data_reg <= shift_reg_data;
                
                // Trigger AXI transaction
                if (shift_reg_cmd == CMD_WRITE) begin
                    axi_write_req <= 1'b1;
                end else if (shift_reg_cmd == CMD_READ) begin
                    axi_read_req <= 1'b1;
                end
            end else begin
                if (axi_write_done) begin
                    axi_write_req <= 1'b0;
                end
                if (axi_read_done) begin
                    axi_read_req <= 1'b0;
                end
            end
        end
    end
    
    // AXI-Lite Write Transaction
    typedef enum logic [2:0] {
        AXI_WRITE_IDLE,
        AXI_WRITE_ADDR,
        AXI_WRITE_DATA,
        AXI_WRITE_RESP
    } axi_write_state_t;
    
    axi_write_state_t axi_write_state;
    
    always_ff @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            axi_write_state <= AXI_WRITE_IDLE;
            m_axi_awaddr <= 32'h0;
            m_axi_awprot <= 3'b000;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= 32'h0;
            m_axi_wstrb <= 4'hF;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b0;
            axi_write_done <= 1'b0;
        end else begin
            case (axi_write_state)
                AXI_WRITE_IDLE: begin
                    if (axi_write_req) begin
                        m_axi_awaddr <= addr_reg;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata <= data_reg;
                        m_axi_wvalid <= 1'b1;
                        axi_write_state <= AXI_WRITE_ADDR;
                    end
                    axi_write_done <= 1'b0;
                end
                
                AXI_WRITE_ADDR: begin
                    if (m_axi_awready && m_axi_wready) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid <= 1'b0;
                        m_axi_bready <= 1'b1;
                        axi_write_state <= AXI_WRITE_RESP;
                    end else if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        axi_write_state <= AXI_WRITE_DATA;
                    end else if (m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        axi_write_state <= AXI_WRITE_DATA;
                    end
                end
                
                AXI_WRITE_DATA: begin
                    if (m_axi_awready && m_axi_awvalid) begin
                        m_axi_awvalid <= 1'b0;
                    end
                    if (m_axi_wready && m_axi_wvalid) begin
                        m_axi_wvalid <= 1'b0;
                    end
                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        m_axi_bready <= 1'b1;
                        axi_write_state <= AXI_WRITE_RESP;
                    end
                end
                
                AXI_WRITE_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        axi_write_done <= 1'b1;
                        axi_write_state <= AXI_WRITE_IDLE;
                    end
                end
            endcase
        end
    end
    
    // AXI-Lite Read Transaction
    typedef enum logic [1:0] {
        AXI_READ_IDLE,
        AXI_READ_ADDR,
        AXI_READ_DATA
    } axi_read_state_t;
    
    axi_read_state_t axi_read_state;
    
    always_ff @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            axi_read_state <= AXI_READ_IDLE;
            m_axi_araddr <= 32'h0;
            m_axi_arprot <= 3'b000;
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b0;
            read_data_reg <= 32'h0;
            axi_read_done <= 1'b0;
        end else begin
            case (axi_read_state)
                AXI_READ_IDLE: begin
                    if (axi_read_req) begin
                        m_axi_araddr <= addr_reg;
                        m_axi_arvalid <= 1'b1;
                        axi_read_state <= AXI_READ_ADDR;
                    end
                    axi_read_done <= 1'b0;
                end
                
                AXI_READ_ADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready <= 1'b1;
                        axi_read_state <= AXI_READ_DATA;
                    end
                end
                
                AXI_READ_DATA: begin
                    if (m_axi_rvalid) begin
                        read_data_reg <= m_axi_rdata;
                        m_axi_rready <= 1'b0;
                        axi_read_done <= 1'b1;
                        axi_read_state <= AXI_READ_IDLE;
                    end
                end
            endcase
        end
    end
    
    // Status register
    always_ff @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            status_reg <= 32'h0;
        end else begin
            status_reg[0] <= axi_write_req || axi_read_req;  // Busy flag
            status_reg[1] <= axi_write_done || axi_read_done; // Done flag
            status_reg[3:2] <= (axi_write_state == AXI_WRITE_RESP) ? m_axi_bresp : 
                              (axi_read_state == AXI_READ_DATA) ? m_axi_rresp : 2'b00;
            status_reg[31:4] <= 28'h0; // Reserved
        end
    end

endmodule

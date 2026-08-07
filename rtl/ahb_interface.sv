import ahb_apb_pkg::*;

module ahb_interface #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter FIFO_WIDTH = ahb_apb_pkg::FIFO_WIDTH
)(
    input  logic                     HCLK,
    input  logic                     HRESETn,

    // AHB Slave Interface
    input  logic                     HSEL,
    input  logic                     HREADY,
    input  logic [1:0]               HTRANS,
    input  logic                     HWRITE,
    input  logic [2:0]               HSIZE,
    input  logic [ADDR_WIDTH-1:0]    HADDR,
    input  logic [DATA_WIDTH-1:0]    HWDATA,

    // FIFO Interface
    input  logic                     fifo_full,
    output logic                     fifo_wr_en,
    output logic [FIFO_WIDTH-1:0]    fifo_wdata,

    // Read Response Path
    input  logic [DATA_WIDTH-1:0]    PRDATA_SYNC,
    input  logic                     READ_VALID,
    input  logic                     PSLVERR_SYNC,

    // AHB Outputs
    output logic [DATA_WIDTH-1:0]    HRDATA,
    output logic                     HREADYOUT,
    output logic [1:0]               HRESP
);

    logic write_pending;
    logic err_cycle2;

    logic                    hwrite_reg;
    logic [2:0]              hsize_reg;
    logic [ADDR_WIDTH-1:0]   haddr_reg;
    logic [1:0]              htrans_reg;

    // Simplified: 2-state FSM, READ_COMPLETE removed (see explanation above)
    typedef enum logic {
        READ_IDLE,
        READ_WAIT_RESP
    } read_state_t;

    read_state_t read_state;

    //------------------------------------------------------------
    // Accept logic deliberately does NOT read HREADY (see explanation:
    // reintroducing it here creates a combinational loop when HREADY
    // is tied to this slave's own HREADYOUT). Internal busy state
    // (read_state, write_pending) already enforces "previous transfer
    // must complete before a new one is accepted."
    //------------------------------------------------------------
    logic addr_phase;
    logic accept_xfer;
    logic accept_read;
    logic accept_write;

    assign addr_phase = HSEL && HTRANS[1];

    assign accept_xfer  = addr_phase && !fifo_full &&
                           !write_pending && (read_state == READ_IDLE) &&
                           !err_cycle2;

    assign accept_read  = accept_xfer && !HWRITE;
    assign accept_write = accept_xfer &&  HWRITE;

    // Combinational read-completion conditions (used by HREADYOUT/HRESP/HRDATA)
    logic read_complete_ok;
    logic read_complete_err;

    assign read_complete_ok  = (read_state == READ_WAIT_RESP) && READ_VALID && !PSLVERR_SYNC;
    assign read_complete_err = (read_state == READ_WAIT_RESP) && READ_VALID &&  PSLVERR_SYNC;

    ahb_packet_t tx_packet;
    logic [DATA_WIDTH-1:0] hrdata_reg;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            fifo_wr_en    <= 1'b0;
            tx_packet     <= '0;
            hrdata_reg    <= '0;

            hwrite_reg    <= 1'b0;
            hsize_reg     <= '0;
            haddr_reg     <= '0;
            htrans_reg    <= '0;

            read_state    <= READ_IDLE;
            write_pending <= 1'b0;
            err_cycle2    <= 1'b0;
        end else begin
            fifo_wr_en <= 1'b0;

            if (err_cycle2)
                err_cycle2 <= 1'b0;

            //----------------------------------------------------
            // Address Phase Capture
            //----------------------------------------------------
            if (accept_xfer) begin

                if (!HWRITE) begin
                    fifo_wr_en <= 1'b1;

                    tx_packet.hwrite <= 1'b0;
                    tx_packet.haddr  <= HADDR;
                    tx_packet.hwdata <= 32'b0;
                    tx_packet.hsize  <= HSIZE;
                    tx_packet.htrans <= HTRANS;

                    read_state <= READ_WAIT_RESP;

                    $display("[%0t] AHB IF : READ REQUEST  Addr=%h",
                              $time, HADDR);

                end else begin
                    hwrite_reg    <= HWRITE;
                    hsize_reg     <= HSIZE;
                    haddr_reg     <= HADDR;
                    htrans_reg    <= HTRANS;

                    write_pending <= 1'b1;
                end
            end

            //----------------------------------------------------
            // Write Data Phase
            //----------------------------------------------------
            if (write_pending && !fifo_full) begin
                fifo_wr_en <= 1'b1;

                tx_packet.hwrite <= hwrite_reg;
                tx_packet.haddr  <= haddr_reg;
                tx_packet.hwdata <= HWDATA;
                tx_packet.hsize  <= hsize_reg;
                tx_packet.htrans <= htrans_reg;

                write_pending <= 1'b0;
            end

            //----------------------------------------------------
            // Read Response ? single state transition back to IDLE,
            // regardless of error; err_cycle2 handles the extra
            // error-completion cycle independently.
            //----------------------------------------------------
            if (read_state == READ_WAIT_RESP && READ_VALID) begin

                $display("[%0t] AHB IF : READ_VALID received", $time);
                $display("[%0t] AHB IF : PRDATA_SYNC=%h", $time, PRDATA_SYNC);

                hrdata_reg <= PRDATA_SYNC;

                if (PSLVERR_SYNC)
                    err_cycle2 <= 1'b1;

                read_state <= READ_IDLE;
            end
        end
    end

    assign fifo_wdata = tx_packet;

    // Combinational forwarding so HRDATA is valid on the same cycle
    // HREADYOUT completes a successful read (registered value would
    // still be stale until the next edge).
    assign HRDATA = read_complete_ok ? PRDATA_SYNC : hrdata_reg;

    //------------------------------------------------------------
    // Output Logic
    //------------------------------------------------------------
    always_comb begin
        if (err_cycle2) begin
            // second cycle of the 2-cycle AHB error response
            HRESP     = 2'b01;
            HREADYOUT = 1'b1;
        end
        else if (read_complete_err) begin
            // first cycle of the 2-cycle AHB error response
            HRESP     = 2'b01;
            HREADYOUT = 1'b0;
        end
        else if (read_complete_ok) begin
            HRESP     = 2'b00;
            HREADYOUT = 1'b1;
        end
        else if (accept_read || accept_write) begin
            HRESP     = 2'b00;
            HREADYOUT = 1'b0;
        end
        else if (write_pending) begin
            HRESP     = 2'b00;
            HREADYOUT = 1'b0;
        end
        else begin
            HRESP = 2'b00;

            case (read_state)
                READ_IDLE:      HREADYOUT = !fifo_full;
                READ_WAIT_RESP: HREADYOUT = 1'b0;
                default:        HREADYOUT = 1'b1;
            endcase
        end
    end

endmodule
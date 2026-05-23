module address_decoder (
    input  logic [31:0] addr,           // Address bus from AXI Slave

    output logic        cs_regs,        // General Config/Status (0x00 - 0x5C)
    output logic        cs_af_bank,     // Acceptance Filter Bank (0x60 - 0xE4)
    output logic        cs_tx_mailbox,  // TX Message Space (0x100 - 0x147)
    output logic        cs_rx_fifo      // RX Message Space (0x1100 - 0x1147+)
);

    // 1. General Registers: 0x00 to 0x5C (Standard CAN and common FD)
    // Also includes Data Phase timings at 0x88 and Ready Request at 0x90
    assign cs_regs       = (addr[12:8] == 5'h0); 

    // 2. Acceptance Filter Bank: Driver expects these starting at 0x60 and 0xE0
    // [FIX] Added 0xA00 range so your CAN FD filters work!
    assign cs_af_bank    = (addr[12:7] == 6'h1) || (addr[12:7] == 6'h3) || (addr[12:8] == 5'hA);

    // 3. TX Mailbox: XCAN_TXMSG_BASE_OFFSET = 0x0100
    // The driver writes the ID, DLC, and Data here.
    assign cs_tx_mailbox = (addr[12:8] == 5'h1);

    // 4. RX FIFO: XCAN_RXMSG_BASE_OFFSET = 0x1100
    // Note: The driver uses 0x1100 for the multi-buffer RX logic.
    assign cs_rx_fifo    = (addr[12:8] == 5'h11); 

endmodule
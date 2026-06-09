# ==============================================================================
# Xilinx Design Constraints (XDC) for Zynq-7000 CAN Controller IP
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Clock Definitions
# ------------------------------------------------------------------------------
# The AXI bus and the CAN core are driven by the 'clk' input.
# In your simulation, you used 125 MHz (8.000 ns period).
# We must tell Vivado the exact period so it can perform Timing Analysis (Setup/Hold).

create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} [get_ports clk]

# ------------------------------------------------------------------------------
# 2. Physical Pin Assignments (I/O Constraints)
# ------------------------------------------------------------------------------
# NOTE: The AXI4-Lite pins (s_axi_*) do NOT get external pin constraints here.
# Vivado's Block Design handles their routing internally to the Zynq ARM processor (PS).
# We only constrain the physical wires leaving the FPGA chip.

# --- CAN TX Pin (can_tx_pad) ---
# Change the PACKAGE_PIN to match the PMOD or Header pin on your specific board.
# Example: "W14" is a common PMOD pin on the PYNQ-Z2.
set_property PACKAGE_PIN B15 [get_ports can_tx_pad]
set_property IOSTANDARD LVCMOS33 [get_ports can_tx_pad]
set_property DRIVE 8 [get_ports can_tx_pad]
set_property SLEW FAST [get_ports can_tx_pad]

# --- CAN RX Pin (can_rx_pad) ---
# Change the PACKAGE_PIN to match the adjacent PMOD pin.
# Example: "Y14" is a common PMOD pin on the PYNQ-Z2.
set_property PACKAGE_PIN B16 [get_ports can_rx_pad]
set_property IOSTANDARD LVCMOS33 [get_ports can_rx_pad]
# Optional: Enable internal pull-up if your external transceiver requires it
# set_property PULLUP true [get_ports can_rx_pad]

# --- Interrupt Pin (irq_out) ---
# If you are integrating this as an IP block in Vivado's Block Design, 
# you DO NOT need to constrain this pin. You will route it internally to the 
# Zynq PS 'IRQ_F2P' port in the GUI. 
#
# ONLY uncomment the lines below if you are wiring the interrupt directly 
# to a physical LED on the board for testing purposes.
# set_property PACKAGE_PIN R14 [get_ports irq_out]
# set_property IOSTANDARD LVCMOS33 [get_ports irq_out]

# ------------------------------------------------------------------------------
# 3. Timing Exceptions (False Paths / Multi-cycle Paths)
# ------------------------------------------------------------------------------
# Since this design is synchronous to a single clock domain (125 MHz AXI Clock),
# no complex CDC (Clock Domain Crossing) constraints are strictly required here.
# However, if 'rst_n' is an asynchronous physical button, we declare it as a false path
# to prevent Vivado from trying to optimize its timing setup.

set_false_path -from [get_ports rst_n]

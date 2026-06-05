# Define the internal clock arriving from the Zynq PS (e.g., 100 MHz target)
# This constraint provides the timing engine with the required boundaries
create_clock -period 12.500 -name internal_axi_clk [get_ports s_axi_aclk]

# Map the external physical pins going to the custom board's CAN transceiver
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports PL_B35_L17_P_CAN_TX]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports PL_B35_L17_N_CAN_RX ]

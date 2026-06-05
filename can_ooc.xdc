# Define the 125 MHz clock (8ns period) directly on the input port
create_clock -period 8.000 -name virtual_clk -waveform {0.000 4.000} [get_ports clk]

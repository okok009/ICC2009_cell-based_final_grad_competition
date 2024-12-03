# operating conditions and boundary conditions #
set sdc_version 1.4
set cycle 10          ;	#clock period defined by designer

create_clock -period   $cycle [get_ports  clk]
set_clock_uncertainty  0.1    [get_clocks clk]
set_clock_latency      0.5    [get_clocks clk]

set_input_delay  [expr $cycle/2] -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 0.5             -clock clk [remove_from_collection [all_outputs] [get_ports busy]]
set_output_delay [expr $cycle/2] -clock clk [get_ports busy]

set_load -pin_load 1  [all_outputs]
set_drive          1  [all_inputs]
set_max_fanout 6      [all_inputs]


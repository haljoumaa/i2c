set_time_format -unit ns -decimal_places 3
create_clock -name {sysclk50} -period 20.000 -waveform {0.000 10.000} [get_ports {CLOCK_50}]
derive_clock_uncertainty

#set_input_delay -max 10ns -clock sysclk50 [all_inputs]

#set_input_delay -max 10ns -clock sysclk50 [get_ports SW*]
#set_input_delay -max 10ns -clock sysclk50 [get_ports KEY*]
#set_input_delay -max 10ns -clock sysclk50 [get_ports EX_IO*]

#set_output_delay -max 10ns -clock sysclk50 [all_outputs]

set_false_path -to [all_outputs]
set_false_path -from [all_inputs]
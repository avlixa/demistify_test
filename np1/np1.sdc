create_clock -name "clock50" -period "50.0 MHz" {clock50}
create_generated_clock -name spiclk -source [get_pins {pll|altpll_component|auto_generated|pll1|clk[0]}] -divide_by 16 [get_registers {substitute_mcu:controller|spi_controller:spi|sck}]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

set FALSE_OUT {sync* rgb* usd* sram* stm led}
set FALSE_IN {ps2k* usd* sram*}

##############################################################################
## This file is part of 'LSST Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'LSST Firmware', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

####################################
## Application Timing Constraints ##
####################################

create_clock -name ethRefClk -period 8.000 [get_ports {ethClkP}]

create_generated_clock -name axilClk     [get_pins {U_Core/U_Eth/ETH_GEN.U_PHY_MAC/U_MMCM/MmcmGen.U_Mmcm/CLKOUT0}]
create_generated_clock -name axilClkDiv2 [get_pins {U_Core/U_Eth/ETH_GEN.U_PHY_MAC/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1}]

[get_clocks -of_objects [get_pins U_Core/U_Eth/ETH_GEN.U_PHY_MAC/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]]

create_generated_clock -name dnaClk  [get_pins {U_Core/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_7SERIES.DeviceDna7Series_Inst/BUFR_Inst/O}]
create_generated_clock -name dnaClkL [get_pins {U_Core/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_7SERIES.DeviceDna7Series_Inst/DNA_CLK_INV_BUFR/O}]
create_generated_clock -name progClk [get_pins {U_Core/U_Version/GEN_ICAP.Iprog_1/GEN_7SERIES.Iprog7Series_Inst/DIVCLK_GEN.BUFR_ICPAPE2/O}]

set_clock_groups -asynchronous -group [get_clocks {axilClk}] -group [get_clocks {ethRefClk}]
set_clock_groups -asynchronous -group [get_clocks {axilClk}] -group [get_clocks {dnaClk}] -group [get_clocks {dnaClkL}]
set_clock_groups -asynchronous -group [get_clocks {axilClk}] -group [get_clocks {progClk}]

##########################
## Misc. Configurations ##
##########################

set_property CFGBVS VCCO                     [current_design]
set_property CONFIG_VOLTAGE 3.3              [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33  [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]

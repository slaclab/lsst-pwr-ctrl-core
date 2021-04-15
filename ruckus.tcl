# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for version 2017.4 of Vivado (or later)
if { [VersionCheck 2017.4 ] < 0 } {
   exit -1
}

# Check for submodule tagging
if { [info exists ::env(OVERRIDE_SUBMODULE_LOCKS)] != 1 || $::env(OVERRIDE_SUBMODULE_LOCKS) == 0 } {
   if { [SubmoduleCheck {ruckus} {3.0.1}  "mustBeExact" ] < 0 } {exit -1}
   if { [SubmoduleCheck {surf}   {2.15.0} "mustBeExact" ] < 0 } {exit -1}
} else {
   puts "\n\n*********************************************************"
   puts "OVERRIDE_SUBMODULE_LOCKS != 0"
   puts "Ignoring the submodule locks in lsst-pwr-ctrl-core/ruckus.tcl"
   puts "*********************************************************\n\n"
}

# Load ruckus files
loadSource -lib lsst_pwr_ctrl_core -dir "$::DIR_PATH/rtl"
loadSource -lib lsst_pwr_ctrl_core -dir "$::DIR_PATH/rtl/i2c"
loadConstraints                    -dir "$::DIR_PATH/xdc"

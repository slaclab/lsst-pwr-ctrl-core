# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for version 2017.4 of Vivado
if { [VersionCheck 2017.4 "mustBeExact"] < 0 } {
   exit -1
}

# Check for submodule tagging
if { [SubmoduleCheck {ruckus} {1.5.8} ] < 0 } {exit -1}
if { [SubmoduleCheck {surf}   {1.6.6} ] < 0 } {exit -1}

# Load ruckus files
loadSource      -dir "$::DIR_PATH/rtl/"
loadConstraints -dir "$::DIR_PATH/xdc/"


-------------------------------------------------------------------------------
-- File       : LsstPwrCtrlPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: LSST's Common Power Controller Core VHDL package
-------------------------------------------------------------------------------
-- This file is part of 'LSST Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LSST Firmware', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package LsstPwrCtrlPkg is

   ----------------
   -- Revision Log:
   ----------------
   -- 02/14/2018 (0x01000000): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.0
   -- 02/27/2018 (0x01000100): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.1
   -- 02/28/2018 (0x01000200): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.2
   -- 02/28/2018 (0x01000300): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.3
   constant LSST_PWR_CORE_VERSION_C : slv(31 downto 0) := x"01_00_03_00";

   -----------------------------------------------------------
   -- Application: Configurations, Constants and Records Types
   -----------------------------------------------------------
   subtype AppType is slv(31 downto 0);

   constant APP_NULL_TYPE_C : AppType := toSlv(0, AppType'length);  -- Zero = undefined application

   constant APP_PROTOTYPE_REB_PWR_TYPE_C  : AppType := toSlv(10834, AppType'length);  -- LCA-10834: Prototype REB Power Board 
   constant APP_PRODUCTION_REB_PWR_TYPE_C : AppType := toSlv(15092, AppType'length);  -- LCA-15092: REB Power Supply (Production Version)
   constant APP_ION_PUMP_CTRL_TYPE_C      : AppType := toSlv(15111, AppType'length);  -- LCA-15111: Ion Pump Main Control Board
   constant APP_24V_48V_PDU_DISTR_TYPE_C  : AppType := toSlv(15764, AppType'length);  -- LCA-15764: 24/48V DC PDU Power Distribution Board
   constant APP_5V_PDU_DISTR_TYPE_C       : AppType := toSlv(15768, AppType'length);  -- LCA-15768: 5V DC PDU Power Distribution Board
   constant APP_HEATER_CTRL_TYPE_C        : AppType := toSlv(15772, AppType'length);  -- LCA-15772: REB Heater Control Board

end package LsstPwrCtrlPkg;

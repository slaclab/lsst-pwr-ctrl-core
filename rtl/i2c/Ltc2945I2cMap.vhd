-------------------------------------------------------------------------------
-- Title      :
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of . It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of , including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;

entity Ltc2945I2cMap is
   generic (
      TPD_G           : time := 1 ns;
      AXI_CLK_FREQ_G  : real := 156.25E+6;  -- units of Hz
      I2C_SCL_FREQ_G  : real := 100.0E+3;   -- units of Hz
      I2C_MIN_PULSE_G : real := 100.0E-9);  -- units of seconds;
   port (
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- I2C Ports
      scl            : inout sl;
      sda            : inout sl);

end entity Ltc2945I2cMap;

architecture rtl of Ltc2945I2cMap is

   constant AXIL_ADDR_SIZE_C : integer := 8;

   constant DEVICE_CFG_C : I2cAxiLiteDevType := (
      i2cAddress  => "0001010000",
      i2cTenbit   => '0',
      dataSize    => 32,                -- ignored
      addrSize    => 8,
      endianness  => '1',
      repeatStart => '1');

   constant ADDR_MAP_C : I2cAxiLiteAddrMapArray(0 to 24) := (
      0 => (axilAddr => X"000000_00", regAddr => X"000000_00", dataSize => 1),  -- CONTROL
      1 => (axilAddr => X"000000_04", regAddr => X"000000_01", dataSize => 1),  -- ALERT
      2 => (axilAddr => X"000000_08", regAddr => X"000000_02", dataSize => 1),  -- STATUS
      3 => (axilAddr => X"000000_0C", regAddr => X"000000_03", dataSize => 1),  -- FAULT
      4 => (axilAddr => X"000000_10", regAddr => X"000000_04", dataSize => 1),  -- FAULT CoR

      5  => (axilAddr => X"000000_14", regAddr => X"000000_05", dataSize => 3),  -- Power
      6  => (axilAddr => X"000000_18", regAddr => X"000000_08", dataSize => 3),  -- Max Power
      7  => (axilAddr => X"000000_1C", regAddr => X"000000_0B", dataSize => 3),  -- Min Power
      8  => (axilAddr => X"000000_20", regAddr => X"000000_0E", dataSize => 3),  -- Max Power Thresh
      9  => (axilAddr => X"000000_24", regAddr => X"000000_11", dataSize => 3),  -- Min Power Thresh
                                                                                 --
      10 => (axilAddr => X"000000_28", regAddr => X"000000_14", dataSize => 2),  -- Sense
      11 => (axilAddr => X"000000_2C", regAddr => X"000000_16", dataSize => 2),  -- Max Sense
      12 => (axilAddr => X"000000_30", regAddr => X"000000_18", dataSize => 2),  -- Min Sense
      13 => (axilAddr => X"000000_34", regAddr => X"000000_1A", dataSize => 2),  -- Max Sense Thresh
      14 => (axilAddr => X"000000_38", regAddr => X"000000_1C", dataSize => 2),  -- Min Sense Thresh

      15 => (axilAddr => X"000000_3C", regAddr => X"000000_1E", dataSize => 2),  -- Vin
      16 => (axilAddr => X"000000_40", regAddr => X"000000_20", dataSize => 2),  -- Max Vin
      17 => (axilAddr => X"000000_44", regAddr => X"000000_22", dataSize => 2),  -- Min Vin
      18 => (axilAddr => X"000000_48", regAddr => X"000000_24", dataSize => 2),  -- Max Vin Thresh
      19 => (axilAddr => X"000000_4C", regAddr => X"000000_26", dataSize => 2),  -- Min Vin Thresh

      20 => (axilAddr => X"000000_50", regAddr => X"000000_28", dataSize => 2),  -- ADin
      21 => (axilAddr => X"000000_54", regAddr => X"000000_2A", dataSize => 2),  -- Max ADin
      22 => (axilAddr => X"000000_58", regAddr => X"000000_2C", dataSize => 2),  -- Min ADin
      23 => (axilAddr => X"000000_5C", regAddr => X"000000_2E", dataSize => 2),  -- Max ADin Thresh
      24 => (axilAddr => X"000000_60", regAddr => X"000000_30", dataSize => 2)  -- Min ADin Thresh
      );

begin

   U_AxiI2cRegMasterMap_1 : entity work.AxiI2cRegMasterMap
      generic map (
         TPD_G            => TPD_G,
         DEVICE_CFG_G     => DEVICE_CFG_C,
         ADDR_MAP_G       => ADDR_MAP_C,
         AXIL_ADDR_SIZE_G => 8,
         I2C_SCL_FREQ_G   => I2C_SCL_FREQ_G,
         I2C_MIN_PULSE_G  => I2C_MIN_PULSE_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G)
      port map (
         axiClk         => axiClk,          -- [in]
         axiRst         => axiRst,          -- [in]
         axiReadMaster  => axiReadMaster,   -- [in]
         axiReadSlave   => axiReadSlave,    -- [out]
         axiWriteMaster => axiWriteMaster,  -- [in]
         axiWriteSlave  => axiWriteSlave,   -- [out]
         scl            => scl,             -- [inout]
         sda            => sda);            -- [inout]

end architecture rtl;

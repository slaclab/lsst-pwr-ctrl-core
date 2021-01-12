-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      .vhd -
--
--      Copyright(c) SLAC 2000
--
--      Author: Jeff Olsen
--      Created on: 2/4/2008 1:32:47 PM
--      Last change: JO 3/6/2018 8:51:53 AM
--
----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    16:30:20 01/31/2008
-- Design Name:
-- Module Name:    LTC2945_Tb - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-------------------------------------------------------------------------------
-- This file is part of 'LSST Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LSST Firmware', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library surf;
use surf.StdRtlPkg.all;
use surf.I2cPkg.all;

library lsst_pwr_ctrl_core;

library unisim;
use unisim.vcomponents.all;

entity LTC2945_Tb is
   port (
      Clk          : in    sl;
      rst          : in    sl;
      ADCReadStart : in    sl;
      sda          : inout sl;
      scl          : inout sl;

      fifowr       : in  sl;
      fifodatain   : in  slv(31 downto 0);
      RdMemAddr    : in  slv(4 downto 0);
      DpMemDataOut : out slv(31 downto 0)
      );


end LTC2945_Tb;

architecture Behavioral of LTC2945_Tb is

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

begin

   scl <= 'H';
   SDA <= 'H';


   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,                     -- buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen
         );                             -- 3-state enable input, high=input, low=output

   IOBUF_SDA : IOBUF                    -- output buffer to ltc
      port map (                        -- Buffer output
         O  => i2ci.sda,                -- Buffer output
         IO => sda,                     -- buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen
         );

   u_LTC2945 : entity lsst_pwr_ctrl_core.LTC2945i2cCore
      generic map (
         TPD_G           => 1 ns,
         ADDR_WIDTH_G    => 8,
         POLL_TIMEOUT_G  => 16,
         I2C_ADDR_G      => "1101111",  -- LTC Addr1, Addr0 = "00"
         I2C_SCL_FREQ_G  => 100.0E+3,   -- units of Hz
         I2C_MIN_PULSE_G => 100.0E-9    -- units of seconds
         )
      port map (
         Clock     => Clk,
         Reset     => rst,
         StartRead => ADCReadStart,
         -- Serial interface
         i2ci      => i2ci,
         i2co      => i2co,
         -- Fifo Interface for writes
         WrStrb    => FifoWr,
         DataIn    => FifoDataIn,
         -- Dual Port memory for output
         RdMemAddr => RdMemAddr,
         MemDout   => DpMemDataOut
         );
end Behavioral;


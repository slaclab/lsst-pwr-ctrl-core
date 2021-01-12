-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      LambdaAxil.vhd -
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Jeff Olsen
--      Created on: 2/14/2018 8:56:03 AM
--      Last change: JO 3/20/2018 11:37:33 AM
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;

entity LambdaAxil is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI-Lite Interface
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      -- I2C bus
      i2ci            : in i2c_in_type;
      i2co            : out i2c_out_type;
      -- Start Conversion
      StartConv       : in    sl;
      -- I2C Fault
      LambdaComFault  : out   sl
      );
end entity LambdaAxil;

architecture Behavioral of LambdaAxil is

   type RegType is record
      ADCReadStart   : sl;
      FifoWr         : sl;
      RdDelay        : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      ADCReadStart   => '0',
      FifoWr         => '0',
      RdDelay        => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r          : RegType := REG_INIT_C;
   signal rin        : RegType;
   signal FifoDataIn : slv(31 downto 0);
   signal LTCDataOut : slv(31 downto 0);
   signal Convert    : sl;

begin

   comb : process (LTCDataOut, axilReadMaster, axilRst, axilWriteMaster, r) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.ADCReadStart := '0';
      v.FifoWr       := '0';
      v.RdDelay      := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Check for a write request
      if (axilStatus.writeEnable = '1') then
         -- Check for start
         if (axilWriteMaster.awaddr(11 downto 0) = x"100") then
            v.ADCReadStart := '1';
         elsif (axilWriteMaster.awaddr(11 downto 0) < x"100") then
            v.FifoWr := '1';
         end if;
         -- Send AXI-Lite Response
         axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);
      end if;

      -- Check for a read request
      if (axilStatus.readEnable = '1') then
         -- Wait 1 cycle for data to get out of the DPMEM pipeline
         v.RdDelay := '1';
      end if;

      if (r.RdDelay = '1') then
         -- Forward the read data from the RAM
         v.axilReadSlave.rdata := LTCDataOut;
         -- Send AXI-Lite Response
         axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);
      end if;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      -- Fifo Data is the address and 24 bit data to the ADC which
      -- becomes the ADC register and 24 bit data to write
      FifoDataIn <= axilWriteMaster.awaddr(9 downto 2) & axilWriteMaster.wdata(23 downto 0);

   end process;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;



   u_Lambda : entity work.LambdaI2CCore
      generic map (
         TPD_G           => 1 ns,
         ADDR_WIDTH_G    => 8,
         POLL_TIMEOUT_G  => 16,
         I2C_ADDR_G      => "1010000",  -- Lambda Addr2, Addr1, Addr0 = "000", A0
         I2C_SCL_FREQ_G  => 100.0E+3,   -- units of Hz
         I2C_MIN_PULSE_G => 100.0E-9    -- units of seconds
         )
      port map (
         Clock     => axilClk,
         Reset     => axilRst,
--      StartRead => r.ADCReadStart,
         StartRead => StartConv,
         -- Serial interface
         i2ci      => i2ci,
         i2co      => i2co,
         -- Fifo Interface for writes
         WrStrb    => r.FifoWr,
         DataIn    => FifoDataIn,
         -- Dual Port memory for output
         RdMemAddr => axilReadMaster.araddr(6 downto 2),
         MemDout   => LTCDataOut,
         LambdaComFault => LambdaComFault
         );

end;


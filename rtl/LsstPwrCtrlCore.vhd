-------------------------------------------------------------------------------
-- File       : LsstPwrCtrlCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-05-01
-- Last update: 2018-04-03
-------------------------------------------------------------------------------
-- Description: LSST's Common Power Controller Core
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.LsstPwrCtrlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity LsstPwrCtrlCore is
   generic (
      TPD_G                 : time                  := 1 ns;
      BUILD_INFO_G          : BuildInfoType;
      NUM_LANE_G            : positive range 1 to 4 := 1;
      APP_TYPE_G            : AppType               := APP_NULL_TYPE_C;  -- See LsstPwrCtrlPkg.vhd for definitions
      ------------------------------------------------------------------------
      -- Generics for overriding the LsstPwrCtrlEthConfig.vhd MAC/IP addresses
      ------------------------------------------------------------------------
      OVERRIDE_ETH_CONFIG_G : boolean               := false;  -- false = uses LsstPwrCtrlEthConfig.vhd, true = uses OVERRIDE_MAC_ADDR_G/OVERRIDE_IP_ADDR_G
      OVERRIDE_MAC_ADDR_G   : slv(47 downto 0)      := x"00_00_16_56_00_08";  -- 08:00:56:16:00:00      
      OVERRIDE_IP_ADDR_G    : slv(31 downto 0)      := x"0A_01_A8_C0");  -- 192.168.1.10
   port (
      -- Register Interface
      axilClk          : out sl;
      axilRst          : out sl;
      axilReadMasters  : out AxiLiteReadMasterArray(6 downto 0);
      axilReadSlaves   : in  AxiLiteReadSlaveArray(6 downto 0);
      axilWriteMasters : out AxiLiteWriteMasterArray(6 downto 0);
      axilWriteSlaves  : in  AxiLiteWriteSlaveArray(6 downto 0);
      -- Misc. Signals
      extRstL          : in  sl;
      ethLinkUp        : out slv(NUM_LANE_G-1 downto 0);
      rssiLinkUp       : out slv(NUM_LANE_G-1 downto 0);
      heartBeat        : out sl;
      efuse            : out slv(31 downto 0);
      dnaValue         : out slv(127 downto 0);
      -- XADC Ports
      vPIn             : in  sl;
      vNIn             : in  sl;
      -- 1GbE Ports
      ethClkP          : in  sl;
      ethClkN          : in  sl;
      ethRxP           : in  slv(NUM_LANE_G-1 downto 0);
      ethRxN           : in  slv(NUM_LANE_G-1 downto 0);
      ethTxP           : out slv(NUM_LANE_G-1 downto 0);
      ethTxN           : out slv(NUM_LANE_G-1 downto 0));
end LsstPwrCtrlCore;

architecture mapping of LsstPwrCtrlCore is

   constant SYS_CLK_FREQ_C : real := 125.0E+6;

   constant NUM_AXI_MASTERS_C : natural := 9;

   constant VERSION_INDEX_C : natural := 7;
   constant XADC_INDEX_C    : natural := 8;

   constant AXI_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, x"0000_0000", 22, 18);

   signal writeMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal writeSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal readMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal readSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal coreWriteMasters : AxiLiteWriteMasterArray(NUM_LANE_G-1 downto 0);
   signal coreWriteSlaves  : AxiLiteWriteSlaveArray(NUM_LANE_G-1 downto 0);
   signal coreReadMasters  : AxiLiteReadMasterArray(NUM_LANE_G-1 downto 0);
   signal coreReadSlaves   : AxiLiteReadSlaveArray(NUM_LANE_G-1 downto 0);

   signal clk : sl;
   signal rst : sl;

   signal userValues : Slv32Array(0 to 63);

begin

   userValues(0)       <= LSST_PWR_CORE_VERSION_C;
   userValues(1)       <= APP_TYPE_G;
   userValues(2)       <= toSlv(NUM_LANE_G, 32);
   userValues(3 to 63) <= (others => x"00000000");

   axilClk <= clk;
   axilRst <= rst;

   axilReadMasters(6 downto 0) <= readMasters(6 downto 0);
   readSlaves(6 downto 0)      <= axilReadSlaves(6 downto 0);

   axilWriteMasters(6 downto 0) <= writeMasters(6 downto 0);
   writeSlaves(6 downto 0)      <= axilWriteSlaves(6 downto 0);

   U_Heartbeat : entity work.Heartbeat
      generic map(
         TPD_G       => TPD_G,
         PERIOD_IN_G => (1.0/SYS_CLK_FREQ_C))
      port map (
         clk => clk,
         o   => heartBeat);

   -------------------
   -- Ethernet Wrapper
   -------------------
   U_Eth : entity work.LsstPwrCtrlEth
      generic map (
         TPD_G                 => TPD_G,
         NUM_LANE_G            => NUM_LANE_G,
         OVERRIDE_ETH_CONFIG_G => OVERRIDE_ETH_CONFIG_G,
         OVERRIDE_MAC_ADDR_G   => OVERRIDE_MAC_ADDR_G,
         OVERRIDE_IP_ADDR_G    => OVERRIDE_IP_ADDR_G,
         SYS_CLK_FREQ_G        => SYS_CLK_FREQ_C)
      port map (
         -- Register Interface
         axilClk          => clk,
         axilRst          => rst,
         axilReadMasters  => coreReadMasters,
         axilReadSlaves   => coreReadSlaves,
         axilWriteMasters => coreWriteMasters,
         axilWriteSlaves  => coreWriteSlaves,
         -- Misc. Signals
         extRstL          => extRstL,
         ethLinkUp        => ethLinkUp,
         rssiLinkUp       => rssiLinkUp,
         efuse            => efuse,
         -- 1GbE Ports
         ethClkP          => ethClkP,
         ethClkN          => ethClkN,
         ethRxP           => ethRxP,
         ethRxN           => ethRxN,
         ethTxP           => ethTxP,
         ethTxN           => ethTxN);

   ---------------------------
   -- AXI-Lite Crossbar Module
   ---------------------------
   U_Xbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => NUM_LANE_G,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_XBAR_CONFIG_C)
      port map (
         axiClk           => clk,
         axiClkRst        => rst,
         sAxiWriteMasters => coreWriteMasters,
         sAxiWriteSlaves  => coreWriteSlaves,
         sAxiReadMasters  => coreReadMasters,
         sAxiReadSlaves   => coreReadSlaves,
         mAxiWriteMasters => writeMasters,
         mAxiWriteSlaves  => writeSlaves,
         mAxiReadMasters  => readMasters,
         mAxiReadSlaves   => readSlaves);

   ---------------------------
   -- AXI-Lite: Version Module
   ---------------------------
   U_Version : entity work.AxiVersion
      generic map (
         TPD_G              => TPD_G,
         BUILD_INFO_G       => BUILD_INFO_G,
         CLK_PERIOD_G       => (1.0/SYS_CLK_FREQ_C),
         XIL_DEVICE_G       => "7SERIES",
         EN_DEVICE_DNA_G    => true,
         EN_DS2411_G        => false,
         EN_ICAP_G          => true,
         USE_SLOWCLK_G      => false,
         BUFR_CLK_DIV_G     => 8,
         AUTO_RELOAD_EN_G   => false,
         AUTO_RELOAD_TIME_G => 10.0,
         AUTO_RELOAD_ADDR_G => (others => '0'))
      port map (
         axiReadMaster  => readMasters(VERSION_INDEX_C),
         axiReadSlave   => readSlaves(VERSION_INDEX_C),
         axiWriteMaster => writeMasters(VERSION_INDEX_C),
         axiWriteSlave  => writeSlaves(VERSION_INDEX_C),
         userValues     => userValues,
         dnaValueOut    => dnaValue,
         axiClk         => clk,
         axiRst         => rst);

   -----------------------
   -- AXI-Lite XADC Module
   -----------------------
   U_Xadc : entity work.AxiXadcMinimumCore
      port map (
         -- XADC Ports
         vPIn           => vPIn,
         vNIn           => vNIn,
         -- AXI-Lite Register Interface
         axiReadMaster  => readMasters(XADC_INDEX_C),
         axiReadSlave   => readSlaves(XADC_INDEX_C),
         axiWriteMaster => writeMasters(XADC_INDEX_C),
         axiWriteSlave  => writeSlaves(XADC_INDEX_C),
         -- Clocks and Resets
         axiClk         => clk,
         axiRst         => rst);

end mapping;

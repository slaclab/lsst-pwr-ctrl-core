-------------------------------------------------------------------------------
-- File       : LsstPwrCtrlCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-05-01
-- Last update: 2018-02-27
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

library unisim;
use unisim.vcomponents.all;

entity LsstPwrCtrlCore is
   generic (
      TPD_G                 : time             := 1 ns;
      OVERRIDE_ETH_CONFIG_G : boolean          := false;
      OVERRIDE_MAC_ADDR_G   : slv(47 downto 0) := x"00_00_16_56_00_08";  -- 08:00:56:16:00:00      
      OVERRIDE_IP_ADDR_G    : slv(31 downto 0) := x"0A_01_A8_C0";  -- 192.168.1.10
      BUILD_INFO_G          : BuildInfoType);
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
      ethLinkUp        : out sl;
      rssiLinkUp       : out sl;
      heartBeat        : out sl;
      efuse            : out slv(31 downto 0);
      dnaValue         : out slv(127 downto 0);
      -- XADC Ports
      vPIn             : in  sl;
      vNIn             : in  sl;
      -- Boot Memory Ports
      bootCsL          : out sl;
      bootMosi         : out sl;
      bootMiso         : in  sl;
      bootWpL          : out sl;
      bootHdL          : out sl;
      -- 1GbE Ports
      ethClkP          : in  sl;
      ethClkN          : in  sl;
      ethRxP           : in  sl;
      ethRxN           : in  sl;
      ethTxP           : out sl;
      ethTxN           : out sl);
end LsstPwrCtrlCore;

architecture mapping of LsstPwrCtrlCore is

   constant SYS_CLK_FREQ_C : real := 125.0E+6;

   constant NUM_AXI_MASTERS_C : natural := 10;

   constant VERSION_INDEX_C   : natural := 7;
   constant XADC_INDEX_C      : natural := 8;
   constant BOOT_PROM_INDEX_C : natural := 9;

   constant AXI_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, x"0000_0000", 22, 18);

   signal writeMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal writeSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal readMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal readSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal clk     : sl;
   signal rst     : sl;
   signal bootSck : sl;

begin

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
         OVERRIDE_ETH_CONFIG_G => OVERRIDE_ETH_CONFIG_G,
         OVERRIDE_MAC_ADDR_G   => OVERRIDE_MAC_ADDR_G,
         OVERRIDE_IP_ADDR_G    => OVERRIDE_IP_ADDR_G,
         SYS_CLK_FREQ_G        => SYS_CLK_FREQ_C)
      port map (
         -- Register Interface
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- Misc.
         extRstL         => extRstL,
         ethLinkUp       => ethLinkUp,
         rssiLinkUp      => rssiLinkUp,
         efuse           => efuse,
         -- 1GbE Ports
         ethClkP         => ethClkP,
         ethClkN         => ethClkN,
         ethRxP          => ethRxP,
         ethRxN          => ethRxN,
         ethTxP          => ethTxP,
         ethTxN          => ethTxN);

   ---------------------------
   -- AXI-Lite Crossbar Module
   ---------------------------
   U_Xbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_XBAR_CONFIG_C)
      port map (
         axiClk              => clk,
         axiClkRst           => rst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => writeMasters,
         mAxiWriteSlaves     => writeSlaves,
         mAxiReadMasters     => readMasters,
         mAxiReadSlaves      => readSlaves);

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

   ----------------------
   -- AXI-Lite: Boot Prom
   ----------------------
   U_SpiProm : entity work.AxiMicronN25QCore
      generic map (
         TPD_G           => TPD_G,
         MEM_ADDR_MASK_G => x"00000000",
         AXI_CLK_FREQ_G  => SYS_CLK_FREQ_C,
         SPI_CLK_FREQ_G  => (SYS_CLK_FREQ_C/5.0))
      port map (
         -- FLASH Memory Ports
         csL            => bootCsL,
         sck            => bootSck,
         mosi           => bootMosi,
         miso           => bootMiso,
         -- AXI-Lite Register Interface
         axiReadMaster  => readMasters(BOOT_PROM_INDEX_C),
         axiReadSlave   => readSlaves(BOOT_PROM_INDEX_C),
         axiWriteMaster => writeMasters(BOOT_PROM_INDEX_C),
         axiWriteSlave  => writeSlaves(BOOT_PROM_INDEX_C),
         -- Clocks and Resets
         axiClk         => clk,
         axiRst         => rst);

   bootWpL <= '1';
   bootHdL <= '1';

   -----------------------------------------------------
   -- Using the STARTUPE2 to access the FPGA's CCLK port
   -----------------------------------------------------
   U_STARTUPE2 : STARTUPE2
      port map (
         CFGCLK    => open,  -- 1-bit output: Configuration main clock output
         CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
         EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
         PREQ      => open,  -- 1-bit output: PROGRAM request to fabric output
         CLK       => '0',  -- 1-bit input: User start-up clock input
         GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
         GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
         KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
         PACK      => '0',  -- 1-bit input: PROGRAM acknowledge input
         USRCCLKO  => bootSck,          -- 1-bit input: User CCLK input
         USRCCLKTS => '0',  -- 1-bit input: User CCLK 3-state enable input
         USRDONEO  => '1',  -- 1-bit input: User DONE pin output control
         USRDONETS => '1');  -- 1-bit input: User DONE 3-state enable output   

end mapping;

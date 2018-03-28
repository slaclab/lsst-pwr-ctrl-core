-------------------------------------------------------------------------------
-- File       : LsstPwrCtrlEth.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-05-01
-- Last update: 2018-03-28
-------------------------------------------------------------------------------
-- Description: LSST's Common Power Controller Core: Ethernet Wrapper
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
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity LsstPwrCtrlEth is
   generic (
      TPD_G                 : time                  := 1 ns;
      NUM_LANE_G            : positive range 1 to 4 := 1;
      OVERRIDE_ETH_CONFIG_G : boolean               := false;
      OVERRIDE_MAC_ADDR_G   : slv(47 downto 0)      := x"00_00_16_56_00_08";
      OVERRIDE_IP_ADDR_G    : slv(31 downto 0)      := x"0A_01_A8_C0";
      SYS_CLK_FREQ_G        : real                  := 125.0E+6);
   port (
      -- Register Interface
      axilClk          : out sl;
      axilRst          : out sl;
      axilReadMasters  : out AxiLiteReadMasterArray(NUM_LANE_G-1 downto 0);
      axilReadSlaves   : in  AxiLiteReadSlaveArray(NUM_LANE_G-1 downto 0);
      axilWriteMasters : out AxiLiteWriteMasterArray(NUM_LANE_G-1 downto 0);
      axilWriteSlaves  : in  AxiLiteWriteSlaveArray(NUM_LANE_G-1 downto 0);
      -- Misc. Signals
      extRstL          : in  sl;
      ethLinkUp        : out slv(NUM_LANE_G-1 downto 0);
      rssiLinkUp       : out slv(NUM_LANE_G-1 downto 0);
      efuse            : out slv(31 downto 0);
      -- 1GbE Ports
      ethClkP          : in  sl;
      ethClkN          : in  sl;
      ethRxP           : in  slv(NUM_LANE_G-1 downto 0);
      ethRxN           : in  slv(NUM_LANE_G-1 downto 0);
      ethTxP           : out slv(NUM_LANE_G-1 downto 0);
      ethTxN           : out slv(NUM_LANE_G-1 downto 0));
end LsstPwrCtrlEth;

architecture mapping of LsstPwrCtrlEth is

   constant DHCP_C          : boolean := false;  -- false = static address, true = DHCP
   constant RSSI_C          : boolean := false;  -- false = UDP only, true = RUDP
   constant APP_ILEAVE_EN_C : boolean := false;  -- false = RSSI uses AxiStreamPacketizer1, true = RSSI uses AxiStreamPacketizer2

   constant SERVER_PORTS_C : PositiveArray(0 downto 0)        := (0 => 8192);  -- UDP Server @ Port = 8192
   constant AXIS_CONFIG_C  : AxiStreamConfigArray(0 downto 0) := (0 => EMAC_AXIS_CONFIG_C);

   signal obMacMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal obMacSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
   signal ibMacMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal ibMacSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);

   signal obServerMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal obServerSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
   signal ibServerMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal ibServerSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);

   signal appIbMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal appIbSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
   signal appObMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal appObSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);

   signal localMac : Slv48Array(NUM_LANE_G-1 downto 0);
   signal dmaClk   : slv(NUM_LANE_G-1 downto 0);
   signal dmaRst   : slv(NUM_LANE_G-1 downto 0);

   signal ethClk     : sl;
   signal ethRst     : sl;
   signal extRst     : sl;
   signal rssiStatus : Slv7Array(3 downto 0) := (others => (others => '0'));

   signal ethMac : slv(47 downto 0);
   signal ethIp  : slv(31 downto 0);


begin

   axilClk <= ethClk;
   axilRst <= ethRst;
   extRst  <= not(extRstL);

   -------------------------
   -- Ethernet Configuration
   -------------------------   
   GEN_CONFIG : if (OVERRIDE_ETH_CONFIG_G = false) generate

      U_Config : entity work.LsstPwrCtrlEthConfig
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clock and Reset
            clk   => ethClk,
            rst   => ethRst,
            -- MAC and IP address
            mac   => ethMac,
            ip    => ethIp,
            efuse => efuse);

   end generate;

   BYP_CONFIG : if (OVERRIDE_ETH_CONFIG_G = true) generate

      ethMac <= OVERRIDE_MAC_ADDR_G;
      ethIp  <= OVERRIDE_IP_ADDR_G;
      efuse  <= (others => '0');

   end generate;

   ------------------------
   -- GigE Core for ARTIX-7
   ------------------------
   U_PHY_MAC : entity work.GigEthGtp7Wrapper
      generic map (
         TPD_G              => TPD_G,
         NUM_LANE_G         => NUM_LANE_G,
         -- Clocking Configurations
         USE_GTREFCLK_G     => false,
         CLKIN_PERIOD_G     => 8.0,     -- 125MHz
         DIVCLK_DIVIDE_G    => 1,       -- 125 MHz = (125 MHz/1)
         CLKFBOUT_MULT_F_G  => 8.0,     -- 1 GHz = (8 x 125 MHz)
         CLKOUT0_DIVIDE_F_G => 8.0,     -- 125 MHz = (1.0 GHz/8)
         -- AXI Streaming Configurations
         AXIS_CONFIG_G      => (others => EMAC_AXIS_CONFIG_C))
      port map (
         -- Local Configurations
         localMac     => localMac,
         -- Streaming DMA Interface
         dmaClk       => dmaClk,
         dmaRst       => dmaRst,
         dmaIbMasters => obMacMasters,
         dmaIbSlaves  => obMacSlaves,
         dmaObMasters => ibMacMasters,
         dmaObSlaves  => ibMacSlaves,
         -- Misc. Signals
         extRst       => extRst,
         phyClk       => ethClk,
         phyRst       => ethRst,
         phyReady     => ethLinkUp,
         -- MGT Ports
         gtClkP       => ethClkP,
         gtClkN       => ethClkN,
         gtTxP        => ethTxP,
         gtTxN        => ethTxN,
         gtRxP        => ethRxP,
         gtRxN        => ethRxN);


   localMac <= (others => ethMac);
   dmaClk   <= (others => ethClk);
   dmaRst   <= (others => ethRst);

   GEN_LANE :
   for i in 0 to NUM_LANE_G-1 generate

      ----------------------
      -- IPv4/ARP/UDP Engine
      ----------------------
      U_UDP : entity work.UdpEngineWrapper
         generic map (
            -- Simulation Generics
            TPD_G          => TPD_G,
            -- UDP Server Generics
            SERVER_EN_G    => true,
            SERVER_SIZE_G  => 1,
            SERVER_PORTS_G => SERVER_PORTS_C,
            -- UDP Client Generics
            CLIENT_EN_G    => false,
            -- General IPv4/ARP/DHCP Generics
            DHCP_G         => DHCP_C,
            CLK_FREQ_G     => SYS_CLK_FREQ_G,
            COMM_TIMEOUT_G => 30)
         port map (
            -- Local Configurations
            localMac           => ethMac,
            localIp            => ethIp,
            -- Interface to Ethernet Media Access Controller (MAC)
            obMacMaster        => obMacMasters(i),
            obMacSlave         => obMacSlaves(i),
            ibMacMaster        => ibMacMasters(i),
            ibMacSlave         => ibMacSlaves(i),
            -- Interface to UDP Server engine(s)
            obServerMasters(0) => obServerMasters(i),
            obServerSlaves(0)  => obServerSlaves(i),
            ibServerMasters(0) => ibServerMasters(i),
            ibServerSlaves(0)  => ibServerSlaves(i),
            -- Clock and Reset
            clk                => ethClk,
            rst                => ethRst);

      GEN_RSSI : if (RSSI_C = true) generate
         ---------------------------------------------------------------
         -- Wrapper for RSSI + AXIS Packetizer
         -- Documentation: https://confluence.slac.stanford.edu/x/1IyfD
         ---------------------------------------------------------------
         U_RssiServer : entity work.RssiCoreWrapper
            generic map (
               TPD_G               => TPD_G,
               APP_ILEAVE_EN_G     => APP_ILEAVE_EN_C,
               MAX_SEG_SIZE_G      => 1024,
               SEGMENT_ADDR_SIZE_G => 7,
               APP_STREAMS_G       => 1,
               APP_STREAM_ROUTES_G => (0 => "--------"),
               CLK_FREQUENCY_G     => SYS_CLK_FREQ_G,
               TIMEOUT_UNIT_G      => 1.0E-3,  -- In units of seconds
               SERVER_G            => true,
               RETRANSMIT_ENABLE_G => true,
               BYPASS_CHUNKER_G    => false,
               WINDOW_ADDR_SIZE_G  => 3,
               PIPE_STAGES_G       => 1,
               APP_AXIS_CONFIG_G   => AXIS_CONFIG_C,
               TSP_AXIS_CONFIG_G   => EMAC_AXIS_CONFIG_C,
               INIT_SEQ_N_G        => 16#80#)
            port map (
               clk_i                => ethClk,
               rst_i                => ethRst,
               openRq_i             => '1',
               -- Transport Layer Interface
               sTspAxisMaster_i     => obServerMasters(i),
               sTspAxisSlave_o      => obServerSlaves(i),
               mTspAxisMaster_o     => ibServerMasters(i),
               mTspAxisSlave_i      => ibServerSlaves(i),
               -- Application Layer Interface
               sAppAxisMasters_i(0) => appIbMasters(i),
               sAppAxisSlaves_o(0)  => appIbSlaves(i),
               mAppAxisMasters_o(0) => appObMasters(i),
               mAppAxisSlaves_i(0)  => appObSlaves(i),
               -- Internal statuses
               statusReg_o          => rssiStatus(i));

         rssiLinkUp(i) <= rssiStatus(i)(0);

      end generate;

      BYP_RSSI : if (RSSI_C = false) generate

         ---------------------------
         -- No UDP reliability Layer
         ---------------------------
         appObMasters(i)    <= obServerMasters(i);
         obServerSlaves(i)  <= appObSlaves(i);
         ibServerMasters(i) <= appIbMasters(i);
         appIbSlaves(i)     <= ibServerSlaves(i);
         rssiLinkUp(i)      <= '0';

      end generate;

      ---------------------------------------------------------------
      -- SLAC Register Protocol Version 3, AXI-Lite Interface
      -- Documentation: https://confluence.slac.stanford.edu/x/cRmVD
      ---------------------------------------------------------------
      U_SRPv3 : entity work.SrpV3AxiLite
         generic map (
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => true,
            GEN_SYNC_FIFO_G     => true,
            AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C)
         port map (
            -- Streaming Slave (Rx) Interface (sAxisClk domain)
            sAxisClk         => ethClk,
            sAxisRst         => ethRst,
            sAxisMaster      => appObMasters(i),
            sAxisSlave       => appObSlaves(i),
            -- Streaming Master (Tx) Data Interface (mAxisClk domain)
            mAxisClk         => ethClk,
            mAxisRst         => ethRst,
            mAxisMaster      => appIbMasters(i),
            mAxisSlave       => appIbSlaves(i),
            -- Master AXI-Lite Interface (axilClk domain)
            axilClk          => ethClk,
            axilRst          => ethRst,
            mAxilReadMaster  => axilReadMasters(i),
            mAxilReadSlave   => axilReadSlaves(i),
            mAxilWriteMaster => axilWriteMasters(i),
            mAxilWriteSlave  => axilWriteSlaves(i));

   end generate GEN_LANE;

end mapping;

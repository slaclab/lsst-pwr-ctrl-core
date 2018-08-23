import pyrogue as pr

class Ltc2945(pr.Device):
    def __init__(self, 
                 description = "LTC2945 Voltage and Current Monitor",
                 shunt      = 0,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        self.add(pr.RemoteCommand(   
            name         = 'ADCReadStart',
            description  = '',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            function     = lambda cmd: cmd.post(1)
        ))        

        #######################
        # Control Register
        #######################
        self.add(pr.RemoteVariable(
            name = 'MultiplierSelect',
            description = 'Selects ADIN or SENSE+/VDD (depends on VinMonitor) data for digital multiplication with SENSE data',
            offset = 0x0,
            bitOffset = 0,
            bitSize = 1,
            enum = {1: 'SENSE+/VDD', 0: 'ADIN'}))
        

        self.add(pr.RemoteVariable(
            name = 'ShutdownEnable',
            description = 'Enables Low-Iq / Shutdown Mode',
            offset = 0x0,
            bitOffset = 1,
            bitSize = 1,
            enum = {0: 'Normal Operation', 1: 'Shutdown'}))
        
        self.add(pr.RemoteVariable(
            name = 'VinMonitor',
            description = 'Enables VDD or SENSE+ voltage monitoring',
            offset = 0x0,
            bitOffset = 2,
            bitSize = 1,
            enum = {1: 'SENSE+', 0: 'VDD'}))
                 
        self.add(pr.RemoteVariable(
            name = 'AdcBusy',
            description = 'Adc Current Status',
            mode = 'RO',
            offset = 0x0,
            bitOffset = 3,
            bitSize = 1))
                 
        self.add(pr.RemoteVariable(
            name = 'TestMode',
            description = 'Test Mode Halts ADC Operations and Enables Writes to Interal ADC/LOGIC Registers',
            offset = 0x0,
            bitOffset = 4,
            bitSize = 1,
            enum = {0: 'Disabled', 1: 'Enabled'}))
                 
        self.add(pr.RemoteVariable(
            name = 'AdcChannelLabel',
            description = 'ADC Channel Label for Snapshot Mode',
            offset = 0x0,
            bitOffset = 5,
            bitSize = 2,
            enum = {0: 'DeltaSense', 1: 'Vin', 2: 'ADIN'}))
                 
        self.add(pr.RemoteVariable(
            name = 'AdcSnapshotMode',
            description = 'Enables ADC Snapshot Mode. Only channel selcted by AdcChannelLabel is measure by the ADC. After the conversion, the BUSY bit is reset and the ADC is halted.',
            offset = 0x0,
            bitOffset = 7,
            bitSize = 1,
            enum = {0: 'Disabled', 1: 'Enabled'}))

        ##########################
        # ALERT Register
        #########################

        alerts = ['MaxPowerAlert',
                 'MinPowerAlert',
                 'MaxSenseAlert',
                 'MinSenseAlert',
                 'MaxVinAlert',
                 'MinVinAlert',
                 'MaxADinAlert',
                 'MinADinAlert']
        for i, name in enumerate(alerts):
            self.add(pr.RemoteVariable(
                name = name,
                offset = 0x4,
                bitOffset = i,
                bitSize = 1,
                enum = {0: 'Disabled', 1: 'Enabled'}))


        #########################
        # STATUS Register
        #########################
        statuses = ['PowerOvervaluePresent',
                    'PowerUndervaluePresent',
                    'SenseOvervaluePresent',
                    'SenseUndervaluePresent',
                    'VinOvervaluePresent',
                    'VinUndervaluePresent',
                    'ADinOvervaluePresent',
                    'ADinUndervaluePresent']
        for i, name in enumerate(statuses):
            self.add(pr.RemoteVariable(
                name = name,
                mode = 'RO',
                offset = 0x8,
                bitOffset = i,
                bitSize = 1,
                base = pr.Bool))

        ###########################
        # Fault Register
        ###########################
        faults = ['PowerOvervalueFault',
                    'PowerUndervalueFault',
                    'SenseOvervalueFault',
                    'SenseUndervalueFault',
                    'VinOvervalueFault',
                    'VinUndervalueFault',
                    'ADinOvervalueFault',
                    'ADinUndervalueFault']
        for i, name in enumerate(faults):
            self.add(pr.RemoteVariable(
                name = name,
                mode = 'RO',
                offset = 0xC,
                bitOffset = i,
                bitSize = 1,
                base = pr.Bool))

        
        ##############################
        # Fault Clear
        #############################
        self.add(pr.RemoteCommand(
            name = 'FaultClear',
            description = 'Clear faults',
            offset = 0x10,
            bitOffset = 0,
            bitSize = 8,
            function = pr.RemoteCommand.read))

        #############################
        # ADC Registers
        ############################
        def convPower(raw):
            return lambda: (raw.value() * 10.48) / 16777216.0 / shunt

        def convCurrent(raw):
            return lambda: (raw.value() * .1024) / 4096.0 / shunt

        def convVoltage(raw):
            return lambda: (raw.value() * 102.4) / 4096.0

        def addPair(name, offset, mode, conv, units):
            self.add(pr.RemoteVariable(
                name = name+'Raw',
                hidden = False,
                mode = mode,
                offset = offset,
                base = pr.UInt))
            
            raw = self.nodes[name+'Raw']
            
            self.add(pr.LinkVariable(
                name = name,
                mode = mode,
                units = units,
                variable = raw,
                linkedGet = conv(raw),
                disp = '{:1.3f}'))

        def addGroup(name, offset, mode, conv, units):
            addPair(name, offset, mode, conv, units)
            addPair('Max'+name, offset+4, mode, conv, units)
            addPair('Min'+name, offset+8, mode, conv, units)

        addGroup('Power', 0x14, 'RO', convPower, 'Watts')
        addGroup('Current', 0x28, 'RO', convCurrent, 'Amps')
        addGroup('Vin', 0x3c, 'RO', convVoltage, 'Volts')
        addGroup('ADin', 0x50, 'RO', convVoltage, 'Volts')

    def readBlocks(self, recurse=True, variable=None, checkEach=False):
        self.ADCReadStart()
        pr.Device.readBlocks(self, recurse, variable, checkEach)


class Ltc2945Raw(pr.Device):
    def __init__(self, 
                 description = "LTC2945 Voltage and Current Monitor",
                 shunt      = 0,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        #######################
        # Control Register
        #######################
        self.add(pr.RemoteVariable(
            name = 'MultiplierSelect',
            description = 'Selects ADIN or SENSE+/VDD (depends on VinMonitor) data for digital multiplication with SENSE data',
            offset = 0x0,
            bitOffset = 0,
            bitSize = 1,
            enum = {1: 'SENSE+/VDD', 0: 'ADIN'}))
        

        self.add(pr.RemoteVariable(
            name = 'ShutdownEnable',
            description = 'Enables Low-Iq / Shutdown Mode',
            offset = 0x0,
            bitOffset = 1,
            bitSize = 1,
            enum = {0: 'Normal Operation', 1: 'Shutdown'}))
        
        self.add(pr.RemoteVariable(
            name = 'VinMonitor',
            description = 'Enables VDD or SENSE+ voltage monitoring',
            offset = 0x0,
            bitOffset = 2,
            bitSize = 1,
            enum = {1: 'SENSE+', 0: 'VDD'}))
                 
        self.add(pr.RemoteVariable(
            name = 'AdcBusy',
            description = 'Adc Current Status',
            mode = 'RO',
            offset = 0x0,
            bitOffset = 3,
            bitSize = 1))
                 
        self.add(pr.RemoteVariable(
            name = 'TestMode',
            description = 'Test Mode Halts ADC Operations and Enables Writes to Interal ADC/LOGIC Registers',
            offset = 0x0,
            bitOffset = 4,
            bitSize = 1,
            enum = {0: 'Disabled', 1: 'Enabled'}))
                 
        self.add(pr.RemoteVariable(
            name = 'AdcChannelLabel',
            description = 'ADC Channel Label for Snapshot Mode',
            offset = 0x0,
            bitOffset = 5,
            bitSize = 2,
            enum = {0: 'DeltaSense', 1: 'Vin', 2: 'ADIN'}))
                 
        self.add(pr.RemoteVariable(
            name = 'AdcSnapshotMode',
            description = 'Enables ADC Snapshot Mode. Only channel selcted by AdcChannelLabel is measure by the ADC. After the conversion, the BUSY bit is reset and the ADC is halted.',
            offset = 0x0,
            bitOffset = 7,
            bitSize = 1,
            enum = {0: 'Disabled', 1: 'Enabled'}))

        ##########################
        # ALERT Register
        #########################

        alerts = ['MaxPowerAlert',
                 'MinPowerAlert',
                 'MaxSenseAlert',
                 'MinSenseAlert',
                 'MaxVinAlert',
                 'MinVinAlert',
                 'MaxADinAlert',
                 'MinADinAlert']
        for i, name in enumerate(alerts):
            self.add(pr.RemoteVariable(
                name = name,
                offset = 0x1,
                bitOffset = i,
                bitSize = 1,
                enum = {0: 'Disabled', 1: 'Enabled'}))


        #########################
        # STATUS Register
        #########################
        statuses = ['PowerOvervaluePresent',
                    'PowerUndervaluePresent',
                    'SenseOvervaluePresent',
                    'SenseUndervaluePresent',
                    'VinOvervaluePresent',
                    'VinUndervaluePresent',
                    'ADinOvervaluePresent',
                    'ADinUndervaluePresent']
        for i, name in enumerate(statuses):
            self.add(pr.RemoteVariable(
                name = name,
                mode = 'RO',
                offset = 0x2,
                bitOffset = i,
                bitSize = 1,
                base = pr.Bool))

        ###########################
        # Fault Register
        ###########################
        faults = ['PowerOvervalueFault',
                    'PowerUndervalueFault',
                    'SenseOvervalueFault',
                    'SenseUndervalueFault',
                    'VinOvervalueFault',
                    'VinUndervalueFault',
                    'ADinOvervalueFault',
                    'ADinUndervalueFault']
        for i, name in enumerate(faults):
            self.add(pr.RemoteVariable(
                name = name,
                mode = 'RO',
                offset = 0x3,
                bitOffset = i,
                bitSize = 1,
                base = pr.Bool))

        
        ##############################
        # Fault Clear
        #############################
 #        self.add(pr.RemoteCommand(
#             name = 'FaultClear',
#             description = 'Clear faults',
#             offset = 0x10,
#             bitOffset = 0,
#             bitSize = 8,
#             function = pr.RemoteCommand.read))

        #############################
        # ADC Registers
        ############################
        def convPower(raw):
            return lambda: (raw.value() * 10.48) / 16777216.0 / shunt

        def convCurrent(raw):
            return lambda: (raw.value() * .1024) / 4096.0 / shunt

        def convVoltage(raw):
            return lambda: (raw.value() * 102.4) / 4096.0

        def addPair(name, offset, mode, conv, units):
            self.add(pr.RemoteVariable(
                name = name+'Raw',
                hidden = False,
                mode = mode,
                offset = offset,
                base = pr.UInt))
            
            raw = self.nodes[name+'Raw']
            
            self.add(pr.LinkVariable(
                name = name,
                mode = mode,
                units = units,
                variable = raw,
                linkedGet = conv(raw),
                disp = '{:1.3f}'))

        def addGroup(name, offsets, bitOffset, bitSize, conv, units):
            addPair(name, offsets[0]*4, bitOffset, bitSize, conv, units)
            addPair('Max'+name, offsets[1]*4, bitOffset, bitSize, conv, units)
            addPair('Min'+name, offsets[2]*4, bitOffset, bitSize, conv, units)

        addGroup('Power', [0x5, 0x8, 0xB], 8,  12, convPower, 'Watts')
        addGroup('Sense', [0x14, 0x16, 0x18], 0, 8, convCurrent, 'Amps')
        addGroup('Vin', [0x1E, 0x20, 0x22], 0, 8, convVoltage, 'Volts')
        addGroup('ADin', [0x28, 0x2A, 0x2C], 0, 8, convVoltage, 'Volts')

            
class LambdaSupply(pr.Device):
    def __init__(self, 
                 description = "Lambda Power Supply I2C",
                 VScale = 0,
                 IScale = 0,
                 **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        self.add(pr.RemoteCommand(   
            name         = 'ADCReadStart',
            description  = '',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            function     = lambda cmd: cmd.post(1)
        )) 
        
        
        self.add(pr.RemoteVariable(   
            name         = 'SerialNumber',
            description  = 'Serial Number',
            offset       = 0x00,
            bitSize      = 8*20,
            bitOffset    = 0x00,
            base         = pr.String,
            mode         = 'RO',
        ))


        self.add(pr.RemoteVariable(   
            name         = 'FirmWareVersion',
            description  = 'FirmWare Version',
            offset       = 0x14,
            bitSize      = 8*4,
            bitOffset    = 0x00,
            base         = pr.String,
            mode         = 'RO',
        ))


        self.add(pr.RemoteVariable(   
            name         = 'ProductVersion',
            description  = 'Product Version',
            offset       = 0x18,
            bitSize      = 8*4,
            bitOffset    = 0x00,
            base         = pr.String,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name    = 'OutputV',
            offset  = 0x1C,
            mode    = 'RO',
        ))

        self.add(pr.LinkVariable(
            name = 'OutputVolts',
            mode = 'RO',
            units = 'volts',
            variable = self.OutputV,
            linkedGet = lambda raw = self.OutputV: (raw.value() * VScale),
            disp = '{:1.3f}',
        ))

        self.add(pr.RemoteVariable(
            name    = 'OutputI',
            offset  = 0x20,
            mode    = 'RO',
        ))

        self.add(pr.LinkVariable(
            name = 'OutputCurrent',
            mode = 'RO',
            units = 'Amps',
            variable = self.OutputI,
            linkedGet = lambda raw = self.OutputI: (raw.value() * IScale),
            disp = '{:1.3f}',
        ))     

        self.add(pr.RemoteVariable(
            name    = 'PlateTemp',
            offset  = 0x24,
            mode    = 'RO',
        ))

        self.add(pr.LinkVariable(
            name = 'SupplyTemp',
            mode = 'RO',
            units = 'temp(c)',
            variable = self.PlateTemp,
            linkedGet = lambda raw = self.PlateTemp: ((raw.value()-610)/2.048 + 25),
            disp = '{:1.3f}',
        ))     

        self.add(pr.RemoteVariable(
            name    = 'Status',
            offset  = 0x28,
            mode    = 'RO',
        ))


        self.add(pr.RemoteVariable(   
            name         = 'PartNumber',
            description  = 'Part Number',
            offset       = 0x2C,
            bitSize      = 8*12,
            bitOffset    = 0x00,
            base         = pr.String,
            mode         = 'RO',
        ))


        self.add(pr.RemoteVariable(   
            name         = 'ManufDate',
            description  = 'Manuf Date',
            offset       = 0x38,
            bitSize      = 8*8,
            bitOffset    = 0x00,
            base         = pr.String,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(   
            name         = 'ManufLoc',
            description  = 'Manuf Loc',
            offset       = 0x40,
            bitSize      = 8*3,
            bitOffset    = 0x00,
            base         = pr.String,
            mode         = 'RO',
        ))


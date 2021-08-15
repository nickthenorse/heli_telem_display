--[[------------------------------------------------------------------------------------------
	
	Heli Telem. Display - Full Screen Telemetry Display for Helicopters
	
    By Nick Pedersen (username "nickthenorse" on RCGroups.com and HeliFreak.com).
	
	v1.0 - 2021-08-14 - Initial release
	
	Thanks for trying out my Jeti Lua app! This is my attempt at learning Lua as well as 
	putting together an app for how I specifically wanted to display the telemetry for my
	FBL-based helicopters. It is based on my use of the Brain2 FBL, but will work well with
	any modern FBL controller. The one caveat is that it is very much dependent on having
	current and capacity sensing from the ESC.
	
	It is a full screen telemetry window, and is hardcoded to display:
	
		- A flight timer (counts upwards only).

		- Rx telemetry: Instantaneous and mininum values for Q, A1, A2, and Rx voltage 
		  (max/min recorded for voltage). Signal levels also shown graphically.
		  
		- Maximum recorded FBL rotation rates for the elevator, aileron and rudder channels 
		  for the flight.
		  
		- Headspeed (instantaneous and maximum).

		- Lipo capacity used, in both percentage and in mAh. Capacity used also shown graphically
		  with a battery symbol. Total flight capacity of the lipo is assumed to be 80% of the 
		  nominal lipo capacity (ie, 80% of a 3700 mAh lipo = 2960 mAh).
		  
		- Custom selectable voice file/alarm levels for battery capacity used during the flight.

		- Custom selectable estimation of used battery capacity based on voltage, if the Rx is
		  powered up with a lipo that is not fully charged. Can also warn via audible voice file.
		  
		- The instantaneous and maximum values for ESC current, ESC temperature, ESC 
		  throttle/power, and FBL vibration level.
		  
		- Main flight pack voltage per cell (just the total lipo voltage divided by the
		  number of cells), as well as the min and max values recorded during the flight.
		  Min and max voltages shown graphically.
		  
		- Custom defineable voltage correction factor/multiplier - most ESCs do not allow you to tweak 
		  the voltage reading in case it is a few percent inaccurate.
		  
		- This main flight pack voltage per cell is also recorded as a custom variable in the
		  Jeti flight logs.
		  
		- Allows user to define a time delay to allow for FBL initialisation. Typically need ca. 10 seconds.

		- Allows user to specify number of samples to average voltage readings.

		- The app will detect when a new lipo is plugged in and automatically reset the flight timer and telemetry values,
		  though this can also be done manually by defining the appropriate switches in the menu.
		  
	This is purely for my own hobbyist and non-commercial use.	No liability or responsibility 
	is assumed for your own use! Feel free to use this code in any way you see fit to modify 
	and/or personalise the telemetry that is being displayed, or as a way to learn lua for yourself.
	
	Also: this is my first attempt at a lua app for Jeti. I can't claim it is particularly
	efficiently coded, and is in no way optimised for optimal memory usage. But it works :)
	
	Code heavily inspired by JETI model s.r.o.'s own lua application samples, as well as:

		- Tero excellent collection of lua "Jeti Tools" https://www.rc-thoughts.com/
		- Thorn's "Display" app from https://www.jetiforum.de/ and https://www.thorn-klaus-jeti.de
		- Dit71's "dbdis" app from https://www.jetiforum.de/ and https://github.com/ribid1/dbdis

--------------------------------------------------------------------------------------------]]


--------------------------------------------------------------------------------------------
-- Variable declarations
--------------------------------------------------------------------------------------------

collectgarbage()

local debugOn = false

--
local sensorsAvailable = {}
local voltageSensorID, voltageSensorParam
local voltageSensorName, voltageSensorLabel
local currentSensorID, currentSensorParam
local capacitySensorID, capacitySensorParam
local temperatureSensorID, temperatureSensorParam
local throttleSensorID, throttleSensorParam
local rpmSensorID, rpmSensorParam
local vibrationsSensorID, vibrationsSensorParam
local elevatorSensorID, elevatorSensorParam
local aileronSensorID, aileronSensorParam
local rudderSensorID, rudderSensorParam

local lipoCellCount
local lipoCapacity
local correctionFactor
local estimateUsedLipoBoolean
local checkboxIndex1
local checkboxIndex2
local estimateUsedLipo
local voltageThresholdUsedLipo
local alarmUsedLipoDetectedFile
local isAlarmUsedLipoDetectedActive = false

local timeDelay

local averagingWindowCellVoltage
local averagingWindowRxVoltage

local switchStartTimer
local switchResetTimer
local switchActivateTelemetryMinMax
local switchResetTelemetryMinMax

local alarmCapacityLevelOne
local alarmCapacityLevelTwo
local alarmCapacityLevelThree
local alarmCapacityLevelFour
local alarmCapacityLevelFive
local alarmCapacityLevelSix
local alarmCapacityLevelOneFile
local alarmCapacityLevelTwoFile
local alarmCapacityLevelThreeFile
local alarmCapacityLevelFourFile
local alarmCapacityLevelFiveFile
local alarmCapacityLevelSixFile
local alarmVoltageLevelOne

local lowVoltageChirp = 0
local lowVoltageChirpBoolean = false

local minVoltagePerCell = 99.9
local maxVoltagePerCell = -1.0
local rx_1_Q_min = 101
local rx_1_RSSI_A1_min = 1000
local rx_1_RSSI_A2_min = 1000
local rx_1_Voltage_min = 99.9
local rx_1_Voltage_max = -1.0
local escCurrentMax = -1.0
local escTempMax = -1
local escThrottleMax = -1
local vibrationsMax = -1
local rpmMax = -1
local elevatorRateMin = 1e6
local elevatorRateMax = -1e6
local aileronRateMin = 1e6
local aileronRateMax = -1e6
local rudderRateMin = 1e6
local rudderRateMax = -1e6
local value_list_cell_voltages={}
local value_list_rx_1_voltages={}

local currentTime
local isRxPoweredOn = false
local hasRxBeenPoweredOn = false
local timeAtPowerOn = 0.0
local timeCounter = 0
local resetRx = false

local isAlarmCapacityOneActive = false
local isAlarmCapacityTwoActive = false
local isAlarmCapacityThreeActive = false
local isAlarmCapacityFourActive = false
local isAlarmCapacityFiveActive = false
local isAlarmCapacitySixActive = false

local resetTelemetryMinMax
local activateTelemetryMinMax

local voltagePerCell = 0.0
local voltagePerCellAveraged = 0.0
local voltagePerCellAtStartup = 0.0
local batteryCapacityPercentAtStartup = 0.0
local batteryCapacityUsedAtStartup = 0.0
local effectivePercentageAtStartUp = 0.0

local rx_1_Voltage_Averaged = 0.0
local escCurrent = 0.0
local escTemp = 0
local escThrottle = 0
local vibrations = 0
local rpm = 0
local batteryCapacityUsed = 0
local batteryCapacityUsedTotal = 0
local elevatorRate = 0
local aileronRate = 0
local rudderRate = 0

local telemetryActive = false
local hasVoltageStartupBeenRead = false

local flightTimerActive = -1
local resetTimer = -1

local lastTime = 0
local avgTime = 0

local flightTimeMinutesSecondsString = ""
local flightTimeTenthsString = ""

local effectiveLipoCapacity = 0

local batteryPercentage=55
local batteryPercentageRounded=0

local rx_1_Q = 0
local rx_1_Voltage = 0.0
local rx_1_RSSI_A1 = 0
local rx_1_RSSI_A2 = 0

--------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------------------
-- Converts voltage reading to a percentage (code from Tero @ RC-Thoughts.com)
--------------------------------------------------------------------------------------------
local function voltageAsAPercentage(value)
	
	local percentList={{3,0},{3.093,1},{3.196,2},{3.301,3},{3.401,4},{3.477,5},{3.544,6},{3.601,7},{3.637,8},{3.664,9},{3.679,10},{3.683,11},{3.689,12},{3.692,13},{3.705,14},{3.71,15},{3.713,16},{3.715,17},{3.72,18},{3.731,19},{3.735,20},{3.744,21},{3.753,22},{3.756,23},{3.758,24},{3.762,25},{3.767,26},{3.774,27},{3.78,28},{3.783,29},{3.786,30},{3.789,31},{3.794,32},{3.797,33},{3.8,34},{3.802,35},{3.805,36},{3.808,37},{3.811,38},{3.815,39},{3.818,40},{3.822,41},{3.825,42},{3.829,43},{3.833,44},{3.836,45},{3.84,46},{3.843,47},{3.847,48},{3.85,49},{3.854,50},{3.857,51},{3.86,52},{3.863,53},{3.866,54},{3.87,55},{3.874,56},{3.879,57},{3.888,58},{3.893,59},{3.897,60},{3.902,61},{3.906,62},{3.911,63},{3.918,64},{3.923,65},{3.928,66},{3.939,67},{3.943,68},{3.949,69},{3.955,70},{3.961,71},{3.968,72},{3.974,73},{3.981,74},{3.987,75},{3.994,76},{4.001,77},{4.007,78},{4.014,79},{4.021,80},{4.029,81},{4.036,82},{4.044,83},{4.052,84},{4.062,85},{4.074,86},{4.085,87},{4.095,88},{4.105,89},{4.111,90},{4.116,91},{4.12,92},{4.125,93},{4.129,94},{4.135,95},{4.145,96},{4.176,97},{4.179,98},{4.193,99},{4.2,100}}

    local result=0
    if(value > 4.2 or value < 3.00)then
        if(value > 4.2)then
            result=100
        end
        if(value < 3.00)then
            result=0
        end
        else
        for index,entry in ipairs(percentList) do
            if(entry[1] >= value)then
                result=entry[2]
                break
            end
        end
    end
	
    --collectgarbage()
	
    return result

end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Functions to save new user input values
--------------------------------------------------------------------------------------------
local function voltageSensorChanged(value)
	voltageSensorID = sensorsAvailable[value].id
	voltageSensorParam = sensorsAvailable[value].param
	voltageSensorName = sensorsAvailable[value].sensorName
	voltageSensorLabel = sensorsAvailable[value].label
	system.pSave("voltageSensorID",voltageSensorID)
	system.pSave("voltageSensorParam",voltageSensorParam)
	system.pSave("voltageSensorName",voltageSensorName)
	system.pSave("voltageSensorLabel",voltageSensorLabel)
	if (debugOn == true) then
		print("Voltage sensor",voltageSensorID,voltageSensorParam)
	end
end

local function currentSensorChanged(value)
	currentSensorID = sensorsAvailable[value].id
	currentSensorParam = sensorsAvailable[value].param
	system.pSave("currentSensorID",currentSensorID)
	system.pSave("currentSensorParam",currentSensorParam)
	if (debugOn == true) then
		print("Current sensor",currentSensorID,currentSensorParam)
	end
end

local function capacitySensorChanged(value)
	capacitySensorID = sensorsAvailable[value].id
	capacitySensorParam = sensorsAvailable[value].param
	system.pSave("capacitySensorID",capacitySensorID)
	system.pSave("capacitySensorParam",capacitySensorParam)
	print("Capacity sensor",capacitySensorID,capacitySensorParam)
	
end

local function temperatureSensorChanged(value)
	temperatureSensorID = sensorsAvailable[value].id
	temperatureSensorParam = sensorsAvailable[value].param
	system.pSave("temperatureSensorID",temperatureSensorID)
	system.pSave("temperatureSensorParam",temperatureSensorParam)
	if (debugOn == true) then
		print("Temperature sensor",temperatureSensorID,temperatureSensorParam)
	end
end

local function throttleSensorChanged(value)
	throttleSensorID = sensorsAvailable[value].id
	throttleSensorParam = sensorsAvailable[value].param
	system.pSave("throttleSensorID",throttleSensorID)
	system.pSave("throttleSensorParam",throttleSensorParam)
	if (debugOn == true) then
		print("Throttle sensor",throttleSensorID,throttleSensorParam)
	end
end

local function rpmSensorChanged(value)
	rpmSensorID = sensorsAvailable[value].id
	rpmSensorParam = sensorsAvailable[value].param
	system.pSave("rpmSensorID",rpmSensorID)
	system.pSave("rpmSensorParam",rpmSensorParam)
	if (debugOn == true) then
		print("RPM sensor",rpmSensorID,rpmSensorParam)
	end
end

local function vibrationsSensorChanged(value)
	vibrationsSensorID = sensorsAvailable[value].id
	vibrationsSensorParam = sensorsAvailable[value].param
	system.pSave("vibrationsSensorID",vibrationsSensorID)
	system.pSave("vibrationsSensorParam",vibrationsSensorParam)
	if (debugOn == true) then
		print("Vibrations sensor",vibrationsSensorID,vibrationsSensorParam)
	end
end

local function elevatorSensorChanged(value)
	elevatorSensorID = sensorsAvailable[value].id
	elevatorSensorParam = sensorsAvailable[value].param
	system.pSave("elevatorSensorID",elevatorSensorID)
	system.pSave("elevatorSensorParam",elevatorSensorParam)
	if (debugOn == true) then
		print("Elevator sensor",elevatorSensorID,elevatorSensorParam)
	end
end

local function aileronSensorChanged(value)
	aileronSensorID = sensorsAvailable[value].id
	aileronSensorParam = sensorsAvailable[value].param
	system.pSave("aileronSensorID",aileronSensorID)
	system.pSave("aileronSensorParam",aileronSensorParam)
	if (debugOn == true) then
		print("Aileron sensor",aileronSensorID,aileronSensorParam)
	end
end

local function rudderSensorChanged(value)
	rudderSensorID = sensorsAvailable[value].id
	rudderSensorParam = sensorsAvailable[value].param
	system.pSave("rudderSensorID",rudderSensorID)
	system.pSave("rudderSensorParam",rudderSensorParam)
	if (debugOn == true) then
		print("Rudder sensor",rudderSensorID,rudderSensorParam)
	end
end

local function lipoCellCountChanged(value)
	lipoCellCount = value
	system.pSave("lipoCellCount",value)
	if (debugOn == true) then
		print("Lipo cell count ",value)
	end
end

local function lipoCapacityChanged(value)
	lipoCapacity = value
	system.pSave("lipoCapacity",value)
	if (debugOn == true) then
		print("Lipo capacity ",value)
	end
end

local function correctionFactorChanged(value)
	correctionFactor = value
	system.pSave("correctionFactor",value)
	if (debugOn == true) then
		print("Correction factor  ",value)
	end
end

local function estimateUsedLipoBooleanChanged(value)
	estimateUsedLipoBoolean = not value
	form.setValue(checkboxIndex1,estimateUsedLipoBoolean)
	if (estimateUsedLipoBoolean == true) then
		estimateUsedLipo = 1
		system.pSave("estimateUsedLipo",estimateUsedLipo)
	else
		estimateUsedLipo = 0
		system.pSave("estimateUsedLipo",estimateUsedLipo)
	end
	if (debugOn == true) then
		print("estimateUsedLipo ",estimateUsedLipo,estimateUsedLipoBoolean)
	end
end

local function voltageThresholdUsedLipoChanged(value)
	voltageThresholdUsedLipo = value
	system.pSave("voltageThresholdUsedLipo",value)
	if (debugOn == true) then
		print("voltageThresholdUsedLipo ",voltageThresholdUsedLipo)
	end
end

local function alarmUsedLipoDetectedFileChanged(value)
	alarmUsedLipoDetectedFile = value
	system.pSave("alarmUsedLipoDetectedFile",value)
	if (debugOn == true) then
		print("alarmUsedLipoDetectedFile ",alarmUsedLipoDetectedFile)
	end
end

local function timeDelayChanged(value)
	timeDelay = value
	system.pSave("timeDelay",value)
	if (debugOn == true) then
		print("timeDelay ",timeDelay)
	end
end

local function averagingWindowCellVoltageChanged(value)
	averagingWindowCellVoltage = value
	system.pSave("averagingWindowCellVoltage",value)
	if (debugOn == true) then
		print("averagingWindowCellVoltage ",averagingWindowCellVoltage)
	end
end

local function averagingWindowRxVoltageChanged(value)
	averagingWindowRxVoltage = value
	system.pSave("averagingWindowRxVoltage",value)
	if (debugOn == true) then
		print("averagingWindowRxVoltage ",averagingWindowRxVoltage)
	end
end

local function switchStartTimerChanged(value)
	switchStartTimer = value
	system.pSave("switchStartTimer",value)
	if (debugOn == true) then
		print("switchStartTimer ",switchStartTimer)
	end
end

local function switchResetTimerChanged(value)
	switchResetTimer = value
	system.pSave("switchResetTimer",value)
	if (debugOn == true) then
		print("switchResetTimer ",switchResetTimer)
	end
end

local function switchActivateTelemetryMinMaxChanged(value)
	switchActivateTelemetryMinMax = value
	system.pSave("switchActivateTelemetryMinMax",value)
	print("switchActivateTelemetryMinMax ",switchActivateTelemetryMinMax)
end

local function switchResetTelemetryMinMaxChanged(value)
	switchResetTelemetryMinMax = value
	system.pSave("switchResetTelemetryMinMax",value)
	if (debugOn == true) then
		print("switchResetTelemetryMinMax ",switchResetTelemetryMinMax)
	end
end

local function alarmCapacityLevelOneChanged(value)
	alarmCapacityLevelOne = value
	system.pSave("alarmCapacityLevelOne",value)
	if (debugOn == true) then
		print("alarmCapacityLevelOne ",alarmCapacityLevelOne)
	end
end

local function alarmCapacityLevelTwoChanged(value)
	alarmCapacityLevelTwo = value
	system.pSave("alarmCapacityLevelTwo",value)
	if (debugOn == true) then
		print("alarmCapacityLevelTwo ",alarmCapacityLevelTwo)
	end
end

local function alarmCapacityLevelThreeChanged(value)
	alarmCapacityLevelThree = value
	system.pSave("alarmCapacityLevelThree",value)
	if (debugOn == true) then
		print("alarmCapacityLevelThree ",alarmCapacityLevelThree)
	end
end

local function alarmCapacityLevelFourChanged(value)
	alarmCapacityLevelFour = value
	system.pSave("alarmCapacityLevelFour",value)
	if (debugOn == true) then
		print("alarmCapacityLevelFour ",alarmCapacityLevelFour)
	end
end

local function alarmCapacityLevelFiveChanged(value)
	alarmCapacityLevelFive = value
	system.pSave("alarmCapacityLevelFive",value)
	if (debugOn == true) then
		print("alarmCapacityLevelFive ",alarmCapacityLevelFive)
	end
end

local function alarmCapacityLevelSixChanged(value)
	alarmCapacityLevelSix = value
	system.pSave("alarmCapacityLevelSix",value)
	if (debugOn == true) then
		print("alarmCapacityLevelSix ",alarmCapacityLevelSix)
	end
end

local function alarmCapacityLevelOneFileChanged(value)
	alarmCapacityLevelOneFile = value
	system.pSave("alarmCapacityLevelOneFile",value)
	if (debugOn == true) then
		print("alarmCapacityLevelOneFile ",alarmCapacityLevelOneFile)
	end
end

local function alarmCapacityLevelTwoFileChanged(value)
	alarmCapacityLevelTwoFile = value
	system.pSave("alarmCapacityLevelTwoFile",value)
	if (debugOn == true) then
		print("alarmCapacityLevelTwoFile ",alarmCapacityLevelTwoFile)
	end
end

local function alarmCapacityLevelThreeFileChanged(value)
	alarmCapacityLevelThreeFile = value
	system.pSave("alarmCapacityLevelThreeFile",value)
	if (debugOn == true) then
		print("alarmCapacityLevelThreeFile ",alarmCapacityLevelThreeFile)
	end
end

local function alarmCapacityLevelFourFileChanged(value)
	alarmCapacityLevelFourFile = value
	system.pSave("alarmCapacityLevelFourFile",value)
	if (debugOn == true) then
		print("alarmCapacityLevelFourFile ",alarmCapacityLevelFourFile)
	end
end

local function alarmCapacityLevelFiveFileChanged(value)
	alarmCapacityLevelFiveFile = value
	system.pSave("alarmCapacityLevelFiveFile",value)
	if (debugOn == true) then
		print("alarmCapacityLevelFiveFile ",alarmCapacityLevelFiveFile)
	end
end

local function alarmCapacityLevelSixFileChanged(value)
	alarmCapacityLevelSixFile = value
	system.pSave("alarmCapacityLevelSixFile",value)
	if (debugOn == true) then
		print("alarmCapacityLevelSixFile ",alarmCapacityLevelSixFile)
	end
end

local function lowVoltageChirpBooleanChanged(value)
	lowVoltageChirpBoolean = not value
	form.setValue(checkboxIndex2,lowVoltageChirpBoolean)
	if (lowVoltageChirpBoolean == true) then
		lowVoltageChirp = 1
		system.pSave("lowVoltageChirp",lowVoltageChirp)
	else
		lowVoltageChirp = 0
		system.pSave("lowVoltageChirp",lowVoltageChirp)
	end
	if (debugOn == true) then
		print("lowVoltageChirp ",lowVoltageChirp,lowVoltageChirpBoolean)
	end
end

local function alarmVoltageLevelOneChanged(value)
	alarmVoltageLevelOne = value
	system.pSave("alarmVoltageLevelOne",value)
	if (debugOn == true) then
		print("alarmVoltageLevelOne ",alarmVoltageLevelOne)
	end
end

--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function that creates user input form
--------------------------------------------------------------------------------------------
local function initForm(formID)
	
	local available = system.getSensors()

	local selectionList={}
	sensorsAvailable = {}

	local voltageCurrentIndex = -1
	local currentCurrentIndex = -1
	local capacityCurrentIndex = -1
	local temperatureCurrentIndex = -1
	local throttleCurrentIndex = -1
	local rpmCurrentIndex = -1
	local vibrationsCurrentIndex = -1
	local elevatorCurrentIndex = -1
	local aileronCurrentIndex = -1
	local rudderCurrentIndex = -1
		
	selectionList[#selectionList + 1] = string.format("%s","Jeti - Rx1 Voltage")
	sensorsAvailable[#sensorsAvailable + 1] = {["unit"] = "V",["param"] = 1,["id"] = 999,["sensorName"] = "Jeti",["label"] = "Rx1 Voltage"}

	selectionList[#selectionList + 1] = string.format("%s","Jeti - Rx2 Voltage")
	sensorsAvailable[#sensorsAvailable + 1] = {["unit"] = "V",["param"] = 2,["id"] = 999,["sensorName"] = "Jeti",["label"] = "Rx2 Voltage"}
		
	selectionList[#selectionList + 1] = string.format("%s","Jeti - RxB Voltage")
	sensorsAvailable[#sensorsAvailable + 1] = {["unit"] = "V",["param"] = 3,["id"] = 999,["sensorName"] = "Jeti",["label"] = "RxB Voltage"}
	
	if (voltageSensorID == 999 and voltageSensorParam == 1) then
		voltageCurrentIndex = 1
	elseif (voltageSensorID == 999 and voltageSensorParam == 2) then
		voltageCurrentIndex = 2
	elseif (voltageSensorID == 999 and voltageSensorParam == 3) then
		voltageCurrentIndex = 3
	end
	
	for index,sensor in ipairs(available) do 
		if(sensor.param ~= 0) then 
			if(sensor.sensorName and string.len(sensor.sensorName) > 0) then
				selectionList[#selectionList + 1] = string.format("%s - %s [%s]",sensor.sensorName,sensor.label,sensor.unit)
			else
				selectionList[#selectionList + 1] = string.format("%s [%s]",sensor.label,sensor.unit)
			end
			
			sensorsAvailable[#sensorsAvailable + 1] = sensor
						
			if(sensor.id == voltageSensorID and sensor.param == voltageSensorParam) then
				voltageCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == currentSensorID and sensor.param == currentSensorParam) then
				currentCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == capacitySensorID and sensor.param == capacitySensorParam) then
				capacityCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == temperatureSensorID and sensor.param == temperatureSensorParam) then
				temperatureCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == throttleSensorID and sensor.param == throttleSensorParam) then
				throttleCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == rpmSensorID and sensor.param == rpmSensorParam) then
				rpmCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == vibrationsSensorID and sensor.param == vibrationsSensorParam) then
				vibrationsCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == elevatorSensorID and sensor.param == elevatorSensorParam) then
				elevatorCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == aileronSensorID and sensor.param == aileronSensorParam) then
				aileronCurrentIndex = #sensorsAvailable
			end
			if(sensor.id == rudderSensorID and sensor.param == rudderSensorParam) then
				rudderCurrentIndex = #sensorsAvailable
			end
		end
	end
	
	form.addRow(2)
	form.addLabel({label="Select telemetry sensors",font=FONT_BOLD,alignRight=false,enabled=false,visible=true,width=200})
	
	form.addRow(2)
	form.addLabel({label="ESC Voltage (V)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,voltageCurrentIndex,true,voltageSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="ESC Lipo Used (mAh)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,capacityCurrentIndex,true,capacitySensorChanged)
	
	form.addRow(2)
	form.addLabel({label="ESC Current (A)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,currentCurrentIndex,true,currentSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="ESC Temperature (° C)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,temperatureCurrentIndex,true,temperatureSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="ESC Throttle (%)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,throttleCurrentIndex,true,throttleSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="ESC Headspeed (RPM)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,rpmCurrentIndex,true,rpmSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="FBL Vibrations (%)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,vibrationsCurrentIndex,true,vibrationsSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="FBL Elevator Rate (°/s)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,elevatorCurrentIndex,true,elevatorSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="FBL Aileron Rate (°/s)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,aileronCurrentIndex,true,aileronSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="FBL Rudder Rate (°/s)",font=FONT_NORMAL,width=160})
	form.addSelectbox(selectionList,rudderCurrentIndex,true,rudderSensorChanged)
	
	form.addRow(2)
	form.addLabel({label="Define Options",font=FONT_BOLD,alignRight=false,enabled=false,visible=true,width=200})
	
	form.addRow(2)
	form.addLabel({label="Lipo Cell Count",font=FONT_NORMAL,width=200})
	form.addIntbox(lipoCellCount,1,99,1,0,1,lipoCellCountChanged)
	
	form.addRow(2)
	form.addLabel({label="Lipo Nominal Capacity (mAh)",font=FONT_NORMAL,width=210})
	form.addIntbox(lipoCapacity,0,10000,0,0,50,lipoCapacityChanged)
		
	form.addRow(2)
	form.addLabel({label="Voltage Correction Factor",font=FONT_NORMAL,width=200})
	form.addIntbox(correctionFactor,1,2000,1000,3,1,correctionFactorChanged)
	
	form.addRow(2)
	form.addLabel({label="Estimate Capacity of Used Lipo?",font=FONT_NORMAL,width=230})
	checkboxIndex1 = form.addCheckbox(estimateUsedLipoBoolean,estimateUsedLipoBooleanChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voltage Threshold (V)",font=FONT_NORMAL,width=230})
	form.addIntbox(voltageThresholdUsedLipo,0,420,330,2,1,voltageThresholdUsedLipoChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voice File",font=FONT_NORMAL,width=150})
	form.addAudioFilebox(alarmUsedLipoDetectedFile,alarmUsedLipoDetectedFileChanged)
	
	form.addRow(2)
	form.addLabel({label="FBL Initialization Time Delay (s)",font=FONT_NORMAL,width=230})
	form.addIntbox(timeDelay,0,100,0,0,1,timeDelayChanged)

	form.addRow(2)
	form.addLabel({label="Samples for Voltage Averaging (#)",font=FONT_NORMAL,width=240})
	form.addIntbox(averagingWindowCellVoltage,1,99,1,0,1,averagingWindowCellVoltageChanged)
	
	form.addRow(1)
	form.addLabel({label="		(If changed, please refresh (F2) on",font=FONT_NORMAL})
	form.addRow(1)
	form.addLabel({label="		'User Applications' screen)",font=FONT_NORMAL})
	
	form.addRow(2)
	form.addLabel({label="Define Battery Announcements",font=FONT_BOLD,alignRight=false,enabled=false,visible=true,width=250})
	
	form.addRow(2)
	form.addLabel({label="Battery Level 1 (%)",font=FONT_NORMAL,width=225})
	form.addIntbox(alarmCapacityLevelOne,0,100,1,0,1,alarmCapacityLevelOneChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voice File",font=FONT_NORMAL,width=150})
	form.addAudioFilebox(alarmCapacityLevelOneFile,alarmCapacityLevelOneFileChanged)
	
	form.addRow(2)
	form.addLabel({label="Battery Level 2 (%)",font=FONT_NORMAL,width=225})
	form.addIntbox(alarmCapacityLevelTwo,0,100,1,0,1,alarmCapacityLevelTwoChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voice File",font=FONT_NORMAL,width=150})
	form.addAudioFilebox(alarmCapacityLevelTwoFile,alarmCapacityLevelTwoFileChanged)
	
	form.addRow(2)
	form.addLabel({label="Battery Level 3 (%)",font=FONT_NORMAL,width=225})
	form.addIntbox(alarmCapacityLevelThree,0,100,1,0,1,alarmCapacityLevelThreeChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voice File",font=FONT_NORMAL,width=150})
	form.addAudioFilebox(alarmCapacityLevelThreeFile,alarmCapacityLevelThreeFileChanged)
	
	form.addRow(2)
	form.addLabel({label="Battery Level 4 (%)",font=FONT_NORMAL,width=225})
	form.addIntbox(alarmCapacityLevelFour,0,100,1,0,1,alarmCapacityLevelFourChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voice File",font=FONT_NORMAL,width=150})
	form.addAudioFilebox(alarmCapacityLevelFourFile,alarmCapacityLevelFourFileChanged)
	
	form.addRow(2)
	form.addLabel({label="Battery Level 5 (%)",font=FONT_NORMAL,width=225})
	form.addIntbox(alarmCapacityLevelFive,0,100,1,0,1,alarmCapacityLevelFiveChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voice File",font=FONT_NORMAL,width=150})
	form.addAudioFilebox(alarmCapacityLevelFiveFile,alarmCapacityLevelFiveFileChanged)
	
	form.addRow(2)
	form.addLabel({label="Battery Level 6 (%)",font=FONT_NORMAL,width=225})
	form.addIntbox(alarmCapacityLevelSix,0,100,1,0,1,alarmCapacityLevelSixChanged)
	
	form.addRow(2)
	form.addLabel({label="		Voice File",font=FONT_NORMAL,width=150})
	form.addAudioFilebox(alarmCapacityLevelSixFile,alarmCapacityLevelSixFileChanged)
	
	-- if lowVoltageChirp == 1 then
		-- lowVoltageChirpBoolean = true
	-- else
		-- lowVoltageChirpBoolean = false
	-- end
	
	form.addRow(2)
	form.addLabel({label="Chirp at Low Lipo Cell Voltage?",font=FONT_NORMAL,width=230})
	checkboxIndex2 = form.addCheckbox(lowVoltageChirpBoolean,lowVoltageChirpBooleanChanged)
	
	form.addRow(2)
	form.addLabel({label="		Low Voltage Threshold (V)",font=FONT_NORMAL,width=220})
	form.addIntbox(alarmVoltageLevelOne,0,420,330,2,5,alarmVoltageLevelOneChanged)
	
	form.addRow(2)
	form.addLabel({label="Define Switches",font=FONT_BOLD,alignRight=false,enabled=false,visible=true,width=200})
	
	form.addRow(2)
	form.addLabel({label="Start Flight Timer Switch",font=FONT_NORMAL,width=200})
	form.addInputbox(switchStartTimer,true,switchStartTimerChanged)
	
	form.addRow(2)
	form.addLabel({label="Reset Flight Timer Switch",font=FONT_NORMAL,width=200})
	form.addInputbox(switchResetTimer,true,switchResetTimerChanged)
	
	form.addRow(2)
	form.addLabel({label="Activate Telem. Max/Min Switch",font=FONT_NORMAL,width=230})
	form.addInputbox(switchActivateTelemetryMinMax,true,switchActivateTelemetryMinMaxChanged)
	
	form.addRow(2)
	form.addLabel({label="Reset Telem. Max/Min Switch",font=FONT_NORMAL,width=225})
	form.addInputbox(switchResetTelemetryMinMax,true,switchResetTelemetryMinMaxChanged)

	
	--collectgarbage()
end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function resets telemetry min/max values
--------------------------------------------------------------------------------------------
local function resetTelemetryValues()
	minVoltagePerCell = 99.9
	maxVoltagePerCell = -1.0
	rx_1_Q_min = 101
	rx_1_RSSI_A1_min = 1000
	rx_1_RSSI_A2_min = 1000
	rx_1_Voltage_min = 99.9
	rx_1_Voltage_max = -1.0
	escCurrentMax = -1.0
	escTempMax = -1
	escThrottleMax = -1
	vibrationsMax = -1
	rpmMax = -1
	elevatorRateMin = 1e6
	elevatorRateMax = -1e6
	aileronRateMin = 1e6
	aileronRateMax = -1e6
	rudderRateMin = 1e6
	rudderRateMax = -1e6
	value_list_cell_voltages={}
	value_list_rx_1_voltages={}
end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function that tracks Tx time counter, and saves the time at which the Rx is detected.
-- This allows the app to apply the user defined time delay, as well reset the min/max
-- values when a new lipo is plugged in. (Called by the Jeti loop function).
--------------------------------------------------------------------------------------------
local function trackTimeAndResetValues()

	currentTime = system.getTimeCounter() * 1E-3
	
	local sensorsRx = system.getTxTelemetry()
	local voltageSensorValue
	
	
	
	if(sensorsRx.rx1Percent > 1) then
		isRxPoweredOn = true
    else
		isRxPoweredOn = false
    end
	
	if (hasRxBeenPoweredOn == false and isRxPoweredOn == true) then
		timeAtPowerOn = currentTime
		timeCounter = 0
	end
	
	
	if(isRxPoweredOn == true) then
		hasRxBeenPoweredOn = true
     end
			
	if (hasRxBeenPoweredOn == true and isRxPoweredOn == false) then
		resetRx = true
	end
		
	if (resetRx == true)  then
		if (isRxPoweredOn == true) then
			resetRx = false
			hasVoltageStartupBeenRead = false
			timeAtPowerOn = currentTime
			timeCounter = 0
			resetTelemetryValues()
			isAlarmUsedLipoDetectedActive = false
			isAlarmCapacityOneActive = false
			isAlarmCapacityTwoActive = false
			isAlarmCapacityThreeActive = false
			isAlarmCapacityFourActive = false 
			isAlarmCapacityFiveActive = false
			isAlarmCapacitySixActive = false 
		end
	end
	
	resetTelemetryMinMax = system.getInputsVal(switchResetTelemetryMinMax)
	activateTelemetryMinMax = system.getInputsVal(switchActivateTelemetryMinMax)
	
	if (isRxPoweredOn == false) then
		voltagePerCell = 0.0
		voltagePerCellAveraged = 0.0
		voltagePerCellAtStartup = 0.0
		batteryCapacityPercentAtStartup = 0.0
		batteryCapacityUsedAtStartup = 0.0
		rx_1_Voltage_Averaged = 0.0
		escCurrent = 0.0
		escTemp = 0
		escThrottle = 0
		vibrations = 0
		rpm = 0.0
	end
	
	if (isRxPoweredOn == true) and (currentTime > (timeAtPowerOn + timeDelay)) then
		telemetryActive = true
	else
		telemetryActive = false
    end
	
	effectiveLipoCapacity = 0.8 * lipoCapacity
	
	if (telemetryActive == true) and (hasVoltageStartupBeenRead == false) then
		if(voltageSensorID == 999) then
			if (voltageSensorParam == 1) then
				voltageSensorValue = sensorsRx.rx1Voltage
			elseif (voltageSensorParam == 2) then
				voltageSensorValue = sensorsRx.rx2Voltage
			elseif (voltageSensorParam == 3) then
				voltageSensorValue = sensorsRx.rxBVoltage
			end
		else
			voltageSensorTable = system.getSensorByID(voltageSensorID,voltageSensorParam)
			if (voltageSensorTable) then
				voltageSensorValue = voltageSensorTable.value
			end
		end
		
		if (voltageSensorValue) then
			voltagePerCellAtStartup = (voltageSensorValue * (correctionFactor/1000))/ lipoCellCount
			batteryCapacityPercentAtStartup = voltageAsAPercentage(voltagePerCellAtStartup)
			batteryCapacityUsedAtStartup = lipoCapacity - (lipoCapacity * (batteryCapacityPercentAtStartup/100))
			effectivePercentageAtStartUp = (1-(batteryCapacityUsedAtStartup / effectiveLipoCapacity))*100
			if (debugOn == true) then
				print("lipoCapacity ",lipoCapacity)
				print("effectiveLipoCapacity ",effectiveLipoCapacity)
				print("voltagePerCellAtStartup ",voltagePerCellAtStartup)
				print("batteryCapacityPercentAtStartup ",batteryCapacityPercentAtStartup)
				print("batteryCapacityUsedAtStartup ",batteryCapacityUsedAtStartup)
				print("effectivePercentageAtStartUp ",effectivePercentageAtStartUp)
			end
		end
		
		hasVoltageStartupBeenRead = true

    end
	
	local effectivePercentageAtStartUpRounded = math.floor(effectivePercentageAtStartUp + 0.5)
	
	if (telemetryActive == true and isAlarmUsedLipoDetectedActive == false and alarmUsedLipoDetectedFile~="" and estimateUsedLipoBoolean == true and voltagePerCellAtStartup < (voltageThresholdUsedLipo/100)) then
		system.playFile(alarmUsedLipoDetectedFile,AUDIO_QUEUE)
		system.playNumber(effectivePercentageAtStartUpRounded,0,"%")
		system.vibration(true,4)
		isAlarmUsedLipoDetectedActive=true   
	end
	
	if (estimateUsedLipoBoolean == false) then
		effectivePercentageAtStartUp = 100
	end
	
	if (resetTelemetryMinMax == 1) then
		telemetryActive = false
		resetTelemetryValues()
	end
	
	flightTimerActive = system.getInputsVal(switchStartTimer)
	resetTimer = system.getInputsVal(switchResetTimer)


	local delta = currentTime - lastTime
	lastTime = currentTime
	
	if (avgTime == 0) then 
		avgTime = delta
	else 
		avgTime = avgTime * 0.95 + delta * 0.05
	end
	
	if (flightTimerActive == 1) then
		timeCounter = timeCounter + delta
	else
		timeCounter = timeCounter
	end
	
	if (resetTimer == 1) then
		timeCounter = 0
	end	
	
	--local hh = (tenths // (60 * 60)) % 24
	local mm = (timeCounter // (60)) % 60
	local ss = (timeCounter // 1) % 60
	local t = (timeCounter // 0.1) % 10

	flightTimeMinutesSecondsString = string.format("%02d:%02d", mm, ss)
	flightTimeTenthsString = string.format(".%01d", t)

	--collectgarbage()
end
------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function that converts dB to Jeti antenna fractions in format of X/9.
--------------------------------------------------------------------------------------------
local function getRSSI(value)
	local result
	if     (value > 999) then result = 999
	elseif (value > 34) then result = 9
	elseif (value > 27) then result = 8
	elseif (value > 22) then result = 7
	elseif (value > 18) then result = 6
	elseif (value > 14) then result = 5
	elseif (value > 10) then result = 4
	elseif (value >  6) then result = 3
	elseif (value >  3) then result = 2
	elseif (value >  0) then result = 1
	else                     result = 0
	end
	return result
end
------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function that averages the voltage reading (if desired by the user).
--------------------------------------------------------------------------------------------
local function averagingFunctionVoltage(value)
    local sum_values = 0.0
	local result
	
	if (#value_list_cell_voltages == (averagingWindowCellVoltage)) then
		table.remove(value_list_cell_voltages,1)
	end    
	value_list_cell_voltages[#value_list_cell_voltages + 1] = value
	for i,entry in pairs(value_list_cell_voltages) do
		sum_values = sum_values + entry
	end
	result = sum_values / #value_list_cell_voltages
	return result
end    
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function that averages the Rx voltage reading (if desired by the user).
--------------------------------------------------------------------------------------------
local function averagingFunctionRxVoltage(value)
	averagingWindowRxVoltage = averagingWindowCellVoltage
	local sum_values = 0.0
	local result
	if (#value_list_rx_1_voltages == (averagingWindowRxVoltage)) then
		table.remove(value_list_rx_1_voltages,1)
	end    
	value_list_rx_1_voltages[#value_list_rx_1_voltages + 1] = value
	for i,entry in pairs(value_list_rx_1_voltages) do
		sum_values = sum_values + entry
	end
	result = sum_values / #value_list_rx_1_voltages
	return result
end    
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Main function that reads the voltage reading (called by the Jeti loop function).
--------------------------------------------------------------------------------------------
local function updateTelemetrySensors()

	local voltageSensorTable
	local currentSensorTable
	local capacitySensorTable
	local temperatureSensorTable
	local throttleSensorTable
	local vibrationsSensorTable
	local rpmSensorTable
	local elevatorSensorTable
	local aileronSensorTable
	local rudderSensorTable
	
	local voltageSensorValue
	
	if(voltageSensorID == 999) then
	
		local sensorsRx = system.getTxTelemetry()
		
		if (voltageSensorParam == 1) then
			voltageSensorValue = sensorsRx.rx1Voltage
		elseif (voltageSensorParam == 2) then
			voltageSensorValue = sensorsRx.rx2Voltage
		elseif (voltageSensorParam == 3) then
			voltageSensorValue = sensorsRx.rxBVoltage
		end
		
	else

		voltageSensorTable = system.getSensorByID(voltageSensorID,voltageSensorParam)
		if (voltageSensorTable) then
			voltageSensorValue = voltageSensorTable.value
		end
		
	end
		
	currentSensorTable = system.getSensorByID(currentSensorID,currentSensorParam)
	if (currentSensorTable) then
		escCurrent = currentSensorTable.value
	end
	
	capacitySensorTable = system.getSensorByID(capacitySensorID,capacitySensorParam)
	if (capacitySensorTable) then
		batteryCapacityUsed = capacitySensorTable.value
	end
	
	temperatureSensorTable = system.getSensorByID(temperatureSensorID,temperatureSensorParam)
	if (temperatureSensorTable) then
		escTemp = temperatureSensorTable.value
	end
	
	throttleSensorTable = system.getSensorByID(throttleSensorID,throttleSensorParam)
	if (throttleSensorTable) then
		escThrottle = throttleSensorTable.value
	end
	
	vibrationsSensorTable = system.getSensorByID(vibrationsSensorID,vibrationsSensorParam)
	if (vibrationsSensorTable) then
		vibrations = vibrationsSensorTable.value
	end
	
	rpmSensorTable = system.getSensorByID(rpmSensorID,rpmSensorParam)
	if (rpmSensorTable) then
		rpm = rpmSensorTable.value
	end
	
	elevatorSensorTable = system.getSensorByID(elevatorSensorID,elevatorSensorParam)
	if (elevatorSensorTable) then
		elevatorRate = elevatorSensorTable.value
	end
	
	aileronSensorTable = system.getSensorByID(aileronSensorID,aileronSensorParam)
	if (aileronSensorTable) then
		aileronRate = aileronSensorTable.value
	end
	
	rudderSensorTable = system.getSensorByID(rudderSensorID,rudderSensorParam)
	if (rudderSensorTable) then
		rudderRate = rudderSensorTable.value
	end
	
	
	if (voltageSensorValue) then
		voltagePerCell = (voltageSensorValue * (correctionFactor/1000))/ lipoCellCount
		voltagePerCellAveraged = averagingFunctionVoltage(voltagePerCell)
	end
	
	
	if (telemetryActive and activateTelemetryMinMax == 1 and voltagePerCellAveraged < minVoltagePerCell and voltagePerCell > 0.1) then
		minVoltagePerCell = voltagePerCellAveraged
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and voltagePerCellAveraged > maxVoltagePerCell and voltagePerCell > 0.1) then
		maxVoltagePerCell = voltagePerCellAveraged
	end
	
	
	if (estimateUsedLipoBoolean == true and voltagePerCellAtStartup < (voltageThresholdUsedLipo/100)) then
		batteryCapacityUsedTotal = batteryCapacityUsedAtStartup + batteryCapacityUsed
	else
		batteryCapacityUsedTotal = batteryCapacityUsed
	end
	
	if (batteryCapacityUsed and effectiveLipoCapacity) then
		if (batteryCapacityUsedTotal > effectiveLipoCapacity) then
			batteryPercentage = 0
		else
			batteryPercentage = (1 - (batteryCapacityUsedTotal / effectiveLipoCapacity))*100
		end
	end

	batteryPercentageRounded = math.floor(batteryPercentage + 0.5)
		
	if (telemetryActive and activateTelemetryMinMax == 1 and escCurrent > escCurrentMax) then
		escCurrentMax = escCurrent
	end
		
	if (telemetryActive and activateTelemetryMinMax == 1 and escTemp > escTempMax) then
		escTempMax = escTemp
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and escThrottle > escThrottleMax) then
		escThrottleMax = escThrottle
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and vibrations > vibrationsMax) then
		vibrationsMax = vibrations
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and rpm > rpmMax) then
		rpmMax = rpm
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and elevatorRate < elevatorRateMin) then
		elevatorRateMin = elevatorRate
	elseif (telemetryActive and activateTelemetryMinMax == 1 and elevatorRate > elevatorRateMax) then
		elevatorRateMax = elevatorRate
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and aileronRate < aileronRateMin) then
		aileronRateMin = aileronRate
	elseif (telemetryActive and activateTelemetryMinMax == 1 and aileronRate > aileronRateMax) then
		aileronRateMax = aileronRate
	end

	if (telemetryActive and activateTelemetryMinMax == 1 and rudderRate < rudderRateMin) then
		rudderRateMin = rudderRate
	elseif (telemetryActive and activateTelemetryMinMax == 1 and rudderRate > rudderRateMax) then
		rudderRateMax = rudderRate
	end

	
	--collectgarbage()
	
	--local mem = collectgarbage('count')
	--print("Memory usage: ", mem)
	
end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function to update Rx telemetry values
--------------------------------------------------------------------------------------------
local function updateRxValues()

	local sensorsRx = system.getTxTelemetry()
	
	if (sensorsRx) then
		rx_1_Q = sensorsRx.rx1Percent
		rx_1_Voltage = sensorsRx.rx1Voltage
		rx_1_RSSI_A1 = sensorsRx.RSSI[1]
		rx_1_RSSI_A2 = sensorsRx.RSSI[2]
	end
	
	if (telemetryActive == false and isRxPoweredOn == true) then
		rx_1_Voltage_Averaged = rx_1_Voltage
	elseif (telemetryActive == true) then
		rx_1_Voltage_Averaged = averagingFunctionRxVoltage(rx_1_Voltage)
	end

	
	if (telemetryActive and activateTelemetryMinMax == 1 and rx_1_Q < rx_1_Q_min) then
		rx_1_Q_min = rx_1_Q
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and rx_1_Voltage_Averaged < rx_1_Voltage_min) then
		rx_1_Voltage_min = rx_1_Voltage_Averaged
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and rx_1_Voltage_Averaged > rx_1_Voltage_max) then
		rx_1_Voltage_max = rx_1_Voltage_Averaged
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and rx_1_RSSI_A1 < rx_1_RSSI_A1_min) then
		rx_1_RSSI_A1_min = rx_1_RSSI_A1
	end
	
	if (telemetryActive and activateTelemetryMinMax == 1 and rx_1_RSSI_A2 < rx_1_RSSI_A2_min) then
		rx_1_RSSI_A2_min = rx_1_RSSI_A2
	end	

end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Audible alarm function
--------------------------------------------------------------------------------------------
local function playVoiceAlarms()

	if (telemetryActive == true and isAlarmCapacityOneActive == false and alarmCapacityLevelOneFile~="" and batteryPercentageRounded <= alarmCapacityLevelOne and batteryPercentageRounded > alarmCapacityLevelTwo and effectivePercentageAtStartUp > alarmCapacityLevelOne) then
		system.playFile(alarmCapacityLevelOneFile,AUDIO_QUEUE)
		system.vibration(true,4)
		isAlarmCapacityOneActive=true   
	end
	
	if (telemetryActive == true and isAlarmCapacityTwoActive == false and alarmCapacityLevelTwoFile~="" and batteryPercentageRounded <= alarmCapacityLevelTwo and batteryPercentageRounded > alarmCapacityLevelThree and effectivePercentageAtStartUp > alarmCapacityLevelTwo) then
		system.playFile(alarmCapacityLevelTwoFile,AUDIO_QUEUE)
		system.vibration(true,4)
		isAlarmCapacityTwoActive=true   
	end
	
	if (telemetryActive == true and isAlarmCapacityThreeActive == false and alarmCapacityLevelThreeFile~="" and batteryPercentageRounded <= alarmCapacityLevelThree and batteryPercentageRounded > alarmCapacityLevelFour and effectivePercentageAtStartUp > alarmCapacityLevelThree) then
		system.playFile(alarmCapacityLevelThreeFile,AUDIO_QUEUE)
		system.vibration(true,4)
		isAlarmCapacityThreeActive=true   
	end
	
	if (telemetryActive == true and isAlarmCapacityFourActive == false and alarmCapacityLevelFourFile~="" and batteryPercentageRounded <= alarmCapacityLevelFour and batteryPercentageRounded > alarmCapacityLevelFive and effectivePercentageAtStartUp > alarmCapacityLevelFour) then
		system.playFile(alarmCapacityLevelFourFile,AUDIO_QUEUE)
		system.vibration(true,4)
		isAlarmCapacityFourActive=true   
	end
	
	if (telemetryActive == true and isAlarmCapacityFiveActive == false and alarmCapacityLevelFiveFile~="" and batteryPercentageRounded <= alarmCapacityLevelFive and batteryPercentageRounded > alarmCapacityLevelSix and effectivePercentageAtStartUp > alarmCapacityLevelFive) then
		system.playFile(alarmCapacityLevelFiveFile,AUDIO_QUEUE)
		system.vibration(true,4)
		isAlarmCapacityFiveActive=true   
	end
	
	if (telemetryActive == true and isAlarmCapacitySixActive == false and alarmCapacityLevelSixFile~="" and batteryPercentageRounded <= alarmCapacityLevelSix and effectivePercentageAtStartUp > alarmCapacityLevelSix) then
		system.playFile(alarmCapacityLevelSixFile,AUDIO_QUEUE)
		system.vibration(true,4)
		isAlarmCapacitySixActive=true   
	end
	
	if (telemetryActive == true and voltagePerCellAveraged <= (alarmVoltageLevelOne/100) and lowVoltageChirpBoolean == true) then
		system.playBeep(1,4000,20)
	end
	
	--collectgarbage()
	
end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Main Jeti Tx loop function
--------------------------------------------------------------------------------------------
local function loop()

	trackTimeAndResetValues()
	updateRxValues()
		
	if (telemetryActive == true) then
		updateTelemetrySensors()
		playVoiceAlarms()
	end

	--collectgarbage()
end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function to create debug form, which lists a bunch of debug related parameters.
--------------------------------------------------------------------------------------------
local function printForm()

	lcd.drawText(0,0,"Time="..string.format("%4.1f s",currentTime),FONT_MINI)
	lcd.drawText(0,10,"Loop="..string.format("%4.1f ms",avgTime*1000),FONT_MINI)
	lcd.drawText(0,20,"tmePwrOn="..string.format("%4.1f s",timeAtPowerOn),FONT_MINI)
	lcd.drawText(0,30,"TimerActiv="..tostring(flightTimerActive),FONT_MINI)
	lcd.drawText(0,40,"resetTimer="..tostring(resetTimer),FONT_MINI)
	
	lcd.drawText(0,50,"flightTimer="..string.format("%4.1f s",timeCounter),FONT_MINI)
	lcd.drawText(0,60,"String="..flightTimeMinutesSecondsString,FONT_MINI)
	lcd.drawText(65,60,flightTimeTenthsString,FONT_MINI)
	
	lcd.drawText(0,70,"hasRxPwdOn="..tostring(hasRxBeenPoweredOn),FONT_MINI)
	lcd.drawText(0,80,"isRxPwdOn="..tostring(isRxPoweredOn),FONT_MINI)
	lcd.drawText(0,90,"resetRx="..tostring(resetRx),FONT_MINI)
	lcd.drawText(0,100,"timeDelay="..string.format("%4.2f s",timeDelay),FONT_MINI)
	lcd.drawText(0,110,"telemActive="..tostring(telemetryActive),FONT_MINI)
	lcd.drawText(0,120,"telemMinMax="..tostring(activateTelemetryMinMax),FONT_MINI)
	lcd.drawText(0,130,"resetMinMax="..tostring(resetTelemetryMinMax),FONT_MINI)

	lcd.drawText(100,0,string.format("N%0.0f",averagingWindowCellVoltage),FONT_MINI)
	
	for i,entry in pairs(value_list_cell_voltages) do
		lcd.drawText(100,10*i,string.format("%4.2f",entry),FONT_MINI)
	end
	
	lcd.drawText(125,0,"Estimate?="..tostring(estimateUsedLipoBoolean),FONT_MINI)
	lcd.drawText(125,10,string.format("VInitial=%4.2f",voltagePerCellAtStartup),FONT_MINI)
	
	lcd.drawText(125,20,string.format("Initial=%i%%",batteryCapacityPercentAtStartup),FONT_MINI)
	lcd.drawText(125,30,string.format("InitialmAh=%i",batteryCapacityUsedAtStartup),FONT_MINI)
	
	lcd.drawText(125,40,string.format("Capacity=%i",lipoCapacity),FONT_MINI)
	lcd.drawText(125,50,string.format("CapEffctv=%i",effectiveLipoCapacity),FONT_MINI)
	lcd.drawText(125,60,string.format("CapUsed=%5.2f%%",batteryCapacityUsed),FONT_MINI)
	lcd.drawText(125,70,string.format("TotalUsed=%6.1f",batteryCapacityUsedTotal),FONT_MINI)
	lcd.drawText(125,80,string.format("TotalPerc=%5.2f%%",batteryPercentage),FONT_MINI)
	lcd.drawText(125,90,string.format("TotalPerc=%2.0f%%",batteryPercentage),FONT_MINI)
	lcd.drawText(125,100,string.format("TotalPerc=%i%%",batteryPercentage),FONT_MINI)
	
	lcd.drawText(215,0,string.format("Cell=%4.2f",voltagePerCell),FONT_MINI)
	lcd.drawText(215,10,string.format("Avg=%4.2f",voltagePerCellAveraged),FONT_MINI)
	lcd.drawText(215,20,string.format("Min=%4.2f",minVoltagePerCell),FONT_MINI)
	lcd.drawText(215,30,string.format("Max=%4.2f",maxVoltagePerCell),FONT_MINI)
		
	lcd.drawText(215,40,"rx_V="..tostring(rx_1_Voltage),FONT_MINI)
	lcd.drawText(215,50,"min="..tostring(rx_1_Voltage_min),FONT_MINI)
	lcd.drawText(215,60,"rx_Q="..tostring(rx_1_Q),FONT_MINI)
	lcd.drawText(215,70,"min="..tostring(rx_1_Q_min),FONT_MINI)
	lcd.drawText(215,80,"rx_A1="..tostring(rx_1_RSSI_A1),FONT_MINI)
	lcd.drawText(215,90,"min="..tostring(rx_1_RSSI_A1_min),FONT_MINI)
	

end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Function that creates main telemetry window.
--------------------------------------------------------------------------------------------
local function printTelemetryWindow()
	
--[[	
	local batteryPercentage = 84
	local batteryCapacityUsedTotal = 481
	local effectiveLipoCapacity = 2960
	local rpm = "0"
	local rpmMax = 0
	local flightTimeMinutesSecondsString = "00:00"
	local flightTimeTenthsString = ".0"
	local voltagePerCellAveraged = 4.08
	local minVoltagePerCell = 4.08
	local maxVoltagePerCell = 4.09
	
	local escCurrent = 0.5
	local escCurrentMax = 0.5
	local escTemp = 35
	local escTempMax = 35
	local escThrottle = 0
	local escThrottleMax = 0

	local vibrations = 0
	local vibrationsMax = 0
	
	local rx_1_Q = 100
	local rx_1_Q_min = 100
	local rx_1_Voltage_Averaged = 8.2
	local rx_1_Voltage_min = 8.19
	local rx_1_Voltage_max = 8.20
	local rx_1_RSSI_A1 = 57
	local rx_1_RSSI_A2 = 57
	local rx_1_RSSI_A1_min = 57
	local rx_1_RSSI_A2_min = 57

	local elevatorRateMin = -0
	local elevatorRateMax = 0

	local aileronRateMin = -0
	local aileronRateMax = 0

	local rudderRateMin = -0
	local rudderRateMax = 0

	local lipoCapacity = 3700
	local lipoCellCount = 12
	local batteryPercentageRounded = 84
	--]]
	
	local base_r,base_g,base_b
	
	local background_r,background_g,background_b = lcd.getBgColor()
	
	if ((background_r + background_g + background_b) < 300) then
		base_r = 255
		base_g = 255
		base_b = 255
	else
		base_r = 0
		base_g = 0
		base_b = 0
	end
	
	local green_r,green_g,green_b = 0,141,0
	local green_light_r,green_light_g,green_light_b = 103,161,103
	local red_r,red_g,red_b = 255,0,0
	local blue_r,blue_g,blue_b = 0,0,255
	local orange_r,orange_g,orange_b = 255,179,0
	
	local voltage_r,voltage_g,voltage_b = 0,204,255
	local antenna_r,antenna_g,antenna_b = 0,204,0
	local quality_r,quality_g,quality_b = 0,0,255
	
	local max_r,max_g,max_b = 255,0,255
	local min_r,min_g,min_b = 88,0,212
	
	local screenMinX = 0
	local screenMinY = 0
	local screenMaxX = 318
	local screenMaxY = 159
	
	
	if (debugOn == true) then
	
		if (telemetryActive) then
			lcd.setColor(base_r,base_g,base_b)
			lcd.drawFilledRectangle(1,1,5,5)
			lcd.setColor(base_r,base_g,base_b)
		else
			lcd.setColor(base_r,base_g,base_b)
			lcd.drawRectangle(1,1,5,5)
			lcd.setColor(base_r,base_g,base_b)
		end
			
		
		if (activateTelemetryMinMax == 1) then
			lcd.setColor(max_r,max_g,max_b)
			lcd.drawFilledRectangle(7,1,5,5)
			lcd.setColor(base_r,base_g,base_b)
		else
			lcd.setColor(base_r,base_g,base_b)
			lcd.drawRectangle(7,1,5,5)
			lcd.setColor(base_r,base_g,base_b)
		end
		
	end
	
	local batterySymbolWidth = 53
	local batterySymbolHeight = 120
	
	local batterySymbolX = screenMaxX*0.5 - batterySymbolWidth*0.5
	local batterySymbolY = screenMaxY - batterySymbolHeight
	
	local batteryTopWidth = batterySymbolWidth*0.5
	local batteryTopHeight = 7
	
	lcd.setColor(base_r,base_g,base_b)
	lcd.drawRectangle(batterySymbolX,batterySymbolY,batterySymbolWidth,batterySymbolHeight)
	lcd.drawRectangle(batterySymbolX+1,batterySymbolY+1,batterySymbolWidth-2,batterySymbolHeight-2)
	lcd.drawFilledRectangle(batterySymbolX+((batterySymbolWidth-batteryTopWidth)*0.5),batterySymbolY-batteryTopHeight,batteryTopWidth,batteryTopHeight)
	
	if (batteryPercentageRounded >= 0 and batteryPercentageRounded <= 100) then
		batteryPercentageRounded = batteryPercentageRounded
	else
		batteryPercentageRounded = 0
	end
	
	local batterySymbolDeltaY = (batteryPercentageRounded*(batterySymbolHeight-4))//100
		
	if (hasRxBeenPoweredOn == true and batteryPercentageRounded <= alarmCapacityLevelFive and batteryPercentageRounded > alarmCapacityLevelSix) then
		lcd.setColor(orange_r,orange_g,orange_b)
	elseif (hasRxBeenPoweredOn == true and batteryPercentageRounded <= alarmCapacityLevelSix) then
		lcd.setColor(red_r,red_g,red_b)
	elseif (hasRxBeenPoweredOn == true and batteryPercentageRounded > alarmCapacityLevelFive) then
		lcd.setColor(green_r,green_g,green_b) 
	else
		lcd.setColor(base_r,base_g,base_b)
	end
		
	lcd.drawFilledRectangle(batterySymbolX+2,batterySymbolY+(batterySymbolHeight-2-batterySymbolDeltaY),batterySymbolWidth-4,batterySymbolDeltaY)
	lcd.setColor(base_r,base_g,base_b)
	

----------------------------------------------------	

	local panel_01_L_Width = batterySymbolX - 12
	local panel_01_L_Height = 29
	local panel_01_L_X = 0
	local panel_01_L_Y = 0
		
	
	lcd.drawText(panel_01_L_X + 1,(panel_01_L_Height - lcd.getTextHeight(FONT_MINI,"Time"))-1,"Time",FONT_MINI)
	lcd.drawText(panel_01_L_Width - lcd.getTextWidth(FONT_MAXI,flightTimeMinutesSecondsString)-9,(panel_01_L_Height - lcd.getTextHeight(FONT_MAXI,flightTimeMinutesSecondsString))*0.5,flightTimeMinutesSecondsString,FONT_MAXI)
	lcd.drawText(panel_01_L_Width - lcd.getTextWidth(FONT_BIG,flightTimeTenthsString)+6,(panel_01_L_Height - lcd.getTextHeight(FONT_BIG,flightTimeTenthsString)),flightTimeTenthsString,FONT_BIG)


----------------------------------------------------
	
	local panel_02_L_Width = batterySymbolX
	local panel_02_L_Height = 59
	local panel_02_L_X = 0
	local panel_02_L_Y = panel_01_L_Height
	
	lcd.setColor(base_r,base_g,base_b)

	lcd.drawFilledRectangle(panel_02_L_X,panel_02_L_Y,panel_02_L_Width-3,2)
	
	local rx_1_RSSI_A1_fraction = getRSSI(rx_1_RSSI_A1)
	local rx_1_RSSI_A2_fraction = getRSSI(rx_1_RSSI_A2)
	local rx_1_RSSI_A1_fraction_min = getRSSI(rx_1_RSSI_A1_min)
	local rx_1_RSSI_A2_fraction_min = getRSSI(rx_1_RSSI_A2_min)
	
	
	local rxQBarWidth = 65
	local rxQBarHeight = 5
	
	local rxQBarX = panel_02_L_X + 18
	local rxQBarY = panel_02_L_Y + 6
	
	lcd.drawText(rxQBarX - 14,rxQBarY-4,"Q",FONT_MINI)		
	lcd.drawRectangle(rxQBarX,rxQBarY,rxQBarWidth,rxQBarHeight)
	
	local rxQBarDeltaX = (rx_1_Q*rxQBarWidth)//100 - 2
	lcd.setColor(quality_r,quality_g,quality_b)
	lcd.drawFilledRectangle(rxQBarX+1,rxQBarY+1,rxQBarDeltaX,rxQBarHeight-2)
		
	local rx_1_Q_min_X = (((rx_1_Q_min)/(100))*100) * (rxQBarWidth-2)//100
	lcd.setColor(red_r,red_g,red_b)
	if (rx_1_Q_min < 99) then
		lcd.drawFilledRectangle(rxQBarX+1+rx_1_Q_min_X,rxQBarY+1,2,rxQBarHeight-2)
	elseif (rx_1_Q_min == 99) then
		lcd.drawFilledRectangle(rxQBarX+1+rx_1_Q_min_X,rxQBarY+1,1,rxQBarHeight-2)
	end
	lcd.setColor(base_r,base_g,base_b)
		
	local rx_1_Q_String = string.format("%1.0f",rx_1_Q)
	lcd.drawText((rxQBarX+rxQBarWidth) + (panel_02_L_Width - (rxQBarX+rxQBarWidth) - lcd.getTextWidth(FONT_MINI,rx_1_Q_String))*0.5-12,rxQBarY-4,rx_1_Q_String,FONT_MINI)
	lcd.setColor(red_r,red_g,red_b)
	local rx_1_Q_min_String = string.format("%i",rx_1_Q_min)
	if (rx_1_Q_min == 101) then
		lcd.drawText((rxQBarX+rxQBarWidth) + (panel_02_L_Width - (rxQBarX+rxQBarWidth) - lcd.getTextWidth(FONT_MINI,"-"))*0.5+10,rxQBarY-5,"-",FONT_MINI)
	else
		lcd.drawText((rxQBarX+rxQBarWidth) + (panel_02_L_Width - (rxQBarX+rxQBarWidth) - lcd.getTextWidth(FONT_MINI,rx_1_Q_min_String))*0.5+10,rxQBarY-4,rx_1_Q_min_String,FONT_MINI)
	end
	lcd.setColor(base_r,base_g,base_b)
	
	
	
	local rx1RSSIA1BarWidth = rxQBarWidth
	local rx1RSSIA1BarHeight = rxQBarHeight

	local rx1RSSIA1BarX = rxQBarX 
	local rx1RSSIA1BarY = rxQBarY + 11
	
	lcd.drawText(rx1RSSIA1BarX - 16,rx1RSSIA1BarY-4,"A1",FONT_MINI)
	lcd.drawRectangle(rx1RSSIA1BarX,rx1RSSIA1BarY,rx1RSSIA1BarWidth,rx1RSSIA1BarHeight)
	
	local rx1RSSIA1BarDeltaX = (100*(rx_1_RSSI_A1_fraction/9)*rx1RSSIA1BarWidth)//100 - 2
	lcd.setColor(antenna_r,antenna_g,antenna_b)
	lcd.drawFilledRectangle(rx1RSSIA1BarX+1,rx1RSSIA1BarY+1,rx1RSSIA1BarDeltaX,rx1RSSIA1BarHeight-2)
	lcd.setColor(base_r,base_g,base_b)
	
	local rx_1_RSSI_A1_fraction_min_X = (((rx_1_RSSI_A1_fraction_min)/(9))*100) * (rx1RSSIA1BarWidth-2)//100
	lcd.setColor(red_r,red_g,red_b)
	if (rx_1_RSSI_A1_fraction_min < 9) then
		lcd.drawFilledRectangle(rx1RSSIA1BarX+1+rx_1_RSSI_A1_fraction_min_X,rx1RSSIA1BarY+1,2,rx1RSSIA1BarHeight-2)
	end
	lcd.setColor(base_r,base_g,base_b)
		
	local rx_1_RSSI_A1_fraction_String = string.format("%i",rx_1_RSSI_A1_fraction)
	lcd.drawText((rx1RSSIA1BarX+rx1RSSIA1BarWidth) + (panel_02_L_Width - (rx1RSSIA1BarX+rx1RSSIA1BarWidth) - lcd.getTextWidth(FONT_MINI,rx_1_RSSI_A1_fraction_String))*0.5-12,rx1RSSIA1BarY-4,rx_1_RSSI_A1_fraction_String,FONT_MINI)
	lcd.setColor(red_r,red_g,red_b)
	local rx_1_RSSI_A1_fraction_min_String = string.format("%i",rx_1_RSSI_A1_fraction_min)
	if (rx_1_RSSI_A1_fraction_min == 999) then
		lcd.drawText((rx1RSSIA1BarX+rx1RSSIA1BarWidth) + (panel_02_L_Width - (rx1RSSIA1BarX+rx1RSSIA1BarWidth) - lcd.getTextWidth(FONT_MINI,"-"))*0.5+10,rx1RSSIA1BarY-5,"-",FONT_MINI)
	else
		lcd.drawText((rx1RSSIA1BarX+rx1RSSIA1BarWidth) + (panel_02_L_Width - (rx1RSSIA1BarX+rx1RSSIA1BarWidth) - lcd.getTextWidth(FONT_MINI,rx_1_RSSI_A1_fraction_min_String))*0.5+10,rx1RSSIA1BarY-4,rx_1_RSSI_A1_fraction_min_String,FONT_MINI)
	end
	lcd.setColor(base_r,base_g,base_b)


	local rx1RSSIA2BarWidth = rxQBarWidth
	local rx1RSSIA2BarHeight = rxQBarHeight

	local rx1RSSIA2BarX = rxQBarX
	local rx1RSSIA2BarY = rx1RSSIA1BarY + 11
	
	lcd.drawText(rx1RSSIA2BarX - 16,rx1RSSIA2BarY-4,"A2",FONT_MINI)
	lcd.drawRectangle(rx1RSSIA2BarX,rx1RSSIA2BarY,rx1RSSIA2BarWidth,rx1RSSIA2BarHeight)

	local rx1RSSIA2BarDeltaX = (100*(rx_1_RSSI_A2_fraction/9)*rx1RSSIA2BarWidth)//100 - 2
	lcd.setColor(antenna_r,antenna_g,antenna_b)
	lcd.drawFilledRectangle(rx1RSSIA2BarX+1,rx1RSSIA2BarY+1,rx1RSSIA2BarDeltaX,rx1RSSIA2BarHeight-2)
	lcd.setColor(base_r,base_g,base_b)
	
	local rx_1_RSSI_A2_fraction_min_X = (((rx_1_RSSI_A2_fraction_min)/(9))*100) * (rx1RSSIA2BarWidth-2)//100
	lcd.setColor(red_r,red_g,red_b)
	if (rx_1_RSSI_A2_fraction_min < 9) then
		lcd.drawFilledRectangle(rx1RSSIA2BarX+1+rx_1_RSSI_A2_fraction_min_X,rx1RSSIA2BarY+1,2,rx1RSSIA2BarHeight-2)
	end
	lcd.setColor(base_r,base_g,base_b)
	
	local rx_1_RSSI_A2_fraction_String = string.format("%i",rx_1_RSSI_A2_fraction)
	lcd.drawText((rx1RSSIA2BarX+rx1RSSIA2BarWidth) + (panel_02_L_Width - (rx1RSSIA2BarX+rx1RSSIA2BarWidth) - lcd.getTextWidth(FONT_MINI,rx_1_RSSI_A2_fraction_String))*0.5-12,rx1RSSIA2BarY-4,rx_1_RSSI_A2_fraction_String,FONT_MINI)
	lcd.setColor(red_r,red_g,red_b)
	local rx_1_RSSI_A2_fraction_min_String = string.format("%i",rx_1_RSSI_A2_fraction_min)
	if (rx_1_RSSI_A2_fraction_min == 999) then
		lcd.drawText((rx1RSSIA2BarX+rx1RSSIA2BarWidth) + (panel_02_L_Width - (rx1RSSIA2BarX+rx1RSSIA2BarWidth) - lcd.getTextWidth(FONT_MINI,"-"))*0.5+10,rx1RSSIA2BarY-5,"-",FONT_MINI)
	else
		lcd.drawText((rx1RSSIA2BarX+rx1RSSIA2BarWidth) + (panel_02_L_Width - (rx1RSSIA2BarX+rx1RSSIA2BarWidth) - lcd.getTextWidth(FONT_MINI,rx_1_RSSI_A2_fraction_String))*0.5+10,rx1RSSIA2BarY-4,rx_1_RSSI_A2_fraction_min_String,FONT_MINI)
	end
	lcd.setColor(base_r,base_g,base_b)
	
	
	local rx_1_Voltage_String = string.format("%4.2f",rx_1_Voltage_Averaged)
	lcd.drawText(panel_02_L_X + 23,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_BIG,rx_1_Voltage_String))-0,rx_1_Voltage_String,FONT_BIG)
	lcd.drawText(panel_02_L_X + 60,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,"v"))-6,"v",FONT_MINI)
	
	lcd.drawText(panel_02_L_X + 71,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,"min"))-10,"min",FONT_MINI)
	lcd.drawText(panel_02_L_X + 71,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,"max"))-2,"max",FONT_MINI)
	local rx_1_Voltage_min_String = string.format("%4.2f",rx_1_Voltage_min)
	lcd.setColor(red_r,red_g,red_b)
	if (rx_1_Voltage_min == 99.9) then
		lcd.drawText(panel_02_L_X + 95,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_NORMAL,"---"))-9," ---",FONT_NORMAL)
	else
		lcd.drawText(panel_02_L_X + 97,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,rx_1_Voltage_min_String))-10,rx_1_Voltage_min_String,FONT_MINI)
	end
	lcd.drawText(panel_02_L_X + 121,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,"v"))-11,"v",FONT_MINI)
	local rx_1_Voltage_max_String = string.format("%4.2f",rx_1_Voltage_max)
	lcd.setColor(green_r,green_g,green_b)
	if (rx_1_Voltage_max == -1.0) then
		lcd.drawText(panel_02_L_X + 95,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_NORMAL,"---"))-0," ---",FONT_NORMAL)
	else
		lcd.drawText(panel_02_L_X + 97,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,rx_1_Voltage_max_String))-1,rx_1_Voltage_max_String,FONT_MINI)
	end
	lcd.drawText(panel_02_L_X + 121,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,"v"))-2,"v",FONT_MINI)
	lcd.setColor(base_r,base_g,base_b)
	
	lcd.drawText(panel_02_L_X + 1,(panel_02_L_Y + panel_02_L_Height - lcd.getTextHeight(FONT_MINI,"Rx"))-1,"Rx",FONT_MINI)
	
	
	
----------------------------------------------------
	
	local panel_03_L_Width = batterySymbolX
	local panel_03_L_Height = 43
	local panel_03_L_X = 0
	local panel_03_L_Y = panel_01_L_Height + panel_02_L_Height
	
	lcd.setColor(base_r,base_g,base_b)

	lcd.drawFilledRectangle(panel_03_L_X,panel_03_L_Y,panel_03_L_Width-3,2)
	
	lcd.drawText(panel_03_L_X + 1,(panel_03_L_Y + panel_03_L_Height - lcd.getTextHeight(FONT_MINI,"FBL"))-1,"FBL",FONT_MINI)
		
	lcd.drawText(panel_03_L_X + 27,panel_03_L_Y+3,"Elev °/s:",FONT_MINI)
	local elevatorRateMinString = string.format("%i",elevatorRateMin)
	lcd.setColor(min_r,min_g,min_b)
	if (elevatorRateMin == 1e6) then
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"---")-42,panel_03_L_Y+3,"---",FONT_MINI)
	else
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,elevatorRateMinString)-38,panel_03_L_Y+3,elevatorRateMinString,FONT_MINI)
	end
	
	lcd.setColor(base_r,base_g,base_b)
	lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"/")-31,panel_03_L_Y+3,"/",FONT_MINI)
	local elevatorRateMaxString = string.format("+%i",elevatorRateMax)
	lcd.setColor(max_r,max_g,max_b)
	if (elevatorRateMax == -1e6) then
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"---")-15,panel_03_L_Y+3,"---",FONT_MINI)
	else
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,elevatorRateMaxString)-5,panel_03_L_Y+3,elevatorRateMaxString,FONT_MINI)
	end
	
	lcd.setColor(base_r,base_g,base_b)
	
	lcd.drawText(panel_03_L_X + 27,panel_03_L_Y+3+13,"Aile °/s:",FONT_MINI)
	local aileronRateMinString = string.format("%i",aileronRateMin)
	lcd.setColor(min_r,min_g,min_b)
	if (aileronRateMin == 1e6) then
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"---")-42,panel_03_L_Y+16,"---",FONT_MINI)
	else
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,aileronRateMinString)-38,panel_03_L_Y+16,aileronRateMinString,FONT_MINI)
	end
	
	lcd.setColor(base_r,base_g,base_b)
	lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"/")-31,panel_03_L_Y+16,"/",FONT_MINI)
	local aileronRateMaxString = string.format("+%i",aileronRateMax)
	lcd.setColor(max_r,max_g,max_b)
	if (aileronRateMax == -1e6) then
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"---")-15,panel_03_L_Y+16,"---",FONT_MINI)
	else
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,aileronRateMaxString)-5,panel_03_L_Y+16,aileronRateMaxString,FONT_MINI)
	end
	
	lcd.setColor(base_r,base_g,base_b)
	
	lcd.drawText(panel_03_L_X + 27,panel_03_L_Y+3+13+13,"Rud °/s:",FONT_MINI)
	local rudderRateMinString = string.format("%i",rudderRateMin)
	lcd.setColor(min_r,min_g,min_b)
	if (rudderRateMin == 1e6) then
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"---")-42,panel_03_L_Y+29,"---",FONT_MINI)
	else
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,rudderRateMinString)-38,panel_03_L_Y+29,rudderRateMinString,FONT_MINI)
	end
	
	lcd.setColor(base_r,base_g,base_b)
	lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"/")-31,panel_03_L_Y+29,"/",FONT_MINI)
	local rudderRateMaxString = string.format("+%i",rudderRateMax)
	lcd.setColor(max_r,max_g,max_b)
	if (rudderRateMax == -1e6) then
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,"---")-15,panel_03_L_Y+29,"---",FONT_MINI)
	else
		lcd.drawText(panel_03_L_X + panel_03_L_Width - lcd.getTextWidth(FONT_MINI,rudderRateMaxString)-5,panel_03_L_Y+29,rudderRateMaxString,FONT_MINI)
	end
	
	lcd.setColor(base_r,base_g,base_b)
	

----------------------------------------------------
	
	local panel_04_L_Width = batterySymbolX
	local panel_04_L_Height = 28
	local panel_04_L_X = 0
	local panel_04_L_Y = panel_01_L_Height + panel_02_L_Height + panel_03_L_Height
		
	lcd.setColor(base_r,base_g,base_b)

	lcd.drawFilledRectangle(panel_04_L_X,panel_04_L_Y,panel_04_L_Width-3,2)
	
	lcd.drawText(panel_04_L_X + panel_04_L_Width - lcd.getTextWidth(FONT_MINI,"RPM")-2,panel_04_L_Y + (panel_04_L_Height - lcd.getTextHeight(FONT_MINI,"RPM"))*0.5+3,"RPM",FONT_MINI)
	local rpmString = string.format("%i",rpm)
	lcd.drawText((panel_04_L_Width - lcd.getTextWidth(FONT_MAXI,rpmString))-25,panel_04_L_Y+panel_04_L_Height - lcd.getTextHeight(FONT_MAXI,rpmString)+8,rpmString,FONT_MAXI)
	
	lcd.drawText(panel_04_L_X+5,panel_04_L_Y + panel_04_L_Height - lcd.getTextHeight(FONT_MINI,"max")-12,"max",FONT_MINI)
	local rpmMaxString = string.format("%i",rpmMax)
	lcd.setColor(max_r,max_g,max_b)

	if (rpmMax == -1.0) then
		lcd.drawText(panel_04_L_X + (panel_04_L_Width - lcd.getTextWidth(FONT_MINI,"------"))*0.5 - 50,panel_04_L_Y + panel_04_L_Height -lcd.getTextHeight(FONT_MINI,"------"),"------",FONT_MINI)
	else
		lcd.drawText(panel_04_L_X + (panel_04_L_Width - lcd.getTextWidth(FONT_MINI,rpmMaxString))*0.5 - 50,panel_04_L_Y + panel_04_L_Height -lcd.getTextHeight(FONT_MINI,rpmMaxString),rpmMaxString,FONT_MINI)
	end



----------------------------------------------------
	
	local panel_01_R_Width = screenMaxX - batterySymbolX - batterySymbolWidth - 12
	local panel_01_R_Height = 29
	local panel_01_R_X = screenMaxX - panel_01_R_Width
	local panel_01_R_Y = 0
	
	lcd.setColor(base_r,base_g,base_b)
		
	lcd.drawText(panel_01_R_X + -5,panel_01_R_Y + panel_01_R_Height - lcd.getTextHeight(FONT_MINI,"Lipo")-1,"Lipo",FONT_MINI)
	lcd.drawText((panel_01_R_X + panel_01_R_Width - lcd.getTextWidth(FONT_MINI,"mAh"))-2,panel_01_R_Y + (panel_01_R_Height - lcd.getTextHeight(FONT_MINI,"mAh"))*0.5,"mAh",FONT_MINI)
	batteryCapacityUsedString = string.format("%i",batteryCapacityUsedTotal)
	
	if (hasRxBeenPoweredOn == true and batteryPercentageRounded <= alarmCapacityLevelFive and batteryPercentageRounded > alarmCapacityLevelSix and batteryCapacityUsedTotal > 0) then
		lcd.setColor(orange_r,orange_g,orange_b)
	elseif (hasRxBeenPoweredOn == true and batteryPercentageRounded <= alarmCapacityLevelSix and batteryCapacityUsedTotal > 0) then
		lcd.setColor(red_r,red_g,red_b)
	else
		lcd.setColor(base_r,base_g,base_b)
	end
		
	lcd.drawText((panel_01_R_X + panel_01_R_Width - lcd.getTextWidth(FONT_MAXI,batteryCapacityUsedString))-28,(panel_01_R_Height - lcd.getTextHeight(FONT_MAXI,batteryCapacityUsedString))*0.5,batteryCapacityUsedString,FONT_MAXI)
	
	lcd.setColor(base_r,base_g,base_b)
	
	if (telemetryActive == true and estimateUsedLipoBoolean == true and voltagePerCellAtStartup < (voltageThresholdUsedLipo/100)) then
		lcd.setColor(red_r,red_g,red_b)
		lcd.drawText(panel_01_R_X + -5,panel_01_R_Y+5,"Est.",FONT_MINI)
		lcd.setColor(base_r,base_g,base_b)
	end

	
----------------------------------------------------

	local panel_02_R_Width = screenMaxX - batterySymbolX - batterySymbolWidth
	local panel_02_R_Height = 75
	local panel_02_R_X = panel_02_L_Width + batterySymbolWidth
	local panel_02_R_Y = panel_01_R_Height
	
	lcd.setColor(base_r,base_g,base_b)

	lcd.drawFilledRectangle(panel_02_R_X+3,panel_02_R_Y,panel_02_R_Width-3,2)
	
	lcd.drawText(panel_02_R_X+4,panel_02_R_Y+5,"Current",FONT_MINI)
	local escCurrentString = string.format("%3.1f",escCurrent)
	lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_BIG,escCurrentString)-45,panel_02_R_Y,escCurrentString,FONT_BIG)
	lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"A")-34,panel_02_R_Y+5,"A",FONT_MINI)
	local escCurrentMaxString = string.format("%iA",escCurrentMax)
	lcd.setColor(max_r,max_g,max_b)
	if (escCurrentMax == -1.0) then
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"--- A")-5,panel_02_R_Y+5,"--- A",FONT_MINI)
	else
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,escCurrentMaxString)-5,panel_02_R_Y+5,escCurrentMaxString,FONT_MINI)
	end
	lcd.setColor(base_r,base_g,base_b)
	
	lcd.drawText(panel_02_R_X+4,panel_02_R_Y+5+18,"Temp",FONT_MINI)
	local escTempString = string.format("%i",escTemp)
	lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_BIG,escTempString)-45,panel_02_R_Y+0+18,escTempString,FONT_BIG)
	lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"°C")-34,panel_02_R_Y+5+18,"°C",FONT_MINI)
	local escTempMaxString = string.format("%i°C",escTempMax)
	lcd.setColor(max_r,max_g,max_b)
	if (escTempMax == -1.0) then
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"---°C")-5,panel_02_R_Y+5+18,"---°C",FONT_MINI)
	else
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,escTempMaxString)-5,panel_02_R_Y+5+18,escTempMaxString,FONT_MINI)
	end
	lcd.setColor(base_r,base_g,base_b)
	
	lcd.drawText(panel_02_R_X+4,panel_02_R_Y+5+18+18,"Throttle",FONT_MINI)
	local escThrottleString = string.format("%i",escThrottle)
	lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_BIG,escThrottleString)-45,panel_02_R_Y+0+18+18,escThrottleString,FONT_BIG)
	lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"%")-34,panel_02_R_Y+5+18+18,"%",FONT_MINI)
	local escThrottleMaxString = string.format("%i%%",escThrottleMax)
	lcd.setColor(max_r,max_g,max_b)
	if (escThrottleMax == -1.0) then
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"--- %")-3,panel_02_R_Y+5+18+18,"--- %",FONT_MINI)
	else
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,escThrottleMaxString)-3,panel_02_R_Y+5+18+18,escThrottleMaxString,FONT_MINI)
	end
	lcd.setColor(base_r,base_g,base_b)
	
	lcd.drawText(panel_02_R_X+4,panel_02_R_Y+5+18+18+18,"Vibrations",FONT_MINI)
	local vibrationsString = string.format("%i",vibrations)
	lcd.drawText(panel_02_R_X+(panel_02_R_Width-lcd.getTextWidth(FONT_BIG,vibrationsString))-45,panel_02_R_Y+0+18+18+18,vibrationsString,FONT_BIG)
	lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"%")-34,panel_02_R_Y+5+18+18+18,"%",FONT_MINI)

	local vibrationsMaxString = string.format("%i%%",vibrationsMax)
	lcd.setColor(max_r,max_g,max_b)
	if (vibrationsMax == -1.0) then
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,"--- %")-3,panel_02_R_Y+5+18+18+18,"--- %",FONT_MINI)
	else
		lcd.drawText(panel_02_R_X+panel_02_R_Width-lcd.getTextWidth(FONT_MINI,vibrationsMaxString)-3,panel_02_R_Y+5+18+18+18,vibrationsMaxString,FONT_MINI)
	end
	lcd.setColor(base_r,base_g,base_b)


----------------------------------------------------
	
	local panel_03_R_Width = screenMaxX - batterySymbolX - batterySymbolWidth
	local panel_03_R_Height = 55
	local panel_03_R_X = panel_04_L_Width + batterySymbolWidth
	local panel_03_R_Y = panel_01_R_Height + panel_02_R_Height
	
	lcd.setColor(base_r,base_g,base_b)

	lcd.drawFilledRectangle(panel_03_R_X+3,panel_03_R_Y,panel_03_R_Width-3,2)
	
	local voltagePerCellAveragedString = string.format("%4.2f",voltagePerCellAveraged)
	lcd.drawText(panel_03_R_X + (panel_03_R_Width - lcd.getTextWidth(FONT_MAXI,voltagePerCellAveragedString))*0.5,panel_03_R_Y + panel_03_R_Height - lcd.getTextHeight(FONT_MAXI,voltagePerCellAveragedString)-8,voltagePerCellAveragedString,FONT_MAXI)
	lcd.drawText(panel_03_R_X + (panel_03_R_Width - lcd.getTextWidth(FONT_MAXI,voltagePerCellAveragedString))*0.5 + 68,panel_03_R_Y + panel_03_R_Height - lcd.getTextHeight(FONT_BIG,"V")-17,"V",FONT_BIG)
	
	lcd.drawText(panel_03_R_X+4,panel_03_R_Y + panel_03_R_Height - lcd.getTextHeight(FONT_MINI,"Cell")-9,"Cell",FONT_MINI)
	lcd.drawText(panel_03_R_X+4,panel_03_R_Y + panel_03_R_Height - lcd.getTextHeight(FONT_MINI,"Volts")+2,"Volts",FONT_MINI)
	
	lcd.drawText(panel_03_R_X + panel_03_R_Width - lcd.getTextWidth(FONT_MINI,"min")-7,panel_03_R_Y+panel_03_R_Height-18,"min",FONT_MINI)
	lcd.drawText(panel_03_R_X + panel_03_R_Width - lcd.getTextWidth(FONT_MINI,"max")-5,panel_03_R_Y+panel_03_R_Height-10,"max",FONT_MINI)

	lcd.drawText(panel_03_R_X+64,panel_03_R_Y+panel_03_R_Height-16,"/",FONT_NORMAL)
	lcd.setColor(green_r,green_g,green_b)
	if (maxVoltagePerCell == -1.0) then
		lcd.drawText(panel_03_R_X+75,panel_03_R_Y+panel_03_R_Height-16,"----",FONT_BOLD)
	else
		lcd.drawText(panel_03_R_X+71,panel_03_R_Y+panel_03_R_Height-16,string.format("%4.2f",maxVoltagePerCell),FONT_BOLD)
	end
	lcd.setColor(red_r,red_g,red_b)
	if (minVoltagePerCell == 99.9) then
		lcd.drawText(panel_03_R_X+41,panel_03_R_Y+panel_03_R_Height-16,"----",FONT_BOLD)
	else
		lcd.drawText(panel_03_R_X+34,panel_03_R_Y+panel_03_R_Height-16,string.format("%4.2f",minVoltagePerCell),FONT_BOLD)
	end
	lcd.setColor(base_r,base_g,base_b)
	
	
	local voltageBarWidth = 76
	local voltageBarHeight = 7
	
	local voltageBarX = panel_03_R_X + (panel_03_R_Width - voltageBarWidth)*0.5 
	local voltageBarY = panel_03_R_Y+5
	
	local minVoltageValueBar = 3.20
	local maxVoltageValueBar = 4.20
	local restingVoltageTick = 3.75
	
	lcd.drawRectangle(voltageBarX,voltageBarY,voltageBarWidth,voltageBarHeight)
	lcd.drawText(voltageBarX-23,voltageBarY-3,string.format("%4.2f",minVoltageValueBar),FONT_MINI)
	lcd.drawText(voltageBarX+voltageBarWidth+2,voltageBarY-3,string.format("%4.2f",maxVoltageValueBar),FONT_MINI)
	
	local voltageBarFillRatio = ((voltagePerCellAveraged - minVoltageValueBar) / (maxVoltageValueBar-minVoltageValueBar))*100
	
	if (voltageBarFillRatio >= 0 and voltageBarFillRatio <= 100) then
		voltageBarFillRatio = voltageBarFillRatio
	else
		voltageBarFillRatio = 0
	end
	
	local voltageBarDeltaX = (voltageBarFillRatio*(voltageBarWidth-2))//100
	lcd.setColor(voltage_r,voltage_g,voltage_b)
		
	lcd.drawFilledRectangle(voltageBarX+1,voltageBarY+1,voltageBarDeltaX,voltageBarHeight-2)
	lcd.setColor(base_r,base_g,base_b)
	
	local restingVoltageTickX = (((restingVoltageTick - minVoltageValueBar) / (maxVoltageValueBar-minVoltageValueBar))*100) * (voltageBarWidth-2)//100
	lcd.setColor(base_r,base_g,base_b)
	lcd.drawLine(voltageBarX+1+restingVoltageTickX,voltageBarY+1,voltageBarX+1+restingVoltageTickX,voltageBarY+voltageBarHeight-2)
	lcd.setColor(base_r,base_g,base_b)
	
	local minVoltageValueX = (((minVoltagePerCell - minVoltageValueBar) / (maxVoltageValueBar-minVoltageValueBar))*100) * (voltageBarWidth-2)//100
	lcd.setColor(red_r,red_g,red_b)
	lcd.drawFilledRectangle(voltageBarX+1+minVoltageValueX,voltageBarY+1,3,voltageBarHeight-2)
	lcd.setColor(base_r,base_g,base_b)
	
	local maxVoltageValueX = (((maxVoltagePerCell - minVoltageValueBar) / (maxVoltageValueBar-minVoltageValueBar))*100) * (voltageBarWidth-2)//100
	lcd.setColor(green_r,green_g,green_b)
	lcd.drawFilledRectangle(voltageBarX+1+maxVoltageValueX,voltageBarY+1,3,voltageBarHeight-2)
	lcd.setColor(base_r,base_g,base_b)
	
		
----------------------------------------------------
		
	local panel_central_Width = screenMaxX - panel_01_L_Width - panel_01_R_Width
	local panel_central_Height = screenMaxY - batterySymbolHeight - batteryTopHeight - 0
	local panel_central_X = panel_01_L_Width
	local panel_central_Y = 0
	
	--local batteryPercentageString = string.format("%2.0f",batteryPercentage)
	--batteryPercentage =0.6
	--batteryPercentageRounded = math.floor(batteryPercentage + 0.5)
	local batteryPercentageString = string.format("%i",batteryPercentageRounded)
	
	if (hasRxBeenPoweredOn == true and batteryPercentageRounded <= alarmCapacityLevelFive and batteryPercentageRounded > alarmCapacityLevelSix and batteryCapacityUsedTotal > 0) then
		lcd.setColor(orange_r,orange_g,orange_b)
	elseif (hasRxBeenPoweredOn == true and batteryPercentageRounded <= alarmCapacityLevelSix and batteryCapacityUsedTotal > 0) then
		lcd.setColor(red_r,red_g,red_b)
	elseif (hasRxBeenPoweredOn == true and batteryPercentageRounded >= alarmCapacityLevelFive) then
		lcd.setColor(green_r,green_g,green_b)
	else
		lcd.setColor(base_r,base_g,base_b)
	end


	lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_MAXI,batteryPercentageString))*0.5+lcd.getTextWidth(FONT_MAXI,batteryPercentageString)-1,panel_central_Y + (panel_central_Height - lcd.getTextHeight(FONT_NORMAL,"%"))*0.5-8,"%",FONT_NORMAL)
	lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_MAXI,batteryPercentageString))*0.5-2,panel_central_Y-5,batteryPercentageString,FONT_MAXI)
	
	lcd.setColor(base_r,base_g,base_b)
	
	if (telemetryActive == true or resetTelemetryMinMax == 1 and estimateUsedLipoBoolean == true and voltagePerCellAtStartup < (voltageThresholdUsedLipo/100)) then
		lcd.setColor(red_r,red_g,red_b)
		lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_MINI,"Lipo not"))*0.5,panel_central_Y+batterySymbolY+10,"Lipo not",FONT_MINI)
		lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_MINI,"fully"))*0.5,panel_central_Y+batterySymbolY+22,"fully",FONT_MINI)
		lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_MINI,"charged!"))*0.5,panel_central_Y+batterySymbolY+34,"charged!",FONT_MINI)
		lcd.setColor(base_r,base_g,base_b)
	end
	
	local lipoCapacityString = string.format("%i",lipoCapacity)
    local lipoCellCountString = string.format("%iS",lipoCellCount)
	
	lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_NORMAL,lipoCapacityString))*0.5,panel_central_Y+batterySymbolHeight-15,lipoCapacityString,FONT_NORMAL)
	lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_MINI,"mAh"))*0.5,panel_central_Y+batterySymbolHeight+2,"mAh",FONT_MINI)
	lcd.drawText(panel_central_X + (panel_central_Width - lcd.getTextWidth(FONT_NORMAL,lipoCellCountString))*0.5,panel_central_Y+batterySymbolHeight+17,lipoCellCountString,FONT_NORMAL)
end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Jeti lua initialization
--------------------------------------------------------------------------------------------
local function init(code)
	print ("-Lua application Heli Telem. Display initialized-")
	
	voltageSensorID = system.pLoad("voltageSensorID",0)
	voltageSensorParam = system.pLoad("voltageSensorParam",0)
	voltageSensorName = system.pLoad("voltageSensorName","...")
	voltageSensorLabel = system.pLoad("voltageSensorLabel","...")

	currentSensorID = system.pLoad("currentSensorID",0)
	currentSensorParam = system.pLoad("currentSensorParam",0)

	capacitySensorID = system.pLoad("capacitySensorID",0)
	capacitySensorParam = system.pLoad("capacitySensorParam",0)

	temperatureSensorID = system.pLoad("temperatureSensorID",0)
	temperatureSensorParam = system.pLoad("temperatureSensorParam",0)

	throttleSensorID = system.pLoad("throttleSensorID",0)
	throttleSensorParam = system.pLoad("throttleSensorParam",0)

	rpmSensorID = system.pLoad("rpmSensorID",0)
	rpmSensorParam = system.pLoad("rpmSensorParam",0)
	
	vibrationsSensorID = system.pLoad("vibrationsSensorID",0)
	vibrationsSensorParam = system.pLoad("vibrationsSensorParam",0)

	elevatorSensorID = system.pLoad("elevatorSensorID",0)
	elevatorSensorParam = system.pLoad("elevatorSensorParam",0)

	aileronSensorID = system.pLoad("aileronSensorID",0)
	aileronSensorParam = system.pLoad("aileronSensorParam",0)

	rudderSensorID = system.pLoad("rudderSensorID",0)
	rudderSensorParam = system.pLoad("rudderSensorParam",0)

	lipoCellCount = system.pLoad("lipoCellCount",1)
	lipoCapacity = system.pLoad("lipoCapacity",0)
	correctionFactor = system.pLoad("correctionFactor",1000)
	timeDelay = system.pLoad("timeDelay",1)
	averagingWindowCellVoltage = system.pLoad("averagingWindowCellVoltage",5)
	averagingWindowRxVoltage = system.pLoad("averagingWindowRxVoltage",5)
	alarmCapacityLevelOne = system.pLoad("alarmCapacityLevelOne",80)
	alarmCapacityLevelTwo = system.pLoad("alarmCapacityLevelTwo",60)
	alarmCapacityLevelThree = system.pLoad("alarmCapacityLevelThree",40)
	alarmCapacityLevelFour = system.pLoad("alarmCapacityLevelFour",20)
	alarmCapacityLevelFive = system.pLoad("alarmCapacityLevelFive",5)
	alarmCapacityLevelSix = system.pLoad("alarmCapacityLevelSix",0)
	alarmCapacityLevelOneFile = system.pLoad("alarmCapacityLevelOneFile","")
	alarmCapacityLevelTwoFile = system.pLoad("alarmCapacityLevelTwoFile","")
	alarmCapacityLevelThreeFile = system.pLoad("alarmCapacityLevelThreeFile","")
	alarmCapacityLevelFourFile = system.pLoad("alarmCapacityLevelFourFile","")
	alarmCapacityLevelFiveFile = system.pLoad("alarmCapacityLevelFiveFile","")
	alarmCapacityLevelSixFile = system.pLoad("alarmCapacityLevelSixFile","")
	alarmVoltageLevelOne = system.pLoad("alarmVoltageLevelOne",330)
	
	estimateUsedLipo = system.pLoad("estimateUsedLipo",0)
	voltageThresholdUsedLipo = system.pLoad("voltageThresholdUsedLipo",410)
	alarmUsedLipoDetectedFile = system.pLoad("alarmUsedLipoDetectedFile","")
	
	lowVoltageChirp = system.pLoad("lowVoltageChirp",0)
	
	switchStartTimer = system.pLoad("switchStartTimer")
	switchResetTimer = system.pLoad("switchResetTimer")
	switchResetTelemetryMinMax = system.pLoad("switchResetTelemetryMinMax")
	switchActivateTelemetryMinMax = system.pLoad("switchActivateTelemetryMinMax")

	system.registerForm(1,MENU_APPS,"Heli Telem. Display",initForm,nil,nil,nil)

	if (debugOn == true) then
		system.registerForm(2,MENU_APPS,"Heli Telem. Display Debug",nil,nil,printForm,nil)
	end

	local modelName = system.getProperty("Model")
	local windowTitle = "Heli Telem. Display - "..modelName
	
	system.registerTelemetry(2,windowTitle,4,printTelemetryWindow)
	system.registerLogVariable("Lipo Volts per Cell","V",(function(index) return voltagePerCellAveraged*100,2 end))

	if estimateUsedLipo == 1 then
		estimateUsedLipoBoolean = true
	else
		estimateUsedLipoBoolean = false
	end
	
	if lowVoltageChirp == 1 then
		lowVoltageChirpBoolean = true
	else
		lowVoltageChirpBoolean = false
	end
	
	
	collectgarbage()

end
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
-- Application interface
--------------------------------------------------------------------------------------------
collectgarbage()
return {init = init, loop = loop, author = "Nick Pedersen", version = "1.0", name = "Heli Telem. Display"}
--------------------------------------------------------------------------------------------
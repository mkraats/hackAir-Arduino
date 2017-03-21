--- hackAIR ESP Firmware
-- Handles WiFi setup and network communications
-- @version 0.1.0
-- @author Thanasis Georgiou

--- The server URL used for sending data to the hackAIR project
server_URL = "http://hackair.draxis.gr:8000/sensors/arduino/measurements"
auth_token = ""

function sent_data(args)
    -- Prepare HTTP headers
    local headers = 'Content-Type: application/json\r\n' ..
                    'HTTP Accept header: application/vnd.hackair.v1+json\r\n' ..
                    'Authorization: ' .. auth_token .. '\r\n'

    -- Parse arguments from serial and encode them in JSON
    local pm25, pm10, battery, tamper, error =
        string.match(args, "([^,]+),([^,]+),([^,]+),([^,]+),([^,]*)")

    local body = string.format([[{
        { "reading": {
            "PM2.5_AirPollutantValue":"%s",
            "PM10_AirPollutantValue":"%s"
        },
        "battery":"%s",
        "tamper":"%s",
        "error":"%s"
    }]], pm25, pm10, battery, tamper, error)

    -- Make the request
    --noinspection UnusedDef
    http.post(server_URL, headers, body,
        function(code, data)
            uart.write(0, tostring(code))
        end
    )
end

--- Handle UART commands
-- The first word (string until first space) is the command, the rest is
-- parameters. Each command is terminated with a \n.
-- @param UART input, must be parsed
function handle_uart(data)
    -- Parse parameters
    local com, args = string.match(data, "([^%s]+)%s([^%s]+)")
    if com == nil then
        com = string.sub(data, 1, -2)
    end

    -- Execute commands
    if com == 'e+raw' then -- Enter raw mode (lua console)
        uart.on("data")
        uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)
    elseif com == 'e+restart' then -- Restart ESP
        node.restart()
    elseif com == 'e+version' then -- Version info
        uart.write(0, 'v2')
    elseif com == 'e+send' then -- Send data to server
        if args == nil then
            print('Command e+send requires parameters (pm25, pm10, battery, tamper, error)')
        else
            sent_data(args)
        end
    elseif com == 'e+clearap' then -- Clear saved access points
        wifi.sta.config('', '')
        node.restart()
    elseif com == 'e+token' then -- Grab the token for authorization
        if args == nil then
            print('Command e+token required parameters (token)')
        else
            auth_token = args
        end
    elseif com == 'e+isready' then -- Is the ESP ready and connected?
        if wifi.sta.getip() ~= nil then
            uart.write(0, tostring(1))
        else
            uart.write(0, tostring(0))
        end
    else
        print('Unknown command ' .. com)
    end
end

-- Start listening to UART for commands
uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
uart.on('data', "\n", handle_uart, 0)

-- Create AP for configuration
wifi.ap.config({ssid = "hackAIR-"..node.chipid(), pwd = "hackAIR-"..node.chipid()})
wifi.setmode(wifi.STATIONAP)

-- Manual mode
enduser_setup.manual(true)
enduser_setup.start(
    function()
        -- WiFi information is stored in wifi.sta.config so we don't have
        -- to do anything special here.

        -- Print debug info
        print("Connected to wifi as:" .. wifi.sta.getip())

        -- Stop portal
        enduser_setup.stop()
        wifi.setmode(wifi.NULLMODE)
        wifi.setmode(wifi.STATION)
        wifi.sta.connect()
    end,
    function(err, str)
        print("enduser_setup: Err #" .. err .. ": " .. str)
    end)

wifiConfig = nil
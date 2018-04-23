return function (channels) --the big fucking global FUNCTION!

    
    _DELAY_STD = 200;
    _DELAY_MINITERM = 400;
    
    _MAIN_TIMEOUT = _DELAY_STD;
    --set uart speed and handler for Adixen
    unitRequest = false;
    setAdixenCOM = function()
        collectgarbage()
        uart.setup(0,9600,8,uart.PARITY_NONE,uart.STOPBITS_1,1);
        uart.on("data","\r",
            function (data)
                if (data:find("%$") ~= nil) then
                    if unitRequest then
                        unitRequest = false
                        local uni = ""
                        if data:find("$0") then
                            uni = "pascal"
                        elseif data:find("$1") then
                            uni = "torr"
                        elseif data:find("$2") then
                            uni = "mbar"
                        end
                        local status,value = string.match(buf, "(%d),(.+)")
                        local value = string.sub(value,1,-2)
                        buf = "{\"channel\": 0,".."\"status\":"..status..",\"value\":\""..value.."\",\"unit\":\""..uni.."\"}"
                    else
                        buf = buf..string.sub(data,data:find("%$")+1, data:len()-1)..",";
                        unitRequest = true
                        uart .write(0, "$UNI,?\r");
                    end
                end
            end
        ,0)
    end

    getUnitAdixen = function(data)
        if data:find("$0") then
            return "pascal"
        elseif data:find("$1") then
            return "torr"
        elseif data:find("$2") then
            return "mbar"
        end
        return nil
    end

    --set uart speed and handler for Adixen Multichannel
    requestedChannel = 1
    local unitAdixen = ""
    setAdixenMultiCOM = function()
        collectgarbage()
        uart.setup(0,9600,8,uart.PARITY_NONE,uart.STOPBITS_1,1);
        uart.on("data","\r",
            function (data)
                if (data:find("%$") ~= nil) then
                    if unitRequest then
                        unitRequest = false
                        unitAdixen = getUnitAdixen(data)
                        uart.write(0, "$PRD,"..requestedChannel.."\r")
                        buf = "{"
                    else
                        local status,value = string.match(data, "%$(%d),(.+)")
                        local value = string.sub(value,1,-2)
                        buf = buf.."{\"channel\":"..requestedChannel..",\"status\":"..status..",\"value\":\""..value.."\",\"unit\":\""..unitAdixen.."\"}"
                        if requestedChannel<3 then
                            requestedChannel = requestedChannel + 1
                            buf = buf..",";
                            uart.write(0, "$PRD,"..requestedChannel.."\r")
                        else
                            buf = buf.."}"
                            requestedChannel = 1
                        end
                    end
                end
            end
        ,0)
    end

    
    _MINITERM_TEMP = 1 --temperature value
    _MINITERM_COLD_TEMP = 2 --temperature of the cold part of thermocouple
    _MINITERM_Y = 3 --power?
    _MINITERM_SET_TEMP = 4 --SP temperature
    _MINITERM_STATUS = 5 --SP temperature
    requestType = _MINITERM_TEMP
--set uart speed and handler for Miniterm
    
    setMinitermCOM = function()
        collectgarbage()
        received = {0,0,0,0,0}
        ind = 1
        uart.setup(0,1200,8,uart.PARITY_NONE,uart.STOPBITS_1,1);
        uart.on("data",1,
            function (data)
                if (ind == 1) then
                    if (data:byte(1) == 238) then
                        received[ind] = data:byte(1)
                        ind = ind + 1
                    end
                else
                    received[ind] = data:byte(1)
                    ind = ind + 1
                    if ind>5 then
                        ind = 1
                        --TODO CRC
                        if requestType == _MINITERM_TEMP then
                            buf = "{\"temperature\":"..((received[4]*256 + received[3])/10)..","
                            requestType = _MINITERM_SET_TEMP
                            uart.write(0, 0xEE, 0x40, 0x3E, 0xE0, 0x1E)
                        elseif requestType == _MINITERM_SET_TEMP then 
                            buf = buf.."\"SP_temperature\":"..((received[4]*256 + received[3])/10)..","
                            requestType = _MINITERM_COLD_TEMP
                            uart.write(0, 0xEE, 0x40, 0x64, 0xE2, 0x46)
                        elseif requestType == _MINITERM_COLD_TEMP then
                            buf = buf.."\"reftemperature\":"..((received[4]*256 + received[3])/100)..","
                            requestType = _MINITERM_Y
                            uart.write(0, 0xEE, 0x40, 0x50, 0xE0, 0x30)
                        elseif requestType == _MINITERM_Y then
                            buf = buf.."\"Y_parameter\":"..((received[4]*256 + received[3])/100).."}"
                            requestType = _MINITERM_STATUS
                            --uart.write(0, 0xEE, 0x30, 0x29, 0x29)
                        end                            
                    end
                    collectgarbage()                        
                end
            end
        ,0)
    end

    setAlcatelCOM = function()
        collectgarbage()
        uart.setup(0,9600,8,uart.PARITY_NONE,uart.STOPBITS_1,1);
        uart.on("data","\n",
            function (data)
                --TODO check data
                something, pressure, unit = string.match(data, '(%d),%s+(.+)%s+(%a+)')
                print(something, pressure, unit);
                tmr.alarm(1,5000, tmr.ALARM_SINGLE, function() 
                    pressure = nil;
                    unit = nil;
                    something = nil;
                end)
                collectgarbage()
            end
        ,0)
    end

    setMKScom = function()
        collectgarbage()
        uart.setup(0, 115200, 8, uart.PARITY_NONE,uart.STOPBITS_1,1);
        uart.on("data","\r",
            function (data)
                --TODO check data
                buf = buf.."{\"pressure\":"..data:sub(1, -2).."}";
            end
        ,0)
    end

    listenToAlcatel = function()
        tmr.alarm(1, _MAIN_TIMEOUT, tmr.ALARM_SINGLE, function()
            selectChannel(2)
            setAlcatelCOM()    
        end)
    end
    
    
    --channel request
    requestChannel = function(n)
        _MAIN_TIMEOUT = _DELAY_STD;
        if channels[n] == _ADIXEN then
            setAdixenCOM()
            selectChannel(n)
            uart.write(0, "$PRD\r");
        elseif channels[n] == _MINITERM then
            _MAIN_TIMEOUT = _DELAY_MINITERM;
            setMinitermCOM()
            selectChannel(n)
            requestType = _MINITERM_TEMP
            uart.write(0, 0xEE, 0x40, 0x08, 0xE0, 0xE8)
            --runOnce = true;
        elseif channels[n] == _ALCATEL then
            if (pressure ~= nil) then
                local val = ""
                buf = "{\"channel\": 0,".."\"status\":"..something..",\"value\":\""..pressure.."\",\"unit\":\""..unit.."\"}"
            else
                buf = "null"
            end
        elseif channels[n] == _ADIXEN_MULTI then
            setAdixenMultiCOM()
            selectChannel(n)
            unitRequest = true
            uart.write(0, "$UNI,?\r");
        elseif channels[n] == _MKS then
            setMKScom()
            selectChannel(n)
            uart.write(0, "$\r")
        end
        listenToAlcatel()
    end

     --channels[2] = _ALCATEL
    listenToAlcatel()
    
    collectgarbage();
    buf = "";
    LED = 4
    activeChannel = 1;
    
    gpio.mode(LED, gpio.OUTPUT)   
    srv=net.createServer(net.TCP)

    lock = false;
    srv:listen(80,function(conn)
        conn:on("receive", function(client,request)
            gpio.write(LED, gpio.LOW)
            if lock == true then
                return 
            end
            lock = true;
            _client = client;
    
            local _, _, auth = string.find(request, "%cAuthorization: Basic ([%w=\+\/]+)");--Authorization:
            if (auth == nil or auth ~= "YWRtaW46YWRtaW4=")then --admin:admin
                   client:send("HTTP/1.0 401 Authorization Required\r\nWWW-Authenticate: Basic realm=\"Dovlenie\"\r\n\r\n<h1>Unauthorized Access</h1>");
                   client:close();
                   lock = false; --unlocking handler
                   collectgarbage(); --collecting garbage
                   return;
            end
            
            local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
            if(method == nil)then
                _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
            end
            
            local _GET = {}
            if (vars ~= nil)then
                for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                    _GET[k] = v
                end
            end
    
            if (string.match(path,"/hui")) then
                buf = buf.."HUI";
            elseif (string.match(path, "/favicon.ico")) then
                buf = "";
            elseif (string.match(path,"/ch1")) then
                requestChannel(1)
            elseif (string.match(path,"/ch2")) then
                requestChannel(2)
            elseif (string.match(path,"/ch3")) then
                requestChannel(3)
            elseif (string.match(path,"/ch4")) then
                requestChannel(4)
            elseif string.match(path,"/channels") then
                buf = "{\"ch1\":"..channels[1]..", \"ch2\":"..channels[2]..", \"ch3\":"..channels[3]..", \"ch4\":"..channels[4].."}";
            elseif (string.match(path,"/version")) then
                buf = VERSION
            else
                buf = buf.."<h1>Dovlenie stand</h1>";
                buf = buf.."<a href=\"/ch1\">channel 1: </a>"..channels[1].."<br>";
                buf = buf.."<a href=\"/ch2\">channel 2: </a>"..channels[2].."<br>";
                buf = buf.."<a href=\"/ch3\">channel 3: </a>"..channels[3].."<br>";
                buf = buf.."<a href=\"/ch4\">channel 4: </a>"..channels[4].."<br>";
                --buf = buf.."<a href=\"?pin=OFF\"><button>Test screen OFF</button></a></p>";
                buf = buf.."<a href=\"/version\">version</a></p>";
            end

            tmr.alarm(0, _MAIN_TIMEOUT, tmr.ALARM_AUTO, function() 
                if (buf == "") then
                    buf = "404";
                end
                client:send(buf);
                buf = "";
                client:close();
                collectgarbage();
                lock = false;
            end)
            collectgarbage();
            gpio.write(LED, gpio.HIGH)
        end)
    end)
end

VERSION = "Davilka 0.4"
--{INH, B, A}
selPins = { {gpio.LOW, gpio.LOW,  gpio.LOW},
            {gpio.LOW, gpio.LOW,  gpio.HIGH},
            {gpio.LOW, gpio.HIGH, gpio.LOW},
            {gpio.LOW, gpio.HIGH, gpio.HIGH},
            {gpio.HIGH, gpio.HIGH, gpio.HIGH}
           }
pinINH = 6;
pinB = 7;
pinA = 8;
function initChannels()
    gpio.mode(pinINH, gpio.OUTPUT)
    gpio.mode(pinB, gpio.OUTPUT)
    gpio.mode(pinA, gpio.OUTPUT)
end

selectChannel = function(channel)
    gpio.write(pinINH, selPins[channel][1])
    gpio.write(pinB, selPins[channel][2])
    gpio.write(pinA, selPins[channel][3])
end

_ADIXEN = "Adixen";
_MINITERM = "Miniterm";
_ALCATEL = "Alcatel";
_ADIXEN_MULTI = "AdixenMultichannel";
_MKS = "MKS";
usedChannels = {0,0,0,0};
function isChannel(i)
    return usedChannels[i]
end

detectMKS = function()
    i = 0;
    uart.setup(0,115200,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
    uart.on("data","\r",
        function (data)
            if (data:find("%PR")) then
                usedChannels[i] = _MKS
                uart.write(0, "%1\r"); --set text mode
            end            
        end
    ,0)
    tmr.alarm(0, 100, tmr.ALARM_SEMI, 
    function() 
        i = i+1;
        selectChannel(i)
        if (i<5) then
            uart.write(0, "v\r");
            tmr.start(0)
        else
            selectChannel(5)
            uart.setup(0,115200,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
            print("detect mks finished")
            for i = 1,4,1 do
                print(isChannel(i))
            end
            detectAlcatel()
        end
    end)
end

detectMiniterm = function()
    --trying to find out where is a Miniterm
    i = 0;
    uart.setup(0,1200,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
    uart.on("data",0,
        function (data)
            --TODO
            if (data:byte(1) == 238) then --ULTIMATE CHECK!!!!!!!!!!!11111111111111
                usedChannels[i] = _MINITERM 
            end
            --received[ind] = data:byte(1)
            --ind = ind + 1
        end
    ,0)
    tmr.alarm(0, 500, tmr.ALARM_SEMI, 
    function() 
        i = i+1;
        selectChannel(i)
        uart.write(0, 0xEE, 0x40, 0x08, 0xE0, 0xE8);
        if (i<5) then
            tmr.start(0)
        else
            selectChannel(5)
            uart.setup(0,115200,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
            print("detect miniterm finished")
            for i = 1,4,1 do
                print(isChannel(i))
            end
            detectMKS()
        end
    end)
end

detectAlcatel = function()
    selectChannel(2)
    uart.setup(0,9600,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
    uart.on("data","\r",
        function (data)
            selectChannel(5)
           usedChannels[2] = _ALCATEL;
           uart.setup(0,115200,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
           print("Alcatel detected")
        end
    ,0)
end

function detectChannels()
    --trying to find out where is an Adixen
    i = 0;
    uart.setup(0,9600,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
    uart.on("data","\r",
        function (data)
            if (data:find("%$") ~= nil) then
                if data:find("%$1") then
                    usedChannels[i] = _ADIXEN;
                elseif data:find("%$3") then
                    usedChannels[i] = _ADIXEN_MULTI;
                end
            end
        end
    ,0)
    tmr.alarm(0, 500, tmr.ALARM_SEMI, 
    function() 
        i = i+1;
        selectChannel(i)
        uart.write(0, "$VER\r");
        if (i<5) then
            tmr.start(0)
        else
            selectChannel(5)
            uart.setup(0,115200,8,uart.PARITY_NONE,uart.STOPBITS_1,0);
            print("detect adixen finished")
            for i = 1,4,1 do
                print(isChannel(i))
            end
            detectMiniterm()
        end
    end)
end

wifi.setmode(wifi.STATION)
wifi.sta.config("ESP8266_net","rirt222222")
wifi.sta.connect()
local cnt = 0
tmr.alarm(3, 1000, 1, function() 
    if (wifi.sta.getip() == nil) and (cnt < 20) then 
        print("Trying Connect to Router, Waiting...")
        cnt = cnt + 1 
    else 
         tmr.stop(3)
         if (cnt < 20) then 
            print("IP is "..wifi.sta.getip())
            --EVERYTHING IS OK INIT ALL
            initChannels()
            detectChannels()
            --register main
            tmr.alarm(1,8500, tmr.ALARM_SINGLE,
                function()
                    collectgarbage("collect")
                    --node.compile("main.lua")
                    m = dofile("main.lc")(usedChannels)    
                end)
         else 
            print("Wifi setup time more than 20s, Please verify wifi.sta.config() function. Then re-download the file.")
         end
         cnt = nil;
         end 
end)


--l = file.list();
--for k,v in pairs(l) do
--  print("name:"..k..", size:"..v)
--end

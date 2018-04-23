gpio.mode(5, gpio.INPUT, gpio.PULLUP)
if (gpio.read(5) == gpio.HIGH) then
    dofile("first.lua")
elseif (gpio.read(5) == gpio.LOW) then
    print("PIN 5 is low. Booting stopped.");
end


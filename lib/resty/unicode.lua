-- Copyright (C) perfGao
-- https://github.com/perfgao/lua-resty-unicode

local bit = require 'bit'
local sb = require "string.buffer".new()

local type = type
local tonumber = tonumber
local str_byte = string.byte
local str_sub = string.sub
local str_format = string.format
local str_char = string.char

local rshift = bit.rshift
local lshift = bit.lshift
local band = bit.band
local bor = bit.bor

local _M = { _VERSION = '0.01' }

_M.encode = function(srcstr)
    if type(srcstr) ~= "string" then
        return srcstr
    end

    sb:reset()

    local i = 0
    while true do
        i = i + 1
        local numbyte = str_byte(srcstr, i)
        if not numbyte then
            break
        end

        local value1, value2

        if numbyte >= 0x00 and numbyte <= 0x7f then
            value1 = numbyte
            value2 = 0
        elseif band(numbyte, 0xe0) == 0xc0 then

            local t1 = band(numbyte, 0x1f)

            i = i + 1

            local t2 = band(str_byte(srcstr, i), 0x3f)

            value1 = bor(t2, lshift(band(t1, 0x03), 6))
            value2 = rshift(t1, 2)
        elseif band(numbyte, 0xf0) == 0xe0 then

            local t1 = band(numbyte, 0x0f)

            i = i + 1

            local t2 = band(str_byte(srcstr, i), 0x3f)

            i = i + 1

            local t3 = band(str_byte(srcstr, i), 0x3f)

            value1 = bor(lshift(band(t2, 0x03), 6), t3)
            value2 = bor(lshift(t1, 4), rshift(t2, 2))
        else
            return nil, "out of range"
        end

        sb:put(str_format("\\u%02x%02x", value2, value1))
    end

    return sb:get()
end


_M.decode = function(srcstr)
    if type(srcstr) ~= "string" then
        return srcstr
    end

    sb:reset()

    local i = 1
    while true do
        local numbyte = str_byte(srcstr, i)
        if not numbyte then
            break
        end

        local substr = str_sub(srcstr, i, i + 1)
        if (substr == "\\u" or substr == "%u") then
            local unicode = tonumber("0x" .. str_sub(srcstr, i + 2, i + 5))
            if not unicode then
                sb:put(substr)
                i = i + 2
            else

                i = i + 6

                if unicode <= 0x007f then
                    -- 0xxxxxxx
                    sb:put(str_char(band(unicode, 0x7f)))
                elseif unicode >= 0x0080 and unicode <= 0x07ff then
                    -- 110xxxxx 10xxxxxx
                    sb:put(str_char(bor(0xc0, band(rshift(unicode, 6), 0x1f))))
                    sb:put(str_char(bor(0x80, band(unicode, 0x3f))))

                elseif unicode >= 0x0800 and unicode <= 0xffff then
                    -- 1110xxxx 10xxxxxx 10xxxxxx
                    sb:put(str_char(bor(0xe0, band(rshift(unicode, 12), 0x0f))))
                    sb:put(str_char(bor(0x80, band(rshift(unicode, 6), 0x3f))))
                    sb:put(str_char(bor(0x80, band(unicode,0x3f))))
                end
            end
        else
            sb:put(str_char(numbyte))
            i = i + 1
        end
    end

    return sb:get()
end


_M._TESTING = function()

    local unicode = _M
    local print = ngx.say

    -- unicode to utf-8
    print(unicode.decode('\\u0041'))    -- A

    -- support url-encode: '%u'
    print(unicode.decode('%u0041'))     -- A

    -- support mixing
    print(unicode.decode('s\\u0065l\\u0065ct * fr%u006fm'))  -- select * from

    -- A variety of encoding text
    print(unicode.decode('%u0045%u006e%u0067%u006c%u0069%u0073%u0068'))
    print(unicode.encode('English'))

    print(unicode.decode('\\u6c49\\u5b57'))
    print(unicode.encode('汉字'))
    print(unicode.decode('\\u6f22\\u5b57'))
    print(unicode.encode('漢字'))

    print(unicode.decode('\\u0440\\u0443\\u0441\\u0441\\u043a\\u0438\\u0439\\u0020\\u0020\\u0442\\u0435\\u043a\\u0441\\u0442'))
    print(unicode.encode('русский  текст'))

    print(unicode.decode('\\u0628\\u0627\\u0644\\u0639\\u0631\\u0628\\u064a\\u0629'))
    print(unicode.encode('بالعربية'))

end

return _M

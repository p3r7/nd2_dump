-- nd2_dump.
-- @eigen
--
-- https://www.nordkeyboards.com/sites/default/files/files/downloads/manuals/nord-stage/Nord%20Stage%20English%20Sysex%20Guide.pdf


-- ------------------------------------------------------------------------
-- deps

local midiutil = include('nd2_dump/lib/midiutil')
local nd2 = include('nd2_dump/lib/nord_drum_2')


-- ------------------------------------------------------------------------
-- parsing pgm dump

local HEADER = {
  0x33, -- clavia
  0x7f, -- sysex id?
  0x08, -- drum 2 id?
  0x19, 0x08, 0x03, 0x08, -- ??
}

local PADDING1 = {
  0x03,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
}

function is_nd2_pgm_dump(a)
  -- NB: skip first byte (0xf0)
  local header_offset = 1

  for i, h in ipairs(HEADER) do
    if a[i+header_offset] ~= h then
      return false
    end
  end

  return true
end

function parse_nd2_pgm_dump(a)
  local data_offset = 1 + #HEADER

  local bank_id = a[data_offset+1]
  local pgm_id = a[data_offset+2]

  -- then PADDING1

end


-- ------------------------------------------------------------------------
-- main

function print_hex_array(a)
  for _, b in ipairs(a) do
    local h = "0x" .. string.format("%02x", b)
    print(h)
  end
end

function init()
  local m = midi.connect()
  local is_sysex_dump_on = false
  local sysex_payload = {}

  local pinged = false
  local uuid = nil

  m.event=function(data)
    local d=midi.to_msg(data)
    if is_sysex_dump_on then
      for _, b in pairs(data) do
        table.insert(sysex_payload, b)
        if b == 0xf7 then
          is_sysex_dump_on = false
          if nd2.is_pong(sysex_payload) then
            print("<- PONG")
            midiutil.print_byte_array_midiox(sysex_payload)
            pinged = true

            print("-----------------------------")
            print("-> UUID?")
            nd2.ask_uuid(m.device)
          elseif nd2.is_uuid_resp(sysex_payload) then
            _, uuid = nd2.extract_uuid(sysex_payload)
            print("<- UUID: " .. midiutil.byte_to_str(uuid))
            midiutil.print_byte_array_midiox(sysex_payload)

            print("-----------------------------")
            print("-> PGM DUMP")
            nd2.pgm_dump(m.device, uuid, 1, 1)
          else
            print("<- PGM DUMP")
            midiutil.print_byte_array_midiox(sysex_payload)
          end
        end
      end
    elseif d.type == 'sysex' then
      is_sysex_dump_on = true
      sysex_payload = {}
      for _, b in pairs(d.raw) do
        table.insert(sysex_payload, b)
      end
    end
  end

  print("-----------------------------")
  print("-> PING")
  nd2.ping(m.device)

end

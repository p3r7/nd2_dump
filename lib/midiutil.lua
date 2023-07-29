-- librarian/midiutil

local midiutil = {}


-- ------------------------------------------------------------------------
-- consts

local DEVICE_ALL = "ALL"


-- ------------------------------------------------------------------------
-- bytes (sysex)

local DEFAULT_BYTE_FORMATER = midiutil.byte_to_str

function midiutil.byte_to_str(b)
  return "0x" .. string.format("%02x", b)
end

function midiutil.byte_to_str_midiox(b)
  return string.upper(string.format("%02x", b))
end

function midiutil.print_byte_array(a, fmt_fn, per_line)
  if fmt_fn == nil then fmt_fn = DEFAULT_BYTE_FORMATER end
  if per_line == nil then per_line = 1 end

  local line = ""
  local per_line_count = 0
  for _, b in ipairs(a) do
    line = line .. fmt_fn(b) .. " "
    per_line_count = per_line_count + 1
    if per_line_count >= per_line then
      print(line:sub(1, -2)) -- without last " "
      line = ""
      per_line_count = 0
    end
  end
  if per_line_count > 0 then
    print(line:sub(1, -2)) -- without last " "
  end
end

function midiutil.print_byte_array_midiox(a)
  midiutil.print_byte_array(a, midiutil.byte_to_str_midiox, 18)
end

function midiutil.byte_array_from_midiox(str)
  local a = {}
  for line in str:gmatch("([^\n]*)\n?") do
    for hs in string.gmatch(line, "[^%s]+") do
      table.insert(a, tonumber(hs, 16))
    end
  end
  return a
end

function midiutil.are_equal_byte_arrays(a, a2)
  if #a ~= #a2 then
    return false
  end

  for i, h in ipairs(a2) do
    if a[i] ~= h then
      return false
    end
  end
  return true
end

function midiutil.sysex_match(a, matcher)
  if #a ~= #matcher then
    return false
  end

  local res = {}

  for i, h in ipairs(matcher) do
    if type(h) == "string" then
      res[h] = a[i]
    elseif a[i] ~= h then
      return false, {}
    end
  end
  return true, res
end

function midiutil.sysex_valorized(a, vars)
  local a2 = tab.gather(a, {}) -- sort of a `table.copy`
  for i, h in ipairs(a2) do
    if type(h) == "string" and vars[h] ~= nil then
      a2[i] = vars[h]
    end
  end
  return a2
end

-- as used by some Clavia synths, Waldorf...
function midiutil.checksum_7bit(a)
  local v = 0
  for _, b in ipairs(a) do
    v = v + a
  end
  return (v & 0x7f)
end

function midiutil.sysex_has_header(a)
  return (a[1] == 0xf0 and a[tab.count(a)] == 0xf7)
end

function midiutil.sysex_sans_header(a)
  if midiutil.sysex_has_header(a) then
    local a2 = tab.gather(a, {}) -- sort of a `table.copy`
    return {table.unpack(a2, 2, #a2-1)}
  end
  return a
end

function midiutil.sysex_with_header(a)
  if midiutil.sysex_has_header(a) then
    return a
  end
  local a2 = tab.gather(a, {}) -- sort of a `table.copy`
  table.insert(a2, 1, 0xf0)
  table.insert(a2, 0xf7)
  return a2
end


-- ------------------------------------------------------------------------
-- send

function midiutil.send_msg(devname, msg)
  local data = midi.to_data(msg)
  local had_effect = false

  for _, dev in pairs(midi.devices) do
    if dev.port ~= nil and dev.name ~= 'virtual' then
      if devname == MIDI_DEV_ALL or devname == dev.name then
        midi.vports[dev.port]:send(data)
        had_effect = true
        if devname ~= MIDI_DEV_ALL then
          break
        end
      end
    end
  end

  return had_effect
end

function midiutil.send_cc(midi_device, ch, cc, val)
  local msg = {
    type = 'cc',
    cc = cc,
    val = val,
    ch = ch,
  }
  midiutil.send_msg(midi_device, msg)
end

function midiutil.send_nrpn(midi_device, ch, msb_cc, lsb_cc, val)
  -- NB:
  -- 16256 = 1111111 0000000
  -- 127   = 0000000 1111111

  local msb = (val & 16256) >> 7
  local lsb = val & 127

  -- print(msb .. " -> MSB CC " .. msb_cc)
  -- print(lsb .. " -> LSB CC " .. lsb_cc)

  -- 64 on cc 63

  midiutil.send_cc(midi_device, ch, msb_cc, msb)
  midiutil.send_cc(midi_device, ch, lsb_cc, lsb)
end

function midiutil.send_pgm_change(midi_device, ch, pgm)
  local msg = {
      type = "program_change",
      val = pgm,
      ch = ch,
    }
  midiutil.send_msg(midi_device, msg)
end


-- ------------------------------------------------------------------------

return midiutil

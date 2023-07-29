
local nd2 = {}


-- ------------------------------------------------------------------------
-- deps

local midiutil = include('nd2_dump/lib/midiutil')


-- ------------------------------------------------------------------------
-- consts

local SYSEX_CLAVIA = 0x33

local MTCH_UUID      = 'uuid'
local MTCH_BANK      = 'bank'
local MTCH_PGM       = 'pgm'
local MTCH_CHECKSUM  = 'checksum'


-- ------------------------------------------------------------------------
-- sysex - ping

nd2.SYSEX_PING_RQ = {SYSEX_CLAVIA, 0x7f, 0x7f, 0x07, 0x00, 0x06, 0x00, 0x7f}
nd2.SYSEX_PING_RESP = {SYSEX_CLAVIA, 0x7f, 0x19, 0x07, 0x00, 0x07, 0x00,
                     0x00, 0x4b, 0x00, 0x00, 0x37, 0x40, 0x18} -- NB: not sure this is universal!

function nd2.ping(midi_dev)
  local payload = midiutil.sysex_with_header(nd2.SYSEX_PING_RQ)
  midiutil.print_byte_array_midiox(payload)
  midi.send(midi_dev, payload)
end

function nd2.is_pong(payload)
  return midiutil.are_equal_byte_arrays(midiutil.sysex_sans_header(payload),
                                        nd2.SYSEX_PING_RESP)
end


-- ------------------------------------------------------------------------
-- sysex - get uuid

nd2.SYSEX_UUID_RQ = {SYSEX_CLAVIA, 0x7f, 0x7f, 0x07, 0x00, 0x02, 0x3a}
nd2.SYSEX_UUID_RESP = {SYSEX_CLAVIA, 0x7f, 0x19, 0x07, 0x00, 0x03, 0x02,
                       0x07, 0x00, MTCH_UUID, 0x03, 0x48}

function nd2.ask_uuid(midi_dev)
  local payload = midiutil.sysex_with_header(nd2.SYSEX_UUID_RQ)
  midi.send(midi_dev, payload)
end

function nd2.extract_uuid(payload)
  local ok, matches = midiutil.sysex_match(midiutil.sysex_sans_header(payload),
                                           nd2.SYSEX_UUID_RESP)
  if ok then
    return true, matches[MTCH_UUID]
  end

  return false, nil
end

function nd2.is_uuid_resp(payload)
  local ok, _ = nd2.extract_uuid(payload)
  return ok
end


-- ------------------------------------------------------------------------
-- sysex - pgm dump

local PGM_DUMP_CHECKSUM = {
  [1] = {
    0x0e,
    0x06,
    0x1e,
    0x16,
    0x2e,
    0x26,
    0x3e,
    0x36,
    0x4e,
    0x46,
    0x5e,
    0x56,
    0x6e,
    0x66,
    0x7e,
    0x76,
    0x07,
    0x0f,
    0x17,
    0x1f,
    0x27,
    0x2f,
    0x37,
    0x3f,
    0x47,
    0x4f,
    0x57,
    0x5f,
    0x67,
    0x6f,
    0x77,
    0x7f,
    0x1c,
    0x14,
    0x0c,
    0x04,
    0x3c,
    0x34,
    0x2c,
    0x24,
    0x5c,
    0x54,
    0x4c,
    0x44,
    0x7c,
    0x74,
    0x6c,
    0x64,
    0x15,
    0x1d,
  },
}

nd2.SYSEX_PGM_RQ = {SYSEX_CLAVIA, 0x7f, 0x7f, MTCH_UUID, 0x03, 0x07,
                    MTCH_BANK, MTCH_PGM, MTCH_CHECKSUM}

function nd2.pgm_dump(midi_dev, uuid, bank, pgm)
  local payload = midiutil.sysex_with_header(nd2.SYSEX_PGM_RQ)
  local vars = {
    [MTCH_UUID] = uuid,
    [MTCH_BANK] = 0x40 + bank - 1,
    [MTCH_PGM] = pgm - 1,
    [MTCH_CHECKSUM] = PGM_DUMP_CHECKSUM[bank][pgm],
  }
  payload = midiutil.sysex_valorized(payload, vars)
  midi.send(midi_dev, payload)
end

-- function nd2.is_pgm_dump(payload, uuid)
--   local payload = midiutil.sysex_sans_header(payload)
-- end


-- ------------------------------------------------------------------------

return nd2

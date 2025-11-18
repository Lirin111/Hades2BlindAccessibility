-- Audio Manager - Lua interface for FMOD audio playback
-- Provides controllable audio with volume, 3D positioning, and looping

local AudioManager = {}
AudioManager.__index = AudioManager

function AudioManager.new()
    local self = setmetatable({}, AudioManager)

    -- Path to manager.py and working directory
    self.plugin_root = rom.path.combine(_PLUGIN.plugins_mod_folder_path, "..")
    self.manager_py = rom.path.combine(self.plugin_root, "src", "manager.py")
    self.work_dir = rom.path.combine(self.plugin_root, "src")
    self.log_path = rom.path.combine(self.plugin_root, "audio_debug.log")

    -- io.popen handle
    self.process = nil
    self.initialized = false

    -- Get audio driver from config, default to 0 if not set or -1
    self.driver = 0
    if config and config.AudioDriver and config.AudioDriver >= 0 then
        self.driver = config.AudioDriver
    end

    rom.log.info("AudioManager: Created (manager: " .. self.manager_py .. ", driver: " .. self.driver .. ")")

    return self
end

function AudioManager:start()
    if self.process then
        rom.log.warning("AudioManager: Already running")
        return false
    end

    -- Start the audio manager process
    local exe_path = rom.path.combine(self.plugin_root, "h2a_audio_manager.exe")
    local cmd = string.format('"%s" 2>"%s"', exe_path, self.log_path)
    self.process = io.popen(cmd, "w")

    if not self.process then
        rom.log.error("AudioManager: Failed to start process")
        return false
    end

    rom.log.info("AudioManager: Process started (driver " .. self.driver .. ", stderr -> audio_debug.log)")

    -- Initialize FMOD with specific driver
    return self:send_command(string.format("INIT 64 %d", self.driver))
end

function AudioManager:send_command(cmd)
    if not self.process then
        rom.log.error("AudioManager: No process running")
        return false
    end

    -- Send command
    self.process:write(cmd .. "\n")
    self.process:flush()

    rom.log.debug("AudioManager: Sent command: " .. cmd)
    return true
end

function AudioManager:load(source_id, filename, is_3d)
    if is_3d == nil then is_3d = false end

    local is_3d_str = is_3d and "true" or "false"
    return self:send_command("LOAD " .. source_id .. " " .. filename .. " " .. is_3d_str)
end

function AudioManager:play(source_id, x, y, z, volume, looping)
    x = x or 0.0
    y = y or 0.0
    z = z or 0.0
    volume = volume or 1.0
    looping = looping or false

    local looping_str = looping and "true" or "false"
    return self:send_command(
        string.format("PLAY %s %.2f %.2f %.2f %.2f %s",
            source_id, x, y, z, volume, looping_str)
    )
end

function AudioManager:play_simple(source_id, volume)
    volume = volume or 1.0
    return self:play(source_id, 0, 0, 0, volume, false)
end

function AudioManager:stop(source_id)
    return self:send_command("STOP " .. source_id)
end

function AudioManager:set_pitch(source_id, pitch)
    pitch = pitch or 1.0
    return self:send_command(string.format("PITCH %s %.2f", source_id, pitch))
end

function AudioManager:set_source_volume(source_id, volume)
    volume = volume or 1.0
    return self:send_command(string.format("SETVOL %s %.2f", source_id, volume))
end

function AudioManager:seek(source_id, position_ms)
    return self:send_command(string.format("SEEK %s %d", source_id, position_ms))
end

function AudioManager:set_pan(source_id, pan)
    -- Pan: -1.0 = left, 0.0 = center, 1.0 = right (2D sounds only)
    pan = pan or 0.0
    return self:send_command(string.format("PAN %s %.2f", source_id, pan))
end

function AudioManager:set_master_volume(volume)
    return self:send_command(string.format("VOLUME %.2f", volume))
end

function AudioManager:update()
    return self:send_command("UPDATE")
end

function AudioManager:pause()
    return self:send_command("PAUSE")
end

function AudioManager:resume()
    return self:send_command("RESUME")
end

function AudioManager:shutdown()
    if self.process then
        self:send_command("QUIT")
        self.process:close()
        self.process = nil
        rom.log.info("AudioManager: Shutdown complete")
    end
end

-- Global audio manager instance
public.audio_manager = nil

-- Initialize audio manager on mod load
local function init_audio()
    if public.audio_manager then
        rom.log.warning("Audio: Manager already initialized")
        return
    end

    public.audio_manager = AudioManager.new()

    if public.audio_manager:start() then
        rom.log.info("Audio: Manager initialized successfully")
    else
        rom.log.error("Audio: Failed to initialize manager")
        public.audio_manager = nil
    end
end

-- Cleanup on mod unload
local function cleanup_audio()
    if public.audio_manager then
        public.audio_manager:shutdown()
        public.audio_manager = nil
    end
end

-- Auto-initialize
init_audio()

-- Export public API
--
-- Usage examples:
--   2D Audio (UI sounds, notifications):
--     public.audio.load("beep", "data/sounds/beep.wav", false)  -- is_3d = false
--     public.audio.play_simple("beep", 1.0)                      -- volume = 1.0
--     public.audio.set_pan("beep", -0.5)                         -- pan left
--
--   3D Audio (positional sounds):
--     public.audio.load("ambient", "data/sounds/ambient.wav", true)  -- is_3d = true
--     public.audio.play("ambient", x, y, z, 0.8, true)               -- pos, volume, looping
--
--   Pitch/Seek:
--     public.audio.set_pitch("beep", 1.5)  -- 1.5x pitch (higher)
--     public.audio.seek("ambient", 5000)   -- seek to 5 seconds
public.audio = {
    load = function(...)
        if public.audio_manager then
            return public.audio_manager:load(...)
        end
        return false
    end,

    play = function(...)
        if public.audio_manager then
            return public.audio_manager:play(...)
        end
        return false
    end,

    play_simple = function(...)
        if public.audio_manager then
            return public.audio_manager:play_simple(...)
        end
        return false
    end,

    stop = function(...)
        if public.audio_manager then
            return public.audio_manager:stop(...)
        end
        return false
    end,

    set_pitch = function(...)
        if public.audio_manager then
            return public.audio_manager:set_pitch(...)
        end
        return false
    end,

    set_source_volume = function(...)
        if public.audio_manager then
            return public.audio_manager:set_source_volume(...)
        end
        return false
    end,

    seek = function(...)
        if public.audio_manager then
            return public.audio_manager:seek(...)
        end
        return false
    end,

    set_pan = function(...)
        if public.audio_manager then
            return public.audio_manager:set_pan(...)
        end
        return false
    end,

    set_volume = function(...)
        if public.audio_manager then
            return public.audio_manager:set_master_volume(...)
        end
        return false
    end,

    update = function()
        if public.audio_manager then
            return public.audio_manager:update()
        end
        return false
    end,

    pause = function()
        if public.audio_manager then
            return public.audio_manager:pause()
        end
        return false
    end,

    resume = function()
        if public.audio_manager then
            return public.audio_manager:resume()
        end
        return false
    end,

    shutdown = cleanup_audio
}

rom.log.info("Audio module loaded")

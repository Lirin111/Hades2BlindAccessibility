# Audio Manager

FMOD-based audio playback system for the Blind Accessibility mod. Provides controllable audio with volume, pitch, 3D positioning, and looping.

## Installation

**For mod developers integrating this audio system:**

1. Copy these files to your mod folder:
   - `audio.lua`
   - `h2a_audio_manager.exe`
   - `fmod.dll`

2. In your `main.lua`:
   ```lua
   public.audio = require("audio")
   ```

3. Add dependency to `manifest.json`:
   ```json
   "SGG_Modding-ENVY"
   ```

**For end users:** If a mod already integrates this system (like Blind_Accessibility), no setup needed.

**Building from source:**

Requirements:
- Python 3.11+
- [uv](https://docs.astral.sh/uv/) package manager

Build:
```batch
build_audio_manager.bat
```

The script automatically creates a venv, installs dependencies (pyfmodex, pyinstaller), and builds the exe.

## Getting Started

Load and play a simple sound:
```lua
-- Load a 2D sound
public.audio.load("beep", "data/sounds/beep.wav", false)

-- Play it
public.audio.play_simple("beep", 1.0)  -- volume 1.0
```

Load and play a 3D positional sound:
```lua
-- Load a 3D sound
public.audio.load("ambient", "data/sounds/ambient.wav", true)

-- Play at position with looping
public.audio.play("ambient", x, y, z, 0.8, true)  -- x,y,z, volume 0.8, looping
```

## API Reference

### Loading

**`load(source_id, filename, is_3d)`**
- `source_id`: String identifier for this sound
- `filename`: Path to .wav file (relative to mod root)
- `is_3d`: Boolean - true for positional audio, false for UI sounds

### Playback

**`play(source_id, x, y, z, volume, looping)`**
- Full control over position, volume, and looping
- Returns: boolean success

**`play_simple(source_id, volume)`**
- 2D playback at volume level
- Equivalent to `play(source_id, 0, 0, 0, volume, false)`

**`stop(source_id)`**
- Stops playback of a sound

### Control

**`set_pitch(source_id, pitch)`**
- Pitch multiplier: 1.0 = normal, 2.0 = octave up, 0.5 = octave down

**`set_source_volume(source_id, volume)`**
- Set volume of individual sound (0.0 to 1.0)
- Does not affect other sounds

**`set_volume(volume)`**
- Set master volume affecting all sounds (0.0 to 1.0)

**`set_pan(source_id, pan)`**
- Pan 2D sounds: -1.0 = left, 0.0 = center, 1.0 = right
- Only works for 2D sounds (is_3d = false)

**`seek(source_id, position_ms)`**
- Seek to position in milliseconds

**`pause()` / `resume()`**
- Pause/resume all audio playback

**`update()`**
- Manually trigger FMOD update (normally called automatically)

## Debugging

**Log file:** `audio_debug.log` in mod root
- Contains driver enumeration
- Initialization status
- Command processing
- FMOD errors

**Common issues:**

1. **No audio output**
   - Check `audio_debug.log` for FMOD initialization errors
   - Verify correct audio driver in `config.lua` (AudioDriver setting)
   - Run driver test: See log for available drivers (0, 1, 2, etc.)

2. **Crackling/distortion**
   - Try different audio driver via config.lua
   - Check if WASAPI driver is being used (shown in log)

3. **Audio on wrong device**
   - Set `AudioDriver` in config.lua to specific driver number
   - Check log for driver list and names
   - -1 = auto-detect (default)

**Testing commands:**

Test audio playback manually:
```batch
cd src
uv run python manager.py
```

Then send commands:
```
INIT 64 0
LOAD test ../data/sounds/magic.wav false
PLAY test 0 0 0 1.0 false
UPDATE
QUIT
```

## Architecture

```
[Lua] audio.lua
    ↓ io.popen
[Process] h2a_audio_manager.exe
    ↓ stdin commands
[Python] manager.py
    ↓ pyfmodex
[Library] fmod.dll
    ↓ Windows Audio
[Output] Audio device
```

**Command Protocol:**
- Lua sends text commands via stdin
- Python parses and executes via FMOD
- One-way communication (no response needed)
- Commands: INIT, LOAD, PLAY, STOP, PITCH, SETVOL, PAN, SEEK, PAUSE, RESUME, UPDATE, QUIT

## Audio Driver Configuration

Edit `config.lua`:
```lua
AudioDriver = -1  -- Auto-detect (default)
AudioDriver = 0   -- Use specific driver (check audio_debug.log for list)
```

Driver 0 is typically your primary audio device (e.g., headphones).

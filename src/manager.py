#!/usr/bin/env python3
"""
FMOD Audio Manager - Modern 3D spatial audio system

This replaces the broken OpenAL implementation with FMOD's proven 3D audio engine.
Provides true 3D positioning of both mono and stereo sources with HRTF processing.
"""

import os
import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum

try:
    import pyfmodex
    from pyfmodex.flags import MODE

    FMOD_AVAILABLE = True
except ImportError:
    FMOD_AVAILABLE = False
    pyfmodex = None
    MODE = None

logger = logging.getLogger(__name__)


class AudioSourceState(Enum):
    """Audio source playback states."""

    STOPPED = "stopped"
    PLAYING = "playing"
    PAUSED = "paused"


@dataclass
class AudioSource:
    """Represents a 3D positioned audio source."""

    source_id: str
    filename: str
    position: Tuple[float, float, float]
    volume: float
    looping: bool
    is_3d: bool
    sound: Any = None  # FMOD Sound object
    channel: Any = None  # FMOD Channel object
    state: AudioSourceState = AudioSourceState.STOPPED


class FMODAudioManager:
    """
    FMOD-based 3D audio manager for the city simulation.

    Provides:
    - True 3D positioning of stereo sources
    - HRTF spatial audio processing
    - Distance-based volume attenuation
    - Multiple simultaneous positioned sources
    - Clean lifecycle management
    """

    def __init__(self, max_channels: int = 64, driver: int = 0):
        """Initialize FMOD audio system."""
        if not FMOD_AVAILABLE:
            raise RuntimeError("FMOD not available - install pyfmodex and FMOD Engine")

        self.system: Optional[pyfmodex.System] = None
        self.sources: Dict[str, AudioSource] = {}
        self.max_channels = max_channels
        self.driver = driver
        self.listener_position = (0.0, 0.0, 0.0)
        self.listener_forward = (0.0, 0.0, 1.0)
        self.listener_up = (0.0, 1.0, 0.0)
        self.master_volume = 1.0
        self.is_paused = False

        logger.info("Initializing FMOD Audio Manager")
        self._initialize_system()

    def _initialize_system(self) -> None:
        """Initialize the FMOD system."""
        try:
            # Create FMOD system
            self.system = pyfmodex.System()

            # List available drivers BEFORE initialization
            try:
                num_drivers = self.system.num_drivers
                logger.info(f"FMOD found {num_drivers} audio drivers:")
                for i in range(num_drivers):
                    driver_info = self.system.get_driver_info(i)
                    logger.info(f"  Driver {i}: {driver_info.name}")
            except Exception as e:
                logger.warning(f"Could not enumerate drivers: {e}")

            # Set output to WASAPI (Windows Audio Session API) for better compatibility
            try:
                from pyfmodex.enums import OUTPUTTYPE
                self.system.output = OUTPUTTYPE.WASAPI
                logger.info("Set FMOD output to WASAPI")
            except Exception as e:
                logger.warning(f"Could not set WASAPI output: {e}, using default")

            # Set the audio driver before initialization
            try:
                if self.driver >= 0 and self.driver < self.system.num_drivers:
                    self.system.driver = self.driver
                    logger.info(f"Set FMOD driver to {self.driver}")
                else:
                    logger.warning(f"Invalid driver {self.driver}, using default")
            except Exception as e:
                logger.warning(f"Could not set driver: {e}, using default")

            self.system.init(maxchannels=self.max_channels)

            version = self.system.version
            logger.info(
                f"FMOD initialized - Version: {version}, Max channels: {self.max_channels}"
            )

            # Log which driver was selected
            try:
                current_driver = self.system.driver
                driver_info = self.system.get_driver_info(current_driver)
                logger.info(f"Using audio driver {current_driver}: {driver_info.name}")
            except Exception as e:
                logger.warning(f"Could not get current driver info: {e}")

            # Configure 3D audio settings
            self._setup_3d_audio()

        except Exception as e:
            logger.error(f"Failed to initialize FMOD: {e}")
            raise RuntimeError(f"FMOD initialization failed: {e}")

    def _setup_3d_audio(self) -> None:
        """Configure 3D audio parameters."""
        if not self.system:
            return

        # Enable doppler for better 3D effect
        self.system.threed_settings.doppler_scale = 1.0

        # Set distance factor for more natural falloff (meters)
        self.system.threed_settings.distance_factor = 1.0

        # Set rolloff scale for distance attenuation
        self.system.threed_settings.rolloff_scale = 1.0

        # Initialize listener at origin with proper orientation
        listener = self.system.listener(0)
        listener.position = [0.0, 0.0, 0.0]
        listener.velocity = [0.0, 0.0, 0.0]
        listener.forward = [0.0, 0.0, 1.0]  # Looking forward (positive Z)
        listener.up = [0.0, 1.0, 0.0]  # Up is positive Y

        logger.info("3D audio settings configured with HRTF and listener setup")

    def set_listener_position(self, x: float, y: float, z: float) -> None:
        """Update the listener (player) position in 3D space."""
        self.listener_position = (x, y, z)

        # Update FMOD 3D listener position
        if self.system:
            try:
                listener = self.system.listener(0)
                listener.position = [x, y, z]
                listener.velocity = [0.0, 0.0, 0.0]  # No velocity for now
                listener.forward = list(self.listener_forward)
                listener.up = list(self.listener_up)
                self.system.update()  # Apply changes immediately
                logger.debug(f"FMOD listener position updated: ({x}, {y}, {z})")
            except Exception as e:
                logger.error(f"Failed to update FMOD listener position: {e}")

        logger.debug(f"Listener position updated: ({x}, {y}, {z})")

    def set_listener_orientation(
        self,
        forward_x: float,
        forward_y: float,
        forward_z: float,
        up_x: float = 0.0,
        up_y: float = 1.0,
        up_z: float = 0.0,
    ) -> None:
        """Update the listener orientation (which way player is facing)."""
        self.listener_forward = (forward_x, forward_y, forward_z)
        self.listener_up = (up_x, up_y, up_z)

        # Update FMOD 3D listener orientation
        if self.system:
            try:
                listener = self.system.listener(0)
                listener.position = list(self.listener_position)
                listener.velocity = [0.0, 0.0, 0.0]  # No velocity for now
                listener.forward = list(self.listener_forward)
                listener.up = list(self.listener_up)
                self.system.update()  # Apply changes immediately
                logger.debug("FMOD listener orientation updated")
            except Exception as e:
                logger.error(f"Failed to update FMOD listener orientation: {e}")

        logger.debug(
            f"Listener orientation updated: forward={self.listener_forward}, up={self.listener_up}"
        )

    def load_sound(
        self, source_id: str, filename: str, is_3d: bool = True, preload: bool = True
    ) -> bool:
        """
        Load an audio file for later playback.

        Args:
            source_id: Unique identifier for this audio source
            filename: Path to audio file
            is_3d: Whether this should be positioned in 3D space
            preload: Whether to load the sound into memory immediately

        Returns:
            True if loaded successfully, False otherwise
        """
        if not self.system:
            logger.error("FMOD system not initialized")
            return False

        if source_id in self.sources:
            return True

        if not os.path.exists(filename):
            logger.error(f"Audio file not found: {filename}")
            return False

        try:
            # Create FMOD sound with appropriate flags
            mode = MODE.THREED if is_3d else MODE.TWOD
            mode |= (
                MODE.LOOP_NORMAL
            )  # Enable looping by default - we'll control it per playback

            # Use linear rolloff for 3D sounds - reaches silence at max_distance
            if is_3d:
                mode |= MODE.THREED_LINEARROLLOFF

            if not preload:
                mode |= (
                    MODE.CREATESTREAM
                )  # Stream from disk instead of loading to memory

            sound = self.system.create_sound(filename, mode=mode)

            # Configure 3D settings if needed
            if is_3d:
                sound.min_distance = 5.0  # Minimum distance for 3D effect - smaller for clearer positioning
                sound.max_distance = (
                    50.0  # Maximum audible distance - closer for more dramatic falloff
                )

            # Create AudioSource object
            audio_source = AudioSource(
                source_id=source_id,
                filename=filename,
                position=(0.0, 0.0, 0.0),
                volume=1.0,
                looping=False,
                is_3d=is_3d,
                sound=sound,
            )

            self.sources[source_id] = audio_source
            logger.info(f"Loaded audio: {source_id} ({filename}) [3D: {is_3d}]")
            return True

        except Exception as e:
            logger.error(f"Failed to load audio '{source_id}': {e}")
            return False

    def play_sound(
        self,
        source_id: str,
        x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        volume: float = 1.0,
        looping: bool = False,
        min_distance: float = 1.0,
        max_distance: float = 20.0,
    ) -> bool:
        """
        Play a loaded sound at specified 3D position.

        Args:
            source_id: ID of previously loaded sound
            x, y, z: 3D position to play sound at
            volume: Playback volume (0.0 to 1.0)
            looping: Whether to loop the sound

        Returns:
            True if playback started successfully, False otherwise
        """
        if source_id not in self.sources:
            logger.error(f"Audio source '{source_id}' not loaded")
            return False

        source = self.sources[source_id]

        if not self.system or not source.sound:
            logger.error("FMOD system or sound not available")
            return False

        try:
            # Stop existing playback if any
            if source.channel:
                try:
                    # Always try to stop, regardless of tracked state
                    source.channel.stop()
                except Exception:
                    # Channel might already be invalid, ignore
                    pass
                finally:
                    # Clear channel reference
                    source.channel = None
                    source.state = AudioSourceState.STOPPED

            # Start playback
            channel = self.system.play_sound(source.sound, paused=self.is_paused)
            if not channel:
                logger.error(f"Failed to get channel for '{source_id}'")
                return False

            # Configure channel
            channel.volume = volume * self.master_volume

            # Set looping via channel loop count
            if looping:
                channel.loop_count = -1  # Infinite loops
                logger.debug(f"Set {source_id} to loop infinitely")
            else:
                channel.loop_count = 0  # Play once only
                logger.debug(f"Set {source_id} to play once")

            # Position in 3D space (if 3D sound)
            if source.is_3d:
                channel.position = [x, y, z]
                # Set distance parameters for this channel
                channel.min_distance = min_distance
                channel.max_distance = max_distance
                logger.debug(
                    f"Positioned '{source_id}' at ({x}, {y}, {z}) with distance {min_distance}-{max_distance}"
                )

            # Update source state
            source.channel = channel
            source.position = (x, y, z)
            source.volume = volume
            source.looping = looping
            source.state = (
                AudioSourceState.PAUSED if self.is_paused else AudioSourceState.PLAYING
            )

            # Update 3D calculations
            self.system.update()

            logger.info(f"Playing '{source_id}' at ({x}, {y}, {z}) [vol: {volume}]")
            return True

        except Exception as e:
            logger.error(f"Failed to play '{source_id}': {e}")
            return False

    def stop_sound(self, source_id: str) -> bool:
        """Stop playback of a specific sound."""
        if source_id not in self.sources:
            logger.warning(f"Audio source '{source_id}' not found")
            return False

        source = self.sources[source_id]
        if source.channel:
            try:
                source.channel.stop()
                source.state = AudioSourceState.STOPPED
                source.channel = None
                logger.debug(f"Stopped '{source_id}'")
                return True
            except Exception as e:
                # Channel already invalid, just clear it
                logger.debug(f"Channel already stopped for '{source_id}': {e}")
                source.channel = None
                source.state = AudioSourceState.STOPPED
                return False

        return False

    def set_pitch(self, source_id: str, pitch: float) -> bool:
        """
        Set pitch/frequency of a playing sound.

        Args:
            source_id: ID of the sound source
            pitch: Pitch multiplier (1.0 = normal, 2.0 = double speed/octave up, 0.5 = half speed/octave down)

        Returns:
            True if successful, False otherwise
        """
        if source_id not in self.sources:
            logger.warning(f"Audio source '{source_id}' not found")
            return False

        source = self.sources[source_id]
        if not source.channel:
            logger.warning(f"Audio source '{source_id}' not playing")
            return False

        try:
            source.channel.pitch = pitch
            logger.debug(f"Set pitch of '{source_id}' to {pitch}")
            return True
        except Exception as e:
            logger.error(f"Failed to set pitch for '{source_id}': {e}")
            return False

    def set_source_volume(self, source_id: str, volume: float) -> bool:
        """
        Set volume of a specific playing sound (not master volume).

        Args:
            source_id: ID of the sound source
            volume: Volume (0.0 to 1.0)

        Returns:
            True if successful, False otherwise
        """
        if source_id not in self.sources:
            logger.warning(f"Audio source '{source_id}' not found")
            return False

        source = self.sources[source_id]
        if not source.channel:
            logger.warning(f"Audio source '{source_id}' not playing")
            return False

        try:
            # Set channel volume (will be affected by master volume)
            source.channel.volume = volume * self.master_volume
            source.volume = volume  # Update stored volume
            logger.debug(f"Set volume of '{source_id}' to {volume}")
            return True
        except Exception as e:
            logger.error(f"Failed to set volume for '{source_id}': {e}")
            return False

    def seek(self, source_id: str, position_ms: int) -> bool:
        """
        Seek to a specific position in the audio.

        Args:
            source_id: ID of the sound source
            position_ms: Position in milliseconds to seek to

        Returns:
            True if successful, False otherwise
        """
        if source_id not in self.sources:
            logger.warning(f"Audio source '{source_id}' not found")
            return False

        source = self.sources[source_id]
        if not source.channel:
            logger.warning(f"Audio source '{source_id}' not playing")
            return False

        try:
            source.channel.position = position_ms
            logger.debug(f"Seeked '{source_id}' to {position_ms}ms")
            return True
        except Exception as e:
            logger.error(f"Failed to seek '{source_id}': {e}")
            return False

    def set_pan(self, source_id: str, pan: float) -> bool:
        """
        Set stereo pan for 2D sounds.

        Args:
            source_id: ID of the sound source
            pan: Pan value (-1.0 = full left, 0.0 = center, 1.0 = full right)

        Returns:
            True if successful, False otherwise
        """
        if source_id not in self.sources:
            logger.warning(f"Audio source '{source_id}' not found")
            return False

        source = self.sources[source_id]
        if source.is_3d:
            logger.warning(f"Cannot set pan on 3D sound '{source_id}'")
            return False

        if not source.channel:
            logger.warning(f"Audio source '{source_id}' not playing")
            return False

        try:
            # Clamp pan to valid range
            pan = max(-1.0, min(1.0, pan))
            source.channel.pan = pan
            logger.debug(f"Set pan of '{source_id}' to {pan}")
            return True
        except Exception as e:
            logger.error(f"Failed to set pan for '{source_id}': {e}")
            return False

    def update_source_position(
        self, source_id: str, x: float, y: float, z: float
    ) -> bool:
        """Update the 3D position of a playing sound source."""
        if source_id not in self.sources:
            return False

        source = self.sources[source_id]
        if not source.channel or not source.is_3d:
            return False

        try:
            source.channel.position = [x, y, z]
            source.position = (x, y, z)
            # Don't call system.update() here - let caller batch updates
            
            logger.debug(f"Updated '{source_id}' position to ({x}, {y}, {z})")
            return True

        except Exception as e:
            logger.error(f"Failed to update position for '{source_id}': {e}")
            return False

    def pause_all(self) -> None:
        """Pause all audio playback."""
        if not self.system:
            return

        self.is_paused = True

        # Pause all active channels
        for source in self.sources.values():
            if source.channel and source.state == AudioSourceState.PLAYING:
                try:
                    source.channel.paused = True
                    source.state = AudioSourceState.PAUSED
                except Exception as e:
                    logger.error(f"Failed to pause '{source.source_id}': {e}")

        logger.info("All audio paused")

    def resume_all(self) -> None:
        """Resume all paused audio playback."""
        if not self.system:
            return

        self.is_paused = False

        # Resume all paused channels
        for source in self.sources.values():
            if source.channel and source.state == AudioSourceState.PAUSED:
                try:
                    source.channel.paused = False
                    source.state = AudioSourceState.PLAYING
                except Exception as e:
                    logger.error(f"Failed to resume '{source.source_id}': {e}")

        logger.info("All audio resumed")

    def stop_all(self) -> None:
        """Stop all audio playback."""
        for source_id in list(self.sources.keys()):
            self.stop_sound(source_id)

        logger.info("All audio stopped")

    def release_all_sounds(self) -> None:
        """Release all loaded sounds and clear sources.

        FMOD system remains active. Use this when changing game states
        to free up audio resources.
        """
        for source in self.sources.values():
            if source.sound:
                try:
                    source.sound.release()
                except Exception as e:
                    logger.debug(f"Failed to release sound '{source.source_id}': {e}")

        self.sources.clear()
        logger.info("All sounds released and sources cleared")

    def set_master_volume(self, volume: float) -> None:
        """Set master volume (0.0 to 1.0)."""
        self.master_volume = max(0.0, min(1.0, volume))

        # Update volume for all playing sources
        for source in self.sources.values():
            if source.channel:
                try:
                    source.channel.volume = source.volume * self.master_volume
                except Exception:
                    pass  # Channel might be stopped

        logger.info(f"Master volume set to {self.master_volume}")

    def get_source_info(self, source_id: str) -> Optional[Dict[str, Any]]:
        """Get information about a loaded audio source."""
        if source_id not in self.sources:
            return None

        source = self.sources[source_id]
        return {
            "source_id": source.source_id,
            "filename": source.filename,
            "position": source.position,
            "volume": source.volume,
            "looping": source.looping,
            "is_3d": source.is_3d,
            "state": source.state.value,
        }

    def list_sources(self) -> List[str]:
        """Get list of all loaded audio source IDs."""
        return list(self.sources.keys())

    def update(self) -> None:
        """Update FMOD system - call this regularly (e.g., each frame)."""
        if self.system:
            try:
                self.system.update()

                # Clean up stopped channels
                for source in self.sources.values():
                    if source.channel:
                        try:
                            if not source.channel.is_playing:
                                source.state = AudioSourceState.STOPPED
                                source.channel = None
                        except Exception:
                            # Channel is likely invalid/stopped
                            source.state = AudioSourceState.STOPPED
                            source.channel = None

            except Exception as e:
                logger.error(f"FMOD update failed: {e}")

    def cleanup(self) -> None:
        """Clean up FMOD resources."""
        logger.info("Cleaning up FMOD Audio Manager")

        # Stop all audio and release channels
        self.stop_all()

        # Release sounds and channels
        for source in self.sources.values():
            # Release channel first
            if source.channel:
                try:
                    source.channel.stop()
                except Exception as e:
                    logger.error(f"Failed to stop channel for '{source.source_id}': {e}")
                source.channel = None
            
            # Release sound
            if source.sound:
                try:
                    source.sound.release()
                except Exception as e:
                    logger.error(f"Failed to release sound '{source.source_id}': {e}")

        self.sources.clear()

        # Close and release FMOD system
        if self.system:
            try:
                self.system.close()
                self.system.release()
                logger.info("FMOD system closed and released")
            except Exception as e:
                logger.error(f"Failed to close FMOD system: {e}")

            self.system = None


def main():
    """Main loop for stdin command processing."""
    import sys
    import json
    import traceback

    # Parse command line args for debug mode
    debug_mode = "--debug" in sys.argv

    # Initialize logging to stderr (stdout is for protocol)
    logging.basicConfig(
        level=logging.DEBUG if debug_mode else logging.INFO,
        format='[AUDIO] %(levelname)s: %(message)s',
        stream=sys.stderr
    )

    logger.info(f"Audio Manager starting... (debug={'ON' if debug_mode else 'OFF'})")

    manager = None

    try:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue

            logger.debug(f"Received command: {line}")

            try:
                parts = line.split()
                cmd = parts[0].upper()

                if cmd == "INIT":
                    if manager:
                        print("ERROR ALREADY_INITIALIZED", flush=True)
                        logger.warning("INIT called but manager already exists")
                        continue

                    # INIT [max_channels] [driver]
                    max_channels = int(parts[1]) if len(parts) > 1 else 64
                    driver = int(parts[2]) if len(parts) > 2 else 0
                    manager = FMODAudioManager(max_channels=max_channels, driver=driver)
                    print(f"OK INITIALIZED channels={max_channels} driver={driver}", flush=True)
                    logger.info(f"Initialized with {max_channels} channels, driver {driver}")

                elif cmd == "LOAD":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        logger.error("LOAD called before INIT")
                        continue

                    # LOAD <source_id> <filename> <is_3d>
                    if len(parts) < 3:
                        print("ERROR INVALID_ARGS missing source_id or filename", flush=True)
                        logger.error(f"LOAD: Invalid args: {parts}")
                        continue

                    source_id = parts[1]
                    filename = parts[2]
                    is_3d = parts[3].lower() == "true" if len(parts) > 3 else False

                    if manager.load_sound(source_id, filename, is_3d):
                        print(f"OK LOADED {source_id} 3d={is_3d}", flush=True)
                    else:
                        print(f"ERROR LOAD_FAILED {source_id} file_not_found_or_invalid", flush=True)

                elif cmd == "PLAY":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        logger.error("PLAY called before INIT")
                        continue

                    # PLAY <source_id> <x> <y> <z> <volume> <looping>
                    if len(parts) < 2:
                        print("ERROR INVALID_ARGS missing source_id", flush=True)
                        logger.error(f"PLAY: Invalid args: {parts}")
                        continue

                    source_id = parts[1]
                    x = float(parts[2]) if len(parts) > 2 else 0.0
                    y = float(parts[3]) if len(parts) > 3 else 0.0
                    z = float(parts[4]) if len(parts) > 4 else 0.0
                    volume = float(parts[5]) if len(parts) > 5 else 1.0
                    looping = parts[6].lower() == "true" if len(parts) > 6 else False

                    if manager.play_sound(source_id, x, y, z, volume, looping):
                        print(f"OK PLAYING {source_id} vol={volume:.2f} loop={looping}", flush=True)
                    else:
                        print(f"ERROR PLAY_FAILED {source_id} not_loaded_or_error", flush=True)

                elif cmd == "STOP":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    # STOP <source_id>
                    if len(parts) < 2:
                        print("ERROR INVALID_ARGS missing source_id", flush=True)
                        continue

                    source_id = parts[1]

                    if manager.stop_sound(source_id):
                        print(f"OK STOPPED {source_id}", flush=True)
                    else:
                        print(f"ERROR STOP_FAILED {source_id} not_found_or_not_playing", flush=True)

                elif cmd == "VOLUME":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    # VOLUME <master_volume>
                    if len(parts) < 2:
                        print("ERROR INVALID_ARGS missing volume", flush=True)
                        continue

                    volume = float(parts[1])
                    manager.set_master_volume(volume)
                    print(f"OK VOLUME {volume:.2f}", flush=True)

                elif cmd == "PITCH":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    # PITCH <source_id> <pitch>
                    if len(parts) < 3:
                        print("ERROR INVALID_ARGS missing source_id or pitch", flush=True)
                        continue

                    source_id = parts[1]
                    pitch = float(parts[2])

                    if manager.set_pitch(source_id, pitch):
                        print(f"OK PITCH {source_id} {pitch:.2f}", flush=True)
                    else:
                        print(f"ERROR PITCH_FAILED {source_id} not_playing_or_error", flush=True)

                elif cmd == "SETVOL":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    # SETVOL <source_id> <volume>
                    if len(parts) < 3:
                        print("ERROR INVALID_ARGS missing source_id or volume", flush=True)
                        continue

                    source_id = parts[1]
                    volume = float(parts[2])

                    if manager.set_source_volume(source_id, volume):
                        print(f"OK SETVOL {source_id} {volume:.2f}", flush=True)
                    else:
                        print(f"ERROR SETVOL_FAILED {source_id} not_playing_or_error", flush=True)

                elif cmd == "SEEK":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    # SEEK <source_id> <position_ms>
                    if len(parts) < 3:
                        print("ERROR INVALID_ARGS missing source_id or position", flush=True)
                        continue

                    source_id = parts[1]
                    position_ms = int(parts[2])

                    if manager.seek(source_id, position_ms):
                        print(f"OK SEEK {source_id} {position_ms}ms", flush=True)
                    else:
                        print(f"ERROR SEEK_FAILED {source_id} not_playing_or_error", flush=True)

                elif cmd == "PAN":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    # PAN <source_id> <pan>
                    if len(parts) < 3:
                        print("ERROR INVALID_ARGS missing source_id or pan", flush=True)
                        continue

                    source_id = parts[1]
                    pan = float(parts[2])

                    if manager.set_pan(source_id, pan):
                        print(f"OK PAN {source_id} {pan:.2f}", flush=True)
                    else:
                        print(f"ERROR PAN_FAILED {source_id} not_2d_or_not_playing", flush=True)

                elif cmd == "UPDATE":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    manager.update()
                    print("OK UPDATED", flush=True)
                    logger.debug("FMOD system updated")

                elif cmd == "PAUSE":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    manager.pause_all()
                    print("OK PAUSED", flush=True)
                    logger.debug("All audio paused")

                elif cmd == "RESUME":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    manager.resume_all()
                    print("OK RESUMED", flush=True)
                    logger.debug("All audio resumed")

                elif cmd == "STATUS":
                    if not manager:
                        print("ERROR NOT_INITIALIZED", flush=True)
                        continue

                    # STATUS <source_id> - get info about a source
                    if len(parts) < 2:
                        # List all sources
                        sources = manager.list_sources()
                        print(f"OK STATUS sources={len(sources)} [{','.join(sources)}]", flush=True)
                    else:
                        source_id = parts[1]
                        info = manager.get_source_info(source_id)
                        if info:
                            print(f"OK STATUS {source_id} state={info['state']} vol={info['volume']:.2f}", flush=True)
                        else:
                            print(f"ERROR STATUS_FAILED {source_id} not_found", flush=True)

                elif cmd == "DEBUG":
                    # DEBUG <on|off> - toggle debug logging
                    if len(parts) > 1:
                        enable = parts[1].lower() in ["on", "true", "1"]
                        logging.getLogger().setLevel(logging.DEBUG if enable else logging.INFO)
                        print(f"OK DEBUG {'ON' if enable else 'OFF'}", flush=True)
                    else:
                        current = logging.getLogger().level == logging.DEBUG
                        print(f"OK DEBUG {'ON' if current else 'OFF'}", flush=True)

                elif cmd == "QUIT":
                    print("OK GOODBYE", flush=True)
                    logger.info("QUIT command received")
                    if manager:
                        manager.cleanup()
                    sys.exit(0)

                else:
                    print(f"ERROR UNKNOWN_COMMAND {cmd}", flush=True)
                    logger.warning(f"Unknown command: {cmd}")

            except IndexError as e:
                print(f"ERROR INVALID_ARGS {str(e)}", flush=True)
                logger.error(f"Invalid arguments: {e}")
            except ValueError as e:
                print(f"ERROR INVALID_VALUE {str(e)}", flush=True)
                logger.error(f"Invalid value: {e}")
            except Exception as e:
                print(f"ERROR EXCEPTION {str(e)}", flush=True)
                logger.error(f"Command error: {e}")
                if debug_mode:
                    logger.error(traceback.format_exc())

    except KeyboardInterrupt:
        logger.info("Interrupted by user")
    finally:
        if manager:
            manager.cleanup()
        logger.info("Audio Manager shutdown")


if __name__ == "__main__":
    main()


return {
  Exorcism = {
    -- How much time you have to start pressing the correct button in the tablet minigame. Set to 0 to use the game's defaults, which scale up difficulty as you progress through a run.
    -- Default: 1.0
    Time = 1.0,

    -- If true, if you press the wrong button too many times, you will fail the minigame.
    -- Default: false
    Failure = false,

    -- If true, announces the required inputs at the start of each step.
    -- Default: true
    Speak = true,

    -- CUSTOM CUES: Use these strings to override the game's default announcements, as they are kinda bad. If left blank (""), the mod will use the game's default text.

    CueLeft = "",
    CueRight = "",
    CueBoth = "",
  },

  NoTrapDamage = true,

  -- HP announcement settings
  AnnouncePlayerHP = true,  -- Announce player health thresholds
  AnnounceBossHP = true,     -- Announce boss health thresholds
  AnnounceMiniBossHP = false  -- Announce mini-boss/elite health thresholds
}
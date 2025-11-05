# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2025-11-05

### Added

- HP announcement system for player health thresholds (10%, 20%, 30%, etc.) via TOLK screen reader
- Boss HP announcement system for tracking boss health thresholds
- Mini-boss HP announcement system for tracking mini-boss/elite health thresholds
- Configuration options for HP announcements (AnnouncePlayerHP, AnnounceBossHP, AnnounceMiniBossHP)
- NoTrapDamage configuration option to disable trap damage
- Ghost Admin (Cauldron) screen integration with cost information read by TOLK
- Market screen integration with better TOLK support
- Surface shop menu integration with TOLK
- Keepsake menu enhanced information for TOLK
- Store and spell button menus with better TOLK integration
- Talent screen override for better accessibility
- Hecate Hide and Seek mini-game accessibility improvements
- Ship's Steering Wheel (Flashback navigation) door menu integration
- VoR Typhon fight and Asphodel anomaly capture point radius set to 9999 for full map coverage

### Changed

- Namespace changed from `erumi321` to `Lirin`
- Website URL updated to `https://github.com/Lirin111/Hades2BlindAccessibility`
- Updated dependency versions for compatibility with latest modding framework
- Exorcism mini-game timing now uses configurable multiplier (default 1.0)
- Exorcism failure mode is now configurable (default: false)
- Removed HP threshold sound effects to prevent FMOD crashes during boss fights

### Fixed

- Ghost Admin screen item reveal presentation now has comprehensive safety checks
- Boss health tracking cleanup when enemies are defeated
- Mini-boss detection now properly distinguishes between elite enemies and actual mini-bosses (1000+ MaxHealth threshold)
- Fresh install compatibility issues resolved

## [0.4.2] - 2024-11-07

### Fixed

- Inventory bug

## [0.4.1] - 2024-11-04

### Changed

- Exorcism timing now uses default region duration after input instead of hardcoded value (0.4)

### Fixed

- Death bug
- Fresh install now works correctly (no longer checks for config.enabled)

## [0.4.0] - 2024-10-26

### Added

- Flashbacks now allow navigation in the same way that the crossroads does (B / D-Pad Left)
- The exorcism mini-game now optionally speaks and has an adjustable allowed time multiplier (see config)

## [0.3.2] - 2024-10-18

### Fixed

- Fixed issues corresponding to Early Access Patch 5 (Olympic Update)

## [0.3.1] - 2024-10-14

### Added

- Keepsake menu reports more information when read by TOLK
- Well of Charon menu reports more information when read by TOLK
- Selene menu reports more information when read by TOLK
- Path of Stars menu reports more information when read by TOLK

## [0.3.0] - 2024-07-11

### Added

- Cauldron menu now reports more information when read by TOLK
- Broker menu now reports more information when read by TOLK
- Changed inventory to act more like vanilla game, gift menu and planting menu now report more information when read by TOLK as a side product
- Shrine of Hermes now reports more information when read by TOLK

## [0.2.0] - 2024-06-12

### Added

- Dependency to TOLK mod to automatically install it
- Interactable teleporter (Trait Tray -> Codex) now shows Hermes Shrines on the Surface

### Fixed

- Door menus in each area now work correctly
- Gatherable resources now appear in correct menu when in a shop
- Bug when grasp is fully upgraded is fixed

## [0.1.5] - 2024-05-27

### Fixed

- Make menu buttons read text through TOLK more consistently

## [0.1.4] - 2024-05-27

### Fixed

- Inventory menu bug preventing it from opening

## [0.1.3] - 2024-05-27

### Added

- Buttons to read Health Gold and Armor within door / reward teleporter menu

### Fixed

- Bug where sometimes door buttons would not be read by TOLK

## [0.1.2] - 2024-05-27

### Fixed

- All code to work for Thunderstore and r2m format

## [0.1.1] - 2024-05-24

### Added

- Hub area teleport menu (B/D-pad Left)
- Door teleport menu (B/D-pad Left -> I/D-pad Right)
- Reward / Harvest Point / Shop teleport menu (B/D-pad Left -> C/D-pad Up)
- Inventory Simplifier (I/D-pad Right -> I/D-pad Right)
- Arcana Menu integration with TOLK screen reader
- Final Boss instant kill move -> 50 damage

[unreleased]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/1.0.0...HEAD
[1.0.0]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.4.2...1.0.0
[0.4.2]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.4.1...0.4.2
[0.4.1]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.4.0...0.4.1
[0.4.0]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.3.2...0.4.0
[0.3.2]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.3.1...0.3.2
[0.3.1]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.3.0...0.3.1
[0.3.0]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.1.5...0.2.0
[0.1.5]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.1.4...0.1.5
[0.1.4]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.1.3...0.1.4
[0.1.3]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.1.2...0.1.3
[0.1.2]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/Lirin111/Hades2BlindAccessibility/compare/9fda26758c61c5dcb971b5c0f3e34c89c09ef8a1...0.1.1


Quick Start — After Reset
1) Copy entire APREP_<date> folder back to C:\ or any drive.
2) Run Scripts\restore_drivers.cmd as Administrator → reboot if asked.
3) Run Scripts\restore_apps.cmd (winget import). If winget fails, use Manifests\installed_apps_fallback.csv manually.
4) Restore Telegram: copy Data\Telegram\*_tdata → %APPDATA%\Telegram Desktop\tdata (after installing Telegram, while it’s closed).
5) Restore user files from Data\UserProfiles\<you>.
6) If needed, send AP-LOGS-<date>.zip to external system.

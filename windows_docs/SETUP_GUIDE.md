# ByteWave School Automation — Windows Setup Guide

## Quick Start

1. Extract the ZIP to `C:\ByteWave\`
2. Run `ByteWave School Automation.exe`
3. First launch creates the database and seeds Ailyans data
4. Log in with your admin account (created in the wizard on first run)

## Data Location

- **Database:** `C:\Users\<You>\Documents\ByteWave\school_default.db`
- **Backups:** `C:\Users\<You>\Documents\ByteWave\backups\`

Do NOT delete this folder. Do NOT copy the `.db` file manually while the app is running.

## Cloud Sync

- App syncs automatically every 2–10 seconds
- Bottom status bar shows `Online - Synced` when connected
- Click `Sync Now` to force an immediate sync
- App works offline; changes sync when reconnected

## License Activation

- **Ailyans:** No license key required (auto-activates)
- **SaaS:** Enter your license key on the login screen → app pulls cloud data → log in

## Troubleshooting

| Issue | Fix |
|---|---|
| "Windows protected your PC" | Click More info → Run anyway (unsigned build — expected) |
| App does not open | Extract to a local folder, not OneDrive. Run as Administrator. Check antivirus. |
| Data not syncing | Check bottom bar says Online - Synced. Click Sync Now. Check internet. |
| Lost admin password | Email atbytewave@gmail.com. Do NOT reinstall. |

## Support

- Email: atbytewave@gmail.com
- LinkedIn: www.linkedin.com/company/bytewaves

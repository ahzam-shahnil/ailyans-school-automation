==========================================================
  ByteWave School Automation
  Windows Installation Guide
==========================================================

Thank you for using ByteWave School Automation.

This package contains everything you need to run the app
on your Windows computer. No installation is required —
just extract and run.

----------------------------------------------------------
  STEP 1: EXTRACT THE ZIP
----------------------------------------------------------

1. Right-click "ailyans-school-manager-windows.zip"
2. Select "Extract All..."
3. Choose a folder (recommended: C:\ByteWave\)
4. Click "Extract"

Note: Do NOT run the .exe from inside the ZIP file.
You must extract it first.

----------------------------------------------------------
  STEP 2: RUN THE APP
----------------------------------------------------------

1. Open the extracted folder
2. Double-click "ByteWave School Automation.exe"
3. First launch will:
   - Create the local database (SDBSchool.db)
   - Seed 673 students, teachers, fee structure
   - Connect to the cloud sync server
   - Show the login screen

Default data path:
  C:\Users\<YourName>\Documents\ByteWave\

Do NOT move or delete this folder while the app is
running — it holds the live database and backups.

----------------------------------------------------------
  STEP 3: LOG IN
----------------------------------------------------------

Default admin:
  Username: admin
  Password: <set during setup, ask your IT coordinator>

If this is the first time you are running the app,
the setup wizard will ask you to create an admin
account. Fill in:
  - School Name
  - Admin Name
  - Contact Number
  - Admin Username
  - Admin Password
  - Admin PIN (4 digits, used for staff approval)

----------------------------------------------------------
  STEP 4: ACTIVATE YOUR LICENSE (SaaS only)
----------------------------------------------------------

If you are an Ailyans school, no license key is needed.
The app auto-activates on first launch.

For other schools (ByteWave SaaS):
  1. On the login screen, tap "Activate License"
  2. Enter your license key
  3. The app will pull all your cloud data
     (users, classes, fee structure, students)
  4. Log in normally after activation

Your license key was sent to your school email.
If you do not have it, contact:
  atbytewave@gmail.com
  www.linkedin.com/company/bytewaves

----------------------------------------------------------
  STEP 5: DAILY USE
----------------------------------------------------------

The app connects to the cloud every 2-10 seconds and
syncs changes automatically. You do not need to click
any "sync" button during normal use.

If you are offline, the app continues working locally.
Changes sync when you reconnect.

----------------------------------------------------------
  TROUBLESHOOTING
----------------------------------------------------------

Windows shows "Windows protected your PC" on first run:
  -> Click "More info" -> "Run anyway"
  (The app is unsigned. This warning is expected.
   Signed version available on request.)

App does not open:
  -> Check that you extracted the ZIP to a folder
     (not a OneDrive or network drive)
  -> Try running as Administrator
  -> Check antivirus does not block the .exe

Data does not sync:
  -> Check the bottom status bar shows "Online - Synced"
  -> Click "Sync Now" in the bottom bar to force
  -> Check your internet connection

Lost admin password:
  -> Contact atbytewave@gmail.com
  -> Do not reinstall — this will overwrite your data

----------------------------------------------------------
  BACKUPS
----------------------------------------------------------

The app keeps automatic backups in:
  C:\Users\<YourName>\Documents\ByteWave\backups\

To restore a backup:
  -> Contact ByteWave support (do not manually copy
     the .db file — the app must be closed first)

----------------------------------------------------------
  SUPPORT
----------------------------------------------------------

ByteWave
Email: atbytewave@gmail.com
LinkedIn: www.linkedin.com/company/bytewaves

When reporting an issue, include:
  - What you were doing
  - The exact error message
  - A screenshot if possible
  - Your Windows version (Settings -> About)

==========================================================
  ByteWave School Automation v2.0
  © 2023-2026 ByteWave
==========================================================

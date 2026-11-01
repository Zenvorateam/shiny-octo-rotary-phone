from pathlib import Path
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text()
if 'android.permission.INTERNET' not in s:
    s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET"/>')
p.write_text(s)

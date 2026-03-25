# Same PORT as Skillmatch web backend/.env (default 5000)
Set-Location $PSScriptRoot\..
flutter run --dart-define=API_PORT=5000 @args

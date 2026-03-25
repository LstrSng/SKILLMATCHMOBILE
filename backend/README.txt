404 on /api/users/register from the phone or from PowerShell?
----------------------------------------------------------------
1) On your PC, test the same URL the app uses:
   Invoke-WebRequest -Uri "http://127.0.0.1:5000/api/users/register" -Method POST -Body "{}" -ContentType "application/json"
   If this returns 404, the problem is your Skillmatch backend (not Flutter).

2) In Skillmatch, open backend/routes/server.js (or wherever app.listen runs).
   You must have BOTH:
     import authRoutes from "./auth.js";   (path may vary)
     app.use("/api/users", authRoutes);
   Restart Node after saving.

3) Only one process should use port 5000. If Skillmatch is wrong, stop it and run THIS folder instead:
     cd SKILLMATCHMOBILE\backend
     npm start
   This server.js includes POST /api/users/register for local testing.

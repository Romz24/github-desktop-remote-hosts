@echo off
rem Apply the GitLab/remote-hosts mod to GitHub Desktop (again after every update). Close GitHub Desktop first.
rem Pass -Restore to undo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch.ps1" %*
pause

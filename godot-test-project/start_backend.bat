@echo off
cd /d C:\Users\aaron\Desktop\014_nvidiaclaw\ssh-ai-bridge
python -m uvicorn main:app --host 127.0.0.1 --port 8000

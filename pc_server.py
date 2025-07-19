import asyncio, websockets, pyautogui, json

HOST = "0.0.0.0"
PORT = 8080

KEYS = {"next": "right", "prev": "left", "play": "f5"}

async def handler(websocket):
    async for raw in websocket:
        cmd = raw.strip().lower()
        if cmd in KEYS:
            pyautogui.press(KEYS[cmd])
            print(f"[CMD] {cmd}")

async def main():
    async with websockets.serve(handler, HOST, PORT):
        print(f"→ Listening on ws://{HOST}:{PORT}")
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())


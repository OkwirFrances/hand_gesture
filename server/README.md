# Slide Control Server

A WebSocket server that receives gesture commands from the Flutter app and controls your presentation using keyboard shortcuts.

## Setup

1. Install Python requirements:
```bash
pip install -r requirements.txt
```

2. Start the server:
```bash
python slide_server.py
```

## Command Mapping

- START (👍 Thumbs Up) -> F5 (Start presentation)
- END (✊ Fist) -> ESC (End presentation)
- NEXT (👉 Point) -> Right Arrow
- PREV (✌️ Peace) -> Left Arrow
- PAUSE (🖐️ Open Palm) -> B (Blank/unblank screen)

## Configuration

- Default port: 8080
- Server address: 0.0.0.0 (accessible from all network interfaces)
- Edit COMMAND_MAPPING in the code to customize keyboard shortcuts

## Troubleshooting

1. If you get permission errors on Linux:
```bash
sudo pip install keyboard
sudo python slide_server.py
```

2. If WebSocket connection fails:
- Check if the server IP address matches _pcIP in your Flutter app
- Ensure port 8080 is not blocked by firewall
- Check if the server and phone are on the same network

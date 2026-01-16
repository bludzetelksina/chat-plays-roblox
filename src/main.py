#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Chat Uses: Roblox Edition
YouTube Chat → Input Emulation → TTS → Game Control
"""

import os
import sys
import time
import json
import re
import threading
import subprocess
import logging
from datetime import datetime, timedelta
from pathlib import Path

# === Зависимости ===
try:
    import googleapiclient.discovery
    import pyautogui
    import pygame
    from gtts import gTTS
except ImportError as e:
    print(f"❌ Отсутствует зависимость: {e}")
    sys.exit(1)

# === Конфигурация ===
CONFIG_PATH = Path("../config/chat_uses.json")
LOGS_DIR = Path("../logs")
ASSETS_DIR = Path("../assets")
TTS_CACHE_DIR = LOGS_DIR / "tts_cache"

# Создаём директории
LOGS_DIR.mkdir(exist_ok=True)
TTS_CACHE_DIR.mkdir(exist_ok=True)

# Настройка логгера
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOGS_DIR / "chat_uses.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("ChatUses")

def handle_stream_command(action: str):
    try:
        result = subprocess.run(
            ["../scripts/stream_control.sh", action],
            cwd="..",
            capture_output=True,
            text=True,
            timeout=10
        )
        logger.info(f"🎥 Stream {action}: {result.stdout.strip()}")
    except Exception as e:
        logger.error(f"Ошибка управления стримом: {e}")

# === Глобальное состояние сессии ===
class SessionState:
    def __init__(self):
        self.is_running = False
        self.current_game_id = None
        self.window_mode = "fullscreen"  # или "windowed"
        self.last_command_time = datetime.min
        self.preset = None

session = SessionState()

# === Загрузка конфигурации ===
def load_config():
    if not CONFIG_PATH.exists():
        logger.error(f"Конфиг не найден: {CONFIG_PATH}")
        sys.exit(1)
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

config = load_config()

# === Эмулятор ввода ===
class InputEmulator:
    def __init__(self):
        pyautogui.FAILSAFE = False
        pyautogui.PAUSE = 0.01

    def key_press(self, key: str):
        """Эмуляция нажатия клавиши (WASD, space, esc и т.д.)"""
        try:
            pyautogui.press(key.lower())
            logger.debug(f"⌨️ Нажата клавиша: {key}")
        except Exception as e:
            logger.warning(f"Ошибка при нажатии {key}: {e}")

    def mouse_click(self, button="left", x=None, y=None):
        """Эмуляция клика мыши"""
        if x is not None and y is not None:
            pyautogui.moveTo(x, y)
        pyautogui.click(button=button)
        logger.debug(f"🖱 Клик: {button} @ ({x}, {y})")

    def move_cursor(self, x: int, y: int):
        pyautogui.moveTo(x, y)
        logger.debug(f"🖱 Перемещение курсора: ({x}, {y})")

    def look(self, direction: str):
        """Простая эмуляция поворота камеры (стрелки)"""
        mapping = {
            "up": "up",
            "down": "down",
            "left": "left",
            "right": "right"
        }
        if direction in mapping:
            self.key_press(mapping[direction])
            logger.debug(f"👁 Поворот камеры: {direction}")

    def system_key(self, combo: str):
        """Системные комбинации: alt+f4, f11 и т.д."""
        try:
            if combo == "altf4":
                pyautogui.hotkey("alt", "f4")
            elif combo == "f11":
                pyautogui.press("f11")
            elif combo == "altenter":
                pyautogui.hotkey("alt", "enter")
            elif combo == "desktop":
                pyautogui.hotkey("win", "d")
            else:
                logger.warning(f"Неизвестная системная команда: {combo}")
        except Exception as e:
            logger.warning(f"Ошибка системной команды {combo}: {e}")

input_emu = InputEmulator()

# === TTS система ===
class TTSEngine:
    def __init__(self):
        pygame.mixer.init()

    def say(self, text: str):
        safe_text = re.sub(r"[^a-zA-Zа-яА-Я0-9\s.,!?]", "", text)[:100]
        if not safe_text.strip():
            return

        tts_file = TTS_CACHE_DIR / f"tts_{hash(safe_text) % 1000}.mp3"
        try:
            if not tts_file.exists():
                tts = gTTS(text=safe_text, lang="ru")
                tts.save(str(tts_file))
            pygame.mixer.music.load(str(tts_file))
            pygame.mixer.music.play()
            while pygame.mixer.music.get_busy():
                time.sleep(0.1)
            # Очистка после воспроизведения
            time.sleep(0.5)
            if tts_file.exists():
                tts_file.unlink()
        except Exception as e:
            logger.error(f"TTS ошибка: {e}")

tts_engine = TTSEngine()

# === Менеджер сессии ===
class SessionManager:
    def start_game(self):
        if session.is_running:
            return
        # Здесь можно запустить launch_roblox.sh
        logger.info("▶️ Запуск Roblox...")
        subprocess.Popen(["../scripts/launch_roblox.sh"], cwd="..")
        session.is_running = True
        session.last_command_time = datetime.now()

    def stop_game(self):
        if not session.is_running:
            return
        logger.info("⏹ Остановка Roblox...")
        subprocess.run(["../scripts/stop_roblox.sh"], cwd="..")
        session.is_running = False
        session.current_game_id = None

    def join_game(self, game_id: str):
        self.start_game()
        session.current_game_id = game_id
        logger.info(f"🎮 Присоединение к игре: {game_id}")

    def leave_game(self):
        session.current_game_id = None
        logger.info("🚪 Выход из игры")

session_mgr = SessionManager()

# === Регистр команд ===
COMMAND_REGISTRY = {
    # Игровые команды
    "w": {"type": "key", "key": "w"},
    "a": {"type": "key", "key": "a"},
    "s": {"type": "key", "key": "s"},
    "d": {"type": "key", "key": "d"},
    "space": {"type": "key", "key": "space"},
    "jump": {"type": "key", "key": "space"},
    "up": {"type": "key", "key": "up"},
    "down": {"type": "key", "key": "down"},
    "left": {"type": "key", "key": "left"},
    "right": {"type": "key", "key": "right"},

    # Системные
    "esc": {"type": "key", "key": "esc"},
    "tab": {"type": "key", "key": "tab"},
    "f11": {"type": "system", "combo": "f11"},
    "altf4": {"type": "system", "combo": "altf4"},
    "altenter": {"type": "system", "combo": "altenter"},
    "desktop": {"type": "system", "combo": "desktop"},

    # Стрим
    "start-stream": {"type": "stream", "action": "start"},
    "stop-stream": {"type": "stream", "action": "stop"},
    "restart-stream": {"type": "stream", "action": "restart"},

    # Управление сессией
    "run": {"type": "session", "action": "start"},
    "stop": {"type": "session", "action": "stop"},
    "joingame": {"type": "session", "action": "join"},
    "leavegame": {"type": "session", "action": "leave"},

    # Мышиные команды — обрабатываются отдельно парсером
}

# === Обработка команды ===
def execute_command(cmd: str, args: list, author: str):
    logger.info(f"📥 Команда от {author}: !{cmd} {' '.join(args)}")

    # Обновляем время последней активности
    session.last_command_time = datetime.now()

    # TTS
    if cmd == "chat" or cmd == "say":
        text = " ".join(args)
        tts_engine.say(text)
        return

    # Загрузка пресета или игры
    if cmd == "load":
        if args:
            target = args[0]
            if target.isdigit():
                session_mgr.join_game(target)
            else:
                session.preset = target
                logger.info(f"💾 Загружен пресет: {target}")
        return

    # Команды мыши
    if cmd == "click":
        button = "left"
        x = y = None
        if len(args) >= 1:
            button = args[0].lower()
        if len(args) >= 3:
            try:
                x, y = int(args[-2]), int(args[-1])
            except ValueError:
                pass
        input_emu.mouse_click(button=button, x=x, y=y)
        return

    if cmd == "movecursor" and len(args) >= 2:
        try:
            x, y = int(args[0]), int(args[1])
            input_emu.move_cursor(x, y)
        except ValueError:
            pass
        return

    if cmd == "look" and args:
        input_emu.look(args[0].lower())
        return

    # Стандартные команды из реестра
if cmd in COMMAND_REGISTRY:
    action = COMMAND_REGISTRY[cmd]
    if action["type"] == "key":
        input_emu.key_press(action["key"])
    elif action["type"] == "system":
        input_emu.system_key(action.get("combo", ""))
    elif action["type"] == "stream":
        if action["action"] == "start":
            handle_stream_command("start")
        elif action["action"] == "stop":
            handle_stream_command("stop")
        elif action["action"] == "restart":
            handle_stream_command("restart")
        else:
            logger.warning(f"Неизвестное действие стрима: {action['action']}")
    elif action["type"] == "session":
        if action["action"] == "start":
            session_mgr.start_game()
        elif action["action"] == "stop":
            session_mgr.stop_game()
        elif action["action"] == "join":
            session_mgr.join_game("default")
        elif action["action"] == "leave":
            session_mgr.leave_game()
    else:
        logger.warning(f"Неизвестный тип команды: {action['type']}")

# === Парсинг сообщения ===
def parse_message(message: str):
    message = message.strip()
    if not message.startswith("!"):
        return None, []

    parts = re.split(r'\s+', message[1:], maxsplit=1)
    cmd = parts[0].lower()
    args_str = parts[1] if len(parts) > 1 else ""

    # Обработка кавычек для !say "hello world"
    if cmd in ("say", "chat") and args_str.startswith('"') and args_str.endswith('"'):
        args = [args_str[1:-1]]
    else:
        args = args_str.split() if args_str else []

    return cmd, args

# === YouTube Chat Listener ===
class YouTubeChatListener:
    def __init__(self, api_key: str, live_chat_id: str):
        self.api_key = api_key
        self.live_chat_id = live_chat_id
        self.youtube = googleapiclient.discovery.build(
            "youtube", "v3", developerKey=api_key
        )

    def poll_messages(self):
        try:
            request = self.youtube.liveChatMessages().list(
                liveChatId=self.live_chat_id,
                part="snippet,authorDetails"
            )
            response = request.execute()
            return response.get("items", [])
        except Exception as e:
            logger.error(f"Ошибка YouTube API: {e}")
            return []

    def run(self):
        last_msg_id = None
        while True:
            try:
                messages = self.poll_messages()
                for msg in reversed(messages):  # от новых к старым
                    msg_id = msg["id"]
                    if msg_id == last_msg_id:
                        break
                    author = msg["authorDetails"]["displayName"]
                    text = msg["snippet"]["displayMessage"]
                    cmd, args = parse_message(text)
                    if cmd:
                        execute_command(cmd, args, author)
                if messages:
                    last_msg_id = messages[0]["id"]
                time.sleep(2)
            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error(f"Ошибка в цикле чата: {e}")
                time.sleep(5)

# === Точка входа ===
def main():
    logger.info("🚀 Запуск Chat Uses: Roblox Edition")

    # Проверка DISPLAY
    if not os.environ.get("DISPLAY"):
        os.environ["DISPLAY"] = ":0"
        logger.info("🖥 Установлен DISPLAY=:0")

    # Запуск YouTube listener в отдельном потоке
    listener = YouTubeChatListener(
        api_key=config["youtube_api_key"],
        live_chat_id=config["live_chat_id"]
    )

    chat_thread = threading.Thread(target=listener.run, daemon=True)
    chat_thread.start()

    # Основной цикл: мониторинг активности
    try:
        while True:
            # Автоматическая пауза при бездействии > 12 часов
            if session.is_running and datetime.now() - session.last_command_time > timedelta(hours=12):
                logger.info("💤 Без активности >12 часов — пауза сессии")
                session_mgr.stop_game()
            time.sleep(30)
    except KeyboardInterrupt:
        logger.info("🛑 Остановка по сигналу")
        session_mgr.stop_game()

if __name__ == "__main__":
    main()

<div align="center">

# 🎙️ Bolo & Build (बोलो & Build)
### *Voice-First AI Application Studio & Windows Desktop Copilot*
#### Powered by **Wispr Flow** • 100% Voice-Driven • Zero Keyboard Typing • Multi-Model & Local Ollama

[![Wispr Flow Referral](https://img.shields.io/badge/Wispr_Flow-Referral_Link-9D4EDD?style=for-the-badge&logo=soundcharts&logoColor=white)](https://wisprflow.ai/r?SUJAL482)
[![Flutter Desktop](https://img.shields.io/badge/Flutter_Windows-Desktop_App-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Local Ollama](https://img.shields.io/badge/Ollama-100%25_Offline_AI-4CAF50?style=for-the-badge&logo=ollama&logoColor=white)](https://ollama.ai)
[![Zero Keyboard](https://img.shields.io/badge/Keys_Typed-0_(100%25_Voice)-FFB52E?style=for-the-badge)](#-zero-keyboard-proof)

<br/>

> **"Speak an application into existence."**  
> Dictate full HTML5 games, calculators, dashboards, and utilities with **Wispr Flow (CapsLock push-to-talk)**, control your desktop, and generate live code in real time using Cloud AI or **100% Local Offline Ollama models**.

---

[🚀 Quick Start](#-quick-start) • [✨ Key Features](#-key-features) • [🧠 AI Providers & Ollama](#-ai-engine--models) • [🖥️ PC Automation](#-pc-control--phone-alerts) • [🎥 Video Proof](#-zero-keyboard-proof)

</div>

---

## 🌟 Highlights

- **🎙️ 100% Wispr Flow Powered**: Seamless push-to-talk (`CapsLock`) voice capture with ultra-low latency (<150ms) clipboard & keystroke sync.
- **⚡ Zero Premature Triggers**: Generation only begins when you click **"Build it"** or press Enter—no accidental cuts while speaking or typing.
- **💬 OpenAI & Claude Style Chat UI**: Full conversational history with user bubbles, assistant cards, and live **animated "Thinking..." shimmer cards**.
- **🎨 Claude Artifacts Studio**: Real-time code inspector, app history switcher, and one-click browser launcher.
- **🦙 Local Ollama Mode (100% Offline & Free)**: Auto-detects local Ollama models (`llama3`, `qwen2.5-coder`, `mistral`, `deepseek-r1`) and cuts off cloud APIs automatically.
- **🔑 Multi-Key Cloud Manager**: Store and hot-swap up to 10 verified keys across **OpenAI (GPT-4o)**, **Google Gemini (`AQ...` / `AIzaSy`)**, **Anthropic Claude**, **Groq Cloud**, and **OpenRouter**.
- **🌐 Multilingual Voice Recognition**: Understands English (India / US), हिन्दी (Hindi), ગુજરાતી (Gujarati), and Hinglish natively.
- **📱 Phone Notification Sync**: Free instant push notifications to your phone via `ntfy.sh` as soon as your app build is complete.

---

## 📸 Architecture & Workflow

```
                   ┌──────────────────────────────────────┐
                   │    🎙️ Wispr Flow (Push-to-Talk)     │
                   │    Hold CapsLock & speak naturally   │
                   └──────────────────┬───────────────────┘
                                      │ (Real-Time Voice Stream)
                                      ▼
                   ┌──────────────────────────────────────┐
                   │   💬 Bolo & Build Chat & Studio      │
                   │   • Animated "Thinking..." State     │
                   │   • Conversational Q&A (Jarvis)      │
                   │   • Live Claude Artifacts Inspector  │
                   └──────────────────┬───────────────────┘
                                      │
                 ┌────────────────────┴────────────────────┐
                 ▼                                         ▼
   ┌───────────────────────────┐             ┌───────────────────────────┐
   │ 🦙 Local Ollama (Offline)  │             │   ☁️ Cloud AI Providers   │
   │ • llama3 / qwen2.5-coder  │             │ • OpenAI GPT-4o           │
   │ • deepseek-r1 / mistral   │             │ • Google Gemini (2.0/1.5) │
   │ • 100% Private & Free     │             │ • Claude 3.5 / Groq       │
   └─────────────┬─────────────┘             └─────────────┬─────────────┘
                 │                                         │
                 └────────────────────┬────────────────────┘
                                      │ (HTML5 / JS App Generated)
                                      ▼
                   ┌──────────────────────────────────────┐
                   │   🚀 Live App Execution & Sync       │
                   │   • Saves to ~/BoloBuilds/           │
                   │   • Launches in Browser              │
                   │   • Push Alert to Mobile (ntfy.sh)   │
                   └──────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites
- **Windows 10 / 11**
- **Flutter SDK** (`C:\tools\flutter\bin`)
- **Visual Studio 2022** (with *Desktop development with C++*)
- **[Wispr Flow](https://wisprflow.ai/r?SUJAL482)** (Push-to-talk desktop client)

### 1. Launch Application (Fast Track)

Open **Command Prompt (CMD)** in the project directory:

```cmd
set PATH=C:\tools\flutter\bin;C:\Windows\System32\WindowsPowerShell\v1.0;%PATH%
cd /d s:\bolo_flutter
flutter run -d windows
```

### 2. Build Standalone Release Package (.exe)

```cmd
set PATH=C:\tools\flutter\bin;C:\Windows\System32\WindowsPowerShell\v1.0;%PATH%
cd /d s:\bolo_flutter
flutter build windows --release
xcopy /E /I /Y "s:\bolo_flutter\build\windows\x64\runner\Release\*" "s:\bolo_flutter\dist\BoloApp\"
start "" "s:\bolo_flutter\dist\BoloApp\bolo_and_build.exe"
```

---

## ✨ Key Features

### 1. Voice-Driven App Generation
Hold `CapsLock` and say:
- *"Jarvis, build a retro space invaders arcade game with score counter and sound effects"*
- *"Create a beautiful Pomodoro focus timer with dark mode and customizable intervals"*
- *"Make a financial loan calculator with interactive EMI breakdown charts"*
- *"Remix it: add sound effects and a particle explosion whenever score increases"*

### 2. Desktop Control & PC Voice Commands
- *"Open Notepad"* or *"Launch Calculator"*
- *"Open youtube.com"* or *"Go to github.com"*
- *"Open my builds folder"*

### 3. Real-Time Conversational AI
Ask identity or utility questions anytime without opening a browser:
- *"Myself Sujal. How are you and what can you build?"*
- *"Explain how binary search works in simple terms"*

---

## 🧠 AI Engine & Models

Bolo & Build supports both **Cloud AI keys** and **Local Offline Ollama**:

| Provider | Supported Models / Endpoints | Setup |
| :--- | :--- | :--- |
| **🦙 Local Ollama** | `llama3`, `qwen2.5-coder`, `mistral`, `deepseek-r1`, `phi3` | Toggle ON in settings (no API key required) |
| **🌐 Google Gemini** | `gemini-2.0-flash`, `gemini-1.5-flash-latest`, `gemini-pro` | Paste `AQ...` or `AIzaSy...` key |
| **🟢 OpenAI** | `gpt-4o`, `gpt-4o-mini` | Paste `sk-proj-...` or `sk-...` key |
| **🟣 Anthropic** | `claude-3-5-sonnet-20241022`, `claude-3-haiku` | Paste `sk-ant-...` key |
| **⚡ Groq Cloud** | `llama-3.3-70b-versatile` | Paste `gsk_...` key |
| **🔀 OpenRouter** | Multi-model routing | Paste `sk-or-...` key |

---

## 📱 PC Control & Phone Alerts

1. Install the free **[ntfy](https://ntfy.sh)** app on your iOS or Android phone.
2. In the Bolo & Build settings panel, subscribe to the generated private topic (e.g. `bolo-xxxx`).
3. Whenever a voice build finishes, your phone will chime with the app title and save path!

---

## 🛡️ Safety & Privacy

- **Safe Execution**: Only opens valid web URLs and local files created by the studio. Arbitrary shell scripts and dangerous terminal commands are strictly blocked.
- **Local Settings**: Stored securely on your machine at `~/.bolo/settings.json`.
- **Offline Mode**: Using Ollama keeps 100% of your voice data and code strictly on your local PC.

---

## 🎯 Wispr Flow Referral Link

Created for the **Wispr Flow Shortlisting Task**. Download and get started with Wispr Flow using the official link:
👉 **[https://wisprflow.ai/r?SUJAL482](https://wisprflow.ai/r?SUJAL482)**

---

<div align="center">
Made with ❤️ using <b>Flutter</b> and <b>Wispr Flow</b>
</div>

from fastapi import FastAPI
from pydantic import BaseModel
from groq import Groq
from dotenv import load_dotenv
import os
import json
import datetime
from fastapi.responses import StreamingResponse

# ---------------- LOAD ENV ----------------
load_dotenv()
client = Groq(api_key=os.getenv("GROQ_API_KEY"))

app = FastAPI(title="My AI Backend (Persistent Memory + Vision)")

# ---------------- MEMORY CONFIG ----------------
MEMORY_FILE = "memory.json"
MAX_MEMORY_MESSAGES = 500

# ---------------- LOAD / SAVE MEMORY ----------------
def load_memory():
    if not os.path.exists(MEMORY_FILE):
        return {}
    with open(MEMORY_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def save_memory(memory):
    with open(MEMORY_FILE, "w", encoding="utf-8") as f:
        json.dump(memory, f, indent=2)

conversation_memory = load_memory()

# ---------------- REQUEST MODEL ----------------
class ChatRequest(BaseModel):
    message: str
    user_id: str = "default_user"
    image: str | None = None  # base64 image

# ---------------- SUBJECT DETECTION ----------------
def detect_subject(prompt: str) -> str:
    p = prompt.lower()
    if any(x in p for x in ["+", "-", "*", "/", "solve", "calculate"]):
        return "math"
    if any(x in p for x in ["velocity", "force", "acceleration", "newton"]):
        return "physics"
    if any(x in p for x in ["reaction", "acid", "base", "mole"]):
        return "chemistry"
    if any(x in p for x in ["cell", "photosynthesis", "enzyme"]):
        return "biology"
    if any(x in p for x in ["history", "war", "independence"]):
        return "history"
    if any(x in p for x in ["python", "java", "code"]):
        return "coding"
    return "chat"

# ---------------- SUBJECT PROMPTS ----------------
def subject_prompt(subject: str) -> str:
    prompts = {
        "math": "You are a mathematics expert. Explain step by step.",
        "physics": "You are a physics teacher.",
        "chemistry": "You are a chemistry expert.",
        "biology": "You are a biology teacher.",
        "history": "You are a history expert.",
        "coding": "You are a programming mentor.",
        "chat": "You are a friendly, intelligent AI assistant."
    }
    return prompts.get(subject, prompts["chat"])

# ---------------- MEMORY CONTEXT ----------------
def get_context_messages(user_id: str):
    history = conversation_memory.get(user_id, [])
    return [{"role": m["role"], "content": m["content"]} for m in history[-10:]]

# ---------------- AI CALL ----------------
def call_ai(user_id: str, prompt: str, image: str | None = None) -> str:
    subject = detect_subject(prompt)

    messages = [
        {"role": "system", "content": subject_prompt(subject)},
        *get_context_messages(user_id)
    ]

    if image:
        messages.append({
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": image}}
            ]
        })
    else:
        messages.append({"role": "user", "content": prompt})

    completion = client.chat.completions.create(
        model="llama-3.2-11b-vision-preview" if image else "llama-3.1-8b-instant",
        messages=messages,
        temperature=0.4
    )

    reply = completion.choices[0].message.content.strip()
    reply = reply.replace("\\n", "\n").replace("**", "").replace("*", "")

    conversation_memory.setdefault(user_id, [])
    conversation_memory[user_id].extend([
        {"role": "user", "content": prompt},
        {"role": "assistant", "content": reply}
    ])

    conversation_memory[user_id] = conversation_memory[user_id][-MAX_MEMORY_MESSAGES:]
    save_memory(conversation_memory)

    return reply

# ---------------- ROUTER ----------------
def router(user_id: str, prompt: str, image: str | None = None) -> str:
    p = prompt.lower()
    if p in ["reset", "clear memory"]:
        conversation_memory[user_id] = []
        save_memory(conversation_memory)
        return "Memory cleared."
    if "time" in p or "date" in p:
        return datetime.datetime.now().strftime("%d %B %Y, %H:%M:%S")
    return call_ai(user_id, prompt, image)

# ---------------- ROUTES ----------------
@app.get("/")
def root():
    return {"status": "AI backend running"}

@app.post("/chat")
def chat(req: ChatRequest):
    return {"reply": router(req.user_id, req.message, req.image)}

@app.post("/chat-stream")
def chat_stream(req: ChatRequest):
    def stream():
        completion = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                *get_context_messages(req.user_id),
                {"role": "user", "content": req.message}
            ],
            stream=True
        )
        for chunk in completion:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content
    return StreamingResponse(stream(), media_type="text/plain")

# ---------------- RUN (RENDER SAFE) ----------------
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=port)
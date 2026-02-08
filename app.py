from fastapi import FastAPI, HTTPException, Depends, Header
from pydantic import BaseModel
from groq import Groq
from dotenv import load_dotenv
import os
import json
import datetime
import hashlib
from fastapi.responses import StreamingResponse

from jose import jwt, JWTError


# ---------------- LOAD ENV ----------------
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY is missing.")

client = Groq(api_key=GROQ_API_KEY)

app = FastAPI(title="My AI Backend (Auth + Memory + Vision)")


# ---------------- AUTH CONFIG ----------------

SECRET_KEY = "CHATLLAMA_SECRET_2026"
ALGORITHM = "HS256"
TOKEN_EXPIRE_DAYS = 7

USERS_FILE = "users.json"


# ---------------- MEMORY CONFIG ----------------

MEMORY_FILE = "memory.json"
MAX_MEMORY_MESSAGES = 500


# ---------------- LOAD / SAVE ----------------

def load_json(file):
    if not os.path.exists(file):
        return {}
    with open(file, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(file, data):
    with open(file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


users_db = load_json(USERS_FILE)
conversation_memory = load_json(MEMORY_FILE)


# ---------------- REQUEST MODELS ----------------

class Register(BaseModel):
    username: str
    password: str


class Login(BaseModel):
    username: str
    password: str


class ChatRequest(BaseModel):
    message: str
    image: str | None = None


# ---------------- PASSWORD (FIXED) ----------------

def hash_pass(p: str):
    return hashlib.sha256(p.encode()).hexdigest()


def verify_pass(p: str, h: str):
    return hashlib.sha256(p.encode()).hexdigest() == h


# ---------------- TOKEN ----------------

def create_token(user):
    data = {
        "sub": user,
        "exp": datetime.datetime.utcnow() +
        datetime.timedelta(days=TOKEN_EXPIRE_DAYS)
    }

    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def get_user(token: str):

    try:
        data = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return data["sub"]

    except JWTError:
        return None


def auth(authorization: str = Header("")):

    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Login required")

    token = authorization.replace("Bearer ", "")

    user = get_user(token)

    if not user:
        raise HTTPException(401, "Invalid token")

    return user


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
        "math": "Math helper",
        "physics": "Physics helper",
        "chemistry": "Chemistry helper",
        "biology": "Biology helper",
        "history": "History helper",
        "coding": "Code helper",
        "chat": "Assistant"
    }

    return prompts.get(subject, prompts["chat"])


# ---------------- MEMORY - KEEP 23 MESSAGES ----------------

def get_context_messages(user_id: str):

    history = conversation_memory.get(user_id, [])

    context = []
    total_chars = 0
    MAX_CHARS = 3500   # Safe for Groq free tier

    # Take newest messages first (reverse)
    for m in reversed(history):

        text = m["content"]

        if not text:
            continue

        length = len(text)

        # Stop if context is getting too big
        if total_chars + length > MAX_CHARS:
            break

        context.append({
            "role": m["role"],
            "content": text[:1200]  # Hard cap per message
        })

        total_chars += length

    # Reverse back to normal order
    return list(reversed(context))

# ---------------- AI ----------------

def call_ai(user_id: str, prompt: str, image=None) -> str:

    subject = detect_subject(prompt)
    system_prompt = subject_prompt(subject)

    messages = [
        {"role": "system", "content": system_prompt},
        *get_context_messages(user_id),
        {"role": "user", "content": prompt},
    ]

    try:

        completion = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=messages,
            temperature=0.4
        )

    except Exception as e:
        print("GROQ ERROR:", e)
        print("ERROR TYPE:", type(e).__name__)
        print("ERROR DETAILS:", str(e))
        return f"⚠️ Error: {str(e)[:100]}"

    reply = completion.choices[0].message.content.strip()

    reply = reply.replace("\\n", "\n")
    reply = reply.replace("**", "").replace("*", "")

    conversation_memory.setdefault(user_id, [])

    conversation_memory[user_id].append({
        "role": "user",
        "content": prompt
    })

    conversation_memory[user_id].append({
        "role": "assistant",
        "content": reply
    })

    conversation_memory[user_id] = conversation_memory[user_id][-MAX_MEMORY_MESSAGES:]

    save_memory()

    return reply


# ---------------- ROUTER ----------------

def router(user_id: str, prompt: str, image=None) -> str:

    p = prompt.lower()

    if p in ["reset", "clear memory"]:
        conversation_memory[user_id] = []
        save_memory()
        return "Memory cleared."

    if "time" in p or "date" in p:
        return datetime.datetime.now().strftime("%d %B %Y, %H:%M:%S")

    return call_ai(user_id, prompt, image)


# ---------------- AUTH ROUTES ----------------

@app.post("/register")
def register(data: Register):

    if data.username in users_db:
        raise HTTPException(400, "User exists")

    users_db[data.username] = {
        "password": hash_pass(data.password),
        "created": str(datetime.datetime.utcnow())
    }

    save_json(USERS_FILE, users_db)

    return {"status": "registered"}


@app.post("/login")
def login(data: Login):

    user = users_db.get(data.username)

    if not user:
        raise HTTPException(401, "Invalid login")

    if not verify_pass(data.password, user["password"]):
        raise HTTPException(401, "Invalid login")

    token = create_token(data.username)

    return {"token": token}


@app.get("/me")
def me(user=Depends(auth)):
    return {"username": user}


# ---------------- ROUTES ----------------

@app.get("/test")
def test():
    return {"status": "working"}


@app.get("/")
def root():
    return {"status": "AI backend running"}


@app.post("/chat")
def chat(req: ChatRequest, user=Depends(auth)):

    reply = router(user, req.message, req.image)

    return {"reply": reply}


@app.post("/chat-stream")
def chat_stream(req: ChatRequest, user=Depends(auth)):

    def stream():

        completion = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": "Assistant"},
                *get_context_messages(user),
                {"role": "user", "content": req.message}
            ],
            stream=True
        )

        for chunk in completion:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    return StreamingResponse(stream(), media_type="text/plain")


# ---------------- RUN ----------------

if __name__ == "__main__":

    import uvicorn

    port = int(os.environ.get("PORT", 8000))

    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)

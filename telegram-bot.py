import os
import uvicorn
from fastapi import FastAPI, Request
from dotenv import load_dotenv
from telegram import Bot, Update
from telegram.ext import Application, CommandHandler, ContextTypes
import firebase_admin
from firebase_admin import credentials, firestore
import uuid
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi.middleware.cors import CORSMiddleware
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import CallbackQueryHandler, CommandHandler, ContextTypes
from telegram import KeyboardButton, ReplyKeyboardMarkup
from telegram.ext import ContextTypes

load_dotenv()

# Create limiter instance
limiter = Limiter(key_func=get_remote_address)

# Load environment variables
DOC_URL = "https://github.com/justmert/sia-telegram-alert-bot/blob/master/README.md"
TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
FIREBASE_ADMIN_SDK_PATH = os.getenv("FIREBASE_ADMIN_SDK_PATH")
SERVER_URL = os.getenv("SERVER_URL")

# Initialize Firebase
cred = credentials.Certificate(FIREBASE_ADMIN_SDK_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()


# Create FastAPI app
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Apply rate limiting middleware
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Telegram Bot Setup
# bot = Bot(TELEGRAM_TOKEN)
application = Application.builder().token(TELEGRAM_TOKEN).build()


# Helper functions for Firebase
def save_user(unique_id, chat_id):
    db.collection("users").document(unique_id).set({"chat_id": chat_id})


def get_chat_id(unique_id):
    doc = db.collection("users").document(unique_id).get()
    return doc.to_dict()["chat_id"] if doc.exists else None


def generate_unique_id():
    return str(uuid.uuid4())


async def register_user(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = (
        update.effective_chat.id
        if update.effective_chat
        else update.callback_query.message.chat_id
    )

    # Check if the user is already registered
    unique_id = get_unique_id_for_chat_id(chat_id)

    if unique_id:
        unique_id_message = "You are already registered with unique id,"
        await context.bot.send_message(chat_id=chat_id, text=unique_id_message)

        # Send unique ID
        await context.bot.send_message(chat_id=chat_id, text=unique_id)

    else:
        unique_id = generate_unique_id()
        save_user(unique_id, chat_id)

        # Send "Your unique ID" message
        unique_id_message = "Your unique id,"
        await context.bot.send_message(chat_id=chat_id, text=unique_id_message)

        # Send unique ID
        await context.bot.send_message(chat_id=chat_id, text=unique_id)

        # Send "Please save it" message
        save_message = f"Please save this unique id. You will need it for the remaining setup. Refer to the <a href='{DOC_URL}'>documentation</a>."
        await context.bot.send_message(
            chat_id=chat_id, text=save_message, parse_mode="HTML"
        )


async def delete_user(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = (
        update.effective_chat.id
        if update.effective_chat
        else update.callback_query.message.chat_id
    )
    unique_id = get_unique_id_for_chat_id(chat_id)
    if unique_id:
        db.collection("users").document(unique_id).delete()
        response_text = "You have been unregistered. You will no longer receive alerts."
    else:
        response_text = "You are already unregistered."

    if update.callback_query:
        await update.callback_query.message.edit_text(text=response_text)
    else:
        await context.bot.send_message(chat_id=chat_id, text=response_text)


def get_unique_id_for_chat_id(chat_id):
    users = db.collection("users").where("chat_id", "==", chat_id).stream()
    for user in users:
        return user.id
    return None


async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    help_text = "⭐ Get real-time Sia Renterd and Hostd alerts on Telegram!\nType /start to get started."
    if update.callback_query:
        await update.callback_query.message.edit_text(text=help_text)
    else:
        await context.bot.send_message(chat_id=update.effective_chat.id, text=help_text)


@app.post("/set_webhook")
async def set_webhook(request: Request):
    update = await request.json()
    update = Update.de_json(update, application.bot)
    await application.process_update(update)
    return {"ok": True}


async def startup_event():
    # Your startup code here
    await application.initialize()
    await application.bot.set_webhook(url=f"{SERVER_URL}/set_webhook")


async def shutdown_event():
    # Your shutdown code here
    # For example, clean up connections, save state, etc.
    pass


app.add_event_handler("startup", startup_event)
app.add_event_handler("shutdown", shutdown_event)


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [
        [InlineKeyboardButton("Register User", callback_data="register_user")],
        [InlineKeyboardButton("Delete User", callback_data="delete_user")],
        [InlineKeyboardButton("Help", callback_data="help")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="Welcome to the SIA Alert Bot! Choose a command:",
        reply_markup=reply_markup,
    )


async def button_callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    command = query.data
    chat_id = query.message.chat_id

    if command == "register_user":
        # Call the register_user function here
        await register_user(update, context)
    elif command == "delete_user":
        # Call the delete_user function here
        await delete_user(update, context)
    elif command == "help":
        # Call the help_command function here
        await help_command(update, context)


application.add_handler(CommandHandler("help", help_command))
application.add_handler(CommandHandler("start", start))
application.add_handler(CallbackQueryHandler(button_callback_handler))

# Run FastAPI
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)

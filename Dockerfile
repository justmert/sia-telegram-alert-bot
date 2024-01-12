FROM python:3

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

#Source telegram-bot.py
COPY telegram-bot.py /usr/src/app/telegram-bot.py

# User to run renterd as. Defaults to root.
ENV PUID=0
ENV PGID=0

# Define ENV for application (Should be replaced with .env)
ENV TELEGRAM_TOKEN=replaceme
ENV SERVER_URL=http://service.app:8006
ENV FIREBASE_ADMIN_SDK_PATH=/data/firebase.json

#Prepare datadir 
VOLUME [ "/data" ]

USER ${PUID}:${PGID}

CMD [ "uvicorn", "telegram-bot:app", "--host", "0.0.0.0", "--port", "9180" ]

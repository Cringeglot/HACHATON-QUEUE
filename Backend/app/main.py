# app/main.py
"""
FastAPI-приложение системы электронной очереди.
"""
import asyncio

from datetime import datetime

from app import auth

from app.auth import get_current_user, require_role, create_user, CreateUserRequest

from fastapi import FastAPI, Depends, HTTPException,  WebSocket, WebSocketDisconnect, Query
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from sqlalchemy import select, func
from sqlalchemy.orm import Session
from fastapi.middleware.cors import CORSMiddleware

from app.db import Base, engine, get_db, SessionLocal
from app.models import Branch, Window, Ticket, TicketLog, User
from app import queue as q


app = FastAPI(title="E-Queue MVP", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",     # Динамически возвращает origin запроса (подходит для localhost с любым портом)
    allow_credentials=True, 
    allow_methods=["*"],        
    allow_headers=["*"],       
)

CLIENT = 0
OPERATOR = 1
DIRECTOR = 2
ADMIN = 3
app.include_router(auth.router)

main_loop = None
# ---------------------------------------------------------------------------
# WebSocket Менеджер
# ---------------------------------------------------------------------------
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, ticket_id: int):
        await websocket.accept()
        if ticket_id not in self.active_connections:
            self.active_connections[ticket_id] = []
        self.active_connections[ticket_id].append(websocket)

    def disconnect(self, websocket: WebSocket, ticket_id: int):
        if ticket_id in self.active_connections:
            self.active_connections[ticket_id].remove(websocket)
            if not self.active_connections[ticket_id]:
                del self.active_connections[ticket_id]

    async def send_update(self, ticket_id: int, ticket_data: dict):
        if ticket_id in self.active_connections:
            for connection in self.active_connections[ticket_id]:
                try:
                    await connection.send_json(ticket_data)
                except Exception as e:
                    print(f"Ошибка отправки WS для талона {ticket_id}: {e}")

ws_manager = ConnectionManager()

def broadcast_ticket_update(ticket_id: int, data: dict):
    """Безопасная отправка WS-уведомлений из обычных синхронных def-функций."""
    global main_loop
    if main_loop and main_loop.is_running():
        asyncio.run_coroutine_threadsafe(ws_manager.send_update(ticket_id, data), main_loop)

@app.websocket("/ws/tickets/{ticket_id}")
async def websocket_ticket(websocket: WebSocket, ticket_id: int, token: str = Query(None)):
    """
    Эндпоинт, к которому стучится фронтенд. 
    Проверяем токен "1" и сразу отправляем текущие данные талона при подключении.
    """
    if token != "1":
        await websocket.close(code=1008) # Ошибка доступа
        return
        
    await ws_manager.connect(websocket, ticket_id)
    
    # 1. Получаем актуальные данные талона из базы при подключении
    try:
        db = SessionLocal()
        t = db.get(Ticket, ticket_id)
        if t:
            resp = _t(t)
            # ИСПОЛЬЗУЕМ .dict() или .model_dump() с предварительным переводом в dict
            # Либо используем встроенную функцию _t(t), которая возвращает TicketResponse, 
            # у которого датированные поля нужно перевести в строки:
            data_to_send = resp.model_dump()
            # Конвертируем datetime в строку ISO, если она там есть
            if isinstance(data_to_send.get('created_at'), datetime):
                data_to_send['created_at'] = data_to_send['created_at'].isoformat()
                
            await websocket.send_json(data_to_send)
        else:
            await websocket.send_json({"error": f"Ticket {ticket_id} not found"})
    except Exception as e:
        print(f"WS Send Error: {e}")
        await websocket.send_json({"error": str(e)})
    finally:
        db.close()

    # 2. Держим соединение открытым
    try:
        while True:
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket, ticket_id)



@app.get("/")
async def user(user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    if user is None:
        raise HTTPException(status_code=401, detail='Authentication Failed')
    return {"User": user}


@app.on_event("startup")
async def on_startup():
    """Создаём таблицы и наполняем справочники, если пусто."""
    global main_loop
    main_loop = asyncio.get_running_loop()
    Base.metadata.create_all(bind=engine)
    # Base.metadata.drop_all(bind=engine)
    db = SessionLocal()
    if not db.query(User).filter(User.username == "admin").first():
        create_user(SessionLocal(), CreateUserRequest(**{"username": "admin", "password": "12345", "role": "admin"}))
    try:
        if db.query(Branch).count() == 0:
            db.add(Branch(name="Москва-Тверская"))
            db.commit()
        if db.query(Window).count() == 0:
            db.add(Window(branch_id=1, number="1", is_open=1))
            db.commit()
    finally:
        db.close()


app.mount("/ui", StaticFiles(directory="static", html=True), name="static")


# ---------------------------------------------------------------------------
# Схемы запросов
# ---------------------------------------------------------------------------

class TicketCreate(BaseModel):
    branch_id: int = 1
    service_id: int = 1
    source: str = "qr"
    scheduled_at: datetime | None = None

class TicketResponse(BaseModel):
    id: int
    number: str 
    status: str
    estimated_wait_min: int = 0 
    window_number: str | None = None  
    source_type: str 
    service_id: int
    client_token: str | None = None  
    created_at: datetime

    class Config:
        from_attributes = True 


class WindowOpen(BaseModel):
    branch_id: int = 1
    number: str = "1"


class BranchCreate(BaseModel):
    name: str

class UserBase(BaseModel):
    username: str 
    password: str


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health", tags=["system"])
def health():
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Талоны
# ---------------------------------------------------------------------------

@app.post("/api/tickets", tags=["tickets"])
def create_ticket(payload: TicketCreate, db: Session = Depends(get_db)):
    """Создать талон. source определяет способ входа."""
    status = "scheduled" if payload.source == "appointment" else "waiting"
    t = Ticket(
        public_code=_next_code(db),
        branch_id=payload.branch_id,
        service_id=payload.service_id,
        source=payload.source,
        status=status,
        scheduled_at=payload.scheduled_at,
    )
    db.add(t)
    db.flush()
    q.log_event(db, t.id, "created", f"source={payload.source}")
    db.commit()
    db.refresh(t)
    return _t(t)


@app.get("/api/tickets", tags=["tickets"])
def list_tickets(db: Session = Depends(get_db)):
    return [_t(t) for t in db.query(Ticket).order_by(Ticket.id).all()]


@app.get("/api/tickets/{ticket_id}", tags=["tickets"])
def get_ticket(ticket_id: int, db: Session = Depends(get_db)):
    t = db.get(Ticket, ticket_id)
    if not t:
        raise HTTPException(404, "Талон не найден")
    return _t(t)


@app.post("/api/tickets/{ticket_id}/cancel", tags=["tickets"])
def cancel_ticket(ticket_id: int, db: Session = Depends(get_db)):
    try:
        t = q.cancel(db, ticket_id, "Отменён клиентом")
        db.commit()
        resp = _t(t)
        broadcast_ticket_update(ticket_id, resp.model_dump(mode='json')) # <--- Уведомляем фронт
        return resp
    except ValueError as e:
        raise HTTPException(400, str(e))


@app.post("/api/tickets/{ticket_id}/complete", tags=["tickets"])
def complete_ticket(ticket_id: int, db: Session = Depends(get_db)):
    try:
        t = q.complete(db, ticket_id)
        db.commit()
        resp = _t(t)
        broadcast_ticket_update(ticket_id, resp.model_dump(mode='json')) # <--- Уведомляем фронт
        return resp
    except ValueError as e:
        raise HTTPException(400, str(e))


@app.post("/api/tickets/{ticket_id}/return", tags=["tickets"])
def return_ticket(ticket_id: int, db: Session = Depends(get_db)):
    try:
        t = q.return_to_queue(db, ticket_id, "Возврат оператором")
        db.commit()
        return _t(t)
    except ValueError as e:
        raise HTTPException(400, str(e))

@app.post("/api/tickets/{ticket_id}/activate", tags=["tickets"])
def activate_ticket(ticket_id: int, db: Session = Depends(get_db)):
    """Подтвердить приход клиента по предзаписи (перевести из scheduled в waiting)."""
    try:
        t = q.activate(db, ticket_id)
        db.commit()
        resp = _t(t)
        broadcast_ticket_update(ticket_id, resp.model_dump(mode='json')) # Уведомляем фронтенд по WebSocket
        return resp
    except ValueError as e:
        raise HTTPException(400, str(e))
# ---------------------------------------------------------------------------
# Окна
# ---------------------------------------------------------------------------

@app.post("/api/windows", tags=["windows"])
def open_window(payload: WindowOpen, db: Session = Depends(get_db), user: dict = Depends(require_role([OPERATOR, DIRECTOR]))):
    """Открыть окно оператора."""
    w = Window(branch_id=payload.branch_id, number=payload.number, is_open=1)
    db.add(w)
    db.commit()
    db.refresh(w)
    return {"id": w.id, "branch_id": w.branch_id, "number": w.number, "is_open": w.is_open}


@app.get("/api/windows", tags=["windows"])
def list_windows(db: Session = Depends(get_db)):
    return [
        {"id": w.id, "branch_id": w.branch_id, "number": w.number, "is_open": w.is_open}
        for w in db.query(Window).order_by(Window.id).all()
    ]


@app.post("/api/windows/{window_id}/call-next", tags=["windows"])
def call_next(window_id: int, db: Session = Depends(get_db), user: dict = Depends(require_role([OPERATOR, DIRECTOR]))):
    """Вызвать из общего пула (appointment + qr). Живая очередь НЕ участвует."""
    w = db.get(Window, window_id)
    if w is None:
        raise HTTPException(404, "Окно не найдено")

    sample = db.scalar(
        select(Ticket).where(
            Ticket.branch_id == w.branch_id,
            Ticket.source.in_(["appointment", "qr"]),
            Ticket.status.in_(["waiting", "scheduled"]),
        )
    )
    if not sample:
        return {"ticket": None, "message": "Общий пул пуст"}

    try:
        t = q.call_next_recorded(db, w.branch_id, sample.service_id, w.id)
        db.commit()
    except ValueError as e:
        raise HTTPException(400, str(e))

    if t is None:
        return {"ticket": None, "message": "Общий пул пуст"}
    
    db.refresh(t)
    ticket_data = _t(t).model_dump(mode='json')
    broadcast_ticket_update(t.id, ticket_data) # Уведомляем Flutter через WebSocket
    return {"ticket": ticket_data, "pool": "recorded"}


@app.post("/api/windows/{window_id}/call-live", tags=["windows"])
def call_live(window_id: int, db: Session = Depends(get_db), user: dict = Depends(require_role([OPERATOR, DIRECTOR]))):
    """Вызвать из живой очереди (source=live)."""
    w = db.get(Window, window_id)
    if w is None:
        raise HTTPException(404, "Окно не найдено")

    try:
        t = q.call_next_live(db, w.branch_id, w.id)
        db.commit()
    except ValueError as e:
        raise HTTPException(400, str(e))

    if t is None:
        return {"ticket": None, "message": "Живая очередь пуста"}
        
    db.refresh(t)
    ticket_data = _t(t).model_dump(mode='json')
    broadcast_ticket_update(t.id, ticket_data) # Уведомляем Flutter через WebSocket
    return {"ticket": ticket_data, "pool": "live"}


@app.post("/api/windows/{window_id}/close", tags=["windows"])
def close_window(window_id: int, db: Session = Depends(get_db), user: dict = Depends(require_role([OPERATOR, DIRECTOR]))):
    """Закрыть окно. Активный клиент возвращается в очередь."""
    returned = q.close_window(db, window_id)
    db.commit()
    return {
        "closed": window_id,
        "returned": _t(returned) if returned else None,
    }


# ---------------------------------------------------------------------------
# Справочники — отделения
# ---------------------------------------------------------------------------

@app.get("/api/branches", tags=["admin"])
def list_branches(db: Session = Depends(get_db)):
    """Список всех отделений."""
    return [{"id": b.id, "name": b.name} for b in db.query(Branch).order_by(Branch.id).all()]


@app.post("/api/branches", tags=["admin"])
def create_branch(payload: BranchCreate, db: Session = Depends(get_db), user: dict = Depends(require_role([ADMIN]))):
    """Создать отделение."""
    b = Branch(name=payload.name)
    db.add(b)
    db.commit()
    db.refresh(b)
    return {"id": b.id, "name": b.name}


# ---------------------------------------------------------------------------
# Аналитика и журнал
# ---------------------------------------------------------------------------

@app.get("/api/analytics", tags=["admin"])
def analytics(db: Session = Depends(get_db), user: dict = Depends(require_role([DIRECTOR]))):
    def count(status=None, source=None):
        stmt = select(func.count(Ticket.id))
        if status: stmt = stmt.where(Ticket.status == status)
        if source: stmt = stmt.where(Ticket.source == source)
        return db.scalar(stmt) or 0

    return {
        "total": count(),
        "waiting": count(status="waiting"),
        "called": count(status="called"),
        "completed": count(status="completed"),
        "by_source": {
            "appointment": count(source="appointment"),
            "qr": count(source="qr"),
            "live": count(source="live"),
        },
    }


@app.get("/api/logs", tags=["admin"])
def list_logs(db: Session = Depends(get_db), user: dict = Depends(require_role([ADMIN]))):
    rows = db.query(TicketLog).order_by(TicketLog.id.desc()).limit(100).all()
    return [
        {
            "id": l.id,
            "ticket_id": l.ticket_id,
            "event_type": l.event_type,
            "comment": l.comment,
            "timestamp": l.timestamp.isoformat(),
        }
        for l in rows
    ]


# ---------------------------------------------------------------------------
# Утилиты
# ---------------------------------------------------------------------------

def _next_code(db: Session) -> str:
    n = db.scalar(select(func.count(Ticket.id))) or 0
    return f"A-{n + 1:03d}"


def _t(t: Ticket) -> TicketResponse:
    dct = {
        "id": t.id,
        "number": t.public_code,
        "status": t.status,
        "estimated_wait_min": 0,
        "window_number": str(t.window_id) if t.window_id is not None else None,
        "source_type": t.source,
        "service_id": t.service_id,
        "client_token": "1",
        "created_at": t.created_at.isoformat() if t.created_at else None,
    }
    return TicketResponse(**dct)
# app/main.py
"""
FastAPI-приложение системы электронной очереди.
"""

from datetime import datetime

from app import auth

from app.auth import get_current_user

from fastapi import FastAPI, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.db import Base, engine, get_db, SessionLocal
from app.models import Branch, Window, Ticket, TicketLog
from app import queue as q


app = FastAPI(title="E-Queue MVP", version="0.1.0")

app.include_router(auth.router)
@app.get("/")
async def user(user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    if user is None:
        raise HTTPException(status_code=401, detail='Authentication Failed')
    return {"User": user}


@app.on_event("startup")
def on_startup():
    """Создаём таблицы и наполняем справочники, если пусто."""
    Base.metadata.create_all(bind=engine)
   # Base.metadata.drop_all(bind=engine)
    db = SessionLocal()
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
        return _t(t)
    except ValueError as e:
        raise HTTPException(400, str(e))


@app.post("/api/tickets/{ticket_id}/complete", tags=["tickets"])
def complete_ticket(ticket_id: int, db: Session = Depends(get_db)):
    try:
        t = q.complete(db, ticket_id)
        db.commit()
        return _t(t)
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


# ---------------------------------------------------------------------------
# Окна
# ---------------------------------------------------------------------------

@app.post("/api/windows", tags=["windows"])
def open_window(payload: WindowOpen, db: Session = Depends(get_db)):
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
def call_next(window_id: int, db: Session = Depends(get_db)):
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
    return {"ticket": _t(t), "pool": "recorded"}


@app.post("/api/windows/{window_id}/call-live", tags=["windows"])
def call_live(window_id: int, db: Session = Depends(get_db)):
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
    return {"ticket": _t(t), "pool": "live"}


@app.post("/api/windows/{window_id}/close", tags=["windows"])
def close_window(window_id: int, db: Session = Depends(get_db)):
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
def create_branch(payload: BranchCreate, db: Session = Depends(get_db)):
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
def analytics(db: Session = Depends(get_db)):
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
def list_logs(db: Session = Depends(get_db)):
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


def _t(t: Ticket) -> dict:
    return {
        "id": t.id,
        "public_code": t.public_code,
        "branch_id": t.branch_id,
        "service_id": t.service_id,
        "source": t.source,
        "status": t.status,
        "window_id": t.window_id,
        "scheduled_at": t.scheduled_at.isoformat() if t.scheduled_at else None,
        "created_at": t.created_at.isoformat() if t.created_at else None,
    }
# app/queue.py
"""
Бизнес-логика очереди.

Два независимых потока:
1. ОБЩИЙ ПУЛ: appointment + qr. Приоритеты: appointment=100, qr=60.
   Anti-starvation для qr (ждал >45 мин → вес 200).
   Опоздавшая предзапись (>15 мин) → вес 60 (как qr).
   Предзапись активируется за 10 минут до scheduled_at.

2. ЖИВАЯ ОЧЕРЕДЬ: source=live. Отдельно, FIFO по id.
   В общий пул не попадает. Оператор вызывает отдельным эндпоинтом.
"""

from datetime import datetime, timezone, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Ticket, TicketLog, Window


# ---------------------------------------------------------------------------
# Настройки
# ---------------------------------------------------------------------------

WEIGHT = {
    "appointment": 100,
    "qr": 60,
}

STARVATION_MINUTES = 45
STARVATION_BOOST = 200
ACTIVATION_MINUTES = 10
LATE_DOWNGRADE_MINUTES = 15


# ---------------------------------------------------------------------------
# Утилиты
# ---------------------------------------------------------------------------

def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt):
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


# ---------------------------------------------------------------------------
# Приоритеты (только для appointment и qr)
# ---------------------------------------------------------------------------

def priority_of(t: Ticket, now: datetime) -> float:
    """Вес талона. Применяется только к appointment и qr."""
    base = WEIGHT.get(t.source, 60)

    wait_min = (now - _aware(t.created_at)).total_seconds() / 60

    # Anti-starvation
    if wait_min >= STARVATION_MINUTES:
        base = STARVATION_BOOST

    # Опоздавшая предзапись понижается
    if t.source == "appointment" and t.scheduled_at:
        late_min = (now - _aware(t.scheduled_at)).total_seconds() / 60
        if late_min > LATE_DOWNGRADE_MINUTES:
            base = WEIGHT["qr"]

    return float(base)


def is_ready(t: Ticket, now: datetime) -> bool:
    """Созрел ли талон для вызова."""
    if t.status not in ("waiting", "scheduled"):
        return False
    if t.source != "appointment" or not t.scheduled_at:
        return True
    sched = _aware(t.scheduled_at)
    return now >= sched - timedelta(minutes=ACTIVATION_MINUTES)


# ---------------------------------------------------------------------------
# Журнал
# ---------------------------------------------------------------------------

def log_event(db: Session, ticket_id: int, event_type: str, comment: str = None):
    """Пишет событие в журнал. Не коммитит."""
    db.add(TicketLog(
        ticket_id=ticket_id,
        event_type=event_type,
        comment=comment,
    ))


# ---------------------------------------------------------------------------
# Вызов следующего
# ---------------------------------------------------------------------------

def call_next_recorded(db: Session, branch_id: int, service_id: int, window_id: int):
    """
    Вызвать следующего из ОБЩЕГО ПУЛА (appointment + qr).
    Живая очередь (live) НЕ участвует.

    Защита от двойного назначения — FOR UPDATE SKIP LOCKED.
    """
    now = now_utc()

    stmt = (
        select(Ticket)
        .where(
            Ticket.branch_id == branch_id,
            Ticket.service_id == service_id,
            Ticket.source.in_(["appointment", "qr"]),
            Ticket.status.in_(["waiting", "scheduled"]),
        )
        .with_for_update(skip_locked=True)
    )
    candidates = [t for t in db.scalars(stmt).all() if is_ready(t, now)]
    if not candidates:
        return None

    best = max(
        candidates,
        key=lambda t: (priority_of(t, now), -_aware(t.created_at).timestamp()),
    )

    best.status = "called"
    best.window_id = window_id
    log_event(db, best.id, "call", f"Вызван в окно {window_id} (общий пул)")
    db.flush()
    return best


def call_next_live(db: Session, branch_id: int, window_id: int):
    """
    Вызвать следующего из ЖИВОЙ очереди (source=live).
    FIFO по id. Приоритеты не применяются.
    """
    stmt = (
        select(Ticket)
        .where(
            Ticket.branch_id == branch_id,
            Ticket.source == "live",
            Ticket.status == "waiting",
        )
        .order_by(Ticket.id)
        .with_for_update(skip_locked=True)
        .limit(1)
    )
    t = db.scalars(stmt).first()
    if t is None:
        return None

    t.status = "called"
    t.window_id = window_id
    log_event(db, t.id, "call", f"Вызван из живой очереди в окно {window_id}")
    db.flush()
    return t


# ---------------------------------------------------------------------------
# Остальные операции
# ---------------------------------------------------------------------------

def complete(db: Session, ticket_id: int):
    """Завершить обслуживание."""
    t = db.get(Ticket, ticket_id)
    if t is None:
        raise ValueError("Талон не найден")
    if t.status != "called":
        raise ValueError(f"Нельзя завершить талон в статусе {t.status}")

    t.status = "completed"
    log_event(db, t.id, "complete", "Обслуживание завершено")
    db.flush()
    return t


def cancel(db: Session, ticket_id: int, reason: str = "Отменён"):
    """Отменить талон."""
    t = db.get(Ticket, ticket_id)
    if t is None:
        raise ValueError("Талон не найден")
    if t.status in ("completed", "canceled"):
        raise ValueError(f"Талон уже {t.status}")

    t.status = "canceled"
    t.window_id = None
    log_event(db, t.id, "cancel", reason)
    db.flush()
    return t


def return_to_queue(db: Session, ticket_id: int, reason: str):
    """Вернуть вызванный талон в очередь."""
    t = db.get(Ticket, ticket_id)
    if t is None:
        raise ValueError("Талон не найден")
    if t.status != "called":
        raise ValueError(f"Нельзя вернуть талон в статусе {t.status}")

    t.status = "waiting"
    t.window_id = None
    log_event(db, t.id, "return_to_queue", reason)
    db.flush()
    return t


def close_window(db: Session, window_id: int):
    """
    Закрыть окно. Активный клиент (status=called) возвращается в очередь.
    """
    active = db.scalar(
        select(Ticket).where(
            Ticket.window_id == window_id,
            Ticket.status == "called",
        )
    )

    returned = None
    if active:
        returned = return_to_queue(
            db, active.id, f"Окно {window_id} закрыто — талон возвращён в очередь"
        )

    w = db.get(Window, window_id)
    if w:
        w.is_open = 0

    db.flush()
    return returned
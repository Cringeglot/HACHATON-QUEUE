# app/models.py
"""
Модели SQLAlchemy. 4 таблицы:
- branches    — отделения
- windows     — окна операторов
- tickets     — талоны
- ticket_logs — журнал событий
"""

from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, DateTime, Text

from app.db import Base


def utcnow():
    return datetime.now(timezone.utc)


class Branch(Base):
    """Отделение почты."""
    __tablename__ = "branches"
    id = Column(Integer, primary_key=True)
    name = Column(String(200), nullable=False)

class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True)
    username = Column(String(50), unique=True)
    hashed_password = Column(String(100))

class Window(Base):
    """Окно оператора."""
    __tablename__ = "windows"
    id = Column(Integer, primary_key=True)
    branch_id = Column(Integer, nullable=False, index=True)
    number = Column(String(16), nullable=False)
    is_open = Column(Integer, default=0)


class Ticket(Base):
    """Талон."""
    __tablename__ = "tickets"

    id = Column(Integer, primary_key=True)
    public_code = Column(String(10), nullable=False)
    branch_id = Column(Integer, nullable=False, index=True)
    service_id = Column(Integer, nullable=False)

    # source: "appointment" | "qr" | "live"
    source = Column(String(20), nullable=False, default="qr")

    # status: "scheduled" | "waiting" | "called" | "completed" | "canceled"
    status = Column(String(20), nullable=False, default="waiting", index=True)

    window_id = Column(Integer, nullable=True)
    scheduled_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)


class TicketLog(Base):
    """Append-only журнал событий талона."""
    __tablename__ = "ticket_logs"

    id = Column(Integer, primary_key=True)
    ticket_id = Column(Integer, nullable=False, index=True)
    event_type = Column(String(50), nullable=False)
    comment = Column(Text, nullable=True)
    timestamp = Column(DateTime(timezone=True), default=utcnow, nullable=False)
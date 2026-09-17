from datetime import datetime, timezone
from app.core.config import QueueSettings

def calculate_ticket_score(ticket, current_time):
    if ticket.source == "pre_registration":
        base_score = QueueSettings.PRIORITY_PRE_REGISTRATION
    elif ticket.source == "qr":
        base_score = QueueSettings.PRIORITY_QR
    else:
        base_score = QueueSettings.PRIORITY_LIVE

    wait_time_minutes = (current_time - ticket.created_at).total_seconds()/60
    bonus_score = wait_time_minutes * QueueSettings.WAIT_TIME_MULTIPLIER

    return base_score+bonus_score

def gen_next_client(db_session, service_id):
    current_time = datetime.now(timezone.utc)

    waiting_tickets = db_session.query(Ticket).filter(
        Ticket.service_id == service_id,
        Ticket.status == "waiting"
    ).all()

    if not waiting_tickets:
        return None

    waiting_tickets.sort(
        key = lambda t: (calculate_ticket_score(t, current_time), t.created_at.timestamp()),
        reverse = True
    )

    return waiting_tickets[0]
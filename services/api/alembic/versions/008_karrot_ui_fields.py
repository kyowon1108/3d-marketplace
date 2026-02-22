"""add karrot-style UI fields

Revision ID: 008
Revises: 007
Create Date: 2026-02-23
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "008"
down_revision: str | None = "007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Users: trust score and location
    op.add_column(
        "users",
        sa.Column("trust_score", sa.Float(), nullable=False, server_default="36.5"),
    )
    op.add_column(
        "users",
        sa.Column("location_name", sa.String(200), nullable=True),
    )

    # Products: sale status
    op.add_column(
        "products",
        sa.Column("status", sa.String(20), nullable=False, server_default="FOR_SALE"),
    )

    # Chat rooms: last message body + unread tracking
    op.add_column(
        "chat_rooms",
        sa.Column("last_message_body", sa.Text(), nullable=True),
    )
    op.add_column(
        "chat_rooms",
        sa.Column("buyer_last_read_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "chat_rooms",
        sa.Column("seller_last_read_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("chat_rooms", "seller_last_read_at")
    op.drop_column("chat_rooms", "buyer_last_read_at")
    op.drop_column("chat_rooms", "last_message_body")
    op.drop_column("products", "status")
    op.drop_column("users", "location_name")
    op.drop_column("users", "trust_score")

"""add message_type and image_url to chat_messages

Revision ID: 013
Revises: 012
Create Date: 2026-02-25
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "013"
down_revision: str | None = "012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "chat_messages",
        sa.Column("message_type", sa.String(20), server_default="TEXT", nullable=False),
    )
    op.add_column(
        "chat_messages",
        sa.Column("image_url", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("chat_messages", "image_url")
    op.drop_column("chat_messages", "message_type")

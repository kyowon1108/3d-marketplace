"""remove trust score

Revision ID: 009
Revises: 008
Create Date: 2026-02-23
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "009"
down_revision: str | None = "008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

def upgrade() -> None:
    op.drop_column("users", "trust_score")

def downgrade() -> None:
    op.add_column(
        "users",
        sa.Column("trust_score", sa.Float(), nullable=False, server_default="36.5"),
    )

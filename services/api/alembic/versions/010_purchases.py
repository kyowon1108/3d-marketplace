"""add purchases table

Revision ID: 010
Revises: 009
Create Date: 2026-02-23
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "010"
down_revision: str | None = "009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "purchases",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("product_id", sa.Uuid(), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("buyer_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("price_cents", sa.BigInteger(), nullable=False),
        sa.Column(
            "purchased_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_purchases_buyer_id", "purchases", ["buyer_id"])
    op.create_index("ix_purchases_product_id", "purchases", ["product_id"])


def downgrade() -> None:
    op.drop_index("ix_purchases_product_id", table_name="purchases")
    op.drop_index("ix_purchases_buyer_id", table_name="purchases")
    op.drop_table("purchases")

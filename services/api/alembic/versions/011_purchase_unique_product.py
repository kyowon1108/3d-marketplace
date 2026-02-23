"""add unique constraint on purchases.product_id

Revision ID: 011
Revises: 010
Create Date: 2026-02-23
"""

from collections.abc import Sequence

from alembic import op

revision: str = "011"
down_revision: str | None = "010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_unique_constraint("uq_purchases_product_id", "purchases", ["product_id"])


def downgrade() -> None:
    op.drop_constraint("uq_purchases_product_id", "purchases", type_="unique")

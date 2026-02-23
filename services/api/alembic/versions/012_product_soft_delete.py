"""add deleted_at column to products for soft delete

Revision ID: 012
Revises: 011
Create Date: 2026-02-24
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "012"
down_revision: str | None = "011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("products", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_products_deleted_at", "products", ["deleted_at"])


def downgrade() -> None:
    op.drop_index("ix_products_deleted_at", table_name="products")
    op.drop_column("products", "deleted_at")

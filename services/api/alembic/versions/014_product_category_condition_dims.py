"""add category, condition, dims_comparison to products

Revision ID: 014
Revises: 013
Create Date: 2026-02-26
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "014"
down_revision: str | None = "013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Enum allowed values for CHECK constraints
CATEGORY_VALUES = (
    "'ELECTRONICS','FURNITURE','CLOTHING','BOOKS_MEDIA',"
    "'SPORTS','LIVING','BEAUTY','HOBBY','OTHER'"
)
CONDITION_VALUES = "'NEW','LIKE_NEW','USED','WORN'"


def upgrade() -> None:
    op.add_column("products", sa.Column("category", sa.String(30), nullable=True))
    op.add_column("products", sa.Column("condition", sa.String(20), nullable=True))
    op.add_column("products", sa.Column("dims_comparison", sa.Text(), nullable=True))

    op.create_check_constraint(
        "ck_products_category",
        "products",
        f"category IN ({CATEGORY_VALUES}) OR category IS NULL",
    )
    op.create_check_constraint(
        "ck_products_condition",
        "products",
        f"condition IN ({CONDITION_VALUES}) OR condition IS NULL",
    )

    op.create_index(
        "ix_products_category_published_at",
        "products",
        ["category", "published_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_products_category_published_at", table_name="products")
    op.drop_constraint("ck_products_condition", "products", type_="check")
    op.drop_constraint("ck_products_category", "products", type_="check")
    op.drop_column("products", "dims_comparison")
    op.drop_column("products", "condition")
    op.drop_column("products", "category")

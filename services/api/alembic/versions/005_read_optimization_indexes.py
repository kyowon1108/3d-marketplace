"""read optimization indexes

Revision ID: 005
Revises: 004
Create Date: 2026-02-22
"""

from collections.abc import Sequence

from alembic import op

revision: str = "005"
down_revision: str | None = "004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index("ix_products_asset_id", "products", ["asset_id"])
    op.create_index("ix_chat_rooms_product_id", "chat_rooms", ["product_id"])
    op.create_index("ix_chat_rooms_buyer_id", "chat_rooms", ["buyer_id"])
    op.create_index("ix_chat_rooms_seller_id", "chat_rooms", ["seller_id"])


def downgrade() -> None:
    op.drop_index("ix_chat_rooms_seller_id", table_name="chat_rooms")
    op.drop_index("ix_chat_rooms_buyer_id", table_name="chat_rooms")
    op.drop_index("ix_chat_rooms_product_id", table_name="chat_rooms")
    op.drop_index("ix_products_asset_id", table_name="products")

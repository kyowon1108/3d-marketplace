"""add asset_images, product_likes, avatar_url, likes/views counts

Revision ID: 006
Revises: 005
Create Date: 2026-02-22
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "006"
down_revision: str | None = "005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. users.avatar_url
    op.add_column("users", sa.Column("avatar_url", sa.String(500), nullable=True))

    # 2. products.likes_count, views_count
    op.add_column(
        "products",
        sa.Column("likes_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "products",
        sa.Column("views_count", sa.Integer(), nullable=False, server_default="0"),
    )

    # 3. asset_images
    op.create_table(
        "asset_images",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("asset_id", sa.Uuid(), sa.ForeignKey("model_assets.id"), nullable=False),
        sa.Column("image_type", sa.String(20), nullable=False),
        sa.Column("storage_key", sa.String(500), nullable=False, unique=True),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("checksum_sha256", sa.String(64), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_asset_images_asset_id", "asset_images", ["asset_id"])

    # 4. product_likes
    op.create_table(
        "product_likes",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("product_id", sa.Uuid(), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("product_id", "user_id", name="uq_product_like_user"),
    )
    op.create_index("ix_product_likes_product_id", "product_likes", ["product_id"])
    op.create_index("ix_product_likes_user_id", "product_likes", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_product_likes_user_id", table_name="product_likes")
    op.drop_index("ix_product_likes_product_id", table_name="product_likes")
    op.drop_table("product_likes")
    op.drop_index("ix_asset_images_asset_id", table_name="asset_images")
    op.drop_table("asset_images")
    op.drop_column("products", "views_count")
    op.drop_column("products", "likes_count")
    op.drop_column("users", "avatar_url")

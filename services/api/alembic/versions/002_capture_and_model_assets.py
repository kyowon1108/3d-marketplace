"""capture sessions and model asset tables

Revision ID: 002
Revises: 001
Create Date: 2026-02-22
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "002"
down_revision: str | None = "001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "capture_sessions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("owner_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("device_info", sa.String(500), nullable=True),
        sa.Column("frame_count", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    op.create_table(
        "model_assets",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("owner_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="INITIATED"),
        sa.Column("dims_source", sa.String(20), nullable=True),
        sa.Column("dims_width", sa.Float(), nullable=True),
        sa.Column("dims_height", sa.Float(), nullable=True),
        sa.Column("dims_depth", sa.Float(), nullable=True),
        sa.Column(
            "capture_session_id",
            sa.Uuid(),
            sa.ForeignKey("capture_sessions.id"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_model_assets_owner_status", "model_assets", ["owner_id", "status"])

    op.create_table(
        "model_asset_files",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("asset_id", sa.Uuid(), sa.ForeignKey("model_assets.id"), nullable=False),
        sa.Column("file_role", sa.String(20), nullable=False),
        sa.Column("storage_key", sa.String(500), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("checksum_sha256", sa.String(64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint("asset_id", "file_role", name="uq_asset_file_role"),
        sa.UniqueConstraint("storage_key", name="uq_storage_key"),
    )
    op.create_index("ix_model_asset_files_asset_id", "model_asset_files", ["asset_id"])


def downgrade() -> None:
    op.drop_table("model_asset_files")
    op.drop_table("model_assets")
    op.drop_table("capture_sessions")

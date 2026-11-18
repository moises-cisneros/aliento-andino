"""Tests de modelos: instanciación, constraints únicos y comportamiento de FK (#119)."""

import uuid
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from sqlalchemy import delete, event, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401  (registra todas las tablas en Base.metadata)
from app.database import Base
from app.models.lesson import Category, Lesson, NoteSequence, PracticeSession
from app.models.social import Post
from app.models.user import RefreshToken, User


def make_user(suffix: str = "a") -> User:
    return User(
        email=f"{suffix}@example.com",
        username=f"user_{suffix}",
        full_name=f"User {suffix}",
        hashed_password="x",
    )


def make_category(name: str = "Escalas") -> Category:
    return Category(name=name)


def make_lesson(category_id: uuid.UUID, created_by: uuid.UUID | None = None) -> Lesson:
    return Lesson(
        category_id=category_id,
        title="Lección 1",
        description="Descripción",
        difficulty="principiante",
        tempo_bpm=80,
        created_by=created_by,
    )


def make_session(
    user_id: uuid.UUID, lesson_id: uuid.UUID, client_id: str | None = None
) -> PracticeSession:
    return PracticeSession(
        user_id=user_id,
        lesson_id=lesson_id,
        client_id=client_id,
        score=90.0,
        correct_notes=9,
        total_notes=10,
        wrong_notes=1,
        missed_notes=0,
        average_tempo=80.0,
        expected_tempo=80,
        tempo_accuracy=0.95,
        total_time_seconds=30.0,
    )


async def seed_basics(session: AsyncSession) -> tuple[User, Lesson]:
    user = make_user()
    category = make_category()
    session.add_all([user, category])
    await session.flush()
    lesson = make_lesson(category.id, user.id)
    session.add(lesson)
    await session.flush()
    return user, lesson


@pytest_asyncio.fixture
async def fk_session():
    """Sesión sobre una SQLite propia con claves foráneas activas (FK enforcement)."""
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(engine.sync_engine, "connect")
    def _enable_fk(dbapi_conn, _record):
        dbapi_conn.execute("PRAGMA foreign_keys=ON")

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)() as s:
        yield s
    await engine.dispose()


class TestInstantiation:
    async def test_user_defaults_and_uuid_pk(self, db_session: AsyncSession):
        user = make_user()
        db_session.add(user)
        await db_session.commit()
        await db_session.refresh(user)

        assert isinstance(user.id, uuid.UUID)
        assert user.is_active is True
        assert user.is_admin is False
        assert user.subscription_status == "free"
        assert user.xp_level == 1
        assert user.is_premium is False

    async def test_primary_keys_are_unique_uuids(self, db_session: AsyncSession):
        users = [make_user("a"), make_user("b")]
        db_session.add_all(users)
        await db_session.commit()
        assert all(isinstance(u.id, uuid.UUID) for u in users)
        assert users[0].id != users[1].id

    async def test_lesson_defaults(self, db_session: AsyncSession):
        _, lesson = await seed_basics(db_session)
        await db_session.commit()
        await db_session.refresh(lesson)

        assert isinstance(lesson.id, uuid.UUID)
        assert lesson.instrument == "quena"
        assert lesson.is_active is True
        assert lesson.is_premium is False
        assert lesson.total_plays == 0

    async def test_created_at_is_populated_in_utc(self, db_session: AsyncSession):
        user = make_user()
        db_session.add(user)
        await db_session.commit()
        await db_session.refresh(user)

        created = user.created_at
        assert created is not None
        # SQLite devuelve naive; PostgreSQL aware. En ambos casos debe ser hora UTC.
        if created.tzinfo is None:
            created = created.replace(tzinfo=UTC)
        assert abs(datetime.now(UTC) - created) < timedelta(minutes=1)
        assert created.utcoffset() == timedelta(0)

    def test_created_at_column_is_timezone_aware(self):
        for table in ("users", "lessons", "practice_sessions", "posts"):
            assert Base.metadata.tables[table].c.created_at.type.timezone is True

    async def test_updated_at_is_null_until_update(self, db_session: AsyncSession):
        user = make_user()
        db_session.add(user)
        await db_session.commit()
        await db_session.refresh(user)
        assert user.updated_at is None

        user.full_name = "Cambiado"
        await db_session.commit()
        await db_session.refresh(user)
        assert user.updated_at is not None


class TestUniqueConstraints:
    async def test_duplicate_client_id_raises_integrity_error(self, db_session: AsyncSession):
        user, lesson = await seed_basics(db_session)
        db_session.add(make_session(user.id, lesson.id, client_id="client-1"))
        await db_session.commit()

        db_session.add(make_session(user.id, lesson.id, client_id="client-1"))
        with pytest.raises(IntegrityError):
            await db_session.commit()
        await db_session.rollback()

    async def test_null_client_ids_can_coexist(self, db_session: AsyncSession):
        user, lesson = await seed_basics(db_session)
        db_session.add_all([make_session(user.id, lesson.id), make_session(user.id, lesson.id)])
        await db_session.commit()
        rows = (await db_session.execute(select(PracticeSession))).scalars().all()
        assert len(rows) == 2

    async def test_duplicate_email_raises_integrity_error(self, db_session: AsyncSession):
        db_session.add(make_user("a"))
        await db_session.commit()

        other = make_user("b")
        other.email = "a@example.com"
        db_session.add(other)
        with pytest.raises(IntegrityError):
            await db_session.commit()
        await db_session.rollback()

    async def test_duplicate_username_raises_integrity_error(self, db_session: AsyncSession):
        db_session.add(make_user("a"))
        await db_session.commit()

        other = make_user("b")
        other.username = "user_a"
        db_session.add(other)
        with pytest.raises(IntegrityError):
            await db_session.commit()
        await db_session.rollback()

    async def test_duplicate_category_name_raises_integrity_error(self, db_session: AsyncSession):
        db_session.add(make_category("Escalas"))
        await db_session.commit()
        db_session.add(make_category("Escalas"))
        with pytest.raises(IntegrityError):
            await db_session.commit()
        await db_session.rollback()

    async def test_user_email_is_required(self, db_session: AsyncSession):
        user = make_user()
        user.email = None
        db_session.add(user)
        with pytest.raises(IntegrityError):
            await db_session.commit()
        await db_session.rollback()


class TestForeignKeyOnDelete:
    async def test_delete_category_cascades_to_lessons_and_notes(self, fk_session: AsyncSession):
        _, lesson = await seed_basics(fk_session)
        fk_session.add(NoteSequence(lesson_id=lesson.id, position=0, note="C4", duration=1.0))
        await fk_session.commit()

        await fk_session.execute(delete(Category))
        await fk_session.commit()

        assert (await fk_session.execute(select(Lesson))).scalars().all() == []
        assert (await fk_session.execute(select(NoteSequence))).scalars().all() == []

    async def test_delete_user_cascades_to_sessions_and_refresh_tokens(
        self, fk_session: AsyncSession
    ):
        user, lesson = await seed_basics(fk_session)
        fk_session.add(make_session(user.id, lesson.id, client_id="c-1"))
        fk_session.add(
            RefreshToken(
                token_jti=str(uuid.uuid4()),
                user_id=user.id,
                expires_at=datetime.now(UTC) + timedelta(days=7),
            )
        )
        await fk_session.commit()

        await fk_session.execute(delete(User))
        await fk_session.commit()

        assert (await fk_session.execute(select(PracticeSession))).scalars().all() == []
        assert (await fk_session.execute(select(RefreshToken))).scalars().all() == []

    async def test_delete_user_sets_lesson_created_by_null(self, fk_session: AsyncSession):
        user, lesson = await seed_basics(fk_session)
        await fk_session.commit()
        lesson_id = lesson.id

        await fk_session.execute(delete(User).where(User.id == user.id))
        await fk_session.commit()
        fk_session.expire_all()

        remaining = (
            await fk_session.execute(select(Lesson).where(Lesson.id == lesson_id))
        ).scalar_one()
        assert remaining.created_by is None

    async def test_delete_practice_session_sets_post_reference_null(self, fk_session: AsyncSession):
        user, lesson = await seed_basics(fk_session)
        practice = make_session(user.id, lesson.id, client_id="c-2")
        fk_session.add(practice)
        await fk_session.flush()
        post = Post(user_id=user.id, content="hola", practice_session_id=practice.id)
        fk_session.add(post)
        await fk_session.commit()
        post_id = post.id

        await fk_session.execute(delete(PracticeSession))
        await fk_session.commit()
        fk_session.expire_all()

        remaining = (await fk_session.execute(select(Post).where(Post.id == post_id))).scalar_one()
        assert remaining.practice_session_id is None

    async def test_orphan_foreign_key_is_rejected(self, fk_session: AsyncSession):
        fk_session.add(make_lesson(category_id=uuid.uuid4()))
        with pytest.raises(IntegrityError):
            await fk_session.commit()
        await fk_session.rollback()

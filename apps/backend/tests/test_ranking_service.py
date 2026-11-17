"""Tests de las funciones puras de gamificación (XP, niveles, semana)."""

from datetime import UTC, datetime

import pytest

from app.services.ranking_service import (
    calculate_level,
    calculate_session_xp,
    get_current_week_monday,
    xp_for_level,
)


class TestCalculateSessionXp:
    @pytest.mark.parametrize(
        "score, difficulty, completed, expected",
        [
            # base(10) + precision + completion(15 si completed), * multiplicador
            (100.0, "principiante", True, 75),  # (10+50+15)*1.0
            (100.0, "avanzado", True, 150),  # (10+50+15)*2.0
            (90.0, "intermedio", True, 82),  # (10+30+15)*1.5 = 82.5 -> 82
            (85.0, "intermedio", True, 67),  # (10+20+15)*1.5 = 67.5 -> 67
            (50.0, "principiante", False, 10),  # (10+0+0)*1.0
            (75.0, "avanzado", False, 40),  # (10+10+0)*2.0
        ],
    )
    def test_xp_values(self, score, difficulty, completed, expected):
        assert calculate_session_xp(score, difficulty, completed) == expected

    def test_unknown_difficulty_defaults_to_multiplier_one(self):
        # dificultad desconocida -> multiplicador 1.0
        assert calculate_session_xp(100.0, "imposible", True) == 75

    def test_completion_bonus_only_when_completed(self):
        with_bonus = calculate_session_xp(60.0, "principiante", True)
        without_bonus = calculate_session_xp(60.0, "principiante", False)
        assert with_bonus - without_bonus == 15


class TestLevels:
    @pytest.mark.parametrize(
        "total_xp, expected_level",
        [(0, 1), (99, 1), (100, 2), (399, 2), (400, 3), (900, 4)],
    )
    def test_calculate_level(self, total_xp, expected_level):
        assert calculate_level(total_xp) == expected_level

    @pytest.mark.parametrize(
        "level, expected_xp",
        [(1, 0), (2, 100), (3, 400), (4, 900)],
    )
    def test_xp_for_level(self, level, expected_xp):
        assert xp_for_level(level) == expected_xp

    def test_level_and_xp_are_inverse(self):
        # El XP justo para alcanzar un nivel debe mapear de vuelta a ese nivel.
        for level in range(1, 10):
            assert calculate_level(xp_for_level(level)) == level


class TestWeekMonday:
    def test_returns_a_monday(self):
        monday = get_current_week_monday()
        assert monday.weekday() == 0

    def test_not_in_the_future(self):
        assert get_current_week_monday() <= datetime.now(UTC).date()

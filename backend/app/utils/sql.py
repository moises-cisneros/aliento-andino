"""Helpers SQL portables entre dialectos (Postgres en prod, SQLite en tests)."""

from sqlalchemy.ext.compiler import compiles
from sqlalchemy.sql import expression


class greatest(expression.FunctionElement):
    """`GREATEST(a, b, ...)` portable.

    Postgres tiene `greatest()` nativo; SQLite no, pero su `max(a, b, ...)`
    escalar (con 2+ argumentos) es equivalente. Usar este helper en lugar de
    `func.greatest` para que los counters con clamp a 0 funcionen en ambos.
    """

    name = "greatest"
    inherit_cache = True


@compiles(greatest)
def _default_greatest(element, compiler, **kw):
    return compiler.visit_function(element)


@compiles(greatest, "sqlite")
def _sqlite_greatest(element, compiler, **kw):
    return "max(%s)" % compiler.process(element.clauses, **kw)

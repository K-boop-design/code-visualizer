import ast
import json
import sys
from typing import Any, Optional


class ASTParser:
    def parse(self, code: str) -> dict:
        tree = ast.parse(code)
        return self._visit(tree)

    def _visit(self, node) -> Optional[dict]:
        if node is None:
            return None
        node_type = type(node).__name__
        handler = getattr(self, f"visit_{node_type}", self._generic_visit)
        return handler(node)

    def _generic_visit(self, node: ast.AST) -> dict:
        result: dict = {
            "type": type(node).__name__,
            "lineno": getattr(node, "lineno", None),
            "col_offset": getattr(node, "col_offset", None),
            "end_lineno": getattr(node, "end_lineno", None),
            "end_col_offset": getattr(node, "end_col_offset", None),
        }
        for field, value in ast.iter_fields(node):
            if isinstance(value, list):
                children = []
                for item in value:
                    if isinstance(item, ast.AST):
                        child = self._visit(item)
                        if child:
                            children.append(child)
                    else:
                        children.append({"value": repr(item)})
                if children:
                    result[field] = children
            elif isinstance(value, ast.AST):
                child = self._visit(value)
                if child:
                    result[field] = child
            elif value is not None:
                result[field] = repr(value)
        return result

    def visit_FunctionDef(self, node: ast.FunctionDef) -> dict:
        result = {
            "type": "FunctionDef",
            "name": node.name,
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "decorators": [self._visit(d) for d in node.decorator_list] if node.decorator_list else [],
            "args": self._visit(node.args) if node.args else [],
            "body": [self._visit(stmt) for stmt in node.body],
        }
        if node.returns:
            result["returns"] = self._visit(node.returns)
        return result

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> dict:
        result = self.visit_FunctionDef(node)
        result["type"] = "AsyncFunctionDef"
        return result

    def visit_ClassDef(self, node: ast.ClassDef) -> dict:
        return {
            "type": "ClassDef",
            "name": node.name,
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "bases": [self._visit(b) for b in node.bases] if node.bases else [],
            "decorators": [self._visit(d) for d in node.decorator_list] if node.decorator_list else [],
            "body": [self._visit(stmt) for stmt in node.body],
        }

    def visit_If(self, node: ast.If) -> dict:
        return {
            "type": "If",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "test": self._visit(node.test),
            "body": [self._visit(stmt) for stmt in node.body],
            "orelse": [self._visit(stmt) for stmt in node.orelse] if node.orelse else [],
        }

    def visit_For(self, node: ast.For) -> dict:
        return {
            "type": "For",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "target": self._visit(node.target),
            "iter": self._visit(node.iter),
            "body": [self._visit(stmt) for stmt in node.body],
            "orelse": [self._visit(stmt) for stmt in node.orelse] if node.orelse else [],
        }

    def visit_AsyncFor(self, node: ast.AsyncFor) -> dict:
        result = self.visit_For(node)
        result["type"] = "AsyncFor"
        return result

    def visit_While(self, node: ast.While) -> dict:
        return {
            "type": "While",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "test": self._visit(node.test),
            "body": [self._visit(stmt) for stmt in node.body],
            "orelse": [self._visit(stmt) for stmt in node.orelse] if node.orelse else [],
        }

    def visit_Try(self, node: ast.Try) -> dict:
        result = {
            "type": "Try",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "body": [self._visit(stmt) for stmt in node.body],
            "handlers": [self._visit(h) for h in node.handlers] if node.handlers else [],
            "orelse": [self._visit(stmt) for stmt in node.orelse] if node.orelse else [],
            "finalbody": [self._visit(stmt) for stmt in node.finalbody] if node.finalbody else [],
        }
        return result

    def visit_ExceptHandler(self, node: ast.ExceptHandler) -> dict:
        return {
            "type": "ExceptHandler",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "exception_type": self._visit(node.type) if node.type else None,
            "name": node.name or "",
            "body": [self._visit(stmt) for stmt in node.body],
        }

    def visit_With(self, node: ast.With) -> dict:
        return {
            "type": "With",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "items": [self._visit(item) for item in node.items],
            "body": [self._visit(stmt) for stmt in node.body],
        }

    def visit_withitem(self, node: ast.withitem) -> dict:
        result = {
            "context_expr": self._visit(node.context_expr),
        }
        if node.optional_vars:
            result["optional_vars"] = self._visit(node.optional_vars)
        return result

    def visit_Assign(self, node: ast.Assign) -> dict:
        return {
            "type": "Assign",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "targets": [self._visit(t) for t in node.targets],
            "value": self._visit(node.value),
        }

    def visit_AugAssign(self, node: ast.AugAssign) -> dict:
        return {
            "type": "AugAssign",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "target": self._visit(node.target),
            "op": type(node.op).__name__,
            "value": self._visit(node.value),
        }

    def visit_AnnAssign(self, node: ast.AnnAssign) -> dict:
        result = {
            "type": "AnnAssign",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "target": self._visit(node.target),
            "annotation": self._visit(node.annotation),
        }
        if node.value:
            result["value"] = self._visit(node.value)
        return result

    def visit_Expr(self, node: ast.Expr) -> dict:
        return {
            "type": "Expr",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "value": self._visit(node.value),
        }

    def visit_Call(self, node: ast.Call) -> dict:
        result = {
            "type": "Call",
            "lineno": node.lineno,
            "end_lineno": node.end_lineno,
            "func": self._visit(node.func),
            "args": [self._visit(a) for a in node.args] if node.args else [],
            "keywords": [self._visit(kw) for kw in node.keywords] if node.keywords else [],
        }
        return result

    def visit_keyword(self, node: ast.keyword) -> dict:
        result = {"value": self._visit(node.value)}
        if node.arg:
            result["arg"] = node.arg
        return result

    def visit_Name(self, node: ast.Name) -> dict:
        return {"type": "Name", "id": node.id, "ctx": type(node.ctx).__name__}

    def visit_Attribute(self, node: ast.Attribute) -> dict:
        return {
            "type": "Attribute",
            "value": self._visit(node.value),
            "attr": node.attr,
            "ctx": type(node.ctx).__name__,
        }

    def visit_Subscript(self, node: ast.Subscript) -> dict:
        return {
            "type": "Subscript",
            "value": self._visit(node.value),
            "slice": self._visit(node.slice),
            "ctx": type(node.ctx).__name__,
        }

    def visit_Constant(self, node: ast.Constant) -> dict:
        val = node.value
        if isinstance(val, str):
            val = val[:200]
        return {"type": "Constant", "value": repr(val), "kind": node.kind}

    def visit_List(self, node: ast.List) -> dict:
        return {
            "type": "List",
            "elts": [self._visit(e) for e in node.elts] if node.elts else [],
            "ctx": type(node.ctx).__name__,
        }

    def visit_Dict(self, node: ast.Dict) -> dict:
        return {
            "type": "Dict",
            "keys": [self._visit(k) for k in node.keys] if node.keys else [],
            "values": [self._visit(v) for v in node.values] if node.values else [],
        }

    def visit_Tuple(self, node: ast.Tuple) -> dict:
        return {
            "type": "Tuple",
            "elts": [self._visit(e) for e in node.elts] if node.elts else [],
            "ctx": type(node.ctx).__name__,
        }

    def visit_Set(self, node: ast.Set) -> dict:
        return {
            "type": "Set",
            "elts": [self._visit(e) for e in node.elts] if node.elts else [],
        }

    def visit_ListComp(self, node: ast.ListComp) -> dict:
        return {
            "type": "ListComp",
            "lineno": node.lineno,
            "elt": self._visit(node.elt),
            "generators": [self._visit(g) for g in node.generators],
        }

    def visit_DictComp(self, node: ast.DictComp) -> dict:
        return {
            "type": "DictComp",
            "lineno": node.lineno,
            "key": self._visit(node.key),
            "value": self._visit(node.value),
            "generators": [self._visit(g) for g in node.generators],
        }

    def visit_SetComp(self, node: ast.SetComp) -> dict:
        return {
            "type": "SetComp",
            "lineno": node.lineno,
            "elt": self._visit(node.elt),
            "generators": [self._visit(g) for g in node.generators],
        }

    def visit_GeneratorExp(self, node: ast.GeneratorExp) -> dict:
        return {
            "type": "GeneratorExp",
            "lineno": node.lineno,
            "elt": self._visit(node.elt),
            "generators": [self._visit(g) for g in node.generators],
        }

    def visit_comprehension(self, node: ast.comprehension) -> dict:
        result = {
            "target": self._visit(node.target),
            "iter": self._visit(node.iter),
            "ifs": [self._visit(i) for i in node.ifs] if node.ifs else [],
        }
        return result

    def visit_BinOp(self, node: ast.BinOp) -> dict:
        return {
            "type": "BinOp",
            "left": self._visit(node.left),
            "op": type(node.op).__name__,
            "right": self._visit(node.right),
        }

    def visit_UnaryOp(self, node: ast.UnaryOp) -> dict:
        return {
            "type": "UnaryOp",
            "op": type(node.op).__name__,
            "operand": self._visit(node.operand),
        }

    def visit_BoolOp(self, node: ast.BoolOp) -> dict:
        return {
            "type": "BoolOp",
            "op": type(node.op).__name__,
            "values": [self._visit(v) for v in node.values],
        }

    def visit_Compare(self, node: ast.Compare) -> dict:
        return {
            "type": "Compare",
            "left": self._visit(node.left),
            "ops": [type(o).__name__ for o in node.ops],
            "comparators": [self._visit(c) for c in node.comparators],
        }

    def visit_Lambda(self, node: ast.Lambda) -> dict:
        return {
            "type": "Lambda",
            "lineno": node.lineno,
            "args": self._visit(node.args),
            "body": self._visit(node.body),
        }

    def visit_Return(self, node: ast.Return) -> dict:
        result = {"type": "Return", "lineno": node.lineno}
        if node.value:
            result["value"] = self._visit(node.value)
        return result

    def visit_Yield(self, node: ast.Yield) -> dict:
        result = {"type": "Yield", "lineno": node.lineno}
        if node.value:
            result["value"] = self._visit(node.value)
        return result

    def visit_Raise(self, node: ast.Raise) -> dict:
        result = {"type": "Raise", "lineno": node.lineno}
        if node.exc:
            result["exc"] = self._visit(node.exc)
        if node.cause:
            result["cause"] = self._visit(node.cause)
        return result

    def visit_Assert(self, node: ast.Assert) -> dict:
        result = {"type": "Assert", "lineno": node.lineno, "test": self._visit(node.test)}
        if node.msg:
            result["msg"] = self._visit(node.msg)
        return result

    def visit_Import(self, node: ast.Import) -> dict:
        return {
            "type": "Import",
            "lineno": node.lineno,
            "names": [{"name": alias.name, "asname": alias.asname} for alias in node.names],
        }

    def visit_ImportFrom(self, node: ast.ImportFrom) -> dict:
        return {
            "type": "ImportFrom",
            "lineno": node.lineno,
            "module": node.module,
            "names": [{"name": alias.name, "asname": alias.asname} for alias in node.names],
            "level": node.level,
        }

    def visit_Slice(self, node: ast.Slice) -> dict:
        result = {"type": "Slice"}
        if node.lower:
            result["lower"] = self._visit(node.lower)
        if node.upper:
            result["upper"] = self._visit(node.upper)
        if node.step:
            result["step"] = self._visit(node.step)
        return result

    def visit_arguments(self, node: ast.arguments) -> dict:
        return {
            "args": [self._visit(a) for a in node.args] if node.args else [],
            "vararg": self._visit(node.vararg) if node.vararg else None,
            "kwonlyargs": [self._visit(a) for a in node.kwonlyargs] if node.kwonlyargs else [],
            "kwarg": self._visit(node.kwarg) if node.kwarg else None,
            "defaults": [self._visit(d) for d in node.defaults] if node.defaults else [],
            "kw_defaults": [self._visit(d) for d in node.kw_defaults] if node.kw_defaults else [],
        }

    def visit_arg(self, node: ast.arg) -> dict:
        result = {"arg": node.arg}
        if node.annotation:
            result["annotation"] = self._visit(node.annotation)
        return result

    def visit_Starred(self, node: ast.Starred) -> dict:
        return {"type": "Starred", "value": self._visit(node.value), "ctx": type(node.ctx).__name__}

    def visit_IfExp(self, node: ast.IfExp) -> dict:
        return {
            "type": "IfExp",
            "test": self._visit(node.test),
            "body": self._visit(node.body),
            "orelse": self._visit(node.orelse),
        }

    def visit_FString(self, node) -> dict:
        return {
            "type": "FString",
            "values": [self._visit(v) for v in node.values] if hasattr(node, "values") and node.values else [],
        }

    def visit_JoinedStr(self, node: ast.JoinedStr) -> dict:
        return {
            "type": "JoinedStr",
            "values": [self._visit(v) for v in node.values],
        }

    def visit_FormattedValue(self, node: ast.FormattedValue) -> dict:
        result = {
            "type": "FormattedValue",
            "value": self._visit(node.value),
        }
        if node.format_spec:
            result["format_spec"] = self._visit(node.format_spec)
        return result

    if sys.version_info >= (3, 10):
        def visit_Match(self, node: ast.Match) -> dict:
            return {
                "type": "Match",
                "lineno": node.lineno,
                "subject": self._visit(node.subject),
                "cases": [self._visit(c) for c in node.cases],
            }

    def visit_match_case(self, node) -> dict:
        result = {
            "pattern": self._visit(node.pattern),
            "body": [self._visit(stmt) for stmt in node.body],
        }
        if node.guard:
            result["guard"] = self._visit(node.guard)
        return result

    def visit_Walrus(self, node) -> dict:
        return {"type": "NamedExpr", "target": self._visit(node.target), "value": self._visit(node.value)}

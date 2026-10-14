"""Boundary checks for the descriptive legacy audit; no external services."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "Scripts/audit_selection_inputs.py"
SPEC = importlib.util.spec_from_file_location("selection_audit", SCRIPT)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class AuditBoundaryTests(unittest.TestCase):
    def test_ambiguous_century_is_not_guessed(self):
        self.assertEqual(AUDIT.date_class("8-Sep-06"), "no_explicit_four_digit_year")

    def test_date_window_boundaries(self):
        for year in (1880, 1929):
            self.assertEqual(AUDIT.date_class(str(year)), "explicit_years_within_1880_1929")
        for year in (1879, 1930):
            self.assertEqual(AUDIT.date_class(str(year)), "explicit_years_outside_1880_1929")

    def test_date_range_not_reduced_to_start(self):
        self.assertEqual(AUDIT.date_class("1920 to 1935"), "explicit_years_cross_1880_1929_boundary")
        self.assertEqual(AUDIT.date_class("1884 to 1885"), "explicit_years_within_1880_1929")

    def test_missing_dates_remain_missing(self):
        self.assertEqual(AUDIT.date_class("  "), "missing")

    def test_annotations_are_not_primary_dates(self):
        self.assertEqual(AUDIT.date_class("unknown (modified 1910)"), "no_explicit_four_digit_year")

    def test_csv_embedded_newline_is_one_record(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.csv"
            path.write_text('id,note\n1,"first\nsecond"\n', encoding="utf-8")
            rows, _, encoding = AUDIT.read_csv(path)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["note"], "first\nsecond")
            self.assertEqual(encoding, "utf-8-sig")

    def test_legacy_encoding_is_explicitly_provisional(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.csv"
            path.write_bytes("id,note\n1,Ê\n".encode("cp1252"))
            _, _, encoding = AUDIT.read_csv(path)
            self.assertIn("provisional_requires_confirmation", encoding)

    def test_malformed_rows_and_duplicate_headers_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.csv"
            for value in ("id,note\n1\n", "id,note\n1,a,b\n", "id,id\n1,2\n"):
                path.write_text(value, encoding="utf-8")
                with self.assertRaises(ValueError):
                    AUDIT.read_csv(path)


if __name__ == "__main__":
    unittest.main()

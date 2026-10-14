"""Scientific/provenance invariants, including failure paths and offline rebuild."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('supplement', ROOT / 'Scripts/build_life_history_supplement.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SupplementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)
        cls.coverage = MODULE.build(out=cls.out)
        cls.baseline = MODULE.read_csv(ROOT / 'Output/LifeHistory/life_history_80_species.csv')
        cls.summary = MODULE.read_csv(cls.out / 'life_history_80_species_supplemented.csv')
        cls.evidence = MODULE.read_csv(cls.out / 'trait_evidence.csv')
        cls.sources = MODULE.read_csv(cls.out / 'sources.csv')
        cls.policy = MODULE.read_json(ROOT / 'config/life_history_supplement_policy.json')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_roster_and_every_original_value_unchanged(self):
        pd.testing.assert_frame_equal(self.summary[self.baseline.columns], self.baseline)
        self.assertEqual(len(self.summary), 80)
        self.assertTrue(self.summary.species.is_unique)

    def test_summary_values_resolve_to_included_trait_specific_evidence(self):
        ev = self.evidence.set_index('evidence_id')
        for row in self.summary.to_dict('records'):
            for col in self.summary:
                if col.startswith('supplement_') and col.endswith('_evidence_ids') and col != 'supplement_all_evidence_ids':
                    trait = col.removeprefix('supplement_').removesuffix('_evidence_ids')
                    value = row['supplement_' + trait]
                    self.assertEqual(bool(value), bool(row[col]))
                    for key in row[col].split('; ') if row[col] else []:
                        self.assertEqual(ev.loc[key, 'species'], row['species'])
                        self.assertEqual(ev.loc[key, 'trait'], trait)
                        self.assertEqual(ev.loc[key, 'decision'], 'include_contextual')
                        self.assertTrue(ev.loc[key, 'citation'])
                        self.assertTrue(ev.loc[key, 'locator'])
                        self.assertTrue(ev.loc[key, 'sha256'])

    def test_four_regional_routes_and_unknowns_not_nonmigrants(self):
        by_species = self.summary.set_index('species')
        expected = {'Brevoortia patronus': 'oceano-estuarine',
                    'Lagodon rhomboides': 'oceano-estuarine',
                    'Haemulon aurolineatum': 'oceanodromous',
                    'Lutjanus synagris': 'oceanodromous'}
        added = self.summary[(self.summary.migration == '') & (self.summary.migration_best_available != '')]
        self.assertEqual(dict(zip(added.species, added.migration_best_available)), expected)
        ev = self.evidence.set_index('evidence_id')
        for row in added.itertuples():
            self.assertTrue(row.migration_best_available_evidence_ids)
            for key in row.migration_best_available_evidence_ids.split('; '):
                self.assertEqual(ev.loc[key, 'species'], row.species)
                self.assertEqual(ev.loc[key, 'trait'], 'migration')
                self.assertEqual(ev.loc[key, 'normalized_value'], row.migration_best_available)
                self.assertEqual(ev.loc[key, 'decision'], 'include_contextual')
        for species in ['Eucinostomus gula', 'Symphurus plagiusa', 'Membras martinica',
                        'Cyclothone microdon', 'Haemulon plumierii', 'Myctophum opalinum']:
            self.assertEqual(by_species.loc[species, 'migration_best_available'], '')
        self.assertEqual(self.coverage['combined_migration_missing'], 40)

    def test_missing_attribution_and_conflicts_fail(self):
        broken = self.evidence.copy()
        broken.loc[0, 'locator'] = ''
        with self.assertRaisesRegex(ValueError, 'attribution'):
            MODULE.validate_evidence(self.baseline, broken, self.sources, self.policy)
        broken = self.evidence.copy()
        broken.loc[0, 'conflict_status'] = 'unresolved'
        with self.assertRaisesRegex(ValueError, 'conflict'):
            MODULE.validate_evidence(self.baseline, broken, self.sources, self.policy)

    def test_promoting_hypothesis_fails(self):
        broken = self.evidence.copy()
        index = broken.index[broken.trait.str.endswith('_hypothesis')][0]
        broken.loc[index, ['decision', 'mapping_rule']] = ['include_contextual', 'direct_v1']
        with self.assertRaisesRegex(ValueError, 'Hypothesis'):
            MODULE.validate_evidence(self.baseline, broken, self.sources, self.policy)

    def test_archive_tampering_fails(self):
        with tempfile.TemporaryDirectory() as dirname:
            root = Path(dirname)
            (root / 'source.pdf').write_bytes(b'altered')
            (root / 'source.pdf.metadata.json').write_text(json.dumps(dict(sha256='bad', requested_url='https://example.org')))
            with self.assertRaisesRegex(ValueError, 'checksum'):
                MODULE.load_sources(root, [dict(source_id='TEST', archive_path='source.pdf',
                                               acquisition='download', url='https://example.org')])

    def test_all_gaps_have_search_audit_and_nafmfd_preserves_uncertainty(self):
        reviews = MODULE.read_csv(self.out / 'migration_gap_review.csv')
        self.assertEqual(set(reviews.species), set(self.baseline.loc[self.baseline.migration == '', 'species']))
        self.assertEqual(len(reviews), 44)
        self.assertTrue((reviews.search_archive_paths != '').all())
        naf = MODULE.read_csv(self.out / 'naf_match_records.csv')
        self.assertEqual(naf.species.nunique(), 15)
        for sp in ['Membras martinica', 'Symphurus plagiusa']:
            self.assertTrue((naf.loc[naf.species == sp, 'Undetermined'] == '1').all())
        gula = naf[naf.species == 'Eucinostomus gula'].iloc[0]
        self.assertEqual(gula['Reference assignment'], 'Semi-anadromous')
        self.assertEqual(gula['Reference'], 'Stoner 1986')

    def test_preserve_plus_age_and_length_units(self):
        ev = self.evidence.set_index('evidence_id')
        self.assertEqual(ev.loc['LHS016', 'normalized_value'], '5+')
        self.assertEqual(ev.loc['LHS014', 'unit'], 'mm TL')
        self.assertEqual(ev.loc['LHS019', 'unit'], 'mm SL')

    def test_canonical_outputs_rebuild_identically(self):
        files = list(self.out.glob('*.csv')) + [self.out / 'coverage.json']
        hashes = {p.name: MODULE.sha(p) for p in files}
        MODULE.build(out=self.out)
        self.assertEqual(hashes, {p.name: MODULE.sha(p) for p in files})


if __name__ == '__main__':
    unittest.main()

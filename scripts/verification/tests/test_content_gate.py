"""Synthetic content-boundary regressions; fixtures are not release evidence."""

import dataclasses
import hashlib
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from content_gate import (  # noqa: E402
    ContentGateError, PackagedAsset, PackagedItem, ReleaseBank, ReviewRecord,
    validate_content_bank, validate_content_gate,
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


class SyntheticSemantics:
    def validate(self, bank):
        return []


class SyntheticReader:
    def __init__(self, bank):
        self.bank = bank

    def read(self, *, workspace, snapshot):
        return self.bank


class SyntheticSignoff:
    def verify(self, bank, *, snapshot):
        return True


class ContentGateTests(unittest.TestCase):
    def setUp(self):
        item_bytes = b"synthetic canonical question"
        asset_bytes = b"synthetic audio bytes"
        item_digest = digest(item_bytes)
        asset_digest = digest(asset_bytes)
        item = PackagedItem("item-1", item_bytes, item_digest,
                            ReviewRecord("item-1", item_digest, "approved",
                                         "fixture", "2026-10-15"), ("audio-1",))
        asset = PackagedAsset("audio-1", "item-1", "audio", asset_bytes,
                              asset_digest,
                              ReviewRecord("audio-1", asset_digest, "approved",
                                           "fixture", "2026-10-15"))
        self.bank = ReleaseBank(b"synthetic package", digest(b"synthetic package"),
                                "release_approved", True, (item,), (asset,))

    def check_rejected(self, bank):
        with self.assertRaises(ContentGateError):
            validate_content_bank(bank, SyntheticSemantics())

    def test_production_reader_is_unavailable(self):
        with self.assertRaisesRegex(ContentGateError, "reader is unavailable"):
            validate_content_gate(workspace=Path("."), snapshot={})

    def test_synthetic_boundary_requires_all_adapters(self):
        with self.assertRaisesRegex(ContentGateError, "semantic validator is unavailable"):
            validate_content_gate(workspace=Path("."), snapshot={},
                                  reader=SyntheticReader(self.bank))
        with self.assertRaisesRegex(ContentGateError, "sign-off verifier is unavailable"):
            validate_content_gate(workspace=Path("."), snapshot={},
                                  reader=SyntheticReader(self.bank),
                                  semantics=SyntheticSemantics())
        validate_content_gate(workspace=Path("."), snapshot={},
                              reader=SyntheticReader(self.bank),
                              semantics=SyntheticSemantics(), signoff=SyntheticSignoff())

    def test_absent_packaged_bank_bytes_rejected(self):
        self.check_rejected(dataclasses.replace(self.bank, package_bytes=b""))

    def test_draft_catalogue_rejected(self):
        self.check_rejected(dataclasses.replace(self.bank, catalogue_status="draft_planning",
                                                release_approved=False))

    def test_changed_asset_bytes_rejected(self):
        asset = dataclasses.replace(self.bank.assets[0], data=b"changed audio bytes")
        self.check_rejected(dataclasses.replace(self.bank, assets=(asset,)))

    def test_missing_item_review_rejected(self):
        item = dataclasses.replace(self.bank.items[0], review=None)
        self.check_rejected(dataclasses.replace(self.bank, items=(item,)))

    def test_missing_audio_review_rejected(self):
        asset = dataclasses.replace(self.bank.assets[0], review=None)
        self.check_rejected(dataclasses.replace(self.bank, assets=(asset,)))

    def test_asset_cannot_be_claimed_by_other_item(self):
        other_bytes = b"other question"
        other_digest = digest(other_bytes)
        other = PackagedItem("item-2", other_bytes, other_digest,
                             ReviewRecord("item-2", other_digest, "approved",
                                          "fixture", "2026-10-15"), ())
        asset = dataclasses.replace(self.bank.assets[0], item_id="item-2")
        self.check_rejected(dataclasses.replace(self.bank, items=(*self.bank.items, other),
                                                assets=(asset,)))

    def test_semantic_issues_rejected(self):
        class RejectingSemantics:
            def validate(self, bank):
                return ["invalid quota"]

        with self.assertRaises(ContentGateError):
            validate_content_bank(self.bank, RejectingSemantics())


if __name__ == "__main__":
    unittest.main()

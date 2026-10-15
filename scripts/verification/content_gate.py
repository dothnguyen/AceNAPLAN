"""Fail-closed boundary for a packaged, reviewed pilot content bank.

The release-bank reader and Dart semantic adapter are deliberately uninstalled.
Neither an evidence envelope nor locally editable review JSON authenticates a
release bundle or educator sign-off.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol


class ContentGateError(ValueError):
    """The content gate has no trustworthy complete result."""


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")


@dataclass(frozen=True)
class ReviewRecord:
    subject_id: str
    digest: str
    status: str
    reviewer: str
    reviewed_at: str


@dataclass(frozen=True)
class PackagedItem:
    item_id: str
    canonical_bytes: bytes
    content_digest: str
    review: ReviewRecord | None
    asset_ids: tuple[str, ...]


@dataclass(frozen=True)
class PackagedAsset:
    asset_id: str
    item_id: str
    kind: str
    data: bytes
    digest: str
    review: ReviewRecord | None = None


@dataclass(frozen=True)
class ReleaseBank:
    """A reader's projection of exact bytes extracted from a release package.

    This is an interface shape, not a selected T12 container format. The reader
    must establish the package/extraction relationship independently.
    """

    package_bytes: bytes
    package_digest: str
    catalogue_status: str
    release_approved: bool
    items: tuple[PackagedItem, ...]
    assets: tuple[PackagedAsset, ...]


class ReleaseBankReader(Protocol):
    def read(self, *, workspace: Path, snapshot: dict[str, str]) -> ReleaseBank: ...


class ReleaseSemantics(Protocol):
    def validate(self, bank: ReleaseBank) -> list[str]: ...


class EducatorSignoff(Protocol):
    def verify(self, bank: ReleaseBank, *, snapshot: dict[str, str]) -> bool: ...


class UnavailableReleaseBankReader:
    def read(self, *, workspace: Path, snapshot: dict[str, str]) -> ReleaseBank:
        raise ContentGateError("packaged release-bank reader is unavailable")


class UnavailableReleaseSemantics:
    def validate(self, bank: ReleaseBank) -> list[str]:
        raise ContentGateError("release-bank semantic validator is unavailable")


class UnavailableEducatorSignoff:
    def verify(self, bank: ReleaseBank, *, snapshot: dict[str, str]) -> bool:
        raise ContentGateError("authentic educator sign-off verifier is unavailable")


def _matches(data: bytes, digest: str) -> bool:
    return (type(data) is bytes and bool(data) and type(digest) is str
            and _SHA256.fullmatch(digest) is not None
            and hashlib.sha256(data).hexdigest() == digest)


def _approved(review: ReviewRecord | None, subject_id: str, digest: str) -> bool:
    return (type(review) is ReviewRecord and review.subject_id == subject_id
            and review.digest == digest and review.status == "approved"
            and type(review.reviewer) is str and bool(review.reviewer.strip())
            and type(review.reviewed_at) is str and bool(review.reviewed_at.strip()))


def validate_content_bank(bank: ReleaseBank, semantics: ReleaseSemantics) -> None:
    """Check bounded byte/review invariants, then the full Dart content rules.

    A successful return is useful only when a trusted reader supplied the exact
    packaged bytes and the semantic adapter executed release validation.
    """
    if type(bank) is not ReleaseBank or not _matches(bank.package_bytes, bank.package_digest):
        raise ContentGateError("packaged bank bytes are absent or changed")
    if bank.catalogue_status != "release_approved" or bank.release_approved is not True:
        raise ContentGateError("content catalogue is draft or unapproved")
    if not bank.items:
        raise ContentGateError("packaged bank contains no questions")
    items: set[str] = set()
    referenced: dict[str, str] = {}
    for item in bank.items:
        if type(item) is not PackagedItem or not item.item_id or item.item_id in items:
            raise ContentGateError("missing or duplicate packaged item")
        items.add(item.item_id)
        if not _matches(item.canonical_bytes, item.content_digest):
            raise ContentGateError("packaged item bytes do not match content digest")
        if not _approved(item.review, item.item_id, item.content_digest):
            raise ContentGateError("missing or unapproved item review")
        if len(set(item.asset_ids)) != len(item.asset_ids):
            raise ContentGateError("duplicate item asset reference")
        for asset_id in item.asset_ids:
            if not asset_id or asset_id in referenced:
                raise ContentGateError("duplicate or invalid item asset reference")
            referenced[asset_id] = item.item_id
    assets: set[str] = set()
    for asset in bank.assets:
        if (type(asset) is not PackagedAsset or not asset.asset_id
                or asset.asset_id in assets or asset.item_id not in items
                or referenced.get(asset.asset_id) != asset.item_id):
            raise ContentGateError("missing, duplicate or unreferenced packaged asset")
        assets.add(asset.asset_id)
        if not _matches(asset.data, asset.digest):
            raise ContentGateError("packaged asset bytes do not match digest")
        if asset.kind == "audio":
            if not _approved(asset.review, asset.asset_id, asset.digest):
                raise ContentGateError("missing or unapproved audio review")
        elif asset.kind != "visual":
            raise ContentGateError("unsupported packaged asset kind")
    if set(referenced) != assets:
        raise ContentGateError("packaged asset bytes are missing")
    issues = semantics.validate(bank)
    if type(issues) is not list or issues:
        raise ContentGateError("release-bank semantic validation did not pass")


def validate_content_gate(*, workspace: Path, snapshot: dict[str, str],
                          reader: ReleaseBankReader | None = None,
                          semantics: ReleaseSemantics | None = None,
                          signoff: EducatorSignoff | None = None) -> None:
    """Run only after fixed gate context and envelope integrity validation."""
    active_reader = reader if reader is not None else UnavailableReleaseBankReader()
    active_semantics = semantics if semantics is not None else UnavailableReleaseSemantics()
    active_signoff = signoff if signoff is not None else UnavailableEducatorSignoff()
    bank = active_reader.read(workspace=workspace, snapshot=snapshot)
    validate_content_bank(bank, active_semantics)
    if active_signoff.verify(bank, snapshot=snapshot) is not True:
        raise ContentGateError("authentic educator sign-off is missing")

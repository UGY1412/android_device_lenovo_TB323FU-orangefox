#!/usr/bin/env python3
"""Verify (and optionally extract) the hash-pinned TB323FU stock files straight
from a local ext4 partition image, without mounting anything.

Why this exists: staging the recovery payload needs a "stock root" (a filesystem
tree with /vendor/..., /system/...). On Linux that is done by loop-mounting the
payload-dumped images (scripts/prepare-stock-root.sh). This script does the same
job in pure Python, so the 25 pinned TB323FU stock files can be checked - and the
stock root materialised - on any host, including Windows.

Scope: read-only ext4 with extents (64-bit block numbers, sparse holes, metadata_csum
directory tails) plus a direct/single-indirect fallback for non-extent inodes - that
covers the Android vendor/system images produced by payload_dumper.

Reader self-check: for every file the parsed allocation (initialised extent blocks +
external extent-tree blocks) is compared against the inode's i_blocks. A mismatch
means the reader mis-parsed something, and is reported rather than silently
producing a wrong hash.

Images are partition-rooted: a row source_path of "/vendor/lib64/x.so" is looked up
as "lib64/x.so" inside vendor.img (the leading partition component is stripped
automatically when the first component is not present).

Usage:
    python ext4_stock_verify.py --image vendor.img \
        --sources proprietary-sources.tsv [--extract-to stock-root] [--list PATH]

Exit code 0 only when every pinned stock file matches its recorded size+SHA-256.
"""

import argparse
import hashlib
import sys
from pathlib import Path

SUPER_MAGIC = 0xEF53
EXT4_EXTENTS_FL = 0x00080000
EXT4_INLINE_DATA_FL = 0x10000000
S_IFMT = 0xF000
S_IFDIR = 0x4000
EXTENT_MAGIC = 0xF30A
HOLE_CHUNK = 1 << 20


def u16(buf, off):
    return int.from_bytes(buf[off:off + 2], "little")


def u32(buf, off):
    return int.from_bytes(buf[off:off + 4], "little")


class NotExt4(Exception):
    pass


class Ext4Image:
    """Minimal read-only ext4 reader."""

    def __init__(self, path):
        self.path = Path(path)
        self.f = self.path.open("rb")

        self.f.seek(1024)
        sb = self.f.read(1024)
        if len(sb) < 1024 or u16(sb, 56) != SUPER_MAGIC:
            raise NotExt4(f"{self.path}: not an ext4 image (bad superblock magic)")

        self.inodes_count = u32(sb, 0)
        self.blocks_count = u32(sb, 4)
        self.first_data_block = u32(sb, 20)
        self.block_size = 1024 << u32(sb, 24)
        self.blocks_per_group = u32(sb, 32)
        self.inodes_per_group = u32(sb, 40)
        inode_size = u16(sb, 88)
        self.inode_size = inode_size if inode_size >= 128 else 128
        incompat = u32(sb, 96)
        self.incompat_64bit = bool(incompat & 0x80)
        self.has_extents = bool(incompat & 0x40)
        self.has_bigalloc = bool(incompat & 0x200)
        desc_size = u16(sb, 254) if self.incompat_64bit else 32
        self.desc_size = desc_size if desc_size >= 32 else 32
        if self.incompat_64bit:
            self.blocks_count |= u32(sb, 336) << 32

        self.groups = -(-self.blocks_count // self.blocks_per_group)
        gdt_off = (self.first_data_block + 1) * self.block_size
        self.gdt = self.read_at(gdt_off, self.groups * self.desc_size)

    # ---------- low level ----------
    def read_at(self, off, size):
        self.f.seek(off)
        data = self.f.read(size)
        if len(data) != size:
            raise IOError(f"{self.path}: short read at {off} (wanted {size}, got {len(data)})")
        return data

    def inode_table_block(self, group):
        e = group * self.desc_size
        lo = u32(self.gdt, e + 8)
        hi = u32(self.gdt, e + 40) if self.incompat_64bit else 0
        return lo | (hi << 32)

    def read_inode(self, idx):
        if idx < 1 or idx > self.inodes_count:
            raise ValueError(f"inode {idx} out of range")
        group = (idx - 1) // self.inodes_per_group
        local = (idx - 1) % self.inodes_per_group
        off = self.inode_table_block(group) * self.block_size + local * self.inode_size
        return self.read_at(off, self.inode_size)

    @staticmethod
    def inode_mode(ino):
        return u16(ino, 0)

    @staticmethod
    def inode_size_bytes(ino):
        return (u32(ino, 108) << 32) | u32(ino, 4)

    @staticmethod
    def inode_flags(ino):
        return u32(ino, 32)

    @staticmethod
    def inode_blocks_512(ino):
        return u32(ino, 28)

    # ---------- block mapping ----------
    def _parse_extent_node(self, data, out, stats, depth_guard=0):
        if depth_guard > 6:
            raise IOError("extent tree too deep")
        if u16(data, 0) != EXTENT_MAGIC:
            raise IOError("bad extent header magic")
        entries = u16(data, 2)
        depth = u16(data, 6)
        body = data[12:]
        if depth == 0:
            for i in range(entries):
                e = i * 12
                if len(body) < e + 12:
                    break
                log = u32(body, e)
                raw_len = u16(body, e + 4)
                if raw_len == 0:
                    # ext4 encodes a 32768-block extent as length 0
                    length, uninit = 32768, False
                elif raw_len > 32768:
                    length, uninit = raw_len - 32768, True
                else:
                    length, uninit = raw_len, False
                start = u32(body, e + 8) | (u16(body, e + 6) << 32)
                if length:
                    out.append((log, length, start, uninit))
                    if not uninit:
                        stats["data_blocks"] += length
        else:
            for i in range(entries):
                e = i * 12
                if len(body) < e + 12:
                    break
                child = u32(body, e + 4) | (u16(body, e + 8) << 32)
                stats["tree_blocks"] += 1
                node = self.read_at(child * self.block_size, self.block_size)
                self._parse_extent_node(node, out, stats, depth_guard + 1)

    def block_map(self, ino):
        """Return (extents, stats); extents are (logical, length, physical, uninit)."""
        stats = {"data_blocks": 0, "tree_blocks": 0}
        flags = self.inode_flags(ino)
        if flags & EXT4_EXTENTS_FL:
            extents = []
            header = ino[40:52]
            if u16(header, 0) != EXTENT_MAGIC:
                raise IOError("inode has EXTENTS_FL but no extent header")
            self._parse_extent_node(ino[40:40 + 60], extents, stats)
            return sorted(extents), stats

        if flags & EXT4_INLINE_DATA_FL:
            raise IOError("inline-data inode not supported (no block map)")

        out = []
        blocks = ino[40:100]
        for i in range(12):
            b = u32(blocks, i * 4)
            if b:
                out.append((i, 1, b, False))
                stats["data_blocks"] += 1
        indirect = u32(blocks, 48)
        if indirect:
            ptrs = self.read_at(indirect * self.block_size, self.block_size)
            stats["tree_blocks"] += 1
            for i in range(self.block_size // 4):
                b = u32(ptrs, i * 4)
                if b:
                    out.append((12 + i, 1, b, False))
                    stats["data_blocks"] += 1
        return sorted(out), stats

    def alloc_ok(self, ino):
        """Cross-check the parsed allocation against the inode's i_blocks field."""
        _extents, stats = self.block_map(ino)
        parsed = stats["data_blocks"] + stats["tree_blocks"]
        recorded = self.inode_blocks_512(ino) // (self.block_size // 512)
        return parsed, recorded

    # ---------- file content ----------
    @staticmethod
    def _zeros(n):
        while n > 0:
            k = min(n, HOLE_CHUNK)
            yield b"\0" * k
            n -= k

    def iter_chunks(self, ino):
        """Yield the file's bytes, materialising sparse holes as zeros."""
        bs = self.block_size
        size = self.inode_size_bytes(ino)
        if size == 0:
            return
        pos = 0
        for log, length, start, uninit in self.block_map(ino)[0]:
            off = log * bs
            if off > pos:
                yield from self._zeros(min(off - pos, max(size - pos, 0)))
                pos = off
            if pos >= size:
                break
            take = min(length * bs, size - pos)
            if uninit:
                yield from self._zeros(take)
            else:
                yield self.read_at(start * bs, take)
            pos += take
        if pos < size:
            yield from self._zeros(size - pos)

    def hash_inode(self, ino):
        h = hashlib.sha256()
        for chunk in self.iter_chunks(ino):
            h.update(chunk)
        return h.hexdigest()

    def read_inode_data(self, ino):
        return b"".join(self.iter_chunks(ino))

    def dir_entries(self, ino):
        for log, length, start, uninit in self.block_map(ino)[0]:
            if uninit:
                continue
            block = self.read_at(start * self.block_size, length * self.block_size)
            off = 0
            while off + 8 <= len(block):
                inode_idx = u32(block, off)
                rec_len = u16(block, off + 4)
                name_len = block[off + 6]
                if rec_len < 8 or off + rec_len > len(block):
                    break
                if inode_idx and name_len:
                    name = block[off + 8:off + 8 + name_len].decode("utf-8", "surrogateescape")
                    yield name, inode_idx
                off += rec_len

    def lookup(self, path):
        idx = 2  # root inode
        ino = self.read_inode(idx)
        for part in [p for p in path.split("/") if p]:
            if (self.inode_mode(ino) & S_IFMT) != S_IFDIR:
                raise NotADirectoryError(f"{part}: not a directory in {path}")
            found = None
            for name, child in self.dir_entries(ino):
                if name == part:
                    found = child
                    break
            if found is None:
                raise FileNotFoundError(f"{part}: not found in {path}")
            idx = found
            ino = self.read_inode(idx)
        return idx, ino


def resolve(image, rel):
    """Resolve a source path against a partition-rooted image."""
    parts = rel.split("/")
    last_err = None
    for start in range(0, min(2, len(parts))):
        try:
            return image.lookup("/".join(parts[start:]))
        except (FileNotFoundError, NotADirectoryError) as e:
            last_err = e
    raise FileNotFoundError(f"{rel}: {last_err}")


def load_stock_rows(sources):
    lines = Path(sources).read_text(encoding="utf-8").splitlines()
    header = lines[0].split("\t")
    rows = [dict(zip(header, ln.split("\t"))) for ln in lines[1:] if ln.strip()]
    return [r for r in rows if r.get("acquisition") == "tb323fu-stock"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--image", required=True, help="ext4 partition image (e.g. vendor.img)")
    ap.add_argument("--sources", required=True, help="proprietary-sources.tsv")
    ap.add_argument("--extract-to", default=None, help="also write the files under this directory")
    ap.add_argument("--extract-all", action="store_true",
                    help="with --extract-to: also extract files whose bytes differ from the pin")
    ap.add_argument("--emit-overrides", default=None,
                    help="write a TSV of pinned-vs-found hashes for every stock row")
    ap.add_argument("--prefix", default="/vendor/", help="only rows whose source_path starts with this")
    ap.add_argument("--list", dest="list_path", default=None, help="debug: list one directory and exit")
    ap.add_argument("--no-alloc-check", action="store_true", help="skip the i_blocks cross-check")
    args = ap.parse_args()

    image = Ext4Image(args.image)
    print(f"image : {image.path} ({image.path.stat().st_size / 2**20:.1f} MiB)")
    print(f"        block_size={image.block_size} inode_size={image.inode_size} groups={image.groups} "
          f"extents={image.has_extents} 64bit={image.incompat_64bit} bigalloc={image.has_bigalloc}")

    if args.list_path:
        idx, ino = resolve(image, args.list_path)
        print(f"dir   : {args.list_path} inode={idx} size={image.inode_size_bytes(ino)}")
        for name, child in sorted(image.dir_entries(ino)):
            print(f"        {child:>8}  {name}")
        return 0

    rows = [r for r in load_stock_rows(args.sources) if r["source_path"].startswith(args.prefix)]
    if not rows:
        print(f"no stock rows under prefix {args.prefix!r}")
        return 1
    print(f"rows  : {len(rows)} pinned stock files under {args.prefix}")
    print()

    ok = bad = missing = 0
    alloc_warnings = 0
    overrides = []
    for r in sorted(rows, key=lambda x: x["source_path"]):
        rel = r["source_path"].lstrip("/")
        want_size = int(r["size"])
        want_hash = r["expected_sha256"]
        try:
            _idx, ino = resolve(image, rel)
        except (FileNotFoundError, NotADirectoryError) as e:
            print(f"MISSING  {rel}  ({e})")
            missing += 1
            overrides.append([r["target_path"], want_hash, str(want_size), "", "", "missing", image.path.name, r["source_path"]])
            continue

        got_size = image.inode_size_bytes(ino)
        got_hash = image.hash_inode(ino)

        note = ""
        if not args.no_alloc_check:
            parsed, recorded = image.alloc_ok(ino)
            if parsed != recorded:
                note = f"  [alloc-check: parsed={parsed} i_blocks={recorded} blocks]"
                alloc_warnings += 1

        match = got_size == want_size and got_hash == want_hash
        if match:
            print(f"OK       {rel}{note}")
            ok += 1
        else:
            print(f"MISMATCH {rel}  size {got_size} (want {want_size})  "
                  f"sha256 {got_hash[:12]} (want {want_hash[:12]}){note}")
            bad += 1

        overrides.append([r["target_path"], want_hash, str(want_size), got_hash, str(got_size),
                          "pinned" if match else "substituted", image.path.name, r["source_path"]])

        if args.extract_to and (match or args.extract_all):
            dest = Path(args.extract_to) / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(image.read_inode_data(ino))

    if args.emit_overrides:
        out = Path(args.emit_overrides)
        out.parent.mkdir(parents=True, exist_ok=True)
        header = ["target_path", "pinned_sha256", "pinned_size", "found_sha256", "found_size",
                  "status", "source_image", "source_path"]
        with out.open("w", encoding="utf-8", newline="\n") as fh:
            fh.write("\t".join(header) + "\n")
            for row in overrides:
                fh.write("\t".join(row) + "\n")
        print(f"\noverride manifest written: {out}")

    print()
    print(f"summary: match={ok} mismatch={bad} missing={missing} of {len(rows)}"
          + (f"; alloc-check warnings={alloc_warnings}" if alloc_warnings else ""))
    print("RESULT: " + ("ALL-STOCK-FILES-MATCH" if bad == 0 and missing == 0 else "STOCK-SOURCE-INCOMPLETE"))
    if args.extract_to and (ok or args.extract_all):
        print(f"stock root written to: {args.extract_to}")
    return 0 if bad == 0 and missing == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

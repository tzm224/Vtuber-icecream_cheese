"""Installer behavior tests with mocked macOS commands. Not a macOS UI test."""
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "io.github.tzm224.cheesepet"


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.fixture = self.root / "fixture"
        self.fixture.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), TMPDIR=str(self.root),
                        PATH=f"{self.bin}:{os.environ['PATH']}", MOCK_FIXTURE=str(self.fixture))
        self.make_archive()
        self.stub("uname", '#!/bin/bash\nif [[ "$1" == -s ]]; then echo "${MOCK_OS:-Darwin}"; else echo "${MOCK_ARCH:-arm64}"; fi\n')
        self.stub("sw_vers", '#!/bin/bash\necho "${MOCK_VERSION:-14.0}"\n')
        self.stub("pgrep", '#!/bin/bash\nexit "${MOCK_PGREP:-1}"\n')
        self.stub("curl", '#!/usr/bin/env python3\nimport sys,os,shutil\nfrom pathlib import Path\nif os.environ.get("MOCK_DOWNLOAD_FAIL"): sys.exit(22)\na=sys.argv; out=a[a.index("-o")+1]; url=a[a.index("-o")-1]\nshutil.copyfile(Path(os.environ["MOCK_FIXTURE"])/url.rsplit("/",1)[-1],out)\n')
        self.stub("ditto", '#!/usr/bin/env python3\nimport sys,zipfile,os\nfrom pathlib import Path\nwith zipfile.ZipFile(sys.argv[-2]) as z:\n z.extractall(sys.argv[-1])\n for i in z.infolist():\n  p=Path(sys.argv[-1])/i.filename\n  if not p.is_dir(): p.chmod((i.external_attr>>16)&0o777 or 0o644)\n')
        self.stub("plutil", '#!/usr/bin/env python3\nimport sys,plistlib\nwith open(sys.argv[-1],"rb") as f: print(plistlib.load(f)["CFBundleIdentifier"])\n')
        self.stub("codesign", '#!/bin/bash\nexit "${MOCK_SIGN_EXIT:-0}"\n')
        self.stub("open", '#!/bin/bash\nprintf "%s" "$1" > "$HOME/opened"\nexit "${MOCK_OPEN_EXIT:-0}"\n')

    def tearDown(self):
        self.temp.cleanup()

    def stub(self, name, contents):
        path = self.bin / name
        path.write_text(contents)
        path.chmod(0o755)

    def make_archive(self, identifier=BUNDLE, extra=None):
        archive = self.fixture / "CheesePet-macOS-universal.zip"
        with zipfile.ZipFile(archive, "w") as z:
            z.writestr("CheesePet.app/Contents/Info.plist", plistlib.dumps({"CFBundleIdentifier": identifier}))
            info = zipfile.ZipInfo("CheesePet.app/Contents/MacOS/CheesePet")
            info.external_attr = 0o100755 << 16
            z.writestr(info, "#!/bin/bash\nexit 0\n")
            if extra:
                z.writestr(extra, "unexpected")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        (self.fixture / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n")

    @property
    def app(self):
        return self.home / "Applications/CheesePet.app"

    def run_install(self, **environment):
        return subprocess.run(["bash", str(ROOT / "install.sh")], env=dict(self.env, **environment), capture_output=True, text=True)

    def test_fresh_install_and_launch(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.app / "Contents/MacOS/CheesePet").is_file())
        self.assertEqual((self.home / "opened").read_text(), str(self.app))
        self.assertFalse(list(self.root.glob("cheese-install.*")))

    def test_intel_install(self):
        self.assertEqual(self.run_install(MOCK_ARCH="x86_64").returncode, 0)

    def test_linux_and_old_macos_rejected(self):
        for environment in ({"MOCK_OS": "Linux"}, {"MOCK_VERSION": "12.7"}, {"MOCK_ARCH": "i386"}):
            with self.subTest(environment=environment):
                self.assertNotEqual(self.run_install(**environment).returncode, 0)
                self.assertFalse(self.app.exists())

    def test_checksum_mismatch_keeps_system_unchanged(self):
        (self.fixture / "SHA256SUMS").write_text("0" * 64 + "  CheesePet-macOS-universal.zip\n")
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.app.exists())

    def test_existing_unrelated_application_is_not_replaced(self):
        (self.app / "Contents").mkdir(parents=True)
        info = self.app / "Contents/Info.plist"
        info.write_bytes(plistlib.dumps({"CFBundleIdentifier": "other.application"}))
        original = info.read_bytes()
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(info.read_bytes(), original)

    def test_upgrade_backs_up_original(self):
        self.assertEqual(self.run_install().returncode, 0)
        (self.app / "old-version-marker").write_text("preserve me")
        self.assertEqual(self.run_install().returncode, 0)
        backups = list((self.home / "Library/Application Support/CheesePet/Backups").glob("*.app"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "old-version-marker").read_text(), "preserve me")
        self.assertFalse((self.app / "old-version-marker").exists())

    def test_running_pet_is_not_updated(self):
        self.assertNotEqual(self.run_install(MOCK_PGREP="0").returncode, 0)
        self.assertFalse(self.app.exists())

    def test_failed_download_cleans_temporary_files(self):
        self.assertNotEqual(self.run_install(MOCK_DOWNLOAD_FAIL="1").returncode, 0)
        self.assertFalse(list(self.root.glob("cheese-install.*")))

    def test_archive_traversal_rejected(self):
        self.make_archive(extra="CheesePet.app/../../escape")
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertFalse(self.app.exists())
        self.assertFalse((self.root / "escape").exists())

    def test_wrong_bundle_and_bad_signature_rejected(self):
        self.make_archive(identifier="wrong.bundle")
        self.assertNotEqual(self.run_install().returncode, 0)
        self.make_archive()
        self.assertNotEqual(self.run_install(MOCK_SIGN_EXIT="1").returncode, 0)
        self.assertFalse(self.app.exists())

    def test_open_failure_is_reported_without_removing_app(self):
        self.assertNotEqual(self.run_install(MOCK_OPEN_EXIT="1").returncode, 0)
        self.assertTrue(self.app.exists())

    def test_invalid_version_cannot_change_download_destination(self):
        self.assertNotEqual(self.run_install(CHEESE_VERSION="v1/../../evil").returncode, 0)
        self.assertFalse(self.app.exists())

    def test_symlink_destination_is_not_followed(self):
        self.app.parent.mkdir()
        target = self.root / "other"
        target.mkdir()
        self.app.symlink_to(target, target_is_directory=True)
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(list(target.iterdir()), [])

    def test_uninstall_moves_app_to_trash(self):
        self.assertEqual(self.run_install().returncode, 0)
        result = subprocess.run(["bash", str(ROOT / "scripts/uninstall.sh")], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.app.exists())
        trashed = list((self.home / ".Trash").glob("CheesePet-*.app"))
        self.assertEqual(len(trashed), 1)
        self.assertTrue((trashed[0] / "Contents/MacOS/CheesePet").exists())

    def test_uninstall_running_app_preserves_it(self):
        self.assertEqual(self.run_install().returncode, 0)
        result = subprocess.run(["bash", str(ROOT / "scripts/uninstall.sh")],
                                env=dict(self.env, MOCK_PGREP="0"), capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.app.exists())

    def test_uninstall_does_not_move_unrelated_app(self):
        (self.app / "Contents").mkdir(parents=True)
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "other.application"}))
        result = subprocess.run(["bash", str(ROOT / "scripts/uninstall.sh")], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.app.exists())


if __name__ == "__main__":
    unittest.main()

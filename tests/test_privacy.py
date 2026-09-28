"""Regression checks for decisions made before untrusted mail is displayed."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))

from olook import cli, config, keyring  # noqa: E402


class RemoteImageTests(unittest.TestCase):
    def setUp(self):
        self.account = {"provider": "gmail", "imap": {"host": "imap.gmail.com"}}
        self.sender = {"account": "test", "fromAddr": "friend@example.com"}
        self.spoofed = {"headers": {"From": "Friend <friend@example.com>"}}
        self.verified = {"headers": {
            "From": "Friend <friend@example.com>",
            "Authentication-Results": "mx.google.com; dmarc=pass header.from=example.com",
        }}

    def decide(self, body, policy, trusted):
        with patch.object(config, "account", return_value=self.account), \
             patch.object(config, "image_policy", return_value=policy), \
             patch.object(config, "trusted_senders", return_value=trusted):
            return cli._auto_images(body, self.sender)

    def test_new_accounts_do_not_load_remote_images(self):
        self.assertEqual(config.image_policy({}), "never")
        self.assertFalse(self.decide(self.verified, config.image_policy({}), set())["autoImages"])

    def test_named_sender_must_also_be_verified(self):
        for policy in ("trusted", "verified"):
            with self.subTest(policy=policy):
                result = self.decide(self.spoofed, policy, {"friend@example.com"})
                self.assertFalse(result["authentication"]["verified"])
                self.assertFalse(result["autoImages"])

    def test_opted_in_named_and_verified_sender_loads_images(self):
        result = self.decide(self.verified, "trusted", {"friend@example.com"})
        self.assertTrue(result["authentication"]["verified"])
        self.assertTrue(result["autoImages"])

    def test_stale_summary_cannot_trust_a_different_verified_sender(self):
        different = {"headers": {
            "From": "Someone <other@example.net>",
            "Authentication-Results": "mx.google.com; dmarc=pass header.from=example.net",
        }}
        result = self.decide(different, "trusted", {"friend@example.com"})
        self.assertTrue(result["authentication"]["verified"])
        self.assertFalse(result["autoImages"])


class KeyringTests(unittest.TestCase):
    def test_missing_keyring_never_writes_plaintext_file(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "secrets.json"
            with patch.object(keyring, "_secret_tool", return_value=None), \
                 patch.object(keyring, "_FALLBACK", target):
                with self.assertRaises(keyring.SecretStorageError):
                    keyring.set_secret("test", "password", "sample")
                self.assertFalse(target.exists())

    def test_failed_keyring_never_writes_plaintext_file(self):
        failure = subprocess.CalledProcessError(1, "secret-tool")
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "secrets.json"
            with patch.object(keyring, "_secret_tool", return_value="secret-tool"), \
                 patch.object(keyring.subprocess, "run", side_effect=failure), \
                 patch.object(keyring, "_FALLBACK", target):
                with self.assertRaises(keyring.SecretStorageError):
                    keyring.set_secret("test", "refresh_token", "sample")
                self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()

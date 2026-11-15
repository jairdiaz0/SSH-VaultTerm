# Test keys

Throwaway private keys used only to test key parsing and validation. They are
not used to access any real server and must never be deployed:

| File | Format | Passphrase |
| --- | --- | --- |
| `ed25519_test` | OpenSSH (`OPENSSH PRIVATE KEY`) | none |
| `ed25519_test_encrypted` | OpenSSH, bcrypt KDF | `test-passphrase-123` |
| `rsa_test` | PKCS#1 (`RSA PRIVATE KEY`) | none |
| `ec_test` | SEC1 (`EC PRIVATE KEY`, nistp256) | none |

Regenerate with:

```sh
ssh-keygen -q -t ed25519 -N '' -C ssh-client-test-ed25519 -f ed25519_test
ssh-keygen -q -t ed25519 -N 'test-passphrase-123' -C ssh-client-test-ed25519-encrypted -f ed25519_test_encrypted
ssh-keygen -q -t rsa -b 2048 -m PEM -N '' -C ssh-client-test-rsa -f rsa_test
ssh-keygen -q -t ecdsa -b 256 -m PEM -N '' -C ssh-client-test-ec -f ec_test
```

Unsupported formats (PKCS#8, DSA, PuTTY) are built inline in the tests, so no
fixture is needed for them.

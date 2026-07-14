# Security Guidelines for SecretFinder

## Overview
This document outlines security best practices for using and developing SecretFinder, particularly in containerized and cloud environments.

---

## 🚨 Critical Issues Addressed

### 1. **Remote Code Execution via Unsafe Downloads**
**Severity**: CRITICAL

**Original Issue** (Dockerfile):
```dockerfile
RUN wget https://raw.githubusercontent.com/m4ll0k/SecretFinder/master/requirements.txt -qO - | pip3 install -r /dev/stdin
RUN wget https://raw.githubusercontent.com/m4ll0k/SecretFinder/master/SecretFinder.py -qO /usr/local/bin/SecretFinder.py
```

**Risk**: If the upstream repository is compromised, all docker builds immediately execute malicious code.

**Fix**: Use `COPY` to include verified local files.

---

### 2. **Non-Reproducible Builds**
**Severity**: HIGH

**Original Issue**:
```dockerfile
FROM python:alpine  # Latest tag = unpredictable, breaks between rebuilds
```

**Fix**: Pin specific versions:
```dockerfile
FROM python:3.11-alpine3.19
```

---

### 3. **SSL/TLS Certificate Verification Disabled**
**Severity**: HIGH

**Code Issue** (SecretFinder.py, line 376):
```python
resp = requests.get(
    url = url,
    verify = False,  # ⚠️ DANGEROUS: MITM vulnerability
    ...
)
```

**Recommendation**: Enable verification in production:
```python
# For HTTPS targets (default):
resp = requests.get(url, verify=True)  # or omit verify parameter

# For self-signed certs only:
resp = requests.get(url, verify='/path/to/ca-bundle.crt')
```

---

### 4. **Unnecessary Tools in Runtime Image**
**Severity**: MEDIUM

**Original Issue**: `wget` and build tools remain in final image, expanding attack surface.

**Fix**: Use multi-stage builds or explicit cleanup:
```dockerfile
RUN apk add --no-cache libxml2 libxslt && \
    rm -rf /var/cache/apk/*
```

---

### 5. **Running as Root**
**Severity**: MEDIUM

**Original Issue**: Container runs as root, allowing privilege escalation.

**Fix** (in hardened Dockerfile):
```dockerfile
RUN addgroup -g 1000 secretfinder && \
    adduser -D -u 1000 -G secretfinder secretfinder
USER secretfinder
```

---

## 🔒 Hardening Checklist

- [x] Pinned base image version (`python:3.11-alpine3.19`)
- [x] Local file inclusion (no remote downloads)
- [x] Non-root user execution
- [x] Explicit health check
- [x] Minimal runtime dependencies
- [x] No build tools in final image
- [x] Package manager cache cleanup
- [ ] **TODO**: Add input validation for URL schemes (prevent SSRF)
- [ ] **TODO**: Enable SSL/TLS verification by default
- [ ] **TODO**: Add rate limiting for HTTP requests
- [ ] **TODO**: Container image scanning (Trivy, Grype)

---

## 📋 Building Securely

### Local Build (Recommended)
```bash
# Verify dependencies first
cat requirements.txt
cat SecretFinder.py

# Build with hardened Dockerfile
docker build -t secretfinder:1.0.0 \
  -f Dockerfile \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .
```

### Build with Security Scanning
```bash
# Scan for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image secretfinder:1.0.0

# Or with Grype
grype secretfinder:1.0.0
```

### Image Signing (Optional but Recommended)
```bash
# Sign with Cosign
cosign sign --key cosign.key secretfinder:1.0.0
```

---

## 🐍 Runtime Security

### Environment Variables
```bash
# Disable SSL verification ONLY in dev/testing (not production!)
docker run -e PYTHONHTTPSVERIFY=0 secretfinder:1.0.0 \
  -i http://target.com -o cli
```

### Network Policies
```bash
# Restrict outbound traffic to HTTPS only
docker run --cap-drop=ALL \
  --read-only \
  --security-opt=no-new-privileges \
  secretfinder:1.0.0 \
  -i http://target.com -o cli
```

### Volume Mounts
```bash
# Read-only code, writable output only
docker run -v $(pwd)/output:/output:rw \
  --read-only \
  secretfinder:1.0.0 \
  -i http://target.com -o /output/results.html
```

---

## 🔗 Dependency Vulnerabilities

Current dependencies (requirements.txt):
- `requests` — HTTP client library
- `jsbeautifier` — JavaScript formatter
- `lxml` — XML/HTML parser
- `requests_file` — Local file support for requests

### Mitigation
- Pin exact versions in `requirements.txt`:
  ```
  requests==2.31.0
  jsbeautifier==1.14.8
  lxml==4.9.3
  requests-file==1.6.0
  ```
- Run periodic vulnerability scans:
  ```bash
  pip install -U safety
  safety check
  ```

---

## 📞 Reporting Security Issues

If you discover a security vulnerability in SecretFinder:

1. **DO NOT** open a public GitHub issue
2. Email: `security@secretfinder.local` (update with real contact)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if applicable)

---

## 📚 Additional Resources

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Container Security Scanning Tools](https://www.aquasec.com/open-source/trivy/)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-07-14 | Initial hardened Dockerfile release |

---

**Last Updated**: 2026-07-14  
**Maintainer**: Security Team
